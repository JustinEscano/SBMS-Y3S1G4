from rest_framework import serializers
from .models import User, Room, Equipment, SensorLog, MaintenanceRequest, LLMQuery, LLMSummary, AuthToken

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = '__all__'

class RoomSerializer(serializers.ModelSerializer):
    class Meta:
        model = Room
        fields = '__all__'

class EquipmentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Equipment
        fields = '__all__'

class SensorLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = SensorLog
        fields = '__all__'

class MaintenanceRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model = MaintenanceRequest
        fields = '__all__'

class LLMQuerySerializer(serializers.ModelSerializer):
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