from rest_framework.permissions import BasePermission, SAFE_METHODS
from .models import User, MaintenanceRequest, MaintenanceAttachment, Notification, Alert

class RoleBasedPermission(BasePermission):
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False

        try:
            db_user = User.objects.get(id=request.user.id)
        except User.DoesNotExist:
            return False

        role = db_user.role

        # Superadmin and Admin: Full access
        if role in ["superadmin", "admin"]:
            return True

        # Get model for queryset-based checks
        model = getattr(getattr(view, "queryset", None), "model", None)
        model_name = model.__name__.lower() if model else None

        # Employee: Full access to maintenance/alert/notification; read-only elsewhere
        if role == "employee":
            if model_name in ["maintenancerequest", "alert", "notification", "maintenanceattachment"]:
                return True
            return request.method in SAFE_METHODS

        # Client: Own records only for specific models; read-only elsewhere
        if role == "client":
            if model_name not in ["llmquery", "maintenancerequest", "maintenanceattachment", "notification", "alert"]:
                return request.method in SAFE_METHODS

            # For writes, defer to has_object_permission (which checks ownership)
            if request.method not in SAFE_METHODS:
                return True  # Permission granted here; object-level check later

            # Reads are allowed (queryset will filter to own)
            return True

        return False

    def has_object_permission(self, request, view, obj):
        # Already checked has_permission; now validate object ownership for writes
        if request.method in SAFE_METHODS:
            return True

        try:
            db_user = User.objects.get(id=request.user.id)
        except User.DoesNotExist:
            return False

        role = db_user.role

        # Superadmin/Admin: Full access
        if role in ["superadmin", "admin"]:
            return True

        # Employee: Full access to maintenance/alerts/notifications
        if role == "employee":
            if isinstance(obj, (MaintenanceRequest, Alert, Notification, MaintenanceAttachment)):
                return True
            return False

        # Client: Only own objects
        if role == "client":
            # Handle upload_attachment action (on MaintenanceRequestViewSet)
            if hasattr(view, 'action') and view.action == 'upload_attachment':
                # obj is the MaintenanceRequest instance
                return obj.user == db_user

            # Standard ownership check
            if hasattr(obj, 'user'):
                return obj.user == db_user
            elif hasattr(obj, 'equipment') and hasattr(obj.equipment, 'room') and request.user == db_user:
                return True

        return False