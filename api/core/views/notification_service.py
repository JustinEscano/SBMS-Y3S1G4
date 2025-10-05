# api/core/views/notification_service.py
from django.core.mail import send_mail
from django.core.mail.backends.smtp import EmailBackend
from django.conf import settings
from django.template.loader import render_to_string
from django.utils.html import strip_tags
from django.utils import timezone
from core.models import Notification, User
import logging

logger = logging.getLogger(__name__)

NOTIFICATION_TEMPLATES = {
    'maintenance_request_created': {
        'category': 'maintenance',
        'title': lambda instance: f"Maintenance Request Submitted: {instance.equipment.name}",
        'message': lambda instance, *args: f"Your request #{instance.id} for {instance.equipment.name} has been submitted.",
        'email_template': 'emails/maintenance_request_submitted.html',
        'context': lambda instance, *args: {
            'request_id': instance.id,
            'equipment_name': instance.equipment.name,
            'issue': instance.issue,
            'comments': instance.comments or "None",
            'assigned_to': instance.assigned_to.username if instance.assigned_to else "Not assigned",
            'user': instance.user.username,
            'year': timezone.now().year,
            'status': instance.status,
            'recipient': instance.user.username,
        }
    },
    'maintenance_request_updated': {
        'category': 'maintenance',
        'title': lambda instance: f"Maintenance Request Updated: {instance.equipment.name}",
        'message': lambda instance, *args: f"Your request #{instance.id} is now {instance.status}. Assigned To: {instance.assigned_to.username if instance.assigned_to else 'Not assigned'}",
        'email_template': 'emails/maintenance_request_updated.html',
        'context': lambda instance, *args: {
            'request_id': instance.id,
            'equipment_name': instance.equipment.name,
            'issue': instance.issue,
            'comments': instance.comments or "None",
            'status': instance.status,
            'assigned_to': instance.assigned_to.username if instance.assigned_to else "Not assigned",
            'user': instance.user.username,
            'year': timezone.now().year,
            'recipient': instance.user.username,
        }
    },
    'maintenance_request_responded': {
        'category': 'maintenance',
        'title': lambda instance: f"Response to Maintenance Request: {instance.equipment.name}",
        'message': lambda instance, response_text, *args: f"Admin responded to your request #{instance.id}: {response_text}\nAssigned To: {instance.assigned_to.username if instance.assigned_to else 'Not assigned'}",
        'email_template': 'emails/maintenance_request_responded.html',
        'context': lambda instance, response_text, *args: {
            'request_id': instance.id,
            'equipment_name': instance.equipment.name,
            'response': response_text,
            'comments': instance.comments or "None",
            'assigned_to': instance.assigned_to.username if instance.assigned_to else "Not assigned",
            'user': instance.user.username,
            'year': timezone.now().year,
            'status': instance.status,
            'recipient': instance.user.username,
        }
    },
    'maintenance_attachment_uploaded': {
        'category': 'maintenance',
        'title': lambda instance: f"New Attachment: {instance.equipment.name}",
        'message': lambda instance, attachment, *args: f"An attachment was added to your request #{instance.id}.",
        'email_template': 'emails/maintenance_attachment_uploaded.html',
        'context': lambda instance, attachment, *args: {
            'request_id': instance.id,
            'equipment_name': instance.equipment.name,
            'file_name': attachment.file_name,
            'user': instance.user.username,
            'uploaded_by': args[-1].user.username if args and args[-1].user else 'Unknown',
            'year': timezone.now().year,
            'recipient': instance.user.username,
        }
    },
    'predictive_alert_created': {
        'category': 'alert',
        'title': lambda instance: f"Predictive Alert: {instance.component.component_type} Failure Likely",
        'message': lambda instance, *args: f"LLM predicts failure for {instance.component.component_type} on {instance.component.equipment.name} (Confidence: {instance.confidence}).",
        'email_template': 'emails/predictive_alert_created.html',
        'context': lambda instance, *args: {
            'alert_id': instance.id,
            'component_name': instance.component.component_type,
            'equipment_name': instance.component.equipment.name,
            'prediction': instance.prediction,
            'confidence': instance.confidence,
            'user': args[-1].user.username if args and args[-1].user else 'Admin',
            'year': timezone.now().year,
            'recipient': args[-1].user.username if args and args[-1].user else 'Admin',
        }
    }
}

class NotificationService:
    """Centralized service for handling notifications (in-app and email)"""
    _admin_users = None

    @classmethod
    def get_admin_users(cls):
        if cls._admin_users is None:
            cls._admin_users = list(User.objects.filter(role__in=['admin', 'superadmin']))
        return cls._admin_users

    @staticmethod
    def send_notification(user, notification_type, instance, request=None, response_text=None, attachment=None):
        try:
            recent_notification = Notification.objects.filter(
                user=user,
                category=NOTIFICATION_TEMPLATES[notification_type]['category'],
                title=NOTIFICATION_TEMPLATES[notification_type]['title'](instance),
                created_at__gte=timezone.now() - timezone.timedelta(minutes=5)
            ).exists()
            if recent_notification:
                logger.info(f"Skipped duplicate notification for {user.username} (Type: {notification_type}, User ID: {user.id})")
                return

            notification = Notification.objects.create(
                user=user,
                title=NOTIFICATION_TEMPLATES[notification_type]['title'](instance),
                message=NOTIFICATION_TEMPLATES[notification_type]['message'](instance, response_text) if response_text else
                        NOTIFICATION_TEMPLATES[notification_type]['message'](instance, attachment, request) if attachment else
                        NOTIFICATION_TEMPLATES[notification_type]['message'](instance),
                read=False,
                category=NOTIFICATION_TEMPLATES[notification_type]['category']
            )
            logger.info(f"In-app notification created for {user.username} (ID: {notification.id}, Type: {notification_type}, User ID: {user.id})")

            email_template = NOTIFICATION_TEMPLATES[notification_type].get('email_template')
            if email_template:
                context = NOTIFICATION_TEMPLATES[notification_type]['context'](
                    instance, response_text, request, user.username
                ) if response_text else NOTIFICATION_TEMPLATES[notification_type]['context'](
                    instance, attachment, request, user.username
                ) if attachment else NOTIFICATION_TEMPLATES[notification_type]['context'](instance, user.username)
                
                html_message = render_to_string(email_template, context)
                plain_message = strip_tags(html_message)
                subject = f"SBMS: {NOTIFICATION_TEMPLATES[notification_type]['title'](instance)}"
                email_backend = EmailBackend(
                    host='smtp.gmail.com',
                    port=587,
                    username=settings.ADMIN_EMAIL_USER if user.role in ['admin', 'superadmin'] else settings.EMPLOYEE_EMAIL_USER,
                    password=settings.ADMIN_EMAIL_PASSWORD if user.role in ['admin', 'superadmin'] else settings.EMPLOYEE_EMAIL_PASSWORD,
                    use_tls=True,
                )
                try:
                    send_mail(
                        subject=subject,
                        message=plain_message,
                        html_message=html_message,
                        from_email=email_backend.username,
                        recipient_list=[user.email],
                        fail_silently=False,
                        connection=email_backend,
                    )
                    logger.info(f"Email sent to {user.email} (Notification ID: {notification.id}, Type: {notification_type}, User ID: {user.id})")
                except Exception as e:
                    logger.error(f"Failed to send email to {user.email} (Notification ID: {notification.id}, Type: {notification_type}, User ID: {user.id}): {str(e)}")
                
        except Exception as e:
            logger.error(f"Failed to send notification to {user.email} (Type: {notification_type}, User ID: {user.id}): {str(e)}")
            raise

    @staticmethod
    def notify_maintenance_request_created(instance, request):
        NotificationService.send_notification(
            user=instance.user,
            notification_type='maintenance_request_created',
            instance=instance,
            request=request
        )
        for admin in NotificationService.get_admin_users():
            NotificationService.send_notification(
                user=admin,
                notification_type='maintenance_request_created',
                instance=instance,
                request=request
            )
        if instance.assigned_to:
            NotificationService.send_notification(
                user=instance.assigned_to,
                notification_type='maintenance_request_created',
                instance=instance,
                request=request
            )

    @staticmethod
    def notify_maintenance_request_updated(instance, request, assigned_changed=False):
        NotificationService.send_notification(
            user=instance.user,
            notification_type='maintenance_request_updated',
            instance=instance,
            request=request
        )
        for admin in NotificationService.get_admin_users():
            NotificationService.send_notification(
                user=admin,
                notification_type='maintenance_request_updated',
                instance=instance,
                request=request
            )
        if assigned_changed and instance.assigned_to:
            NotificationService.send_notification(
                user=instance.assigned_to,
                notification_type='maintenance_request_updated', 
                instance=instance,
                request=request
            )

    @staticmethod
    def notify_maintenance_request_responded(maintenance_request, response_text, request):
        NotificationService.send_notification(
            user=maintenance_request.user,
            notification_type='maintenance_request_responded',
            instance=maintenance_request,
            request=request,
            response_text=response_text
        )
        if maintenance_request.assigned_to:
            NotificationService.send_notification(
                user=maintenance_request.assigned_to,
                notification_type='maintenance_request_responded',
                instance=maintenance_request,
                request=request,
                response_text=response_text
            )

    @staticmethod
    def notify_maintenance_attachment_uploaded(maintenance_request, attachment, request):
        NotificationService.send_notification(
            user=maintenance_request.user,
            notification_type='maintenance_attachment_uploaded',
            instance=maintenance_request,
            request=request,
            attachment=attachment
        )
        for admin in NotificationService.get_admin_users():
            NotificationService.send_notification(
                user=admin,
                notification_type='maintenance_attachment_uploaded',
                instance=maintenance_request,
                request=request,
                attachment=attachment
            )

    @staticmethod
    def notify_predictive_alert_created(predictive_alert, request):
        for admin in NotificationService.get_admin_users():
            NotificationService.send_notification(
                user=admin,
                notification_type='predictive_alert_created',
                instance=predictive_alert,
                request=request
            )