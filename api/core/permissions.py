from rest_framework.permissions import BasePermission, SAFE_METHODS
from .models import User, MaintenanceRequest, MaintenanceAttachment, Notification

class RoleBasedPermission(BasePermission):
    def has_permission(self, request, view):
        # Check if user is authenticated
        if not request.user or not request.user.is_authenticated:
            return False

        try:
            # Fetch user from your USERS table (assuming id matches request.user.id)
            db_user = User.objects.get(id=request.user.id)
        except User.DoesNotExist:
            return False

        role = getattr(db_user, "role", None)

        # Superadmin and Admin have full access
        if role in ["superadmin", "admin"]:
            return True

        # Employee has access to maintenance-related and read-only for others
        if role == "employee":
            model = getattr(getattr(view, "queryset", None), "model", None)
            model_name = model.__name__.lower() if model else None

            if model_name in ["maintenancerequest", "alert", "notification", "maintenanceattachment"]:
                return True

            # Read-only for other models
            return request.method in SAFE_METHODS

        # Client has limited access: read-only for most, full for own LLMQuery, MaintenanceRequest, MaintenanceAttachment, and Notification
        if role == "client":
            model = getattr(getattr(view, "queryset", None), "model", None)
            model_name = model.__name__.lower() if model else None

            if model_name in ["llmquery", "maintenancerequest", "maintenanceattachment", "notification"]:
                # Allow create/update for own records
                if request.method in ['POST', 'PATCH', 'PUT']:
                    if model_name == "maintenancerequest" and request.data.get('user') != str(db_user.id):
                        return False
                    if model_name == "llmquery" and request.data.get('user') != str(db_user.id):
                        return False
                    if model_name == "maintenanceattachment":
                        # Ensure client can only upload to their own maintenance request
                        maintenance_request_id = request.data.get('maintenance_request') or \
                            (view.kwargs.get('pk') if view.action == 'upload_attachment' else None)
                        if maintenance_request_id:
                            try:
                                maintenance_request = MaintenanceRequest.objects.get(id=maintenance_request_id)
                                if maintenance_request.user != db_user:
                                    return False
                            except MaintenanceRequest.DoesNotExist:
                                return False
                    if model_name == "notification":
                        # Allow clients to update their own notifications (e.g., mark as read)
                        notification_id = view.kwargs.get('pk')
                        if notification_id and request.method in ['PUT', 'PATCH']:
                            try:
                                notification = Notification.objects.get(id=notification_id)
                                if notification.user != db_user:
                                    return False
                            except Notification.DoesNotExist:
                                return False
                    return True

            # Read-only for other models
            return request.method in SAFE_METHODS

        return False