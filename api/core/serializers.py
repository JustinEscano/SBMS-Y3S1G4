from rest_framework import serializers
from .models import User, Room, Equipment, SensorLog, MaintenanceRequest, LLMQuery, LLMSummary, AuthToken, EQUIPMENT_TYPE_CHOICES, EQUIPMENT_STATUS_CHOICES, ROOM_TYPE_CHOICES
from django.contrib.auth.hashers import make_password

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'password', 'role', 'created_at']
        extra_kwargs = {'password': {'write_only': True}}

    def create(self, validated_data):
        validated_data['password'] = make_password(validated_data['password'])
        return super().create(validated_data)

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
    
    class Meta:
        model = Equipment
        fields = '__all__'
        
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

class MaintenanceRequestSerializer(serializers.ModelSerializer):
    equipment_name = serializers.CharField(source='equipment.name', read_only=True)
    user_name = serializers.CharField(source='user.username', read_only=True)
    
    class Meta:
        model = MaintenanceRequest
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