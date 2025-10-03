from rest_framework import serializers
from .models import (
    User, Room, Equipment, SensorLog, HeartbeatLog, MaintenanceRequest, LLMQuery, LLMSummary,
    AuthToken, Alert, Notification, MaintenanceAttachment, Component, EnergySummary,
    PredictiveAlert, BillingRate, ROLE_CHOICES, EQUIPMENT_TYPE_CHOICES,
    EQUIPMENT_STATUS_CHOICES, ROOM_TYPE_CHOICES, COMPONENT_TYPE_CHOICES,
    MAINTENANCE_STATUS_CHOICES, ALERT_TYPE_CHOICES, ALERT_SEVERITY_CHOICES,
    PERIOD_TYPE_CHOICES, CURRENCY_CHOICES, NOTIFICATION_CATEGORY_CHOICES
)
from django.contrib.auth.hashers import make_password
from django.utils import timezone
from datetime import time

class UserSerializer(serializers.ModelSerializer):
    role_display = serializers.CharField(source='get_role_display', read_only=True)
    
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'password', 'role', 'role_display', 'created_at']
        extra_kwargs = {'password': {'write_only': True}}

    def create(self, validated_data):
        validated_data['password'] = make_password(validated_data['password'])
        return super().create(validated_data)

    def validate_role(self, value):
        valid_roles = [choice[0] for choice in ROLE_CHOICES]
        if value not in valid_roles:
            raise serializers.ValidationError(f"Invalid role. Must be one of: {', '.join(valid_roles)}")
        return value

class RoomSerializer(serializers.ModelSerializer):
    type_display = serializers.CharField(source='get_type_display', read_only=True)
    
    class Meta:
        model = Room
        fields = ['id', 'name', 'floor', 'capacity', 'type', 'type_display', 'typical_energy_usage', 'occupancy_pattern', 'created_at']
        
    def validate_type(self, value):
        valid_types = [choice[0] for choice in ROOM_TYPE_CHOICES]
        if value not in valid_types:
            raise serializers.ValidationError(f"Invalid room type. Must be one of: {', '.join(valid_types)}")
        return value

    def validate_typical_energy_usage(self, value):
        if value is not None and value < 0:
            raise serializers.ValidationError("Typical energy usage must be non-negative")
        return value

    def validate_occupancy_pattern(self, value):
        if value and len(value) > 255:
            raise serializers.ValidationError("Occupancy pattern must not exceed 255 characters")
        return value

class EquipmentSerializer(serializers.ModelSerializer):
    room_name = serializers.CharField(source='room.name', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    type_display = serializers.CharField(source='get_type_display', read_only=True)
    qr_code_data = serializers.SerializerMethodField()
    
    class Meta:
        model = Equipment
        fields = ['id', 'name', 'room', 'room_name', 'type', 'type_display', 'status', 'status_display', 'device_id', 'qr_code', 'qr_code_data', 'created_at']
        
    def get_qr_code_data(self, obj):
        return obj.generate_qr_code()
        
    def validate_type(self, value):
        valid_types = [choice[0] for choice in EQUIPMENT_TYPE_CHOICES]
        if value not in valid_types:
            raise serializers.ValidationError(f"Invalid equipment type. Must be one of: {', '.join(valid_types)}")
        return value
        
    def validate_status(self, value):
        valid_statuses = [choice[0] for choice in EQUIPMENT_STATUS_CHOICES]
        if value not in valid_statuses:
            raise serializers.ValidationError(f"Invalid status. Must be one of: {', '.join(valid_statuses)}")
        return value

class ComponentSerializer(serializers.ModelSerializer):
    equipment_name = serializers.CharField(source='equipment.name', read_only=True)
    component_type_display = serializers.CharField(source='get_component_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    
    class Meta:
        model = Component
        fields = ['id', 'equipment', 'equipment_name', 'component_type', 'component_type_display', 'identifier', 'status', 'status_display', 'created_at']
    
    def validate_component_type(self, value):
        valid_types = [choice[0] for choice in COMPONENT_TYPE_CHOICES]
        if value not in valid_types:
            raise serializers.ValidationError(f"Invalid component type. Must be one of: {', '.join(valid_types)}")
        return value
    
    def validate_identifier(self, value):
        equipment_id = self.initial_data.get('equipment')
        if equipment_id and Component.objects.filter(equipment_id=equipment_id, identifier=value).exists():
            raise serializers.ValidationError(f"Component with identifier '{value}' already exists for this equipment")
        return value

class SensorLogSerializer(serializers.ModelSerializer):
    equipment_name = serializers.CharField(source='equipment.name', read_only=True)
    component_name = serializers.CharField(source='component.component_type', read_only=True)
    
    class Meta:
        model = SensorLog
        fields = [
            'id', 'equipment', 'equipment_name', 'component', 'component_name', 'temperature', 'humidity',
            'light_detected', 'motion_detected', 'energy_usage', 'voltage', 'current', 'power', 'energy',
            'recorded_at', 'pzem_recorded_at', 'dht22_recorded_at', 'photoresistor_recorded_at', 'motion_recorded_at'
        ]

    def validate(self, data):
        component = data.get('component')
        if component:
            component_type = component.component_type
            if component_type == 'pzem' and data.get('pzem_recorded_at') is None:
                raise serializers.ValidationError("pzem_recorded_at is required for PZEM component")
            if component_type == 'dht22' and data.get('dht22_recorded_at') is None:
                raise serializers.ValidationError("dht22_recorded_at is required for DHT22 component")
            if component_type == 'photoresistor' and data.get('photoresistor_recorded_at') is None:
                raise serializers.ValidationError("photoresistor_recorded_at is required for Photoresistor component")
            if component_type == 'motion' and data.get('motion_recorded_at') is None:
                raise serializers.ValidationError("motion_recorded_at is required for Motion component")
        return data

class HeartbeatLogSerializer(serializers.ModelSerializer):
    equipment_name = serializers.CharField(source='equipment.name', read_only=True)
    
    class Meta:
        model = HeartbeatLog
        fields = [
            'id', 'equipment', 'equipment_name', 'timestamp', 'dht22_working', 'pzem_working',
            'photoresistor_working', 'success_rate', 'wifi_signal', 'uptime', 'sensor_type',
            'current_temp', 'current_humidity', 'current_power', 'pzem_error_count',
            'voltage_stability', 'failed_readings', 'recorded_at'
        ]

    def validate_pzem_error_count(self, value):
        if value < 0:
            raise serializers.ValidationError("PZEM error count must be non-negative")
        return value

    def validate_voltage_stability(self, value):
        if value is not None and value < 0:
            raise serializers.ValidationError("Voltage stability must be non-negative")
        return value

    def validate_failed_readings(self, value):
        if value < 0:
            raise serializers.ValidationError("Failed readings count must be non-negative")
        return value

class EnergySummarySerializer(serializers.ModelSerializer):
    component_name = serializers.CharField(source='component.component_type', read_only=True)
    room_name = serializers.CharField(source='room.name', read_only=True)
    period_type_display = serializers.CharField(source='get_period_type_display', read_only=True)
    
    class Meta:
        model = EnergySummary
        fields = [
            'id', 'component', 'component_name', 'room', 'room_name', 'period_start', 'period_end',
            'period_type', 'period_type_display', 'total_energy', 'avg_power', 'peak_power',
            'reading_count', 'anomaly_count', 'total_cost', 'currency', 'created_at'
        ]

    def validate_total_energy(self, value):
        if value < 0:
            raise serializers.ValidationError("Total energy must be non-negative")
        return value

    def validate_avg_power(self, value):
        if value < 0:
            raise serializers.ValidationError("Average power must be non-negative")
        return value

    def validate_peak_power(self, value):
        if value < 0:
            raise serializers.ValidationError("Peak power must be non-negative")
        return value

    def validate_reading_count(self, value):
        if value < 0:
            raise serializers.ValidationError("Reading count must be non-negative")
        return value

    def validate_anomaly_count(self, value):
        if value < 0:
            raise serializers.ValidationError("Anomaly count must be non-negative")
        return value

    def validate_total_cost(self, value):
        if value < 0:
            raise serializers.ValidationError("Total cost must be non-negative")
        return value

    def validate_period_type(self, value):
        valid_types = [choice[0] for choice in PERIOD_TYPE_CHOICES]
        if value not in valid_types:
            raise serializers.ValidationError(f"Invalid period type. Must be one of: {', '.join(valid_types)}")
        return value

class PredictiveAlertSerializer(serializers.ModelSerializer):
    component_name = serializers.CharField(source='component.component_type', read_only=True)
    
    class Meta:
        model = PredictiveAlert
        fields = ['id', 'component', 'component_name', 'prediction', 'confidence', 'triggered_at', 'resolved', 'resolved_at']

    def validate_confidence(self, value):
        if not 0 <= value <= 1:
            raise serializers.ValidationError("Confidence must be between 0 and 1")
        return value

class BillingRateSerializer(serializers.ModelSerializer):
    room_name = serializers.CharField(source='room.name', read_only=True)
    currency_display = serializers.CharField(source='get_currency_display', read_only=True)
    
    class Meta:
        model = BillingRate
        fields = ['id', 'room', 'room_name', 'rate_per_kwh', 'currency', 'currency_display', 'start_time', 'end_time', 'valid_from', 'valid_to', 'created_at']
        read_only_fields = ['id', 'created_at', 'currency_display']

    def validate_rate_per_kwh(self, value):
        if value <= 0:
            raise serializers.ValidationError("Rate per kWh must be positive")
        return value

    def validate_currency(self, value):
        valid_currencies = [choice[0] for choice in CURRENCY_CHOICES]
        if value not in valid_currencies:
            raise serializers.ValidationError(f"Invalid currency. Must be one of: {', '.join(valid_currencies)}")
        return value

    def validate(self, data):
        start_time = data.get('start_time')
        end_time = data.get('end_time')
        valid_from = data.get('valid_from')
        valid_to = data.get('valid_to')
        room = data.get('room')

        if valid_to and valid_from and valid_from >= valid_to:
            raise serializers.ValidationError("valid_from must be before valid_to")

        if start_time and end_time:
            if start_time >= end_time:
                raise serializers.ValidationError("start_time must be before end_time")

            start_minutes = start_time.hour * 60 + start_time.minute
            end_minutes = end_time.hour * 60 + end_time.minute

            existing_rates = BillingRate.objects.filter(room=room)
            if self.instance:
                existing_rates = existing_rates.exclude(id=self.instance.id)
            
            for rate in existing_rates:
                if rate.start_time and rate.end_time:
                    existing_start = rate.start_time.hour * 60 + rate.start_time.minute
                    existing_end = rate.end_time.hour * 60 + rate.end_time.minute
                    time_overlap = not (end_minutes <= existing_start or start_minutes >= existing_end)
                    validity_overlap = (
                        (rate.valid_to is None or (valid_from and valid_from < rate.valid_to)) and
                        (valid_to is None or (rate.valid_from and rate.valid_from < valid_to))
                    )
                    if time_overlap and validity_overlap:
                        raise serializers.ValidationError(
                            f"Rate period overlaps with existing rate ID {rate.id} in time and validity."
                        )

        return data

class AlertSerializer(serializers.ModelSerializer):
    equipment_name = serializers.CharField(source='equipment.name', read_only=True)
    type_display = serializers.CharField(source='get_type_display', read_only=True)
    severity_display = serializers.CharField(source='get_severity_display', read_only=True)
    
    class Meta:
        model = Alert
        fields = ['id', 'equipment', 'equipment_name', 'type', 'type_display', 'message', 'severity', 'severity_display', 'triggered_at', 'resolved', 'resolved_at']

    def validate_type(self, value):
        valid_types = [choice[0] for choice in ALERT_TYPE_CHOICES]
        if value not in valid_types:
            raise serializers.ValidationError(f"Invalid alert type. Must be one of: {', '.join(valid_types)}")
        return value

class MaintenanceAttachmentSerializer(serializers.ModelSerializer):
    uploaded_by_name = serializers.CharField(source='uploaded_by.username', read_only=True)
    
    class Meta:
        model = MaintenanceAttachment
        fields = ['id', 'maintenance_request', 'file', 'file_name', 'file_type', 'uploaded_at', 'uploaded_by', 'uploaded_by_name']
    
    def validate_file(self, value):
        max_size = 10 * 1024 * 1024  # 10MB limit
        allowed_types = ['image/jpeg', 'image/png', 'application/pdf']
        
        if value.size > max_size:
            raise serializers.ValidationError("File size exceeds 10MB limit")
        
        if value.content_type not in allowed_types:
            raise serializers.ValidationError(f"File type {value.content_type} not allowed. Allowed types: {', '.join(allowed_types)}")
        
        return value

class MaintenanceRequestSerializer(serializers.ModelSerializer):
    equipment_name = serializers.CharField(source='equipment.name', read_only=True)
    user_name = serializers.CharField(source='user.username', read_only=True)
    assigned_to_name = serializers.CharField(source='assigned_to.username', read_only=True)
    attachments = MaintenanceAttachmentSerializer(many=True, read_only=True)
    
    class Meta:
        model = MaintenanceRequest
        fields = ['id', 'user', 'user_name', 'equipment', 'equipment_name', 'issue', 'status', 
                 'assigned_to', 'assigned_to_name', 'comments', 'scheduled_date', 'resolved_at', 
                 'created_at', 'attachments']

    def validate_status(self, value):
        valid_statuses = [choice[0] for choice in MAINTENANCE_STATUS_CHOICES]
        if value not in valid_statuses:
            raise serializers.ValidationError(f"Invalid status. Must be one of: {', '.join(valid_statuses)}")
        return value

class NotificationSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.username', read_only=True)
    category_display = serializers.CharField(source='get_category_display', read_only=True)
    
    class Meta:
        model = Notification
        fields = ['id', 'user', 'user_name', 'title', 'message', 'read', 'category', 'category_display', 'created_at']

    def to_representation(self, instance):
        """Standardize notification payload for frontend"""
        representation = super().to_representation(instance)
        return {
            'id': str(representation['id']),
            'type': representation['category'],
            'title': representation['title'],
            'message': representation['message'],
            'read': representation['read'],
            'metadata': {
                'user_name': representation['user_name'],
                'category_display': representation['category_display'],
                'created_at': representation['created_at']
            }
        }

class LLMQuerySerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.username', read_only=True)
    
    class Meta:
        model = LLMQuery
        fields = ['id', 'user', 'user_name', 'query', 'response', 'created_at']

class LLMSummarySerializer(serializers.ModelSerializer):
    class Meta:
        model = LLMSummary
        fields = ['id', 'generated_for', 'summary', 'created_at']

class AuthTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = AuthToken
        fields = ['id', 'user', 'token', 'expires_at']