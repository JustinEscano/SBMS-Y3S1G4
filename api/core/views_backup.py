from rest_framework import viewsets, generics
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone
from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from django.db.models import Avg, Count, StdDev, Sum, Max, Min
from django.core.mail import send_mail
from django.core.mail.backends.smtp import EmailBackend
from django.conf import settings
from django.template.loader import render_to_string
from django.utils.html import strip_tags
from .models import *
from .serializers import *
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework_simplejwt.views import TokenObtainPairView
from .permissions import RoleBasedPermission
import logging
import datetime
from django.db.models import Q
import uuid
from dateutil.relativedelta import relativedelta

# Set up logging
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
    _admin_users = None  # Cache for admin users

    @classmethod
    def get_admin_users(cls):
        """Cache and return admin users"""
        if cls._admin_users is None:
            cls._admin_users = list(User.objects.filter(role__in=['admin', 'superadmin']))
        return cls._admin_users

    @staticmethod
    def send_notification(user, notification_type, instance, request=None, response_text=None, attachment=None):
        """Send notification based on type, with rate limiting and enhanced logging"""
        try:
            # Rate limiting: Check for recent similar notifications
            recent_notification = Notification.objects.filter(
                user=user,
                category=NOTIFICATION_TEMPLATES[notification_type]['category'],
                title=NOTIFICATION_TEMPLATES[notification_type]['title'](instance),
                created_at__gte=timezone.now() - timezone.timedelta(minutes=5)
            ).exists()
            if recent_notification:
                logger.info(f"Skipped duplicate notification for {user.username} (Type: {notification_type}, User ID: {user.id})")
                return

            # Create in-app notification
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

            # Send email if template is defined
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
                    # Store failed email attempt for retry (optional, can be implemented later)
                
        except Exception as e:
            logger.error(f"Failed to send notification to {user.email} (Type: {notification_type}, User ID: {user.id}): {str(e)}")
            raise

    @staticmethod
    def notify_maintenance_request_created(instance, request):
        # Notify the user who created the request
        NotificationService.send_notification(
            user=instance.user,
            notification_type='maintenance_request_created',
            instance=instance,
            request=request
        )
        # Notify admins
        for admin in NotificationService.get_admin_users():
            NotificationService.send_notification(
                user=admin,
                notification_type='maintenance_request_created',
                instance=instance,
                request=request
            )
        # Notify assigned employee
        if instance.assigned_to:
            NotificationService.send_notification(
                user=instance.assigned_to,
                notification_type='maintenance_request_created',
                instance=instance,
                request=request
            )

    @staticmethod
    def notify_maintenance_request_updated(instance, request, assigned_changed=False):
        # Notify the user
        NotificationService.send_notification(
            user=instance.user,
            notification_type='maintenance_request_updated',
            instance=instance,
            request=request
        )
        # Notify admins
        for admin in NotificationService.get_admin_users():
            NotificationService.send_notification(
                user=admin,
                notification_type='maintenance_request_updated',
                instance=instance,
                request=request
            )
        # Notify new assignee if changed
        if assigned_changed and instance.assigned_to:
            NotificationService.send_notification(
                user=instance.assigned_to,
                notification_type='maintenance_request_updated', 
                instance=instance,
                request=request
            )

    @staticmethod
    def notify_maintenance_request_responded(maintenance_request, response_text, request):
        # Notify the user
        NotificationService.send_notification(
            user=maintenance_request.user,
            notification_type='maintenance_request_responded',
            instance=maintenance_request,
            request=request,
            response_text=response_text
        )
        # Notify assigned employee
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
        # Notify the user
        NotificationService.send_notification(
            user=maintenance_request.user,
            notification_type='maintenance_attachment_uploaded',
            instance=maintenance_request,
            request=request,
            attachment=attachment
        )
        # Notify admins
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
        # Notify admins
        for admin in NotificationService.get_admin_users():
            NotificationService.send_notification(
                user=admin,
                notification_type='predictive_alert_created',
                instance=predictive_alert,
                request=request
            )

class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    username_field = User.EMAIL_FIELD
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token['role'] = user.role
        return token

class CustomTokenObtainPairView(TokenObtainPairView):
    serializer_class = CustomTokenObtainPairSerializer

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [AllowAny]

def home(request):
    return HttpResponse("Welcome to the DBMS API.")

class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [RoleBasedPermission]

class RoomViewSet(viewsets.ModelViewSet):
    queryset = Room.objects.all()
    serializer_class = RoomSerializer
    permission_classes = [RoleBasedPermission]

class EquipmentViewSet(viewsets.ModelViewSet):
    queryset = Equipment.objects.all()
    serializer_class = EquipmentSerializer
    permission_classes = [RoleBasedPermission]
    def perform_create(self, serializer):
        instance = serializer.save()
        instance.generate_qr_code()
        logger.info(f"Equipment created: {instance.id} - {instance.name}")

class ComponentViewSet(viewsets.ModelViewSet):
    queryset = Component.objects.select_related('equipment').all()
    serializer_class = ComponentSerializer
    permission_classes = [RoleBasedPermission]
    def get_queryset(self):
        queryset = super().get_queryset()
        user = self.request.user
        if hasattr(user, 'role') and user.role == 'client':
            return queryset.filter(equipment__maintenancerequest__user=user).distinct()
        return queryset

class SensorLogViewSet(viewsets.ModelViewSet):
    queryset = SensorLog.objects.select_related('equipment', 'component').order_by('-recorded_at')
    serializer_class = SensorLogSerializer
    permission_classes = [RoleBasedPermission]
    def get_queryset(self):
        queryset = super().get_queryset()
        user = self.request.user
        if hasattr(user, 'role') and user.role == 'client':
            queryset = queryset.filter(equipment__maintenancerequest__user=user).distinct()
        
        # Apply query parameter filters
        room_id = self.request.query_params.get('room_id')
        component_id = self.request.query_params.get('component_id')
        period_start = self.request.query_params.get('period_start')
        period_end = self.request.query_params.get('period_end')
        
        if room_id:
            try:
                uuid.UUID(room_id)
                queryset = queryset.filter(equipment__room_id=room_id)
            except ValueError:
                logger.error(f"Invalid room_id format: {room_id}")
                raise ValueError("Invalid room_id format. Must be a valid UUID")
        if component_id:
            try:
                uuid.UUID(component_id)
                queryset = queryset.filter(component_id=component_id)
            except ValueError:
                logger.error(f"Invalid component_id format: {component_id}")
                raise ValueError("Invalid component_id format. Must be a valid UUID")
        if period_start:
            try:
                period_start = timezone.datetime.fromisoformat(period_start.replace('Z', '+00:00'))
                queryset = queryset.filter(recorded_at__gte=period_start)
            except ValueError:
                logger.error(f"Invalid period_start format: {period_start}")
                raise ValueError("Invalid period_start format. Use ISO format")
        if period_end:
            try:
                period_end = timezone.datetime.fromisoformat(period_end.replace('Z', '+00:00'))
                queryset = queryset.filter(recorded_at__lte=period_end)
            except ValueError:
                logger.error(f"Invalid period_end format: {period_end}")
                raise ValueError("Invalid period_end format. Use ISO format")
        
        return queryset

class HeartbeatLogViewSet(viewsets.ModelViewSet):
    queryset = HeartbeatLog.objects.select_related('equipment').order_by('-recorded_at')
    serializer_class = HeartbeatLogSerializer
    permission_classes = [RoleBasedPermission]
    def get_queryset(self):
        queryset = super().get_queryset()
        user = self.request.user
        if hasattr(user, 'role') and user.role == 'client':
            return queryset.filter(equipment__maintenancerequest__user=user).distinct()
        return queryset

class EnergySummaryViewSet(viewsets.ModelViewSet):
    queryset = EnergySummary.objects.select_related('component', 'room').order_by('-period_start')
    serializer_class = EnergySummarySerializer
    permission_classes = [RoleBasedPermission]

    def get_queryset(self):
        queryset = super().get_queryset()
        user = self.request.user
        period_type = self.request.query_params.get('period_type')
        room_id = self.request.query_params.get('room_id')
        period_start_str = self.request.query_params.get('start_time')  # Match app's param name

        if hasattr(user, 'role') and user.role == 'client':
            queryset = queryset.filter(room__maintenancerequest__user=user).distinct()

        if period_type:
            queryset = queryset.filter(period_type=period_type)

        if room_id:
            queryset = queryset.filter(room_id=room_id)

        if period_start_str:
            try:
                period_start_dt = timezone.datetime.fromisoformat(period_start_str.replace('Z', '+00:00'))
                queryset = queryset.filter(period_start__gte=period_start_dt)
            except ValueError:
                logger.error(f"Invalid start_time format: {period_start_str}")

        return queryset

    def list(self, request, *args, **kwargs):
        period_type = request.query_params.get('period_type')
        period_start_str = request.query_params.get('start_time')
        room_id = request.query_params.get('room_id')

        if period_start_str:
            try:
                period_start = timezone.datetime.fromisoformat(period_start_str.replace('Z', '+00:00'))
            except ValueError:
                return Response({'error': 'Invalid start_time format'}, status=status.HTTP_400_BAD_REQUEST)
        else:
            period_start = None

        if period_type in ['weekly', 'monthly']:
            if not period_start:
                return Response({'error': 'start_time is required for weekly/monthly summaries'}, status=status.HTTP_400_BAD_REQUEST)

            # Determine period_end based on period_type
            if period_type == 'weekly':
                period_end = period_start + timezone.timedelta(days=7)
            else:  # monthly
                period_end = period_start + relativedelta(months=1)

            # Fetch daily summaries in the period
            daily_qs = EnergySummary.objects.filter(
                period_type='daily',
                period_start__gte=period_start,
                period_end__lte=period_end,
            )
            if room_id:
                daily_qs = daily_qs.filter(room_id=room_id)

            if not daily_qs.exists():
                # Return zero-filled summary
                zero_data = {
                    'id': None,
                    'component': None,
                    'room': room_id,
                    'period_start': period_start.isoformat(),
                    'period_end': period_end.isoformat(),
                    'period_type': period_type,
                    'total_energy': 0.0,
                    'avg_power': 0.0,
                    'peak_power': 0.0,
                    'reading_count': 0,
                    'anomaly_count': 0,
                    'total_cost': 0.0,
                    'currency': 'PHP',
                    'effective_rate': 0.0,
                }
                return Response([zero_data])

            # Aggregate data
            agg = daily_qs.aggregate(
                total_energy=Sum('total_energy'),
                avg_power=Avg('avg_power'),
                peak_power=Max('peak_power'),
                reading_count=Sum('reading_count'),
                anomaly_count=Sum('anomaly_count'),
                total_cost=Sum('total_cost'),
            )

            effective_rate = agg['total_cost'] / agg['total_energy'] if agg['total_energy'] else 0.0
            currency = daily_qs.first().currency  # Assume consistent currency

            aggregated_data = {
                'id': None,  # Aggregated, no single ID
                'component': None,
                'room': room_id,
                'period_start': period_start.isoformat(),
                'period_end': period_end.isoformat(),
                'period_type': period_type,
                'total_energy': agg['total_energy'] or 0.0,
                'avg_power': agg['avg_power'] or 0.0,
                'peak_power': agg['peak_power'] or 0.0,
                'reading_count': agg['reading_count'] or 0,
                'anomaly_count': agg['anomaly_count'] or 0,
                'total_cost': agg['total_cost'] or 0.0,
                'currency': currency,
                'effective_rate': effective_rate,
            }
            return Response([aggregated_data])

        # For daily (or other), use standard queryset with filtering
        queryset = self.filter_queryset(self.get_queryset())
        if not queryset.exists() and period_type == 'daily':
            # Return zero-filled for daily if no data
            zero_data = {
                'id': None,
                'component': None,
                'room': room_id,
                'period_start': period_start.isoformat() if period_start else timezone.now().isoformat(),
                'period_end': (period_start + timezone.timedelta(days=1)).isoformat() if period_start else timezone.now().isoformat(),
                'period_type': 'daily',
                'total_energy': 0.0,
                'avg_power': 0.0,
                'peak_power': 0.0,
                'reading_count': 0,
                'anomaly_count': 0,
                'total_cost': 0.0,
                'currency': 'PHP',
                'effective_rate': 0.0,
            }
            return Response([zero_data])

        page = self.paginate_queryset(queryset)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)

        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

class PredictiveAlertViewSet(viewsets.ModelViewSet):
    queryset = PredictiveAlert.objects.select_related('component', 'component__equipment').order_by('-triggered_at')
    serializer_class = PredictiveAlertSerializer
    permission_classes = [RoleBasedPermission]
    def get_queryset(self):
        queryset = super().get_queryset()
        user = self.request.user
        if hasattr(user, 'role') and user.role == 'client':
            return queryset.filter(component__equipment__maintenancerequest__user=user).distinct()
        resolved = self.request.query_params.get('resolved')
        if resolved is not None:
            resolved_bool = resolved.lower() == 'true'
            queryset = queryset.filter(resolved=resolved_bool)
        return queryset

class BillingRateViewSet(viewsets.ModelViewSet):
    queryset = BillingRate.objects.select_related('room').order_by('-created_at')
    serializer_class = BillingRateSerializer
    permission_classes = [RoleBasedPermission]
    
    def get_queryset(self):
        queryset = super().get_queryset()
        user = self.request.user
        if hasattr(user, 'role') and user.role == 'client':
            return queryset.filter(room__maintenancerequest__user=user).distinct()
        room_id = self.request.query_params.get('room_id')
        if room_id:
            return queryset.filter(room_id=room_id)
        return queryset
    
    @action(detail=False, methods=['get'], permission_classes=[RoleBasedPermission])
    def debug_test(self, request):
        logger.info("Debug test endpoint hit with params: %s", request.query_params)
        return Response({
            'success': True,
            'message': 'BillingRateViewSet debug endpoint working',
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_200_OK)
    
    @action(detail=False, methods=['get'], permission_classes=[RoleBasedPermission])
    def calculate_energy_cost(self, request):
        logger.info("Energy cost calculation requested with params: %s", request.query_params)
        try:
            room_id = request.query_params.get('room_id')
            equipment_id = request.query_params.get('equipment_id')
            component_id = request.query_params.get('component')
            period_start = request.query_params.get('period_start')
            period_end = request.query_params.get('period_end')
            period_type = request.query_params.get('period_type')

            if not period_start or not period_end or not period_type:
                logger.error("Missing required query parameters: period_start, period_end, period_type")
                return Response(
                    {'error': 'period_start, period_end, and period_type are required'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            try:
                period_start = timezone.datetime.fromisoformat(period_start.replace('Z', '+00:00'))
                period_end = timezone.datetime.fromisoformat(period_end.replace('Z', '+00:00'))
                # Extend period_end by 1 second to account for microsecond precision
                period_end = period_end + timezone.timedelta(seconds=1)
            except ValueError:
                logger.error("Invalid date format: period_start=%s, period_end=%s", period_start, period_end)
                return Response(
                    {'error': 'Invalid date format. Use ISO format (e.g., 2025-09-27T00:00:00Z)'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            if period_type not in [choice[0] for choice in PERIOD_TYPE_CHOICES]:
                logger.error(f"Invalid period_type: {period_type}")
                return Response(
                    {'error': f"Invalid period_type. Must be one of: {', '.join([choice[0] for choice in PERIOD_TYPE_CHOICES])}"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Debug query
            energy_summaries = EnergySummary.objects.filter(
                period_start__gte=period_start,
                period_end__lte=period_end,
                period_type='daily'
            )
            logger.info("Initial query count: %s", energy_summaries.count())
            if room_id:
                try:
                    uuid.UUID(room_id)
                    energy_summaries = energy_summaries.filter(room_id=room_id)
                    logger.info("After room_id filter (%s): %s", room_id, energy_summaries.count())
                except ValueError:
                    logger.error(f"Invalid room_id format: {room_id}")
                    return Response(
                        {'error': 'Invalid room_id format. Must be a valid UUID'},
                        status=status.HTTP_400_BAD_REQUEST
                    )
            if equipment_id:
                try:
                    uuid.UUID(equipment_id)
                    energy_summaries = energy_summaries.filter(component__equipment_id=equipment_id)
                    logger.info("After equipment_id filter (%s): %s", equipment_id, energy_summaries.count())
                except ValueError:
                    logger.error(f"Invalid equipment_id format: {equipment_id}")
                    return Response(
                        {'error': 'Invalid equipment_id format. Must be a valid UUID'},
                        status=status.HTTP_400_BAD_REQUEST
                    )
            if component_id:
                try:
                    uuid.UUID(component_id)
                    energy_summaries = energy_summaries.filter(component_id=component_id)
                    logger.info("After component_id filter (%s): %s", component_id, energy_summaries.count())
                except ValueError:
                    logger.error(f"Invalid component_id format: {component_id}")
                    return Response(
                        {'error': 'Invalid component_id format. Must be a valid UUID'},
                        status=status.HTTP_400_BAD_REQUEST
                    )

            # Log all EnergySummary records for debugging
            all_summaries = EnergySummary.objects.filter(
                period_type='daily',
                room_id=room_id,
                component_id=component_id
            ).values('id', 'period_start', 'period_end', 'total_energy', 'total_cost')
            logger.info("All matching EnergySummaries: %s", list(all_summaries))

            if not energy_summaries.exists():
                logger.info("No daily energy summaries found for criteria: room_id=%s, equipment_id=%s, component_id=%s, period_start=%s, period_end=%s",
                           room_id, equipment_id, component_id, period_start.isoformat(), period_end.isoformat())
                return Response(
                    {'success': True, 'data': {'total_cost': 0, 'details': []}, 'timestamp': timezone.now().isoformat()},
                    status=status.HTTP_200_OK
                )

            total_cost = 0
            total_energy = 0
            details = []
            for summary in energy_summaries:
                rate = BillingRate.objects.filter(
                    Q(room=summary.room) | Q(room__isnull=True),
                    Q(valid_from__lte=summary.period_start) | Q(valid_from__isnull=True),
                    Q(valid_to__gte=summary.period_start) | Q(valid_to__isnull=True)
                ).order_by('-created_at').first()

                if not rate:
                    logger.warning(f"No billing rate found for room {summary.room.name} on %s", summary.period_start)
                    details.append({
                        'room_id': str(summary.room.id),
                        'room_name': summary.room.name,
                        'component_id': str(summary.component.id),
                        'component_type': summary.component.component_type,
                        'total_energy': summary.total_energy,
                        'rate_per_kwh': 0,
                        'effective_rate': 0,
                        'currency': 'PHP',
                        'cost': 0,
                        'period_start': summary.period_start.isoformat(),
                        'period_end': summary.period_end.isoformat(),
                    })
                    continue

                cost = summary.total_energy * rate.get_rate_for_time(summary.period_start)
                total_cost += cost
                total_energy += summary.total_energy
                details.append({
                    'room_id': str(summary.room.id),
                    'room_name': summary.room.name,
                    'component_id': str(summary.component.id),
                    'component_type': summary.component.component_type,
                    'total_energy': summary.total_energy,
                    'rate_per_kwh': rate.rate_per_kwh,
                    'effective_rate': rate.get_rate_for_time(summary.period_start),
                    'currency': rate.currency,
                    'cost': round(cost, 2),
                    'period_start': summary.period_start.isoformat(),
                    'period_end': summary.period_end.isoformat(),
                })

            effective_rate = total_cost / total_energy if total_energy > 0 else 0
            logger.info(f"Calculated total_cost=%s, total_energy=%s, effective_rate=%s, currency=%s for %s summaries",
                       total_cost, total_energy, effective_rate, rate.currency if rate else 'PHP', len(details))
            return Response({
                'success': True,
                'data': {
                    'total_cost': round(total_cost, 2),
                    'effective_rate': round(effective_rate, 2),
                    'currency': rate.currency if rate else 'PHP',
                    'details': details
                },
                'timestamp': timezone.now().isoformat()
            }, status=status.HTTP_200_OK)

        except Exception as e:
            logger.error(f"Error in calculate_energy_cost: {str(e)}")
            return Response(
                {'error': f'Server error: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=False, methods=['get'], permission_classes=[RoleBasedPermission])
    def energy_cost_simple(self, request):
        # [Existing energy_cost_simple unchanged]
        logger.info("Simple energy cost calculation requested with params: %s", request.query_params)
        try:
            room_id = request.query_params.get('room_id')
            period_type = request.query_params.get('period_type')
            date = request.query_params.get('date')

            if not room_id or not period_type or not date:
                logger.error("Missing required query parameters")
                return Response(
                    {'error': 'room_id, period_type, and date are required'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            try:
                date = timezone.datetime.fromisoformat(date.replace('Z', '+00:00')).date()
            except ValueError:
                logger.error("Invalid date format: %s", date)
                return Response(
                    {'error': 'Invalid date format. Use ISO format (e.g., 2025-09-27)'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            if period_type not in [choice[0] for choice in PERIOD_TYPE_CHOICES]:
                logger.error(f"Invalid period_type: {period_type}")
                return Response(
                    {'error': f"Invalid period_type. Must be one of: {', '.join([choice[0] for choice in PERIOD_TYPE_CHOICES])}"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            try:
                uuid.UUID(room_id)
            except ValueError:
                logger.error(f"Invalid room_id format: {room_id}")
                return Response(
                    {'error': 'Invalid room_id format. Must be a valid UUID'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            summary = EnergySummary.objects.filter(
                room_id=room_id,
                period_type=period_type,
                period_start__date=date
            ).select_related('room', 'component').first()

            if not summary:
                logger.info(f"No energy summary found for room %s, period %s, date %s", room_id, period_type, date)
                return Response(
                    {'error': 'No data for this period'},
                    status=status.HTTP_404_NOT_FOUND
                )

            rate = BillingRate.objects.filter(
                Q(room=summary.room) | Q(room__isnull=True),
                Q(valid_from__lte=summary.period_start) | Q(valid_from__isnull=True),
                Q(valid_to__gte=summary.period_start) | Q(valid_to__isnull=True)
            ).order_by('-created_at').first()

            total_cost = 0
            effective_rate = 0
            rate_per_kwh = 0
            currency = 'PHP'
            if rate:
                effective_rate = rate.get_rate_for_time(summary.period_start)
                rate_per_kwh = rate.rate_per_kwh
                total_cost = round(summary.total_energy * effective_rate, 2)
                currency = rate.currency
            else:
                logger.warning(f"No applicable billing rate found for room %s", summary.room.name)

            data = {
                'room_id': str(summary.room.id),
                'room_name': summary.room.name,
                'component_id': str(summary.component.id),
                'component_type': summary.component.component_type,
                'period_type': summary.period_type,
                'period_start': summary.period_start.isoformat(),
                'period_end': summary.period_end.isoformat(),
                'total_energy': summary.total_energy,
                'rate_per_kwh': rate_per_kwh,
                'effective_rate': effective_rate,
                'currency': currency,
                'total_cost': total_cost,
            }

            logger.info(f"Simple energy cost: %s %s for room %s, period %s, date %s", total_cost, currency, room_id, period_type, date)
            return Response({
                'success': True,
                'data': data,
                'timestamp': timezone.now().isoformat()
            }, status=status.HTTP_200_OK)

        except Exception as e:
            logger.error(f"Error in energy_cost_simple: %s", str(e))
            return Response(
                {'error': f'Server error: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class AlertViewSet(viewsets.ModelViewSet):
    queryset = Alert.objects.select_related('equipment').all()
    serializer_class = AlertSerializer
    permission_classes = [RoleBasedPermission]

    def get_queryset(self):
        queryset = super().get_queryset()
        user = self.request.user
        if hasattr(user, 'role') and user.role == 'client':
            queryset = queryset.filter(equipment__maintenancerequest__user=user).distinct()
        resolved = self.request.query_params.get('resolved')
        severity = self.request.query_params.get('severity')
        alert_type = self.request.query_params.get('type')
        if resolved is not None:
            resolved_bool = resolved.lower() == 'true'
            queryset = queryset.filter(resolved=resolved_bool)
        if severity:
            queryset = queryset.filter(severity=severity)
        if alert_type:
            queryset = queryset.filter(type=alert_type)
        return queryset

class MaintenanceAttachmentViewSet(viewsets.ModelViewSet):
    queryset = MaintenanceAttachment.objects.select_related('maintenance_request', 'uploaded_by').all()
    serializer_class = MaintenanceAttachmentSerializer
    permission_classes = [RoleBasedPermission]
    def get_queryset(self):
        queryset = super().get_queryset()
        user = self.request.user
        if hasattr(user, 'role') and user.role == 'client':
            return queryset.filter(maintenance_request__user=user)
        return queryset

class MaintenanceRequestViewSet(viewsets.ModelViewSet):
    queryset = MaintenanceRequest.objects.select_related('user', 'equipment', 'assigned_to').prefetch_related('attachments').all()
    serializer_class = MaintenanceRequestSerializer
    permission_classes = [RoleBasedPermission]
    def get_queryset(self):
        queryset = super().get_queryset()
        user = self.request.user
        if hasattr(user, 'role'):
            if user.role == 'client':
                return queryset.filter(user=user)
            elif user.role == 'employee':
                return queryset.filter(assigned_to=user)
        return queryset
    def perform_create(self, serializer):
        instance = serializer.save(user=self.request.user)
        logger.info(f"Maintenance request created: {instance.id} by {self.request.user.username}")
        NotificationService.notify_maintenance_request_created(instance, self.request)
    def perform_update(self, serializer):
        logger.info(f"Updating maintenance request {self.get_object().id} by user {self.request.user.username}")
        old_assigned_to = self.get_object().assigned_to
        instance = serializer.save()
        assigned_changed = 'assigned_to' in serializer.validated_data and instance.assigned_to != old_assigned_to
        logger.info(f"Updated maintenance request {instance.id} with status {instance.status}")
        NotificationService.notify_maintenance_request_updated(instance, self.request, assigned_changed)
    @action(detail=True, methods=['post'], permission_classes=[RoleBasedPermission])
    def respond(self, request, pk=None):
        logger.info(f"Response requested for maintenance request {pk}")
        try:
            maintenance_request = self.get_object()
            response_text = request.data.get('response')
            assigned_to_id = request.data.get('assigned_to')
            if not response_text:
                logger.error("Missing response field")
                return Response(
                    {'error': 'Response field is required'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            old_assigned_to = maintenance_request.assigned_to
            if assigned_to_id:
                try:
                    new_assigned_to = User.objects.get(id=assigned_to_id)
                    maintenance_request.assigned_to = new_assigned_to
                except User.DoesNotExist:
                    logger.error(f"User with id {assigned_to_id} not found")
                    return Response(
                        {'error': f'User with id {assigned_to_id} not found'},
                        status=status.HTTP_400_BAD_REQUEST
                    )
            current_time = timezone.now().strftime('%Y-%m-%d %H:%M:%S')
            new_comment = f"\n[{current_time}] {request.user.username} (Admin): {response_text}"
            maintenance_request.comments = (maintenance_request.comments or '') + new_comment
            maintenance_request.save()
            NotificationService.notify_maintenance_request_responded(maintenance_request, response_text, request)
            if assigned_to_id and maintenance_request.assigned_to != old_assigned_to:
                NotificationService.notify_maintenance_request_updated(maintenance_request, request, assigned_changed=True)
            logger.info(f"Response added to maintenance request {pk} by {request.user.username}")
            return Response(
                MaintenanceRequestSerializer(maintenance_request).data,
                status=status.HTTP_200_OK
            )
        except Exception as e:
            logger.error(f"Error adding response: {str(e)}")
            return Response(
                {'error': f'Server error: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    @action(detail=True, methods=['post'], permission_classes=[RoleBasedPermission])
    def upload_attachment(self, request, pk=None):
        logger.info(f"Attachment upload requested for maintenance request {pk}")
        try:
            maintenance_request = self.get_object()
            file_obj = request.FILES.get('file')
            file_name = request.data.get('file_name', file_obj.name if file_obj else None)
            if not file_obj or not file_name:
                logger.error("Missing file or file_name")
                return Response(
                    {'error': 'Both file and file_name are required'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            attachment = MaintenanceAttachment.objects.create(
                maintenance_request=maintenance_request,
                file=file_obj,
                file_name=file_name,
                file_type=file_obj.content_type,
                uploaded_by=request.user
            )
            NotificationService.notify_maintenance_attachment_uploaded(maintenance_request, attachment, request)
            logger.info(f"Attachment uploaded: {attachment.id} for {maintenance_request.id}")
            return Response(
                MaintenanceAttachmentSerializer(attachment).data,
                status=status.HTTP_201_CREATED
            )
        except Exception as e:
            logger.error(f"Error uploading attachment: {str(e)}")
            return Response(
                {'error': f'Server error: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class NotificationViewSet(viewsets.ModelViewSet):
    queryset = Notification.objects.select_related('user').order_by('-created_at')
    serializer_class = NotificationSerializer
    permission_classes = [RoleBasedPermission]

    def get_queryset(self):
        queryset = self.queryset
        user = self.request.user
        user_id = self.request.query_params.get('user')

        # Allow ?user=<id> for admin/superadmin
        if user_id and hasattr(user, 'role') and user.role in ['admin', 'superadmin']:
            queryset = queryset.filter(user_id=user_id)
        elif hasattr(user, 'role') and user.role == 'client':
            queryset = queryset.filter(user=user)

        return queryset

    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated])
    def mark_all_read(self, request):
        user = request.user
        if hasattr(user, 'role') and user.role == 'client':
            notifications = Notification.objects.filter(user=user, read=False)
        else:
            notifications = Notification.objects.filter(read=False)
        count = notifications.update(read=True)
        logger.info(f"Marked {count} notifications as read for {user.username} (User ID: {user.id})")
        return Response({'status': f'{count} notifications marked as read'})

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def mark_read(self, request, pk=None):
        """Mark a single notification as read"""
        notification = get_object_or_404(Notification, pk=pk)
        if request.user.role == 'client' and notification.user != request.user:
            logger.warning(f"User {request.user.username} (ID: {request.user.id}) attempted to mark notification {pk} as read without permission")
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)
        notification.read = True
        notification.save()
        logger.info(f"Notification {pk} marked as read for {request.user.username} (User ID: {request.user.id})")
        return Response({'status': 'Notification marked as read'})

class LLMQueryViewSet(viewsets.ModelViewSet):
    queryset = LLMQuery.objects.select_related('user').all()
    serializer_class = LLMQuerySerializer
    permission_classes = [RoleBasedPermission]

class LLMSummaryViewSet(viewsets.ModelViewSet):
    queryset = LLMSummary.objects.all()
    serializer_class = LLMSummarySerializer
    permission_classes = [RoleBasedPermission]

class AuthTokenViewSet(viewsets.ModelViewSet):
    queryset = AuthToken.objects.select_related('user').all()
    serializer_class = AuthTokenSerializer
    permission_classes = [RoleBasedPermission]

@api_view(['POST'])
@permission_classes([AllowAny])
def esp32_heartbeat(request):
    """
    Endpoint for ESP32 to send heartbeat and update status
    Expected JSON format:
    {
        "device_id": "ESP32_001",
        "timestamp": 123456,
        "dht22_working": true,
        "pzem_working": true,
        "photoresistor_working": true,
        "success_rate": 95.0,
        "wifi_signal": -50,
        "uptime": 123,
        "sensor_type": "DHT22_3PIN_MODULE_GPIO5_PZEM_SERIAL2_PHOTO_GPIO19",
        "current_temp": 22.0,
        "current_humidity": 50.0,
        "current_power": 115.0,
        "pzem_error_count": 0,
        "voltage_stability": 0.5,
        "failed_readings": 0
    }
    """
    logger.info(f"ESP32 heartbeat received: {request.method} {request.path}")
    logger.info(f"Heartbeat data: {request.data}")
    
    try:
        data = request.data
        if not data.get('device_id'):
            logger.error("Missing device_id in heartbeat")
            return Response(
                {'error': 'device_id is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        try:
            equipment = Equipment.objects.get(device_id=data['device_id'])
            equipment.status = 'online'
            equipment.save()
            
            # Update or create Component records based on sensor_type
            sensor_types = data.get('sensor_type', '').split('_')
            for sensor in sensor_types:
                if 'PZEM' in sensor:
                    component, _ = Component.objects.get_or_create(
                        equipment=equipment,
                        identifier=sensor,
                        defaults={'component_type': 'pzem', 'status': 'online' if data.get('pzem_working', True) else 'error'}
                    )
                    component.status = 'online' if data.get('pzem_working', True) else 'error'
                    component.save()
                elif 'DHT22' in sensor:
                    component, _ = Component.objects.get_or_create(
                        equipment=equipment,
                        identifier=sensor,
                        defaults={'component_type': 'dht22', 'status': 'online' if data.get('dht22_working', True) else 'error'}
                    )
                    component.status = 'online' if data.get('dht22_working', True) else 'error'
                    component.save()
                elif 'PHOTO' in sensor:
                    component, _ = Component.objects.get_or_create(
                        equipment=equipment,
                        identifier=sensor,
                        defaults={'component_type': 'photoresistor', 'status': 'online' if data.get('photoresistor_working', True) else 'error'}
                    )
                    component.status = 'online' if data.get('photoresistor_working', True) else 'error'
                    component.save()
            
            heartbeat = HeartbeatLog.objects.create(
                equipment=equipment,
                timestamp=int(data.get('timestamp', 0)),
                dht22_working=bool(data.get('dht22_working', False)),
                pzem_working=bool(data.get('pzem_working', True)),
                photoresistor_working=bool(data.get('photoresistor_working', True)),
                success_rate=float(data.get('success_rate', 0.0)),
                wifi_signal=int(data.get('wifi_signal', 0)),
                uptime=int(data.get('uptime', 0)),
                sensor_type=data.get('sensor_type', ''),
                current_temp=float(data.get('current_temp', 0.0)),
                current_humidity=float(data.get('current_humidity', 0.0)),
                current_power=float(data.get('current_power', 0.0)),
                pzem_error_count=int(data.get('pzem_error_count', 0)),
                voltage_stability=float(data.get('voltage_stability', 0.0)),
                failed_readings=int(data.get('failed_readings', 0)),
            )
            logger.info(f"Heartbeat saved for {data['device_id']}: {heartbeat.id}")
            return Response({
                'success': True,
                'message': f'Heartbeat received from {data["device_id"]}',
                'timestamp': timezone.now().isoformat()
            })
        except Equipment.DoesNotExist:
            logger.error(f"Equipment with device_id {data['device_id']} not found")
            return Response(
                {'error': f'Equipment with device_id {data["device_id"]} not found'},
                status=status.HTTP_404_NOT_FOUND
            )
    except ValueError as e:
        logger.error(f"Invalid data format: {str(e)}")
        return Response(
            {'error': f'Invalid data format: {str(e)}'},
            status=status.HTTP_400_BAD_REQUEST
        )
    except Exception as e:
        logger.error(f"Server error in heartbeat: {str(e)}")
        return Response(
            {'error': f'Server error: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['POST'])
@permission_classes([AllowAny])
def esp32_sensor_data(request):
    logger.info(f"ESP32 sensor data received: {request.method} {request.path}")
    logger.info(f"Request data: {request.data}")
    try:
        data = request.data
        if not data.get('device_id'):
            logger.error("Missing device_id")
            return Response(
                {'error': 'device_id is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        try:
            equipment = Equipment.objects.get(device_id=data['device_id'])
            logger.info(f"Found equipment: {equipment.name}")
            if not equipment.room:
                logger.error(f"Equipment {equipment.name} has no associated room")
                return Response(
                    {'error': f'Equipment {equipment.name} has no associated room'},
                    status=status.HTTP_400_BAD_REQUEST
                )
        except Equipment.DoesNotExist:
            logger.error(f"Equipment with device_id {data['device_id']} not found")
            return Response(
                {'error': f'Equipment with device_id {data["device_id"]} not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        created_logs = []
        created_alert_ids = []
        resolved_alert_ids = []
        recorded_at = timezone.now()
        if data.get('recorded_at'):
            try:
                recorded_at = timezone.datetime.fromisoformat(data['recorded_at'].replace('Z', '+00:00'))
            except ValueError:
                logger.error(f"Invalid recorded_at format: {data['recorded_at']}")
                return Response(
                    {'error': 'Invalid recorded_at format. Use ISO format'},
                    status=status.HTTP_400_BAD_REQUEST
                )

        for component_data in data.get('components', []):
            component_type = component_data.get('component_type')
            identifier = component_data.get('identifier')
            if not component_type or not identifier:
                logger.error("Missing component_type or identifier")
                continue
            
            component, _ = Component.objects.get_or_create(
                equipment=equipment,
                identifier=identifier,
                defaults={'component_type': component_type, 'status': 'online'}
            )
            
            sensor_log_data = {
                'equipment': equipment,
                'component': component,
                'recorded_at': recorded_at,
            }
            
            if component_type == 'pzem':
                sensor_log_data.update({
                    'voltage': float(component_data.get('voltage', 0.0)),
                    'current': float(component_data.get('current', 0.0)),
                    'power': float(component_data.get('power', 0.0)),
                    'energy': float(component_data.get('energy', 0.0)),
                    'reset_flag': bool(component_data.get('reset_flag', False)),
                    'pzem_recorded_at': recorded_at
                })
            elif component_type == 'dht22':
                sensor_log_data.update({
                    'temperature': float(component_data.get('temperature', 0.0)),
                    'humidity': float(component_data.get('humidity', 0.0)),
                    'dht22_recorded_at': recorded_at
                })
            elif component_type == 'photoresistor':
                sensor_log_data.update({
                    'light_detected': bool(component_data.get('light_detected', False)),
                    'photoresistor_recorded_at': recorded_at
                })
            elif component_type == 'motion':
                sensor_log_data.update({
                    'motion_detected': bool(component_data.get('motion_detected', False)),
                    'motion_recorded_at': recorded_at
                })
            
            sensor_log = SensorLog.objects.create(**sensor_log_data)
            created_logs.append(str(sensor_log.id))
            
            # Check for anomalies
            if component_type == 'pzem' and sensor_log.power > 0:
                recent_logs = SensorLog.objects.filter(
                    component=component,
                    pzem_recorded_at__gte=timezone.now() - timezone.timedelta(hours=1)
                )
                avg_power = recent_logs.aggregate(avg=Avg('power'))['avg'] or 0
                if avg_power and sensor_log.power > (avg_power * 2):
                    alert, created = Alert.objects.get_or_create(
                        equipment=equipment,
                        type='energy_anomaly',
                        resolved=False,
                        defaults={
                            'message': f'Energy usage anomaly: {sensor_log.power}W vs avg {avg_power:.2f}W',
                            'severity': 'low'
                        }
                    )
                    if created:
                        created_alert_ids.append(str(alert.id))
                elif avg_power and sensor_log.power <= (avg_power * 2):
                    alerts = Alert.objects.filter(
                        equipment=equipment,
                        type='energy_anomaly',
                        resolved=False
                    )
                    for alert in alerts:
                        alert.resolved = True
                        alert.resolved_at = timezone.now()
                        alert.save()
                        resolved_alert_ids.append(str(alert.id))
            elif component_type == 'dht22' and sensor_log.temperature > 40:
                alert, created = Alert.objects.get_or_create(
                    equipment=equipment,
                    type='temperature_threshold',
                    resolved=False,
                    defaults={
                        'message': f'Temperature alert: {sensor_log.temperature}°C exceeds 40°C',
                        'severity': 'high'
                    }
                )
                if created:
                    created_alert_ids.append(str(alert.id))
            elif component_type == 'dht22' and sensor_log.temperature <= 40:
                alerts = Alert.objects.filter(
                    equipment=equipment,
                    type='temperature_threshold',
                    resolved=False
                )
                for alert in alerts:
                    alert.resolved = True
                    alert.resolved_at = timezone.now()
                    alert.save()
                    resolved_alert_ids.append(str(alert.id))
            elif component_type == 'dht22' and sensor_log.humidity > 80:
                alert, created = Alert.objects.get_or_create(
                    equipment=equipment,
                    type='humidity_threshold',
                    resolved=False,
                    defaults={
                        'message': f'Humidity exceeded 80%: {sensor_log.humidity}%',
                        'severity': 'medium'
                    }
                )
                if created:
                    created_alert_ids.append(str(alert.id))
            elif component_type == 'dht22' and sensor_log.humidity <= 80:
                alerts = Alert.objects.filter(
                    equipment=equipment,
                    type='humidity_threshold',
                    resolved=False
                )
                for alert in alerts:
                    alert.resolved = True
                    alert.resolved_at = timezone.now()
                    alert.save()
                    resolved_alert_ids.append(str(alert.id))
            elif component_type == 'motion' and sensor_log.motion_detected:
                prev_log = SensorLog.objects.filter(component=component).order_by('-recorded_at').exclude(id=sensor_log.id).first()
                if prev_log and not prev_log.motion_detected:
                    alert, created = Alert.objects.get_or_create(
                        equipment=equipment,
                        type='motion',
                        resolved=False,
                        defaults={
                            'message': 'Motion detected',
                            'severity': 'medium'
                        }
                    )
                    if created:
                        created_alert_ids.append(str(alert.id))
            elif component_type == 'motion' and not sensor_log.motion_detected:
                alerts = Alert.objects.filter(
                    equipment=equipment,
                    type='motion',
                    resolved=False
                )
                for alert in alerts:
                    alert.resolved = True
                    alert.resolved_at = timezone.now()
                    alert.save()
                    resolved_alert_ids.append(str(alert.id))
        
        equipment.status = 'online'
        equipment.save()
        
        # Update EnergySummary for PZEM components
        pzem_components = Component.objects.filter(equipment=equipment, component_type='pzem')
        for component in pzem_components:
            today = recorded_at.date()
            period_start = timezone.datetime.combine(today, datetime.time.min, tzinfo=timezone.get_current_timezone())
            period_end = timezone.datetime.combine(today, datetime.time.max, tzinfo=timezone.get_current_timezone())
            recent_logs = SensorLog.objects.filter(
                component=component,
                pzem_recorded_at__gte=period_start,
                pzem_recorded_at__lte=period_end,
                energy__isnull=False
            )
            log_count = recent_logs.count()
            logger.info(f"PZEM logs for {today}: {log_count}")
            if log_count >= 1:  # Allow single reading for testing
                energy_stats = recent_logs.aggregate(max_energy=Max('energy'), min_energy=Min('energy'))
                total_energy = (energy_stats['max_energy'] - energy_stats['min_energy']) if energy_stats['max_energy'] is not None and energy_stats['min_energy'] is not None else recent_logs.first().energy or 0
                if recent_logs.filter(reset_flag=True).exists():
                    total_energy += energy_stats['max_energy'] or 0
                avg_power = recent_logs.aggregate(avg=Avg('power'))['avg'] or 0
                peak_power = recent_logs.aggregate(max=Max('power'))['max'] or 0
                anomaly_count = Alert.objects.filter(
                    equipment=equipment,
                    type='energy_anomaly',
                    triggered_at__gte=period_start,
                    triggered_at__lte=period_end
                ).count()

                rate = BillingRate.objects.filter(
                    Q(room=equipment.room) | Q(room__isnull=True),
                    Q(valid_from__lte=period_start) | Q(valid_from__isnull=True),
                    Q(valid_to__gte=period_start) | Q(valid_to__isnull=True)
                ).order_by('-created_at').first()

                if not rate:
                    default_rate_per_kwh = 10.00
                    if total_energy >= 0.1:
                        default_rate_per_kwh = 15.00
                    elif total_energy >= 0.01:
                        default_rate_per_kwh = 12.50
                    rate = BillingRate.objects.create(
                        room=equipment.room,
                        rate_per_kwh=default_rate_per_kwh,
                        currency='PHP',
                        valid_from=period_start,
                        valid_to=period_start + timezone.timedelta(days=365),
                        start_time=None,
                        end_time=None
                    )
                    logger.info(f"Created default BillingRate {rate.id} for room {equipment.room.name} at {default_rate_per_kwh} PHP/kWh")

                effective_rate = rate.get_rate_for_time(period_start)
                total_cost = round(total_energy * effective_rate, 2)
                currency = rate.currency

                energy_summary, _ = EnergySummary.objects.update_or_create(
                    component=component,
                    room=equipment.room,
                    period_start=period_start,
                    period_end=period_end,
                    period_type='daily',
                    defaults={
                        'total_energy': total_energy,
                        'avg_power': avg_power,
                        'peak_power': peak_power,
                        'reading_count': log_count,
                        'anomaly_count': anomaly_count,
                        'total_cost': total_cost,
                        'currency': currency,
                        'effective_rate': effective_rate  # Added for frontend
                    }
                )
                logger.info(f"Updated/Created EnergySummary {energy_summary.id} with total_cost {total_cost} {currency}, effective_rate {effective_rate}")

        if created_alert_ids:
            recent_request = MaintenanceRequest.objects.filter(
                equipment=equipment,
                status__in=['pending', 'in_progress'],
                created_at__gte=timezone.now() - timezone.timedelta(hours=1)
            ).exists()
            if not recent_request:
                assignee = User.objects.filter(role='employee').first()
                if not assignee:
                    assignee = User.objects.create_user(
                        username='system', email='system@example.com', 
                        password='systempass', role='employee'
                    )
                maintenance_request = MaintenanceRequest.objects.create(
                    user=assignee,
                    equipment=equipment,
                    issue=f'Auto-generated from alert: Temperature/Motion/Energy anomaly',
                    status='pending',
                    assigned_to=assignee,
                    scheduled_date=timezone.now().date() + timezone.timedelta(days=1),
                )
                NotificationService.notify_maintenance_request_created(maintenance_request, request)
        
        logger.info(f"Sensor data saved: {created_logs}, Alerts created: {created_alert_ids}, Alerts resolved: {resolved_alert_ids}")
        return Response({
            'success': True,
            'message': 'Sensor data received successfully',
            'log_ids': created_logs,
            'alert_ids': created_alert_ids,
            'resolved_alert_ids': resolved_alert_ids,
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_201_CREATED)
    except ValueError as e:
        logger.error(f"Invalid data format: {str(e)}")
        return Response(
            {'error': f'Invalid data format: {str(e)}'},
            status=status.HTTP_400_BAD_REQUEST
        )
    except Exception as e:
        logger.error(f"Server error: {str(e)}")
        return Response(
            {'error': f'Server error: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
@api_view(['GET'])
@permission_classes([AllowAny])
def esp32_health_check(request):
    logger.info("ESP32 health check requested")
    return Response({
        'status': 'healthy',
        'message': 'ESP32 API is running',
        'timestamp': timezone.now().isoformat()
    })

@api_view(['GET'])
@permission_classes([AllowAny])
def equipment_field_options(request):
    logger.info("Equipment field options requested")
    return Response({
        'equipment_status_options': [
            {'value': 'online', 'label': 'Online', 'description': 'Equipment is working and connected'},
            {'value': 'offline', 'label': 'Offline', 'description': 'Equipment is not working or disconnected'},
            {'value': 'maintenance', 'label': 'Maintenance', 'description': 'Equipment is under maintenance'},
            {'value': 'error', 'label': 'Error', 'description': 'Equipment has errors or issues'},
        ],
        'equipment_type_options': [
            {'value': 'esp32', 'label': 'ESP32', 'description': 'ESP32 microcontroller'},
            {'value': 'sensor', 'label': 'Sensor', 'description': 'General sensors'},
            {'value': 'actuator', 'label': 'Actuator', 'description': 'Motors, relays, etc.'},
            {'value': 'controller', 'label': 'Controller', 'description': 'Control devices'},
            {'value': 'monitor', 'label': 'Monitor', 'description': 'Monitoring devices'},
        ],
        'component_type_options': [
            {'value': 'pzem', 'label': 'PZEM', 'description': 'Power monitoring module'},
            {'value': 'dht22', 'label': 'DHT22', 'description': 'Temperature and humidity sensor'},
            {'value': 'photoresistor', 'label': 'Photoresistor', 'description': 'Light detection sensor'},
            {'value': 'motion', 'label': 'Motion Sensor', 'description': 'Motion detection sensor'},
        ],
        'room_type_options': [
            {'value': 'office', 'label': 'Office', 'description': 'Office spaces'},
            {'value': 'lab', 'label': 'Laboratory', 'description': 'Laboratory'},
            {'value': 'meeting', 'label': 'Meeting Room', 'description': 'Meeting rooms'},
            {'value': 'storage', 'label': 'Storage', 'description': 'Storage areas'},
            {'value': 'corridor', 'label': 'Corridor', 'description': 'Hallways/corridors'},
            {'value': 'utility', 'label': 'Utility', 'description': 'Utility rooms'},
        ],
        'role_options': [
            {'value': 'client', 'label': 'Client'},
            {'value': 'admin', 'label': 'Admin'},
            {'value': 'employee', 'label': 'Employee'},
            {'value': 'superadmin', 'label': 'Superadmin'},
        ],
        'alert_type_options': [
            {'value': 'temperature_threshold', 'label': 'Temperature Threshold'},
            {'value': 'motion', 'label': 'Motion Detected'},
            {'value': 'humidity_threshold', 'label': 'Humidity Threshold'},
            {'value': 'energy_anomaly', 'label': 'Energy Anomaly'},
            {'value': 'predictive_failure', 'label': 'Predictive Failure'},
        ],
        'alert_severity_options': [
            {'value': 'low', 'label': 'Low'},
            {'value': 'medium', 'label': 'Medium'},
            {'value': 'high', 'label': 'High'},
        ],
        'period_type_options': [
            {'value': 'daily', 'label': 'Daily'},
            {'value': 'weekly', 'label': 'Weekly'},
            {'value': 'monthly', 'label': 'Monthly'},
        ],
        'currency_options': [
            {'value': 'PHP', 'label': 'Philippine Peso', 'description': 'Philippine Peso (PHP)'},
        ],
    })

@api_view(['GET'])
@permission_classes([IsAuthenticated, RoleBasedPermission])
def dashboard_summary(request):
    logger.info("Dashboard summary requested")
    try:
        total_rooms = Room.objects.count()
        total_equipment = Equipment.objects.count()
        online_equipment = Equipment.objects.filter(status='online').count()
        total_components = Component.objects.count()
        avg_temp = SensorLog.objects.filter(dht22_recorded_at__isnull=False).aggregate(avg_temp=Avg('temperature'))['avg_temp'] or 0
        total_alerts = Alert.objects.count()
        unresolved_alerts = Alert.objects.filter(resolved=False).count()
        predictive_alerts = PredictiveAlert.objects.filter(resolved=False).count()
        recent_logs = SensorLog.objects.select_related('equipment', 'component').order_by('-recorded_at')[:5]
        
        # Calculate billing cost for today
        today = timezone.now().date()
        energy_summaries = EnergySummary.objects.filter(
            period_start__date=today,
            period_type='daily'
        ).select_related('room')
        total_cost = 0
        for summary in energy_summaries:
            rate = BillingRate.objects.filter(
                Q(room=summary.room) | Q(room__isnull=True),
                Q(valid_from__lte=summary.period_start) | Q(valid_from__isnull=True),
                Q(valid_to__gte=summary.period_start) | Q(valid_to__isnull=True)
            ).order_by('-created_at').first()
            if rate:
                total_cost += summary.total_energy * rate.get_rate_for_time(summary.period_start)
        
        summary_data = {
            'total_rooms': total_rooms,
            'total_equipment': total_equipment,
            'online_equipment': online_equipment,
            'total_components': total_components,
            'avg_temperature': round(avg_temp, 2),
            'total_alerts': total_alerts,
            'unresolved_alerts': unresolved_alerts,
            'predictive_alerts': predictive_alerts,
            'daily_energy_cost': round(total_cost, 2),
            'recent_logs': SensorLogSerializer(recent_logs, many=True).data,
        }
        return Response({
            'success': True,
            'data': summary_data,
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_200_OK)
    except Exception as e:
        logger.error(f"Error in dashboard_summary: {str(e)}")
        return Response(
            {'error': f'Server error: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['GET'])
@permission_classes([IsAuthenticated, RoleBasedPermission])
def room_realtime(request, pk):
    logger.info(f"Room realtime data requested for {pk}")
    try:
        room = get_object_or_404(Room, pk=pk)
        equipments = Equipment.objects.filter(room=room, type='esp32').prefetch_related('components')
        realtime_data = []
        for equipment in equipments:
            for component in equipment.components.all():
                latest_log = SensorLog.objects.filter(component=component).order_by('-recorded_at').first()
                if latest_log:
                    data = {
                        'equipment_id': str(equipment.id),
                        'equipment_name': equipment.name,
                        'component_id': str(component.id),
                        'component_type': component.component_type,
                        'device_id': equipment.device_id,
                        'status': component.status,
                        'recorded_at': latest_log.recorded_at.isoformat(),
                    }
                    if component.component_type == 'pzem':
                        data.update({
                            'voltage': latest_log.voltage,
                            'current': latest_log.current,
                            'power': latest_log.power,
                            'energy': latest_log.energy,
                            'pzem_recorded_at': latest_log.pzem_recorded_at.isoformat() if latest_log.pzem_recorded_at else None,
                        })
                    elif component.component_type == 'dht22':
                        data.update({
                            'temperature': latest_log.temperature,
                            'humidity': latest_log.humidity,
                            'dht22_recorded_at': latest_log.dht22_recorded_at.isoformat() if latest_log.dht22_recorded_at else None,
                        })
                    elif component.component_type == 'photoresistor':
                        data.update({
                            'light_detected': latest_log.light_detected,
                            'photoresistor_recorded_at': latest_log.photoresistor_recorded_at.isoformat() if latest_log.photoresistor_recorded_at else None,
                        })
                    elif component.component_type == 'motion':
                        data.update({
                            'motion_detected': latest_log.motion_detected,
                            'motion_recorded_at': latest_log.motion_recorded_at.isoformat() if latest_log.motion_recorded_at else None,
                        })
                    data['alerts'] = AlertSerializer(Alert.objects.filter(equipment=equipment, resolved=False), many=True).data
                    data['predictive_alerts'] = PredictiveAlertSerializer(PredictiveAlert.objects.filter(component=component, resolved=False), many=True).data
                    realtime_data.append(data)
        return Response({
            'success': True,
            'room_name': room.name,
            'data': realtime_data,
            'count': len(realtime_data),
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_200_OK)
    except Exception as e:
        logger.error(f"Error in room_realtime: {str(e)}")
        return Response(
            {'error': f'Server error: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['POST'])
@permission_classes([RoleBasedPermission])
def check_anomalies(request):
    logger.info("Anomaly check requested")
    try:
        component_id = request.data.get('component_id')
        window_hours = int(request.data.get('check_window_hours', 1))
        cutoff = timezone.now() - timezone.timedelta(hours=window_hours)
        if component_id:
            components = [get_object_or_404(Component, pk=component_id)]
        else:
            components = Component.objects.filter(equipment__type='esp32').select_related('equipment')
        
        created_alerts = []
        created_requests = []
        for component in components:
            recent_logs = SensorLog.objects.filter(component=component, recorded_at__gte=cutoff)
            if not recent_logs.exists():
                continue
            latest_log = recent_logs.latest('recorded_at')
            
            # Component-specific anomaly checks
            if component.component_type == 'pzem':
                energy_summary = EnergySummary.objects.filter(
                    component=component,
                    period_type='daily',
                    period_start__gte=cutoff
                ).first()
                avg_power = energy_summary.avg_power if energy_summary else recent_logs.aggregate(avg=Avg('power'))['avg'] or 0
                if avg_power and latest_log.power > (avg_power * 2):
                    alert, created = Alert.objects.get_or_create(
                        equipment=component.equipment,
                        type='energy_anomaly',
                        resolved=False,
                        defaults={
                            'message': f'Energy usage anomaly: {latest_log.power}W vs avg {avg_power:.2f}W',
                            'severity': 'low'
                        }
                    )
                    if created:
                        created_alerts.append(str(alert.id))
                elif avg_power and latest_log.power <= (avg_power * 2):
                    # Resolve energy_anomaly alerts if power normalizes
                    alerts = Alert.objects.filter(
                        equipment=component.equipment,
                        type='energy_anomaly',
                        resolved=False
                    )
                    for alert in alerts:
                        alert.resolved = True
                        alert.resolved_at = timezone.now()
                        alert.save()
                        created_alerts.append(str(alert.id))
            elif component.component_type == 'dht22' and latest_log.temperature > 40:
                alert, created = Alert.objects.get_or_create(
                    equipment=component.equipment,
                    type='temperature_threshold',
                    resolved=False,
                    defaults={
                        'message': f'Temperature exceeded 40°C: {latest_log.temperature}°C',
                        'severity': 'high'
                    }
                )
                if created:
                    created_alerts.append(str(alert.id))
            elif component.component_type == 'dht22' and latest_log.temperature <= 40:
                # Resolve temperature_threshold alerts if temperature normalizes
                alerts = Alert.objects.filter(
                    equipment=component.equipment,
                    type='temperature_threshold',
                    resolved=False
                )
                for alert in alerts:
                    alert.resolved = True
                    alert.resolved_at = timezone.now()
                    alert.save()
                    created_alerts.append(str(alert.id))
            elif component.component_type == 'dht22' and latest_log.humidity > 80:
                alert, created = Alert.objects.get_or_create(
                    equipment=component.equipment,
                    type='humidity_threshold',
                    resolved=False,
                    defaults={
                        'message': f'Humidity exceeded 80%: {latest_log.humidity}%',
                        'severity': 'medium'
                    }
                )
                if created:
                    created_alerts.append(str(alert.id))
            elif component.component_type == 'dht22' and latest_log.humidity <= 80:
                # Resolve humidity_threshold alerts if humidity normalizes
                alerts = Alert.objects.filter(
                    equipment=component.equipment,
                    type='humidity_threshold',
                    resolved=False
                )
                for alert in alerts:
                    alert.resolved = True
                    alert.resolved_at = timezone.now()
                    alert.save()
                    created_alerts.append(str(alert.id))
            elif component.component_type == 'motion' and latest_log.motion_detected:
                prev_log = SensorLog.objects.filter(component=component, recorded_at__lt=latest_log.recorded_at).order_by('-recorded_at').first()
                if prev_log and not prev_log.motion_detected:
                    alert, created = Alert.objects.get_or_create(
                        equipment=component.equipment,
                        type='motion',
                        resolved=False,
                        defaults={
                            'message': 'Motion detected in area',
                            'severity': 'medium'
                        }
                    )
                    if created:
                        created_alerts.append(str(alert.id))
            elif component.component_type == 'motion' and not latest_log.motion_detected:
                # Resolve motion alerts if no motion detected
                alerts = Alert.objects.filter(
                    equipment=component.equipment,
                    type='motion',
                    resolved=False
                )
                for alert in alerts:
                    alert.resolved = True
                    alert.resolved_at = timezone.now()
                    alert.save()
                    created_alerts.append(str(alert.id))
            
            # Auto-create maintenance request if no recent request exists
            if created_alerts:
                recent_request = MaintenanceRequest.objects.filter(
                    equipment=component.equipment,
                    created_at__gte=cutoff,
                    status__in=['pending', 'in_progress']
                ).exists()
                if not recent_request:
                    assignee = User.objects.filter(role='employee').first()
                    maintenance_request = MaintenanceRequest.objects.create(
                        user_id=request.user.id,
                        equipment=component.equipment,
                        issue=f'Auto-generated: {component.component_type} anomaly detected',
                        status='pending',
                        assigned_to=assignee,
                        scheduled_date=timezone.now().date(),
                    )
                    created_requests.append(f"Auto for {component.equipment.name} - {component.component_type}")
                    NotificationService.notify_maintenance_request_created(maintenance_request, request)
        
        return Response({
            'success': True,
            'created_alerts': created_alerts,
            'created_requests': created_requests,
            'message': f'Checked {len(components)} components',
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_200_OK)
    except Exception as e:
        logger.error(f"Error in check_anomalies: {str(e)}")
        return Response(
            {'error': f'Server error: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['POST'])
@permission_classes([RoleBasedPermission])
def predict_maintenance(request):
    """
    Endpoint for LLM-based predictive maintenance analysis
    Expected JSON format:
    {
        "component_id": "uuid",
        "window_days": 7
    }
    """
    logger.info(f"Predictive maintenance requested: {request.method} {request.path}")
    logger.info(f"Request data: {request.data}")
    try:
        component_id = request.data.get('component_id')
        window_days = int(request.data.get('window_days', 7))
        cutoff = timezone.now() - timezone.timedelta(days=window_days)
        
        if component_id:
            components = [get_object_or_404(Component, pk=component_id)]
        else:
            components = Component.objects.filter(equipment__type='esp32').select_related('equipment', 'equipment__room')
        
        created_alerts = []
        created_requests = []
        for component in components:
            try:
                from main import ask
                logger.info(f"LLM module imported for component {component.id}")
            except ImportError as e:
                logger.error(f"Failed to import LLM module: {e}")
                return Response(
                    {'error': 'LLM service not available'},
                    status=status.HTTP_503_SERVICE_UNAVAILABLE
                )
            
            # Gather data for LLM
            recent_logs = SensorLog.objects.filter(component=component, recorded_at__gte=cutoff)
            recent_heartbeats = HeartbeatLog.objects.filter(equipment=component.equipment, recorded_at__gte=cutoff)
            energy_summary = EnergySummary.objects.filter(component=component, period_start__gte=cutoff).first()
            room = component.equipment.room
            
            context = {
                'component_type': component.component_type,
                'equipment_name': component.equipment.name,
                'room_name': room.name if room else 'Unknown',
                'typical_energy_usage': room.typical_energy_usage if room else None,
                'occupancy_pattern': room.occupancy_pattern if room else None,
                'recent_power_avg': recent_logs.aggregate(avg=Avg('power'))['avg'] or 0,
                'recent_voltage_stability': recent_heartbeats.aggregate(avg=Avg('voltage_stability'))['avg'] or 0,
                'recent_pzem_error_count': recent_heartbeats.aggregate(sum=Sum('pzem_error_count'))['sum'] or 0,
                'recent_failed_readings': recent_heartbeats.aggregate(sum=Sum('failed_readings'))['sum'] or 0,
                'energy_anomalies': Alert.objects.filter(equipment=component.equipment, type='energy_anomaly', triggered_at__gte=cutoff).count(),
            }
            
            query = f"""
            Analyze the following data for predictive maintenance:
            - Component: {context['component_type']} on {context['equipment_name']}
            - Room: {context['room_name']}
            - Typical Energy Usage: {context['typical_energy_usage'] or 'Unknown'} kWh
            - Occupancy Pattern: {context['occupancy_pattern'] or 'Unknown'}
            - Average Power (last {window_days} days): {context['recent_power_avg']:.2f}W
            - Voltage Stability: {context['recent_voltage_stability']:.2f}
            - PZEM Error Count: {context['recent_pzem_error_count']}
            - Failed Readings: {context['recent_failed_readings']}
            - Energy Anomalies: {context['energy_anomalies']}
            Predict the likelihood of component failure and provide a confidence score (0-1).
            """
            
            result = ask(query)
            if "error" in result:
                logger.error(f"LLM query failed: {result['error']}")
                continue
            
            prediction = result.get('answer', '')
            confidence = 0.5  # Default confidence if not provided
            try:
                confidence = float(result.get('confidence', 0.5))
                if not 0 <= confidence <= 1:
                    confidence = 0.5
            except (ValueError, TypeError):
                logger.warning("Invalid confidence score from LLM, using default 0.5")
            
            predictive_alert, created = PredictiveAlert.objects.get_or_create(
                component=component,
                resolved=False,
                defaults={
                    'prediction': prediction,
                    'confidence': confidence
                }
            )
            if created:
                created_alerts.append(str(predictive_alert.id))
                NotificationService.notify_predictive_alert_created(predictive_alert, request)
                
                # Auto-create maintenance request for high-confidence predictions
                if confidence >= 0.8:
                    recent_request = MaintenanceRequest.objects.filter(
                        equipment=component.equipment,
                        created_at__gte=timezone.now() - timezone.timedelta(hours=1),
                        status__in=['pending', 'in_progress']
                    ).exists()
                    if not recent_request:
                        assignee = User.objects.filter(role='employee').first()
                        if not assignee:
                            assignee = User.objects.create_user(
                                username='system', email='system@example.com', 
                                password='systempass', role='employee'
                            )
                        maintenance_request = MaintenanceRequest.objects.create(
                            user=assignee,
                            equipment=component.equipment,
                            issue=f'LLM Prediction: {component.component_type} failure likely (Confidence: {confidence})',
                            status='pending',
                            assigned_to=assignee,
                            scheduled_date=timezone.now().date() + timezone.timedelta(days=1),
                        )
                        created_requests.append(f"Auto for {component.equipment.name} - {component.component_type}")
                        NotificationService.notify_maintenance_request_created(maintenance_request, request)
        
        return Response({
            'success': True,
            'created_alerts': created_alerts,
            'created_requests': created_requests,
            'message': f'Predicted maintenance for {len(components)} components',
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_200_OK)
    except Exception as e:
        logger.error(f"Error in predict_maintenance: {str(e)}")
        return Response(
            {'error': f'Server error: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['GET'])
@permission_classes([AllowAny])
def latest_sensor_data(request):
    logger.info("Latest sensor data requested")
    try:
        latest_logs = []
        components = Component.objects.filter(equipment__type='esp32').select_related('equipment')
        for component in components:
            latest_log = SensorLog.objects.filter(component=component).order_by('-recorded_at').first()
            if latest_log:
                data = {
                    'equipment_id': str(component.equipment.id),
                    'equipment_name': component.equipment.name,
                    'component_id': str(component.id),
                    'component_type': component.component_type,
                    'device_id': component.equipment.device_id,
                    'status': component.status,
                    'recorded_at': latest_log.recorded_at.isoformat(),
                }
                if component.component_type == 'pzem':
                    data.update({
                        'voltage': latest_log.voltage,
                        'current': latest_log.current,
                        'power': latest_log.power,
                        'energy': latest_log.energy,
                        'pzem_recorded_at': latest_log.pzem_recorded_at.isoformat() if latest_log.pzem_recorded_at else None,
                    })
                elif component.component_type == 'dht22':
                    data.update({
                        'temperature': latest_log.temperature,
                        'humidity': latest_log.humidity,
                        'dht22_recorded_at': latest_log.dht22_recorded_at.isoformat() if latest_log.dht22_recorded_at else None,
                    })
                elif component.component_type == 'photoresistor':
                    data.update({
                        'light_detected': latest_log.light_detected,
                        'photoresistor_recorded_at': latest_log.photoresistor_recorded_at.isoformat() if latest_log.photoresistor_recorded_at else None,
                    })
                elif component.component_type == 'motion':
                    data.update({
                        'motion_detected': latest_log.motion_detected,
                        'motion_recorded_at': latest_log.motion_recorded_at.isoformat() if latest_log.motion_recorded_at else None,
                    })
                latest_logs.append(data)
        
        logger.info(f"Returning {len(latest_logs)} sensor readings")
        return Response({
            'success': True,
            'data': latest_logs,
            'count': len(latest_logs),
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_200_OK)
    except Exception as e:
        logger.error(f"Server error in latest_sensor_data: {str(e)}")
        return Response(
            {'error': f'Server error: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['POST'])
@permission_classes([AllowAny])
def llm_query(request):
    logger.info(f"LLM query received: {request.method} {request.path}")
    logger.info(f"Query data: {request.data}")
    try:
        query_text = request.data.get('query')
        user_id = request.data.get('user_id')
        if not query_text:
            logger.error("Missing query in request")
            return Response(
                {'error': 'query is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        try:
            from main import ask
            logger.info("LLM module imported successfully")
        except ImportError as e:
            logger.error(f"Failed to import LLM module: {e}")
            return Response(
                {'error': 'LLM service not available'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE
            )
        logger.info(f"Processing query: {query_text}")
        result = ask(query_text)
        if "error" in result:
            logger.error(f"LLM query failed: {result['error']}")
            return Response(
                {'error': result['error']},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        if user_id:
            try:
                user = User.objects.get(id=user_id)
                llm_query_record = LLMQuery.objects.create(
                    user=user,
                    query=query_text,
                    response=result.get('answer', '')
                )
                logger.info(f"Query saved to database: {llm_query_record.id}")
            except User.DoesNotExist:
                logger.warning(f"User {user_id} not found, query not saved")
            except Exception as e:
                logger.error(f"Failed to save query: {e}")
        logger.info(f"LLM query processed successfully")
        return Response({
            'success': True,
            'query': query_text,
            'answer': result.get('answer', ''),
            'sources': result.get('sources', []),
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_200_OK)
    except Exception as e:
        logger.error(f"Server error in LLM query: {str(e)}")
        return Response(
            {'error': f'Server error: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['GET'])
@permission_classes([AllowAny])
def llm_health_check(request):
    logger.info("LLM health check requested")
    try:
        from main import ask
        result = ask("How many records are there?")
        if "error" in result:
            return Response({
                'status': 'unhealthy',
                'message': 'LLM service has errors',
                'error': result['error'],
                'timestamp': timezone.now().isoformat()
            }, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        return Response({
            'status': 'healthy',
            'message': 'LLM service is running',
            'database_connected': True,
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_200_OK)
    except ImportError as e:
        logger.error(f"LLM module import failed: {e}")
        return Response({
            'status': 'unhealthy',
            'message': 'LLM service not available',
            'error': str(e),
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_503_SERVICE_UNAVAILABLE)
    except Exception as e:
        logger.error(f"LLM health check failed: {e}")
        return Response({
            'status': 'unhealthy',
            'message': 'LLM service error',
            'error': str(e),
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_503_SERVICE_UNAVAILABLE)