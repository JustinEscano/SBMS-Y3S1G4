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
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework_simplejwt.views import TokenObtainPairView
from .permissions import RoleBasedPermission
import logging
import sys
import os

# Add LLM module to path
llm_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), 'llm', 'static_remote_LLM')
sys.path.append(llm_path)

# Set up logging
logger = logging.getLogger(__name__)

class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    username_field = User.EMAIL_FIELD # force SimpleJWT to use email

    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        # Add extra claims if needed
        token['role'] = user.role
        return token

class CustomTokenObtainPairView(TokenObtainPairView):
    serializer_class = CustomTokenObtainPairSerializer

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
    queryset = SensorLog.objects.all().order_by('-recorded_at') # Latest first
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

# New endpoint for field options
@api_view(['GET'])
@permission_classes([AllowAny])
def equipment_field_options(request):
    """
    Endpoint to get standardized field options for frontend dropdowns
    """
    logger.info("Equipment field options requested")
    return Response({
        'equipment_status_options': [
            {'value': 'online', 'label': 'Online', 'description': 'Equipment is working and connected'},
            {'value': 'offline', 'label': 'Offline', 'description': 'Equipment is not working or disconnected'},
            {'value': 'maintenance', 'label': 'Maintenance', 'description': 'Equipment is under maintenance'},
            {'value': 'error', 'label': 'Error', 'description': 'Equipment has errors or issues'},
        ],
        'equipment_type_options': [
            {'value': 'esp32', 'label': 'ESP32', 'description': 'ESP32 microcontroller'},
            {'value': 'sensor', 'label': 'Sensor', 'description': 'General sensors'},
            {'value': 'actuator', 'label': 'Actuator', 'description': 'Motors, relays, etc.'},
            {'value': 'controller', 'label': 'Controller', 'description': 'Control devices'},
            {'value': 'monitor', 'label': 'Monitor', 'description': 'Monitoring devices'},
        ],
        'room_type_options': [
            {'value': 'office', 'label': 'Office', 'description': 'Office spaces'},
            {'value': 'lab', 'label': 'Laboratory', 'description': 'Laboratory'},
            {'value': 'meeting', 'label': 'Meeting Room', 'description': 'Meeting rooms'},
            {'value': 'storage', 'label': 'Storage', 'description': 'Storage areas'},
            {'value': 'corridor', 'label': 'Corridor', 'description': 'Hallways/corridors'},
            {'value': 'utility', 'label': 'Utility', 'description': 'Utility rooms'},
        ]
    })

# ESP32 Integration Endpoints
@api_view(['POST'])
@permission_classes([AllowAny]) # Allow ESP32 to send data without authentication
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
    logger.info(f"ESP32 sensor data received: {request.method} {request.path}")
    logger.info(f"Request data: {request.data}")
    
    try:
        data = request.data
        
        # Validate required fields
        required_fields = ['device_id', 'temperature', 'humidity', 'light_level', 'motion_detected']
        for field in required_fields:
            if field not in data:
                logger.error(f"Missing required field: {field}")
                return Response(
                    {'error': f'Missing required field: {field}'},
                    status=status.HTTP_400_BAD_REQUEST
                )

        # Find equipment by device_id
        try:
            equipment = Equipment.objects.get(device_id=data['device_id'])
            logger.info(f"Found equipment: {equipment.name}")
        except Equipment.DoesNotExist:
            logger.error(f"Equipment with device_id {data['device_id']} not found")
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
            energy_usage=float(data.get('energy_usage', 0.0)), # Optional field
            recorded_at=timezone.now()
        )

        # Update equipment status to online (using standardized value)
        equipment.status = 'online'
        equipment.save()

        logger.info(f"Sensor data saved successfully: {sensor_log.id}")
        
        return Response({
            'success': True,
            'message': 'Sensor data received successfully',
            'log_id': str(sensor_log.id),
            'timestamp': sensor_log.recorded_at.isoformat()
        }, status=status.HTTP_201_CREATED)

    except ValueError as e:
        logger.error(f"Invalid data format: {str(e)}")
        return Response(
            {'error': f'Invalid data format: {str(e)}'},
            status=status.HTTP_400_BAD_REQUEST
        )
    except Exception as e:
        logger.error(f"Server error: {str(e)}")
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
    logger.info("ESP32 health check requested")
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
    logger.info("Latest sensor data requested")
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

        logger.info(f"Returning {len(latest_logs)} sensor readings")
        return Response({
            'success': True,
            'data': latest_logs,
            'count': len(latest_logs)
        }, status=status.HTTP_200_OK)

    except Exception as e:
        logger.error(f"Server error in latest_sensor_data: {str(e)}")
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
    logger.info(f"ESP32 heartbeat received: {request.method} {request.path}")
    logger.info(f"Heartbeat data: {request.data}")
    
    try:
        device_id = request.data.get('device_id')
        if not device_id:
            logger.error("Missing device_id in heartbeat")
            return Response(
                {'error': 'device_id is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            equipment = Equipment.objects.get(device_id=device_id)
            equipment.status = 'online' # Use standardized value
            equipment.save()
            
            logger.info(f"Heartbeat processed for {device_id}")
            return Response({
                'success': True,
                'message': f'Heartbeat received from {device_id}',
                'timestamp': timezone.now().isoformat()
            })

        except Equipment.DoesNotExist:
            logger.error(f"Equipment with device_id {device_id} not found")
            return Response(
                {'error': f'Equipment with device_id {device_id} not found'},
                status=status.HTTP_404_NOT_FOUND
            )

    except Exception as e:
        logger.error(f"Server error in heartbeat: {str(e)}")
        return Response(
            {'error': f'Server error: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

# LLM Integration Endpoints
@api_view(['POST'])
@permission_classes([AllowAny])
def llm_query(request):
    """
    Endpoint to query the LLM about sensor data and building management
    Expected JSON format:
    {
        "query": "What is the average temperature?",
        "user_id": "optional_user_id"
    }
    """
    logger.info(f"LLM query received: {request.method} {request.path}")
    logger.info(f"Query data: {request.data}")
    
    try:
        query_text = request.data.get('query')
        user_id = request.data.get('user_id')
        
        if not query_text:
            logger.error("Missing query in request")
            return Response(
                {'error': 'query is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Import LLM module
        try:
            from main import ask
            logger.info("LLM module imported successfully")
        except ImportError as e:
            logger.error(f"Failed to import LLM module: {e}")
            return Response(
                {'error': 'LLM service not available'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE
            )

        # Process the query
        logger.info(f"Processing query: {query_text}")
        result = ask(query_text)
        
        if "error" in result:
            logger.error(f"LLM query failed: {result['error']}")
            return Response(
                {'error': result['error']},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        # Save query to database if user_id provided
        if user_id:
            try:
                user = User.objects.get(id=user_id)
                llm_query_record = LLMQuery.objects.create(
                    user=user,
                    query=query_text,
                    response=result.get('answer', '')
                )
                logger.info(f"Query saved to database: {llm_query_record.id}")
            except User.DoesNotExist:
                logger.warning(f"User {user_id} not found, query not saved")
            except Exception as e:
                logger.error(f"Failed to save query: {e}")

        logger.info(f"LLM query processed successfully")
        return Response({
            'success': True,
            'query': query_text,
            'answer': result.get('answer', ''),
            'sources': result.get('sources', []),
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_200_OK)

    except Exception as e:
        logger.error(f"Server error in LLM query: {str(e)}")
        return Response(
            {'error': f'Server error: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['GET'])
@permission_classes([AllowAny])
def llm_health_check(request):
    """
    Health check endpoint for LLM service
    """
    logger.info("LLM health check requested")
    
    try:
        # Try to import LLM module
        from main import ask
        
        # Test with a simple query
        result = ask("How many records are there?")
        
        if "error" in result:
            return Response({
                'status': 'unhealthy',
                'message': 'LLM service has errors',
                'error': result['error'],
                'timestamp': timezone.now().isoformat()
            }, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        
        return Response({
            'status': 'healthy',
            'message': 'LLM service is running',
            'database_connected': True,
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_200_OK)
        
    except ImportError as e:
        logger.error(f"LLM module import failed: {e}")
        return Response({
            'status': 'unhealthy',
            'message': 'LLM service not available',
            'error': str(e),
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_503_SERVICE_UNAVAILABLE)
    
    except Exception as e:
        logger.error(f"LLM health check failed: {e}")
        return Response({
            'status': 'unhealthy',
            'message': 'LLM service error',
            'error': str(e),
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_503_SERVICE_UNAVAILABLE)