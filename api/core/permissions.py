from rest_framework.permissions import BasePermission, SAFE_METHODS
from .models import User  # import your custom user model

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

        # Admin has full access
        if role == "admin":
            return True

        # Client has limited access
        if role == "client":
            model = getattr(getattr(view, "queryset", None), "model", None)
            model_name = model.__name__.lower() if model else None

            # Allow client access only to LLMQuery and MaintenanceRequest
            if model_name in ["llmquery", "maintenancerequest"]:
                return True

            # Otherwise, only allow safe (read-only) methods
            return request.method in SAFE_METHODS

        return False