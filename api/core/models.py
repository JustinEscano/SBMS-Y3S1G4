from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models
import uuid


class CustomUserManager(BaseUserManager):
    def create_user(self, username, email, password=None, role='client', **extra_fields):
        if not email:
            raise ValueError("Email is required")
        email = self.normalize_email(email)

        # Force staff and superuser flags based on role
        if role == 'admin':
            extra_fields.setdefault('is_staff', True)
            extra_fields.setdefault('is_superuser', False)  # Admins may not be superusers unless needed
        else:
            extra_fields['is_staff'] = False
            extra_fields['is_superuser'] = False

        user = self.model(username=username, email=email, role=role, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, username, email, password=None, **extra_fields):
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_staff', True)
        return self.create_user(username, email, password, role='admin', **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    username = models.CharField(max_length=255, unique=True)
    email = models.EmailField(unique=True)
    role = models.CharField(max_length=50)
    created_at = models.DateTimeField(auto_now_add=True)

    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)

    USERNAME_FIELD = 'username'
    REQUIRED_FIELDS = ['email', 'role']

    objects = CustomUserManager()

    def __str__(self):
        return self.username

    def save(self, *args, **kwargs):
        # Enforce is_staff logic based on role even during updates
        if self.role == 'admin':
            self.is_staff = True
        else:
            self.is_staff = False
            self.is_superuser = False
        super().save(*args, **kwargs)

class Room(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    floor = models.IntegerField()
    capacity = models.IntegerField()
    type = models.CharField(max_length=100)
    created_at = models.DateTimeField(auto_now_add=True)

class Equipment(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    room = models.ForeignKey(Room, on_delete=models.CASCADE)
    type = models.CharField(max_length=100)
    status = models.CharField(max_length=100)
    qr_code = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)

class SensorLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    equipment = models.ForeignKey(Equipment, on_delete=models.CASCADE)
    temperature = models.FloatField()
    humidity = models.FloatField()
    light_level = models.FloatField()
    motion_detected = models.BooleanField()
    energy_usage = models.FloatField()
    recorded_at = models.DateTimeField()

class MaintenanceRequest(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    equipment = models.ForeignKey(Equipment, on_delete=models.CASCADE)
    issue = models.TextField()
    status = models.CharField(max_length=100)
    scheduled_date = models.DateField()
    resolved_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

class LLMQuery(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    query = models.TextField()
    response = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

class LLMSummary(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    generated_for = models.DateField()
    summary = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

class AuthToken(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    token = models.CharField(max_length=255)
    expires_at = models.DateTimeField()
