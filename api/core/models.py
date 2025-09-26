from django.db import models
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
import uuid
from django.db.models import Avg

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
    qr_code = models.CharField(max_length=255, null=True, blank=True)
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
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=['component', 'period_start', 'period_type']),
            models.Index(fields=['room', 'period_start']),
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
    rate_per_kwh = models.FloatField()
    time_period = models.CharField(max_length=255, null=True, blank=True, help_text="e.g., 'peak:9AM-5PM'")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=['room', 'time_period']),
        ]

    def __str__(self):
        return f"Rate for {self.room.name if self.room else 'Global'} - {self.rate_per_kwh}"

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