from django.db import models
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
import uuid
from django.db.models import Avg
from django.core.validators import MinValueValidator
from django.utils import timezone

# Constants for standardized field values
ROLE_CHOICES = [
    ('client', 'Client'),
    ('admin', 'Admin'),
    ('employee', 'Employee'),
    ('superadmin', 'Superadmin'),
]

EQUIPMENT_STATUS_CHOICES = [
    ('online', 'Online'),
    ('offline', 'Offline'),
    ('maintenance', 'Maintenance'),
    ('error', 'Error'),
]

EQUIPMENT_TYPE_CHOICES = [
    ('esp32', 'ESP32'),
    ('sensor', 'Sensor'),
    ('actuator', 'Actuator'),
    ('controller', 'Controller'),
    ('monitor', 'Monitor'),
]

EQUIPMENT_MODE_CHOICES = [
    ('hvac', 'HVAC'),
    ('lighting', 'Lighting'),
    ('security', 'Security'),
]

ROOM_TYPE_CHOICES = [
    ('office', 'Office'),
    ('lab', 'Laboratory'),
    ('meeting', 'Meeting Room'),
    ('storage', 'Storage'),
    ('corridor', 'Corridor'),
    ('utility', 'Utility'),
]

MAINTENANCE_STATUS_CHOICES = [
    ('pending', 'Pending'),
    ('in_progress', 'In Progress'),
    ('resolved', 'Resolved'),
]

ALERT_TYPE_CHOICES = [
    ('temperature_threshold', 'Temperature Threshold'),
    ('motion', 'Motion Detected'),
    ('humidity_threshold', 'Humidity Threshold'),
    ('energy_anomaly', 'Energy Anomaly'),
    ('predictive_failure', 'Predictive Failure'),
]

ALERT_SEVERITY_CHOICES = [
    ('low', 'Low'),
    ('medium', 'Medium'),
    ('high', 'High'),
]

COMPONENT_TYPE_CHOICES = [
    ('pzem', 'PZEM'),
    ('dht22', 'DHT22'),
    ('photoresistor', 'Photoresistor'),
    ('motion', 'Motion Sensor'),
]

PERIOD_TYPE_CHOICES = [
    ('daily', 'Daily'),
    ('weekly', 'Weekly'),
    ('monthly', 'Monthly'),
]

CURRENCY_CHOICES = [
    ('PHP', 'Philippine Peso'),
]

NOTIFICATION_CATEGORY_CHOICES = [
    ('maintenance', 'Maintenance'),
    ('alert', 'Alert'),
    ('system', 'System'),
]

class UserManager(BaseUserManager):
    def create_user(self, username, email, password=None, role='client', **extra_fields):
        if not email:
            raise ValueError("Email is required")
        if not username:
            raise ValueError("Username is required")
        email = self.normalize_email(email)
        user = self.model(username=username, email=email, role=role, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

class User(AbstractBaseUser):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    username = models.CharField(max_length=255, unique=True)
    email = models.EmailField(unique=True)
    password = models.CharField(max_length=128)
    role = models.CharField(max_length=50, choices=ROLE_CHOICES, default='client')
    created_at = models.DateTimeField(auto_now_add=True)
    last_login = models.DateTimeField(null=True, blank=True)

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username', 'role']
    EMAIL_FIELD = 'email'

    objects = UserManager()

    def __str__(self):
        return self.email

class Profile(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    full_name = models.CharField(max_length=255, blank=True, null=True)
    organization = models.CharField(max_length=255, blank=True, null=True)
    address = models.CharField(max_length=500, blank=True, null=True)
    profile_picture = models.ImageField(upload_to='profile_pictures/%Y/%m/%d/', blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Profile for {self.user.username}"

class Room(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    floor = models.IntegerField()
    capacity = models.IntegerField()
    type = models.CharField(max_length=100, choices=ROOM_TYPE_CHOICES)
    typical_energy_usage = models.FloatField(null=True, blank=True, help_text="Typical energy usage in kWh")
    occupancy_pattern = models.CharField(max_length=255, null=True, blank=True, help_text="e.g., '9AM-5PM weekdays'")
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name

class Equipment(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    room = models.ForeignKey(Room, on_delete=models.SET_NULL, null=True, blank=True)
    type = models.CharField(max_length=100, choices=EQUIPMENT_TYPE_CHOICES)
    status = models.CharField(max_length=100, choices=EQUIPMENT_STATUS_CHOICES, default='offline')
    device_id = models.CharField(max_length=100, unique=True, null=True, blank=True)
    qr_code = models.TextField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def generate_qr_code(self):
        """Generate QR code for this equipment (e.g., linking to its ID for scan)"""
        if self.qr_code:
            return self.qr_code
        try:
            import qrcode
            import base64
            from io import BytesIO
            qr = qrcode.QRCode(version=1, box_size=10, border=5)
            qr.add_data(f"https://yourapp.com/equipment/{self.id}/scan")
            qr.make(fit=True)
            img = qr.make_image(fill_color="black", back_color="white")
            buffer = BytesIO()
            img.save(buffer, format='PNG')
            img_str = base64.b64encode(buffer.getvalue()).decode()
            self.qr_code = f"data:image/png;base64,{img_str}"
            self.save()
            return self.qr_code
        except ImportError:
            self.qr_code = f"eq:{self.id}"
            self.save()
            return self.qr_code

    def __str__(self):
        return self.name

class Component(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    equipment = models.ForeignKey(Equipment, on_delete=models.CASCADE, related_name='components')
    component_type = models.CharField(max_length=50, choices=COMPONENT_TYPE_CHOICES)
    identifier = models.CharField(max_length=100, help_text="Unique identifier, e.g., PZEM_SERIAL2")
    status = models.CharField(max_length=100, choices=EQUIPMENT_STATUS_CHOICES, default='offline')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('equipment', 'identifier')
        indexes = [
            models.Index(fields=['equipment', 'component_type']),
        ]

    def __str__(self):
        return f"{self.equipment.name} - {self.component_type} ({self.identifier})"

class SensorLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    equipment = models.ForeignKey(Equipment, on_delete=models.CASCADE)
    component = models.ForeignKey(Component, on_delete=models.CASCADE, null=True, blank=True)
    temperature = models.FloatField(null=True, blank=True)
    humidity = models.FloatField(null=True, blank=True)
    light_detected = models.BooleanField(null=True, blank=True)
    motion_detected = models.BooleanField(null=True, blank=True)
    energy_usage = models.FloatField(null=True, blank=True)
    voltage = models.FloatField(null=True, blank=True)
    current = models.FloatField(null=True, blank=True)
    power = models.FloatField(null=True, blank=True)
    energy = models.FloatField(null=True, blank=True)
    recorded_at = models.DateTimeField()
    pzem_recorded_at = models.DateTimeField(null=True, blank=True)
    dht22_recorded_at = models.DateTimeField(null=True, blank=True)
    photoresistor_recorded_at = models.DateTimeField(null=True, blank=True)
    motion_recorded_at = models.DateTimeField(null=True, blank=True)
    reset_flag = models.BooleanField(default=False)

    class Meta:
        ordering = ['-recorded_at']
        indexes = [
            models.Index(fields=['equipment', 'component', 'recorded_at']),
            models.Index(fields=['component', 'pzem_recorded_at']),
        ]

    def __str__(self):
        return f"{self.equipment.name} - {self.component.component_type if self.component else 'Unknown'} - {self.recorded_at}"

class HeartbeatLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    equipment = models.ForeignKey(Equipment, on_delete=models.CASCADE)
    timestamp = models.BigIntegerField()
    dht22_working = models.BooleanField()
    pzem_working = models.BooleanField(default=True)
    photoresistor_working = models.BooleanField(default=True)
    success_rate = models.FloatField()
    wifi_signal = models.IntegerField()
    uptime = models.BigIntegerField()
    sensor_type = models.CharField(max_length=100)
    current_temp = models.FloatField()
    current_humidity = models.FloatField()
    current_power = models.FloatField(default=0.0)
    pzem_error_count = models.IntegerField(default=0)
    voltage_stability = models.FloatField(null=True, blank=True, help_text="Standard deviation of voltage")
    failed_readings = models.IntegerField(default=0)
    recorded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-recorded_at']
        indexes = [
            models.Index(fields=['equipment', 'recorded_at']),
        ]

    def __str__(self):
        return f"{self.equipment.name} - Heartbeat {self.recorded_at}"

class EnergySummary(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    component = models.ForeignKey(Component, on_delete=models.CASCADE)
    room = models.ForeignKey(Room, on_delete=models.CASCADE)
    period_start = models.DateTimeField()
    period_end = models.DateTimeField()
    period_type = models.CharField(max_length=50, choices=PERIOD_TYPE_CHOICES)
    total_energy = models.FloatField()
    avg_power = models.FloatField()
    peak_power = models.FloatField()
    reading_count = models.IntegerField()
    anomaly_count = models.IntegerField(default=0)
    total_cost = models.FloatField(validators=[MinValueValidator(0.0)], help_text="Total cost for the period in currency")
    currency = models.CharField(max_length=3, choices=CURRENCY_CHOICES, default='PHP')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=['component', 'period_start', 'period_type']),
            models.Index(fields=['room', 'period_start']),
        ]
        constraints = [
            models.CheckConstraint(
                check=models.Q(total_energy__gte=0),
                name='total_energy_non_negative'
            ),
            models.CheckConstraint(
                check=models.Q(avg_power__gte=0),
                name='avg_power_non_negative'
            ),
            models.CheckConstraint(
                check=models.Q(peak_power__gte=0),
                name='peak_power_non_negative'
            ),
            models.CheckConstraint(
                check=models.Q(reading_count__gte=0),
                name='reading_count_non_negative'
            ),
            models.CheckConstraint(
                check=models.Q(anomaly_count__gte=0),
                name='anomaly_count_non_negative'
            ),
            models.CheckConstraint(
                check=models.Q(total_cost__gte=0),
                name='total_cost_non_negative'
            ),
        ]

    def __str__(self):
        return f"{self.component} - {self.period_type} {self.period_start}"

class PredictiveAlert(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    component = models.ForeignKey(Component, on_delete=models.CASCADE)
    prediction = models.TextField(help_text="LLM-generated prediction, e.g., 'PZEM failure likely'")
    confidence = models.FloatField(help_text="Prediction confidence score (0-1)")
    triggered_at = models.DateTimeField(auto_now_add=True)
    resolved = models.BooleanField(default=False)
    resolved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-triggered_at']
        indexes = [
            models.Index(fields=['component', 'triggered_at']),
        ]

    def __str__(self):
        return f"{self.component} - Predictive Alert {self.triggered_at}"

class BillingRate(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    room = models.ForeignKey(Room, on_delete=models.CASCADE, null=True, blank=True)
    rate_per_kwh = models.FloatField(validators=[MinValueValidator(0.01)], help_text="Rate per kWh in currency")
    currency = models.CharField(max_length=3, choices=CURRENCY_CHOICES, default='PHP')
    start_time = models.TimeField(null=True, blank=True, help_text="Start time for rate applicability (e.g., 09:00)")
    end_time = models.TimeField(null=True, blank=True, help_text="End time for rate applicability (e.g., 17:00)")
    valid_from = models.DateTimeField(null=True, blank=True, help_text="Start date for rate validity")
    valid_to = models.DateTimeField(null=True, blank=True, help_text="End date for rate validity")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=['room', 'start_time', 'end_time']),
            models.Index(fields=['valid_from', 'valid_to']),
        ]
        constraints = [
            models.CheckConstraint(
                check=models.Q(start_time__lt=models.F('end_time')) | models.Q(start_time__isnull=True) | models.Q(end_time__isnull=True),
                name='start_time_before_end_time'
            ),
            models.CheckConstraint(
                check=models.Q(valid_from__lt=models.F('valid_to')) | models.Q(valid_from__isnull=True) | models.Q(valid_to__isnull=True),
                name='valid_from_before_valid_to'
            ),
            models.UniqueConstraint(
                fields=['room', 'start_time', 'end_time', 'valid_from', 'valid_to'],
                condition=models.Q(start_time__isnull=False, end_time__isnull=False, valid_from__isnull=False),
                name='unique_room_time_validity_period'
            ),
        ]

    def __str__(self):
        room_name = self.room.name if self.room else 'Global'
        time_range = f"{self.start_time.strftime('%H:%M')}-{self.end_time.strftime('%H:%M')}" if self.start_time and self.end_time else 'All Day'
        validity_range = f"{self.valid_from.strftime('%Y-%m-%d') if self.valid_from else 'No start'} to {self.valid_to.strftime('%Y-%m-%d') if self.valid_to else 'Ongoing'}"
        return f"Rate for {room_name} - {self.rate_per_kwh} {self.currency}/kWh ({time_range}, {validity_range})"

    def get_rate_for_time(self, timestamp):
        """Return the applicable rate based on start_time, end_time, valid_from, valid_to, and timestamp."""
        if self.valid_from and timestamp < self.valid_from:
            return 0  # Rate not yet valid
        if self.valid_to and timestamp > self.valid_to:
            return 0  # Rate expired
        if not self.start_time or not self.end_time:
            return self.rate_per_kwh  # No time restriction, use full rate
        current_time = timestamp.time()
        if self.start_time <= current_time <= self.end_time:
            return self.rate_per_kwh
        return self.rate_per_kwh * 0.8  # 20% discount for off-peak times

class Alert(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    equipment = models.ForeignKey(Equipment, on_delete=models.CASCADE)
    type = models.CharField(max_length=100, choices=ALERT_TYPE_CHOICES)
    message = models.TextField()
    severity = models.CharField(max_length=50, choices=ALERT_SEVERITY_CHOICES, default='medium')
    triggered_at = models.DateTimeField(auto_now_add=True)
    resolved = models.BooleanField(default=False)
    resolved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-triggered_at']

    def __str__(self):
        return f"{self.equipment.name} - {self.type} ({self.severity})"

class MaintenanceRequest(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey('User', on_delete=models.CASCADE)
    equipment = models.ForeignKey(Equipment, on_delete=models.CASCADE)
    issue = models.TextField()
    status = models.CharField(max_length=100, choices=MAINTENANCE_STATUS_CHOICES, default='pending')
    assigned_to = models.ForeignKey('User', on_delete=models.SET_NULL, null=True, blank=True, related_name='assigned_requests')
    comments = models.TextField(blank=True)
    scheduled_date = models.DateField()
    resolved_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.equipment.name} - {self.issue[:50]}"

class MaintenanceAttachment(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    maintenance_request = models.ForeignKey('MaintenanceRequest', on_delete=models.CASCADE, related_name='attachments')
    file = models.FileField(upload_to='maintenance_attachments/%Y/%m/%d/')
    file_name = models.CharField(max_length=255)
    file_type = models.CharField(max_length=100)
    uploaded_at = models.DateTimeField(auto_now_add=True)
    uploaded_by = models.ForeignKey('User', on_delete=models.SET_NULL, null=True)

    def __str__(self):
        return f"Attachment for {self.maintenance_request} - {self.file_name}"

class Notification(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey('User', on_delete=models.CASCADE)
    title = models.CharField(max_length=255)
    message = models.TextField()
    read = models.BooleanField(default=False)
    category = models.CharField(max_length=50, choices=NOTIFICATION_CATEGORY_CHOICES, default='system')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.username} - {self.title}"

class LLMQuery(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey('User', on_delete=models.CASCADE)
    query = models.TextField()
    response = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - {self.query[:50]}"

class LLMSummary(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    generated_for = models.DateField()
    summary = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Summary for {self.generated_for}"

class AuthToken(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey('User', on_delete=models.CASCADE)
    token = models.CharField(max_length=255)
    expires_at = models.DateTimeField()

    def __str__(self):
        return f"{self.user.username} - Token"