from django.contrib.auth.signals import user_logged_in
from django.dispatch import receiver
from core.models import Profile
import logging

logger = logging.getLogger(__name__)

@receiver(user_logged_in)
def create_profile_on_login(sender, user, request, **kwargs):
    """Create a Profile for the user on login if it doesn't exist."""
    if not Profile.objects.filter(user=user).exists():
        try:
            profile = Profile.objects.create(
                user=user,
                full_name=user.username,
                organization="",
                address=""
            )
            logger.info(f"Profile created for user {user.username} (ID: {user.id}) on login")
        except Exception as e:
            logger.error(f"Failed to create profile for user {user.username} (ID: {user.id}) on login: {str(e)}")