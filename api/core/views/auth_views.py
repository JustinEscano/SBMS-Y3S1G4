from rest_framework import generics
from rest_framework.permissions import AllowAny
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework_simplejwt.views import TokenObtainPairView
from django.http import HttpResponse
from core.serializers import UserSerializer
from core.models import User, Profile
import logging

logger = logging.getLogger(__name__)

class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    username_field = User.EMAIL_FIELD

    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token['role'] = user.role
        return token

    def validate(self, attrs):
        data = super().validate(attrs)
        user = self.user
        if not Profile.objects.filter(user=user).exists():
            try:
                Profile.objects.create(
                    user=user,
                    full_name=user.username,
                    organization="",
                    address=""
                )
                logger.info(f"Profile created for user {user.username} (ID: {user.id}) on token obtain")
            except Exception as e:
                logger.error(f"Failed to create profile for user {user.username} (ID: {user.id}) on token obtain: {str(e)}")
        return data

class CustomTokenObtainPairView(TokenObtainPairView):
    serializer_class = CustomTokenObtainPairSerializer

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [AllowAny]

    def perform_create(self, serializer):
        """Create a user and automatically create a Profile with default values."""
        user = serializer.save()
        try:
            Profile.objects.create(
                user=user,
                full_name=user.username,
                organization="",
                address=""
            )
            logger.info(f"User {user.username} (ID: {user.id}) created with default profile")
        except Exception as e:
            logger.error(f"Failed to create profile for user {user.username} (ID: {user.id}): {str(e)}")
        return user

def home(request):
    return HttpResponse("Welcome to the DBMS API.")