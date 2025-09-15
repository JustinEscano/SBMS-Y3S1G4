from rest_framework.permissions import BasePermission, SAFE_METHODS
from .models import User  # Import custom User model

class RoleBasedPermission(BasePermission):
    def has_permission(self, request, view):
        # Check if user is authenticated
        if not request.user or not request.user.is_authenticated:
            return False

        try:
            # Fetch user from the USERS table using the request.user.id
            db_user = User.objects.get(id=request.user.id)
        except User.DoesNotExist:
            return False

        role = getattr(db_user, "role", None)
        model = getattr(getattr(view, "queryset", None), "model", None)
        model_name = model.__name__.lower() if model else None

        # Superadmin has full access to all resources
        if role == "superadmin":
            return True

        # Admin has full access except for LLMSummary (read-only)
        if role == "admin":
            if model_name == "llmsummary":
                return request.method in SAFE_METHODS
            return True

        # Employee has full access to MaintenanceRequest and SensorLog, read-only for Room, Equipment, LLMQuery
        if role == "employee":
            if model_name in ["maintenancerequest", "sensorlog"]:
                return True
            if model_name in ["room", "equipment", "llmquery"]:
                return request.method in SAFE_METHODS
            return False

        # Client has full access to LLMQuery and MaintenanceRequest, read-only for Room, Equipment, SensorLog
        if role == "client":
            if model_name in ["llmquery", "maintenancerequest"]:
                return True
            if model_name in ["room", "equipment", "sensorlog"]:
                return request.method in SAFE_METHODS
            return False

        return False