# api/core/views/esp32_views.py
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone
from django.shortcuts import get_object_or_404
from django.db.models import Avg, Sum, Max, Min
from django.db.models import Q
import logging
import datetime
from core.models import Equipment, Component, SensorLog, HeartbeatLog, Alert, MaintenanceRequest, User, EnergySummary, BillingRate
from core.serializers import SensorLogSerializer, AlertSerializer
from .notification_service import NotificationService
from django.conf import settings

logger = logging.getLogger(__name__)

@api_view(['POST'])
@permission_classes([AllowAny])
def esp32_heartbeat(request):
    """
    Endpoint for ESP32 to send heartbeat and update status
    Expected JSON format:
    {
        "device_id": "ESP32_001",
        "timestamp": 123456,
        "dht22_working": true,
        "pzem_working": true,
        "photoresistor_working": true,
        "success_rate": 95.0,
        "wifi_signal": -50,
        "uptime": 123,
        "sensor_type": "DHT22_3PIN_MODULE_GPIO5_PZEM_SERIAL2_PHOTO_GPIO19",
        "current_temp": 22.0,
        "current_humidity": 50.0,
        "current_power": 115.0,
        "pzem_error_count": 0,
        "voltage_stability": 0.5,
        "failed_readings": 0
    }
    """
    logger.info(f"ESP32 heartbeat received: {request.method} {request.path}")
    logger.info(f"Heartbeat data: {request.data}")
    
    try:
        data = request.data
        if not data.get('device_id'):
            logger.error("Missing device_id in heartbeat")
            return Response(
                {'error': 'device_id is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        try:
            equipment = Equipment.objects.get(device_id=data['device_id'])
            equipment.status = 'online'
            equipment.save()
            
            sensor_types = data.get('sensor_type', '').split('_')
            for sensor in sensor_types:
                if 'PZEM' in sensor:
                    component, _ = Component.objects.get_or_create(
                        equipment=equipment,
                        identifier=sensor,
                        defaults={'component_type': 'pzem', 'status': 'online' if data.get('pzem_working', True) else 'error'}
                    )
                    component.status = 'online' if data.get('pzem_working', True) else 'error'
                    component.save()
                elif 'DHT22' in sensor:
                    component, _ = Component.objects.get_or_create(
                        equipment=equipment,
                        identifier=sensor,
                        defaults={'component_type': 'dht22', 'status': 'online' if data.get('dht22_working', True) else 'error'}
                    )
                    component.status = 'online' if data.get('dht22_working', True) else 'error'
                    component.save()
                elif 'PHOTO' in sensor:
                    component, _ = Component.objects.get_or_create(
                        equipment=equipment,
                        identifier=sensor,
                        defaults={'component_type': 'photoresistor', 'status': 'online' if data.get('photoresistor_working', True) else 'error'}
                    )
                    component.status = 'online' if data.get('photoresistor_working', True) else 'error'
                    component.save()
            
            heartbeat = HeartbeatLog.objects.create(
                equipment=equipment,
                timestamp=int(data.get('timestamp', 0)),
                dht22_working=bool(data.get('dht22_working', False)),
                pzem_working=bool(data.get('pzem_working', True)),
                photoresistor_working=bool(data.get('photoresistor_working', True)),
                success_rate=float(data.get('success_rate', 0.0)),
                wifi_signal=int(data.get('wifi_signal', 0)),
                uptime=int(data.get('uptime', 0)),
                sensor_type=data.get('sensor_type', ''),
                current_temp=float(data.get('current_temp', 0.0)),
                current_humidity=float(data.get('current_humidity', 0.0)),
                current_power=float(data.get('current_power', 0.0)),
                pzem_error_count=int(data.get('pzem_error_count', 0)),
                voltage_stability=float(data.get('voltage_stability', 0.0)),
                failed_readings=int(data.get('failed_readings', 0)),
            )
            logger.info(f"Heartbeat saved for {data['device_id']}: {heartbeat.id}")
            return Response({
                'success': True,
                'message': f'Heartbeat received from {data["device_id"]}',
                'timestamp': timezone.now().isoformat()
            })
        except Equipment.DoesNotExist:
            logger.error(f"Equipment with device_id {data['device_id']} not found")
            return Response(
                {'error': f'Equipment with device_id {data["device_id"]} not found'},
                status=status.HTTP_404_NOT_FOUND
            )
    except ValueError as e:
        logger.error(f"Invalid data format: {str(e)}")
        return Response(
            {'error': f'Invalid data format: {str(e)}'},
            status=status.HTTP_400_BAD_REQUEST
        )
    except Exception as e:
        logger.error(f"Server error in heartbeat: {str(e)}")
        return Response(
            {'error': f'Server error: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['POST'])
@permission_classes([AllowAny])
def esp32_sensor_data(request):
    logger.info(f"ESP32 sensor data received: {request.method} {request.path}")
    logger.info(f"Request data: {request.data}")
    try:
        data = request.data
        if not data.get('device_id'):
            logger.error("Missing device_id")
            return Response(
                {'error': 'device_id is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        try:
            equipment = Equipment.objects.get(device_id=data['device_id'])
            logger.info(f"Found equipment: {equipment.name}")
            if not equipment.room:
                logger.error(f"Equipment {equipment.name} has no associated room")
                return Response(
                    {'error': f'Equipment {equipment.name} has no associated room'},
                    status=status.HTTP_400_BAD_REQUEST
                )
        except Equipment.DoesNotExist:
            logger.error(f"Equipment with device_id {data['device_id']} not found")
            return Response(
                {'error': f'Equipment with device_id {data["device_id"]} not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        created_logs = []
        created_alert_ids = []
        resolved_alert_ids = []
        recorded_at = timezone.now()
        if data.get('recorded_at'):
            try:
                recorded_at = timezone.datetime.fromisoformat(data['recorded_at'].replace('Z', '+00:00'))
            except ValueError:
                logger.error(f"Invalid recorded_at format: {data['recorded_at']}")
                return Response(
                    {'error': 'Invalid recorded_at format. Use ISO format'},
                    status=status.HTTP_400_BAD_REQUEST
                )

        for component_data in data.get('components', []):
            component_type = component_data.get('component_type')
            identifier = component_data.get('identifier')
            if not component_type or not identifier:
                logger.error("Missing component_type or identifier")
                continue
            
            component, _ = Component.objects.get_or_create(
                equipment=equipment,
                identifier=identifier,
                defaults={'component_type': component_type, 'status': 'online'}
            )
            
            sensor_log_data = {
                'equipment': equipment,
                'component': component,
                'recorded_at': recorded_at,
            }
            
            if component_type == 'pzem':
                sensor_log_data.update({
                    'voltage': float(component_data.get('voltage', 0.0)),
                    'current': float(component_data.get('current', 0.0)),
                    'power': float(component_data.get('power', 0.0)),
                    'energy': float(component_data.get('energy', 0.0)),
                    'reset_flag': bool(component_data.get('reset_flag', False)),
                    'pzem_recorded_at': recorded_at
                })
            elif component_type == 'dht22':
                sensor_log_data.update({
                    'temperature': float(component_data.get('temperature', 0.0)),
                    'humidity': float(component_data.get('humidity', 0.0)),
                    'dht22_recorded_at': recorded_at
                })
            elif component_type == 'photoresistor':
                sensor_log_data.update({
                    'light_detected': bool(component_data.get('light_detected', False)),
                    'photoresistor_recorded_at': recorded_at
                })
            elif component_type == 'motion':
                sensor_log_data.update({
                    'motion_detected': bool(component_data.get('motion_detected', False)),
                    'motion_recorded_at': recorded_at
                })
            
            sensor_log = SensorLog.objects.create(**sensor_log_data)
            created_logs.append(str(sensor_log.id))
            
            if component_type == 'pzem' and sensor_log.power > 0:
                recent_logs = SensorLog.objects.filter(
                    component=component,
                    pzem_recorded_at__gte=timezone.now() - timezone.timedelta(hours=1)
                )
                avg_power = recent_logs.aggregate(avg=Avg('power'))['avg'] or 0
                if avg_power and sensor_log.power > (avg_power * 2):
                    alert, created = Alert.objects.get_or_create(
                        equipment=equipment,
                        type='energy_anomaly',
                        resolved=False,
                        defaults={
                            'message': f'Energy usage anomaly: {sensor_log.power}W vs avg {avg_power:.2f}W',
                            'severity': 'low'
                        }
                    )
                    if created:
                        created_alert_ids.append(str(alert.id))
                elif avg_power and sensor_log.power <= (avg_power * 2):
                    alerts = Alert.objects.filter(
                        equipment=equipment,
                        type='energy_anomaly',
                        resolved=False
                    )
                    for alert in alerts:
                        alert.resolved = True
                        alert.resolved_at = timezone.now()
                        alert.save()
                        resolved_alert_ids.append(str(alert.id))
            elif component_type == 'dht22' and sensor_log.temperature > 40:
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
            elif component_type == 'dht22' and sensor_log.temperature <= 40:
                alerts = Alert.objects.filter(
                    equipment=equipment,
                    type='temperature_threshold',
                    resolved=False
                )
                for alert in alerts:
                    alert.resolved = True
                    alert.resolved_at = timezone.now()
                    alert.save()
                    resolved_alert_ids.append(str(alert.id))
            elif component_type == 'dht22' and sensor_log.humidity > 80:
                alert, created = Alert.objects.get_or_create(
                    equipment=equipment,
                    type='humidity_threshold',
                    resolved=False,
                    defaults={
                        'message': f'Humidity exceeded 80%: {sensor_log.humidity}%',
                        'severity': 'medium'
                    }
                )
                if created:
                    created_alert_ids.append(str(alert.id))
            elif component_type == 'dht22' and sensor_log.humidity <= 80:
                alerts = Alert.objects.filter(
                    equipment=equipment,
                    type='humidity_threshold',
                    resolved=False
                )
                for alert in alerts:
                    alert.resolved = True
                    alert.resolved_at = timezone.now()
                    alert.save()
                    resolved_alert_ids.append(str(alert.id))
            elif component_type == 'motion' and sensor_log.motion_detected:
                prev_log = SensorLog.objects.filter(component=component).order_by('-recorded_at').exclude(id=sensor_log.id).first()
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
            elif component_type == 'motion' and not sensor_log.motion_detected:
                alerts = Alert.objects.filter(
                    equipment=equipment,
                    type='motion',
                    resolved=False
                )
                for alert in alerts:
                    alert.resolved = True
                    alert.resolved_at = timezone.now()
                    alert.save()
                    resolved_alert_ids.append(str(alert.id))
        
        equipment.status = 'online'
        equipment.save()
        
        pzem_components = Component.objects.filter(equipment=equipment, component_type='pzem')
        for component in pzem_components:
            today = recorded_at.date()
            period_start = timezone.datetime.combine(today, datetime.time.min, tzinfo=timezone.get_current_timezone())
            period_end = timezone.datetime.combine(today, datetime.time.max, tzinfo=timezone.get_current_timezone())
            recent_logs = SensorLog.objects.filter(
                component=component,
                pzem_recorded_at__gte=period_start,
                pzem_recorded_at__lte=period_end,
                energy__isnull=False
            )
            log_count = recent_logs.count()
            logger.info(f"PZEM logs for {today}: {log_count}")
            if log_count >= 1:
                energy_stats = recent_logs.aggregate(max_energy=Max('energy'), min_energy=Min('energy'))
                total_energy = (energy_stats['max_energy'] - energy_stats['min_energy']) if energy_stats['max_energy'] is not None and energy_stats['min_energy'] is not None else recent_logs.first().energy or 0
                if recent_logs.filter(reset_flag=True).exists():
                    total_energy += energy_stats['max_energy'] or 0
                avg_power = recent_logs.aggregate(avg=Avg('power'))['avg'] or 0
                peak_power = recent_logs.aggregate(max=Max('power'))['max'] or 0
                anomaly_count = Alert.objects.filter(
                    equipment=equipment,
                    type='energy_anomaly',
                    triggered_at__gte=period_start,
                    triggered_at__lte=period_end
                ).count()

                rate = BillingRate.objects.filter(
                    Q(room=equipment.room) | Q(room__isnull=True),
                    Q(valid_from__lte=period_start) | Q(valid_from__isnull=True),
                    Q(valid_to__gte=period_start) | Q(valid_to__isnull=True)
                ).order_by('-created_at').first()

                if not rate:
                    default_rate_per_kwh = 10.00
                    if total_energy >= 0.1:
                        default_rate_per_kwh = 15.00
                    elif total_energy >= 0.01:
                        default_rate_per_kwh = 12.50
                    rate = BillingRate.objects.create(
                        room=equipment.room,
                        rate_per_kwh=default_rate_per_kwh,
                        currency='PHP',
                        valid_from=period_start,
                        valid_to=period_start + timezone.timedelta(days=365),
                        start_time=None,
                        end_time=None
                    )
                    logger.info(f"Created default BillingRate {rate.id} for room {equipment.room.name} at {default_rate_per_kwh} PHP/kWh")

                effective_rate = rate.get_rate_for_time(period_start)
                total_cost = round(total_energy * effective_rate, 2)
                currency = rate.currency

                energy_summary, _ = EnergySummary.objects.update_or_create(
                    component=component,
                    room=equipment.room,
                    period_start=period_start,
                    period_end=period_end,
                    period_type='daily',
                    defaults={
                        'total_energy': total_energy,
                        'avg_power': avg_power,
                        'peak_power': peak_power,
                        'reading_count': log_count,
                        'anomaly_count': anomaly_count,
                        'total_cost': total_cost,
                        'currency': currency,
                        'effective_rate': effective_rate
                    }
                )
                logger.info(f"Updated/Created EnergySummary {energy_summary.id} with total_cost {total_cost} {currency}, effective_rate {effective_rate}")

        if created_alert_ids:
            recent_request = MaintenanceRequest.objects.filter(
                equipment=equipment,
                status__in=['pending', 'in_progress'],
                created_at__gte=timezone.now() - timezone.timedelta(hours=1)
            ).exists()
            if not recent_request:
                assignee = User.objects.filter(role='employee').first()
                if not assignee:
                    assignee = User.objects.create_user(
                        username='system', email='system@example.com', 
                        password='systempass', role='employee'
                    )
                maintenance_request = MaintenanceRequest.objects.create(
                    user=assignee,
                    equipment=equipment,
                    issue=f'Auto-generated from alert: Temperature/Motion/Energy anomaly',
                    status='pending',
                    assigned_to=assignee,
                    scheduled_date=timezone.now().date() + timezone.timedelta(days=1),
                )
                NotificationService.notify_maintenance_request_created(maintenance_request, request)
        
        logger.info(f"Sensor data saved: {created_logs}, Alerts created: {created_alert_ids}, Alerts resolved: {resolved_alert_ids}")
        return Response({
            'success': True,
            'message': 'Sensor data received successfully',
            'log_ids': created_logs,
            'alert_ids': created_alert_ids,
            'resolved_alert_ids': resolved_alert_ids,
            'timestamp': timezone.now().isoformat()
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
    logger.info("ESP32 health check requested")
    return Response({
        'status': 'healthy',
        'message': 'ESP32 API is running',
        'timestamp': timezone.now().isoformat()
    })

@api_view(['GET'])
@permission_classes([AllowAny])
def equipment_field_options(request):
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
        'component_type_options': [
            {'value': 'pzem', 'label': 'PZEM', 'description': 'Power monitoring module'},
            {'value': 'dht22', 'label': 'DHT22', 'description': 'Temperature and humidity sensor'},
            {'value': 'photoresistor', 'label': 'Photoresistor', 'description': 'Light detection sensor'},
            {'value': 'motion', 'label': 'Motion Sensor', 'description': 'Motion detection sensor'},
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
            {'value': 'predictive_failure', 'label': 'Predictive Failure'},
        ],
        'alert_severity_options': [
            {'value': 'low', 'label': 'Low'},
            {'value': 'medium', 'label': 'Medium'},
            {'value': 'high', 'label': 'High'},
        ],
        'period_type_options': [
            {'value': 'daily', 'label': 'Daily'},
            {'value': 'weekly', 'label': 'Weekly'},
            {'value': 'monthly', 'label': 'Monthly'},
        ],
        'currency_options': [
            {'value': 'PHP', 'label': 'Philippine Peso', 'description': 'Philippine Peso (PHP)'},
        ],
    })

@api_view(['GET'])
@permission_classes([AllowAny])
def latest_sensor_data(request):
    logger.info("Latest sensor data requested")
    try:
        latest_logs = []
        components = Component.objects.filter(equipment__type='esp32').select_related('equipment')
        for component in components:
            latest_log = SensorLog.objects.filter(component=component).order_by('-recorded_at').first()
            if latest_log:
                data = {
                    'equipment_id': str(component.equipment.id),
                    'equipment_name': component.equipment.name,
                    'component_id': str(component.id),
                    'component_type': component.component_type,
                    'device_id': component.equipment.device_id,
                    'status': component.status,
                    'recorded_at': latest_log.recorded_at.isoformat(),
                }
                if component.component_type == 'pzem':
                    data.update({
                        'voltage': latest_log.voltage,
                        'current': latest_log.current,
                        'power': latest_log.power,
                        'energy': latest_log.energy,
                        'pzem_recorded_at': latest_log.pzem_recorded_at.isoformat() if latest_log.pzem_recorded_at else None,
                    })
                elif component.component_type == 'dht22':
                    data.update({
                        'temperature': latest_log.temperature,
                        'humidity': latest_log.humidity,
                        'dht22_recorded_at': latest_log.dht22_recorded_at.isoformat() if latest_log.dht22_recorded_at else None,
                    })
                elif component.component_type == 'photoresistor':
                    data.update({
                        'light_detected': latest_log.light_detected,
                        'photoresistor_recorded_at': latest_log.photoresistor_recorded_at.isoformat() if latest_log.photoresistor_recorded_at else None,
                    })
                elif component.component_type == 'motion':
                    data.update({
                        'motion_detected': latest_log.motion_detected,
                        'motion_recorded_at': latest_log.motion_recorded_at.isoformat() if latest_log.motion_recorded_at else None,
                    })
                latest_logs.append(data)
        
        logger.info(f"Returning {len(latest_logs)} sensor readings")
        return Response({
            'success': True,
            'data': latest_logs,
            'count': len(latest_logs),
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_200_OK)
    except Exception as e:
        logger.error(f"Server error in latest_sensor_data: {str(e)}")
        return Response(
            {'error': f'Server error: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )