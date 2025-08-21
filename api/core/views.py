from rest_framework import viewsets
from rest_framework import generics
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone
from django.http import HttpResponse
from .models import *
from .serializers import *

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [AllowAny]

def home(request):
    return HttpResponse("Welcome to the DBMS API.")

class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.all()
    serializer_class = UserSerializer

class RoomViewSet(viewsets.ModelViewSet):
    queryset = Room.objects.all()
    serializer_class = RoomSerializer

class EquipmentViewSet(viewsets.ModelViewSet):
    queryset = Equipment.objects.all()
    serializer_class = EquipmentSerializer

class SensorLogViewSet(viewsets.ModelViewSet):
    queryset = SensorLog.objects.all().order_by('-recorded_at')  # Latest first
    serializer_class = SensorLogSerializer

class MaintenanceRequestViewSet(viewsets.ModelViewSet):
    queryset = MaintenanceRequest.objects.all()
    serializer_class = MaintenanceRequestSerializer

class LLMQueryViewSet(viewsets.ModelViewSet):
    queryset = LLMQuery.objects.all()
    serializer_class = LLMQuerySerializer

class LLMSummaryViewSet(viewsets.ModelViewSet):
    queryset = LLMSummary.objects.all()
    serializer_class = LLMSummarySerializer

class AuthTokenViewSet(viewsets.ModelViewSet):
    queryset = AuthToken.objects.all()
    serializer_class = AuthTokenSerializer

# ESP32 Integration Endpoints

@api_view(['POST'])
@permission_classes([AllowAny])  # Allow ESP32 to send data without authentication
def esp32_sensor_data(request):
    """
    Endpoint for ESP32 to send sensor data
    Expected JSON format:
    {
        "device_id": "ESP32_001",
        "temperature": 23.5,
        "humidity": 45.2,
        "light_level": 1250,
        "motion_detected": false,
        "energy_usage": 12.3
    }
    """
    try:
        data = request.data
        
        # Validate required fields
        required_fields = ['device_id', 'temperature', 'humidity', 'light_level', 'motion_detected']
        for field in required_fields:
            if field not in data:
                return Response(
                    {'error': f'Missing required field: {field}'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
        
        # Find equipment by device_id
        try:
            equipment = Equipment.objects.get(device_id=data['device_id'])
        except Equipment.DoesNotExist:
            return Response(
                {'error': f'Equipment with device_id {data["device_id"]} not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Create sensor log entry
        sensor_log = SensorLog.objects.create(
            equipment=equipment,
            temperature=float(data['temperature']),
            humidity=float(data['humidity']),
            light_level=float(data['light_level']),
            motion_detected=bool(data['motion_detected']),
            energy_usage=float(data.get('energy_usage', 0.0)),  # Optional field
            recorded_at=timezone.now()
        )
        
        # Update equipment status to online
        equipment.status = 'online'
        equipment.save()
        
        return Response({
            'success': True,
            'message': 'Sensor data received successfully',
            'log_id': str(sensor_log.id),
            'timestamp': sensor_log.recorded_at.isoformat()
        }, status=status.HTTP_201_CREATED)
        
    except ValueError as e:
        return Response(
            {'error': f'Invalid data format: {str(e)}'}, 
            status=status.HTTP_400_BAD_REQUEST
        )
    except Exception as e:
        return Response(
            {'error': f'Server error: {str(e)}'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['GET'])
@permission_classes([AllowAny])
def esp32_health_check(request):
    """
    Simple health check endpoint for ESP32
    """
    return Response({
        'status': 'healthy',
        'message': 'ESP32 API is running',
        'timestamp': timezone.now().isoformat()
    })

@api_view(['GET'])
@permission_classes([AllowAny])
def latest_sensor_data(request):
    """
    Get the latest sensor readings for dashboard
    """
    try:
        # Get latest sensor log for each ESP32 equipment
        latest_logs = []
        equipment_list = Equipment.objects.filter(type__in=['esp32'])
        
        for equipment in equipment_list:
            latest_log = SensorLog.objects.filter(equipment=equipment).order_by('-recorded_at').first()
            if latest_log:
                latest_logs.append({
                    'equipment_id': str(equipment.id),
                    'equipment_name': equipment.name,
                    'device_id': equipment.device_id,
                    'temperature': latest_log.temperature,
                    'humidity': latest_log.humidity,
                    'light_level': latest_log.light_level,
                    'motion_detected': latest_log.motion_detected,
                    'energy_usage': latest_log.energy_usage,
                    'recorded_at': latest_log.recorded_at.isoformat(),
                    'status': equipment.status
                })
        
        return Response({
            'success': True,
            'data': latest_logs,
            'count': len(latest_logs)
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        return Response(
            {'error': f'Server error: {str(e)}'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['POST'])
@permission_classes([AllowAny])
def esp32_heartbeat(request):
    """
    Endpoint for ESP32 to send heartbeat and update status
    """
    try:
        device_id = request.data.get('device_id')
        if not device_id:
            return Response(
                {'error': 'device_id is required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            equipment = Equipment.objects.get(device_id=device_id)
            equipment.status = 'online'
            equipment.save()
            
            return Response({
                'success': True,
                'message': f'Heartbeat received from {device_id}',
                'timestamp': timezone.now().isoformat()
            })
        except Equipment.DoesNotExist:
            return Response(
                {'error': f'Equipment with device_id {device_id} not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )
            
    except Exception as e:
        return Response(
            {'error': f'Server error: {str(e)}'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )