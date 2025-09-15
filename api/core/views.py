from rest_framework import viewsets
from rest_framework import generics
from rest_framework.decorators import api_view, permission_classes, action  # Added 'action' import
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone
from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from django.db.models import Avg, Count
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
    username_field = User.EMAIL_FIELD  # force SimpleJWT to use email

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
    permission_classes = [RoleBasedPermission]

class RoomViewSet(viewsets.ModelViewSet):
    queryset = Room.objects.all()
    serializer_class = RoomSerializer
    permission_classes = [RoleBasedPermission]

class EquipmentViewSet(viewsets.ModelViewSet):
    queryset = Equipment.objects.all()
    serializer_class = EquipmentSerializer
    permission_classes = [RoleBasedPermission]

    def perform_create(self, serializer):
        instance = serializer.save()
        # Auto-generate QR code on create
        instance.generate_qr_code()

class SensorLogViewSet(viewsets.ModelViewSet):
    queryset = SensorLog.objects.all().order_by('-recorded_at')  # Latest first
    serializer_class = SensorLogSerializer
    permission_classes = [RoleBasedPermission]

class AlertViewSet(viewsets.ModelViewSet):
    queryset = Alert.objects.all()
    serializer_class = AlertSerializer
    permission_classes = [RoleBasedPermission]

    def get_queryset(self):
        queryset = super().get_queryset()
        # Filterable by query params, e.g., ?resolved=false&severity=high&type=motion
        resolved = self.request.query_params.get('resolved')
        if resolved is not None:
            resolved_bool = resolved.lower() == 'true'
            queryset = queryset.filter(resolved=resolved_bool)
        severity = self.request.query_params.get('severity')
        if severity:
            queryset = queryset.filter(severity=severity)
        alert_type = self.request.query_params.get('type')
        if alert_type:
            queryset = queryset.filter(type=alert_type)
        return queryset

class MaintenanceAttachmentViewSet(viewsets.ModelViewSet):
    queryset = MaintenanceAttachment.objects.all()
    serializer_class = MaintenanceAttachmentSerializer
    permission_classes = [RoleBasedPermission]

class MaintenanceRequestViewSet(viewsets.ModelViewSet):
    queryset = MaintenanceRequest.objects.all()
    serializer_class = MaintenanceRequestSerializer
    permission_classes = [RoleBasedPermission]

    def perform_create(self, serializer):
        instance = serializer.save(user=self.request.user)  # Ensure user is set
        logger.info(f"Maintenance request created: {instance.id} by {self.request.user.username}")

    def perform_update(self, serializer):
        instance = serializer.save()
        # Send notification on status change or assignment
        if 'status' in serializer.validated_data or 'assigned_to' in serializer.validated_data:
            old_status = getattr(self.get_object(), 'status', None)
            new_status = serializer.validated_data.get('status', old_status)
            if new_status != old_status:
                # Notify user on resolution
                if new_status == 'resolved':
                    Notification.objects.create(
                        user=instance.user,
                        title=f"Maintenance Request Resolved: {instance.equipment.name}",
                        message=f"Your request for {instance.equipment.name} has been resolved."
                    )
            # Notify assignee on assignment
            if instance.assigned_to and 'assigned_to' in serializer.validated_data:
                Notification.objects.create(
                    user=instance.assigned_to,
                    title=f"New Assignment: {instance.equipment.name}",
                    message=f"You have been assigned to resolve the issue: {instance.issue[:100]}"
                )

    @action(detail=True, methods=['post'], permission_classes=[RoleBasedPermission])
    def upload_attachment(self, request, pk=None):
        """
        POST /maintenancerequest/{id}/upload_attachment/
        Upload an attachment for a maintenance request.
        Expected form-data: {'file': <file>, 'file_name': <string>}
        """
        logger.info(f"Attachment upload requested for maintenance request {pk}")
        try:
            maintenance_request = self.get_object()
            file_obj = request.FILES.get('file')
            file_name = request.data.get('file_name', file_obj.name if file_obj else None)

            if not file_obj or not file_name:
                logger.error("Missing file or file_name")
                return Response(
                    {'error': 'Both file and file_name are required'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            attachment = MaintenanceAttachment.objects.create(
                maintenance_request=maintenance_request,
                file=file_obj,
                file_name=file_name,
                file_type=file_obj.content_type,
                uploaded_by=request.user
            )

            logger.info(f"Attachment uploaded: {attachment.id} for {maintenance_request.id}")
            return Response(
                MaintenanceAttachmentSerializer(attachment).data,
                status=status.HTTP_201_CREATED
            )

        except Exception as e:
            logger.error(f"Error uploading attachment: {str(e)}")
            return Response(
                {'error': f'Server error: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class NotificationViewSet(viewsets.ModelViewSet):
    queryset = Notification.objects.all()
    serializer_class = NotificationSerializer
    permission_classes = [RoleBasedPermission]

    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user)

class LLMQueryViewSet(viewsets.ModelViewSet):
    queryset = LLMQuery.objects.all()
    serializer_class = LLMQuerySerializer
    permission_classes = [RoleBasedPermission]

class LLMSummaryViewSet(viewsets.ModelViewSet):
    queryset = LLMSummary.objects.all()
    serializer_class = LLMSummarySerializer
    permission_classes = [RoleBasedPermission]

class AuthTokenViewSet(viewsets.ModelViewSet):
    queryset = AuthToken.objects.all()
    serializer_class = AuthTokenSerializer
    permission_classes = [RoleBasedPermission]

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
        ],
        'role_options': [
            {'value': 'client', 'label': 'Client'},
            {'value': 'admin', 'label': 'Admin'},
            {'value': 'employee', 'label': 'Employee'},
            {'value': 'superadmin', 'label': 'Superadmin'},
        ],
        'alert_type_options': [
            {'value': 'temperature_threshold', 'label': 'Temperature Threshold'},
            {'value': 'motion', 'label': 'Motion Detected'},
            {'value': 'humidity_threshold', 'label': 'Humidity Threshold'},
            {'value': 'energy_anomaly', 'label': 'Energy Anomaly'},
        ],
        'alert_severity_options': [
            {'value': 'low', 'label': 'Low'},
            {'value': 'medium', 'label': 'Medium'},
            {'value': 'high', 'label': 'High'},
        ],
    })

@api_view(['GET'])
@permission_classes([IsAuthenticated, RoleBasedPermission])
def dashboard_summary(request):
    """
    GET /dashboard/summary - Aggregated dashboard data
    """
    logger.info("Dashboard summary requested")
    try:
        total_rooms = Room.objects.count()
        total_equipment = Equipment.objects.count()
        online_equipment = Equipment.objects.filter(status='online').count()
        avg_temp = SensorLog.objects.aggregate(avg_temp=Avg('temperature'))['avg_temp'] or 0
        total_alerts = Alert.objects.count()
        unresolved_alerts = Alert.objects.filter(resolved=False).count()
        recent_logs = SensorLog.objects.order_by('-recorded_at')[:5]

        summary_data = {
            'total_rooms': total_rooms,
            'total_equipment': total_equipment,
            'online_equipment': online_equipment,
            'avg_temperature': round(avg_temp, 2),
            'total_alerts': total_alerts,
            'unresolved_alerts': unresolved_alerts,
            'recent_logs': SensorLogSerializer(recent_logs, many=True).data,
        }

        return Response({
            'success': True,
            'data': summary_data,
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_200_OK)

    except Exception as e:
        logger.error(f"Error in dashboard_summary: {str(e)}")
        return Response(
            {'error': f'Server error: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['GET'])
@permission_classes([IsAuthenticated, RoleBasedPermission])
def room_realtime(request, pk):
    """
    GET /rooms/{id}/realtime - Real-time data for a specific room
    """
    logger.info(f"Room realtime data requested for {pk}")
    try:
        room = get_object_or_404(Room, pk=pk)
        equipments = Equipment.objects.filter(room=room, type='esp32')
        realtime_data = []

        for equipment in equipments:
            latest_log = SensorLog.objects.filter(equipment=equipment).order_by('-recorded_at').first()
            if latest_log:
                realtime_data.append({
                    'equipment_id': str(equipment.id),
                    'equipment_name': equipment.name,
                    'device_id': equipment.device_id,
                    'temperature': latest_log.temperature,
                    'humidity': latest_log.humidity,
                    'light_level': latest_log.light_level,
                    'motion_detected': latest_log.motion_detected,
                    'energy_usage': latest_log.energy_usage,
                    'recorded_at': latest_log.recorded_at.isoformat(),
                    'status': equipment.status,
                    'alerts': AlertSerializer(Alert.objects.filter(equipment=equipment, resolved=False), many=True).data,
                })

        return Response({
            'success': True,
            'room_name': room.name,
            'data': realtime_data,
            'count': len(realtime_data),
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_200_OK)

    except Exception as e:
        logger.error(f"Error in room_realtime: {str(e)}")
        return Response(
            {'error': f'Server error: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['POST'])
@permission_classes([RoleBasedPermission])
def check_anomalies(request):
    """
    POST /check-anomalies - Check recent sensor logs for anomalies and create alerts/maintenance
    Body: {"equipment_id": "uuid", "check_window_hours": 1} or empty for all
    """
    logger.info("Anomaly check requested")
    try:
        equipment_id = request.data.get('equipment_id')
        window_hours = int(request.data.get('check_window_hours', 1))
        cutoff = timezone.now() - timezone.timedelta(hours=window_hours)

        if equipment_id:
            equipments = [get_object_or_404(Equipment, pk=equipment_id)]
        else:
            equipments = Equipment.objects.filter(type='esp32')

        created_alerts = []
        created_requests = []

        for equipment in equipments:
            recent_logs = SensorLog.objects.filter(equipment=equipment, recorded_at__gte=cutoff)
            if not recent_logs.exists():
                continue

            latest_log = recent_logs.latest('recorded_at')

            # Threshold checks
            if latest_log.temperature > 40:
                alert, created = Alert.objects.get_or_create(
                    equipment=equipment,
                    type='temperature_threshold',
                    resolved=False,
                    defaults={
                        'message': f'Temperature exceeded 40°C: {latest_log.temperature}°C',
                        'severity': 'high'
                    }
                )
                if created:
                    created_alerts.append(str(alert.id))
                    # Auto-create maintenance if no recent request
                    recent_request = MaintenanceRequest.objects.filter(
                        equipment=equipment,
                        created_at__gte=cutoff,
                        status__in=['pending', 'in_progress']
                    ).exists()
                    if not recent_request:
                        # Assign to first employee if available
                        assignee = User.objects.filter(role='employee').first()
                        MaintenanceRequest.objects.create(
                            user_id=request.user.id,  # Or system user
                            equipment=equipment,
                            issue=f'Auto-generated: High temperature alert ({latest_log.temperature}°C)',
                            status='pending',
                            assigned_to=assignee,
                            scheduled_date=timezone.now().date(),
                        )
                        created_requests.append(f"Auto for {equipment.name}")

            if latest_log.humidity > 80:
                Alert.objects.get_or_create(
                    equipment=equipment,
                    type='humidity_threshold',
                    resolved=False,
                    defaults={
                        'message': f'Humidity exceeded 80%: {latest_log.humidity}%',
                        'severity': 'medium'
                    }
                )

            if latest_log.motion_detected:
                # Check if motion was not detected in previous log to avoid spam
                prev_log = SensorLog.objects.filter(equipment=equipment, recorded_at__lt=latest_log.recorded_at).order_by('-recorded_at').first()
                if prev_log and not prev_log.motion_detected:
                    alert, created = Alert.objects.get_or_create(
                        equipment=equipment,
                        type='motion',
                        resolved=False,
                        defaults={
                            'message': 'Motion detected in area',
                            'severity': 'medium'
                        }
                    )
                    if created:
                        created_alerts.append(str(alert.id))

            # Energy anomaly: simple check if > 2x avg
            avg_energy = recent_logs.aggregate(avg=Avg('energy_usage'))['avg']
            if avg_energy and latest_log.energy_usage > (avg_energy * 2):
                Alert.objects.get_or_create(
                    equipment=equipment,
                    type='energy_anomaly',
                    resolved=False,
                    defaults={
                        'message': f'Energy usage anomaly: {latest_log.energy_usage} vs avg {avg_energy:.2f}',
                        'severity': 'low'
                    }
                )

        return Response({
            'success': True,
            'created_alerts': created_alerts,
            'created_requests': created_requests,
            'message': f'Checked {len(equipments)} equipments',
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_200_OK)

    except Exception as e:
        logger.error(f"Error in check_anomalies: {str(e)}")
        return Response(
            {'error': f'Server error: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['POST'])
@permission_classes([AllowAny])
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
            energy_usage=float(data.get('energy_usage', 0.0)),  # Optional field
            recorded_at=timezone.now()
        )

        # Update equipment status to online (using standardized value)
        equipment.status = 'online'
        equipment.save()

        # Trigger alerts based on thresholds (2.7, 2.8, 2.9)
        created_alert_ids = []
        # Temperature threshold
        if sensor_log.temperature > 40:
            alert, created = Alert.objects.get_or_create(
                equipment=equipment,
                type='temperature_threshold',
                resolved=False,
                defaults={
                    'message': f'Temperature alert: {sensor_log.temperature}°C exceeds 40°C',
                    'severity': 'high'
                }
            )
            if created:
                created_alert_ids.append(str(alert.id))

        # Motion alert
        if sensor_log.motion_detected:
            prev_log = SensorLog.objects.filter(equipment=equipment).order_by('-recorded_at').exclude(id=sensor_log.id).first()
            if prev_log and not prev_log.motion_detected:
                alert, created = Alert.objects.get_or_create(
                    equipment=equipment,
                    type='motion',
                    resolved=False,
                    defaults={
                        'message': 'Motion detected',
                        'severity': 'medium'
                    }
                )
                if created:
                    created_alert_ids.append(str(alert.id))

        # Auto-generate maintenance from anomaly (4.8)
        if created_alert_ids:
            # Check for recent pending request
            recent_request = MaintenanceRequest.objects.filter(
                equipment=equipment,
                status__in=['pending', 'in_progress'],
                created_at__gte=timezone.now() - timezone.timedelta(hours=1)
            ).exists()
            if not recent_request:
                assignee = User.objects.filter(role='employee').first()
                if not assignee:
                    # Create fallback system user if no employee exists
                    assignee = User.objects.create_user(
                        username='system', email='system@example.com', 
                        password='systempass', role='employee'
                    )
                MaintenanceRequest.objects.create(
                    user=assignee,  # Use system user
                    equipment=equipment,
                    issue=f'Auto-generated from alert: Temperature/Motion anomaly',
                    status='pending',
                    assigned_to=assignee,
                    scheduled_date=timezone.now().date() + timezone.timedelta(days=1),
                )

        logger.info(f"Sensor data saved successfully: {sensor_log.id}, Alerts: {created_alert_ids}")
        
        return Response({
            'success': True,
            'message': 'Sensor data received successfully',
            'log_id': str(sensor_log.id),
            'alert_ids': created_alert_ids,
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
            equipment.status = 'online'  # Use standardized value
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