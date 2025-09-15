from rest_framework import serializers
from .models import User, Room, Equipment, SensorLog, MaintenanceRequest, LLMQuery, LLMSummary, AuthToken, Alert, Notification, MaintenanceAttachment, ROLE_CHOICES, EQUIPMENT_TYPE_CHOICES, EQUIPMENT_STATUS_CHOICES, ROOM_TYPE_CHOICES
from django.contrib.auth.hashers import make_password

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
        """Validate role against allowed choices"""
        valid_roles = [choice[0] for choice in ROLE_CHOICES]
        if value not in valid_roles:
            raise serializers.ValidationError(f"Invalid role. Must be one of: {', '.join(valid_roles)}")
        return value

class RoomSerializer(serializers.ModelSerializer):
    type_display = serializers.CharField(source='get_type_display', read_only=True)
    
    class Meta:
        model = Room
        fields = '__all__'
        
    def validate_type(self, value):
        """Validate room type against allowed choices"""
        valid_types = [choice[0] for choice in ROOM_TYPE_CHOICES]
        if value not in valid_types:
            raise serializers.ValidationError(f"Invalid room type. Must be one of: {', '.join(valid_types)}")
        return value

class EquipmentSerializer(serializers.ModelSerializer):
    room_name = serializers.CharField(source='room.name', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    type_display = serializers.CharField(source='get_type_display', read_only=True)
    qr_code_data = serializers.SerializerMethodField()
    
    class Meta:
        model = Equipment
        fields = '__all__'
        
    def get_qr_code_data(self, obj):
        """Generate and return QR code data if not exists"""
        return obj.generate_qr_code()
        
    def validate_type(self, value):
        """Validate equipment type against allowed choices"""
        valid_types = [choice[0] for choice in EQUIPMENT_TYPE_CHOICES]
        if value not in valid_types:
            raise serializers.ValidationError(f"Invalid equipment type. Must be one of: {', '.join(valid_types)}")
        return value
        
    def validate_status(self, value):
        """Validate equipment status against allowed choices"""
        valid_statuses = [choice[0] for choice in EQUIPMENT_STATUS_CHOICES]
        if value not in valid_statuses:
            raise serializers.ValidationError(f"Invalid status. Must be one of: {', '.join(valid_statuses)}")
        return value

class SensorLogSerializer(serializers.ModelSerializer):
    equipment_name = serializers.CharField(source='equipment.name', read_only=True)
    
    class Meta:
        model = SensorLog
        fields = '__all__'

class AlertSerializer(serializers.ModelSerializer):
    equipment_name = serializers.CharField(source='equipment.name', read_only=True)
    type_display = serializers.CharField(source='get_type_display', read_only=True)
    severity_display = serializers.CharField(source='get_severity_display', read_only=True)
    
    class Meta:
        model = Alert
        fields = '__all__'

class MaintenanceAttachmentSerializer(serializers.ModelSerializer):
    uploaded_by_name = serializers.CharField(source='uploaded_by.username', read_only=True)
    
    class Meta:
        model = MaintenanceAttachment
        fields = ['id', 'maintenance_request', 'file', 'file_name', 'file_type', 'uploaded_at', 'uploaded_by', 'uploaded_by_name']
    
    def validate_file(self, value):
        """Validate file size and type"""
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

class NotificationSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.username', read_only=True)
    
    class Meta:
        model = Notification
        fields = '__all__'

class LLMQuerySerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.username', read_only=True)
    
    class Meta:
        model = LLMQuery
        fields = '__all__'

class LLMSummarySerializer(serializers.ModelSerializer):
    class Meta:
        model = LLMSummary
        fields = '__all__'

class AuthTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = AuthToken
        fields = '__all__'