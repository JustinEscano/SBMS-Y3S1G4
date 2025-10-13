# views.py - Fixed imports and updated OTP email to use template
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import check_password
from core.permissions import RoleBasedPermission  # Assuming this is your custom permission
from django.core.cache import cache
from django.core.mail import send_mail
from django.template.loader import render_to_string
from django.utils.html import strip_tags
from django.utils.crypto import get_random_string
from django.conf import settings
from django.utils import timezone
import logging

logger = logging.getLogger(__name__)
User = get_user_model()

class PasswordViewSet(viewsets.ModelViewSet):
    """
    A dedicated ViewSet for handling password changes securely.
    Accessible only to authenticated users for their own account.
    """
    queryset = User.objects.all()
    permission_classes = [RoleBasedPermission]

    @action(detail=False, methods=['patch'], url_path='change')
    def change(self, request):
        """
        Change the authenticated user's password.
        Expects: {"current_password": "old_password", "password": "new_password"}
        Verifies current password, hashes new one, and updates.
        """
        user = request.user
        if not user.is_authenticated:
            return Response({"detail": "Authentication required."}, status=status.HTTP_401_UNAUTHORIZED)

        current_password = request.data.get('current_password')
        new_password = request.data.get('password')

        if not current_password or not new_password:
            return Response(
                {'error': 'current_password and password are required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if len(new_password) < 6:
            return Response(
                {'password': ['New password must be at least 6 characters.']},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Verify current password (handles hashing automatically)
        if not check_password(current_password, user.password):
            return Response(
                {'current_password': ['Wrong current password.']},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Set and save new password (Django hashes it automatically)
        user.set_password(new_password)
        user.save(update_fields=['password'])

        logger.info(f"Password changed successfully for user {user.username} (ID: {user.id})")

        # Return a success response without sensitive data
        return Response(
            {'detail': 'Password changed successfully.'},
            status=status.HTTP_200_OK
        )
    
class OTPPasswordViewSet(viewsets.ViewSet):
    """
    Dedicated ViewSet for OTP-based password reset.
    Steps: Request OTP via email -> Verify OTP and set new password.
    OTPs are stored in cache for 10 minutes (key: f"otp_reset_{email}").
    """
    permission_classes = [AllowAny]

    @action(detail=False, methods=['post'], url_path='request')
    def request_otp(self, request):
        """
        Send OTP to user's email.
        Expects: {"email": "user@example.com"}
        """
        email = request.data.get('email')
        if not email:
            return Response({'detail': 'Email is required'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            # Don't reveal if email exists for security
            logger.info(f"OTP request for non-existent email: {email}")
            return Response({'detail': 'If the email exists, an OTP has been sent.'}, status=status.HTTP_200_OK)

        # Generate 6-digit OTP
        otp = get_random_string(length=6, allowed_chars='0123456789')
        cache_key = f"otp_reset_{email}"
        cache.set(cache_key, otp, 600)  # 10 minutes expiry

        # Render email template
        context = {
            'recipient': user.username,
            'otp': otp,
            'year': timezone.now().year,
        }
        html_message = render_to_string('emails/otp_email.html', context)
        plain_message = strip_tags(html_message)
        subject = 'SBMS: Password Reset OTP'

        # Send email (customize subject/body as needed)
        send_mail(
            subject=subject,
            message=plain_message,
            html_message=html_message,
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[email],
            fail_silently=False,
        )

        logger.info(f"OTP sent to {email} for user {user.username}")
        return Response({'detail': 'OTP sent to your email.'}, status=status.HTTP_200_OK)

    @action(detail=False, methods=['patch'], url_path='verify')
    def verify_and_reset(self, request):
        """
        Verify OTP and set new password.
        Expects: {"email": "user@example.com", "otp": "123456", "password": "newpass123"}
        """
        email = request.data.get('email')
        otp = request.data.get('otp')
        new_password = request.data.get('password')

        if not all([email, otp, new_password]):
            return Response({'detail': 'Email, OTP, and password are required'}, status=status.HTTP_400_BAD_REQUEST)

        if len(new_password) < 6:
            return Response({'password': ['New password must be at least 6 characters.']}, status=status.HTTP_400_BAD_REQUEST)

        cache_key = f"otp_reset_{email}"
        stored_otp = cache.get(cache_key)

        if not stored_otp or stored_otp != otp:
            return Response({'otp': ['Invalid or expired OTP.']}, status=status.HTTP_400_BAD_REQUEST)

        try:
            user = User.objects.get(email=email)
            user.set_password(new_password)
            user.save(update_fields=['password'])
            cache.delete(cache_key)  # Clear OTP after use

            logger.info(f"Password reset via OTP for user {user.username} (ID: {user.id})")

            # Optional: Generate and return new JWT tokens for auto-login
            from rest_framework_simplejwt.tokens import RefreshToken
            refresh = RefreshToken.for_user(user)
            return Response({
                'access': str(refresh.access_token),
                'refresh': str(refresh),
                'detail': 'Password reset successfully.'
            }, status=status.HTTP_200_OK)

        except User.DoesNotExist:
            return Response({'detail': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)
        
    # In your OTPPasswordViewSet - Add this new action for OTP verification only
    @action(detail=False, methods=['post'], url_path='verify-otp')
    def verify_otp(self, request):
        """
        Verify OTP without resetting password.
        Expects: {"email": "user@example.com", "otp": "123456"}
        """
        email = request.data.get('email')
        otp = request.data.get('otp')

        if not all([email, otp]):
            return Response({'detail': 'Email and OTP are required'}, status=status.HTTP_400_BAD_REQUEST)

        cache_key = f"otp_reset_{email}"
        stored_otp = cache.get(cache_key)

        if not stored_otp or stored_otp != otp:
            return Response({'otp': ['Invalid or expired OTP.']}, status=status.HTTP_400_BAD_REQUEST)

        return Response({'detail': 'OTP verified successfully.'}, status=status.HTTP_200_OK)