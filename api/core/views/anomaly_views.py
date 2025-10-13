# api/core/views/anomaly_views.py
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone
from django.shortcuts import get_object_or_404
from django.db.models import Avg
import logging
from core.models import Component, SensorLog, Alert, MaintenanceRequest, User, EnergySummary
from core.serializers import AlertSerializer
from core.permissions import RoleBasedPermission
from .notification_service import NotificationService

logger = logging.getLogger(__name__)

@api_view(['POST'])
@permission_classes([RoleBasedPermission])
def check_anomalies(request):
    logger.info("Anomaly check requested")
    try:
        component_id = request.data.get('component_id')
        window_hours = int(request.data.get('check_window_hours', 1))
        cutoff = timezone.now() - timezone.timedelta(hours=window_hours)
        if component_id:
            components = [get_object_or_404(Component, pk=component_id)]
        else:
            components = Component.objects.filter(equipment__type='esp32').select_related('equipment')
        
        created_alerts = []
        created_requests = []
        for component in components:
            recent_logs = SensorLog.objects.filter(component=component, recorded_at__gte=cutoff)
            if not recent_logs.exists():
                continue
            latest_log = recent_logs.latest('recorded_at')
            
            if component.component_type == 'pzem':
                energy_summary = EnergySummary.objects.filter(
                    component=component,
                    period_type='daily',
                    period_start__gte=cutoff
                ).first()
                avg_power = energy_summary.avg_power if energy_summary else recent_logs.aggregate(avg=Avg('power'))['avg'] or 0
                if avg_power and latest_log.power > (avg_power * 2):
                    alert, created = Alert.objects.get_or_create(
                        equipment=component.equipment,
                        type='energy_anomaly',
                        resolved=False,
                        defaults={
                            'message': f'Energy usage anomaly: {latest_log.power}W vs avg {avg_power:.2f}W',
                            'severity': 'low'
                        }
                    )
                    if created:
                        created_alerts.append(str(alert.id))
                elif avg_power and latest_log.power <= (avg_power * 2):
                    alerts = Alert.objects.filter(
                        equipment=component.equipment,
                        type='energy_anomaly',
                        resolved=False
                    )
                    for alert in alerts:
                        alert.resolved = True
                        alert.resolved_at = timezone.now()
                        alert.save()
                        created_alerts.append(str(alert.id))
            elif component.component_type == 'dht22' and latest_log.temperature > 40:
                alert, created = Alert.objects.get_or_create(
                    equipment=component.equipment,
                    type='temperature_threshold',
                    resolved=False,
                    defaults={
                        'message': f'Temperature exceeded 40°C: {latest_log.temperature}°C',
                        'severity': 'high'
                    }
                )
                if created:
                    created_alerts.append(str(alert.id))
            elif component.component_type == 'dht22' and latest_log.temperature <= 40:
                alerts = Alert.objects.filter(
                    equipment=component.equipment,
                    type='temperature_threshold',
                    resolved=False
                )
                for alert in alerts:
                    alert.resolved = True
                    alert.resolved_at = timezone.now()
                    alert.save()
                    created_alerts.append(str(alert.id))
            elif component.component_type == 'dht22' and latest_log.humidity > 80:
                alert, created = Alert.objects.get_or_create(
                    equipment=component.equipment,
                    type='humidity_threshold',
                    resolved=False,
                    defaults={
                        'message': f'Humidity exceeded 80%: {latest_log.humidity}%',
                        'severity': 'medium'
                    }
                )
                if created:
                    created_alerts.append(str(alert.id))
            elif component.component_type == 'dht22' and latest_log.humidity <= 80:
                alerts = Alert.objects.filter(
                    equipment=component.equipment,
                    type='humidity_threshold',
                    resolved=False
                )
                for alert in alerts:
                    alert.resolved = True
                    alert.resolved_at = timezone.now()
                    alert.save()
                    created_alerts.append(str(alert.id))
            elif component.component_type == 'motion' and latest_log.motion_detected:
                prev_log = SensorLog.objects.filter(component=component, recorded_at__lt=latest_log.recorded_at).order_by('-recorded_at').first()
                if prev_log and not prev_log.motion_detected:
                    alert, created = Alert.objects.get_or_create(
                        equipment=component.equipment,
                        type='motion',
                        resolved=False,
                        defaults={
                            'message': 'Motion detected in area',
                            'severity': 'medium'
                        }
                    )
                    if created:
                        created_alerts.append(str(alert.id))
            elif component.component_type == 'motion' and not latest_log.motion_detected:
                alerts = Alert.objects.filter(
                    equipment=component.equipment,
                    type='motion',
                    resolved=False
                )
                for alert in alerts:
                    alert.resolved = True
                    alert.resolved_at = timezone.now()
                    alert.save()
                    created_alerts.append(str(alert.id))
            
            if created_alerts:
                recent_request = MaintenanceRequest.objects.filter(
                    equipment=component.equipment,
                    created_at__gte=cutoff,
                    status__in=['pending', 'in_progress']
                ).exists()
                if not recent_request:
                    assignee = User.objects.filter(role='employee').first()
                    maintenance_request = MaintenanceRequest.objects.create(
                        user_id=request.user.id,
                        equipment=component.equipment,
                        issue=f'Auto-generated: {component.component_type} anomaly detected',
                        status='pending',
                        assigned_to=assignee,
                        scheduled_date=timezone.now().date(),
                    )
                    created_requests.append(f"Auto for {component.equipment.name} - {component.component_type}")
                    NotificationService.notify_maintenance_request_created(maintenance_request, request)
        
        return Response({
            'success': True,
            'created_alerts': created_alerts,
            'created_requests': created_requests,
            'message': f'Checked {len(components)} components',
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_200_OK)
    except Exception as e:
        logger.error(f"Error in check_anomalies: {str(e)}")
        return Response(
            {'error': f'Server error: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['POST'])
@permission_classes([RoleBasedPermission])
def predict_maintenance(request):
    """
    Endpoint for LLM-based predictive maintenance analysis
    Expected JSON format:
    {
        "component_id": "uuid",
        "window_days": 7
    }
    """
    logger.info(f"Predictive maintenance requested: {request.method} {request.path}")
    logger.info(f"Request data: {request.data}")
    try:
        component_id = request.data.get('component_id')
        window_days = int(request.data.get('window_days', 7))
        cutoff = timezone.now() - timezone.timedelta(days=window_days)
        
        if component_id:
            components = [get_object_or_404(Component, pk=component_id)]
        else:
            components = Component.objects.filter(equipment__type='esp32').select_related('equipment', 'equipment__room')
        
        created_alerts = []
        created_requests = []
        for component in components:
            try:
                from main import ask
                logger.info(f"LLM module imported for component {component.id}")
            except ImportError as e:
                logger.error(f"Failed to import LLM module: {e}")
                return Response(
                    {'error': 'LLM service not available'},
                    status=status.HTTP_503_SERVICE_UNAVAILABLE
                )
            
            recent_logs = SensorLog.objects.filter(component=component, recorded_at__gte=cutoff)
            recent_heartbeats = HeartbeatLog.objects.filter(equipment=component.equipment, recorded_at__gte=cutoff)
            energy_summary = EnergySummary.objects.filter(component=component, period_start__gte=cutoff).first()
            room = component.equipment.room
            
            context = {
                'component_type': component.component_type,
                'equipment_name': component.equipment.name,
                'room_name': room.name if room else 'Unknown',
                'typical_energy_usage': room.typical_energy_usage if room else None,
                'occupancy_pattern': room.occupancy_pattern if room else None,
                'recent_power_avg': recent_logs.aggregate(avg=Avg('power'))['avg'] or 0,
                'recent_voltage_stability': recent_heartbeats.aggregate(avg=Avg('voltage_stability'))['avg'] or 0,
                'recent_pzem_error_count': recent_heartbeats.aggregate(sum=Sum('pzem_error_count'))['sum'] or 0,
                'recent_failed_readings': recent_heartbeats.aggregate(sum=Sum('failed_readings'))['sum'] or 0,
                'energy_anomalies': Alert.objects.filter(equipment=component.equipment, type='energy_anomaly', triggered_at__gte=cutoff).count(),
            }
            
            query = f"""
            Analyze the following data for predictive maintenance:
            - Component: {context['component_type']} on {context['equipment_name']}
            - Room: {context['room_name']}
            - Typical Energy Usage: {context['typical_energy_usage'] or 'Unknown'} kWh
            - Occupancy Pattern: {context['occupancy_pattern'] or 'Unknown'}
            - Average Power (last {window_days} days): {context['recent_power_avg']:.2f}W
            - Voltage Stability: {context['recent_voltage_stability']:.2f}
            - PZEM Error Count: {context['recent_pzem_error_count']}
            - Failed Readings: {context['recent_failed_readings']}
            - Energy Anomalies: {context['energy_anomalies']}
            Predict the likelihood of component failure and provide a confidence score (0-1).
            """
            
            result = ask(query)
            if "error" in result:
                logger.error(f"LLM query failed: {result['error']}")
                continue
            
            prediction = result.get('answer', '')
            confidence = 0.5
            try:
                confidence = float(result.get('confidence', 0.5))
                if not 0 <= confidence <= 1:
                    confidence = 0.5
            except (ValueError, TypeError):
                logger.warning("Invalid confidence score from LLM, using default 0.5")
            
            predictive_alert, created = PredictiveAlert.objects.get_or_create(
                component=component,
                resolved=False,
                defaults={
                    'prediction': prediction,
                    'confidence': confidence
                }
            )
            if created:
                created_alerts.append(str(predictive_alert.id))
                NotificationService.notify_predictive_alert_created(predictive_alert, request)
                
                if confidence >= 0.8:
                    recent_request = MaintenanceRequest.objects.filter(
                        equipment=component.equipment,
                        created_at__gte=timezone.now() - timezone.timedelta(hours=1),
                        status__in=['pending', 'in_progress']
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
                            equipment=component.equipment,
                            issue=f'LLM Prediction: {component.component_type} failure likely (Confidence: {confidence})',
                            status='pending',
                            assigned_to=assignee,
                            scheduled_date=timezone.now().date() + timezone.timedelta(days=1),
                        )
                        created_requests.append(f"Auto for {component.equipment.name} - {component.component_type}")
                        NotificationService.notify_maintenance_request_created(maintenance_request, request)
        
        return Response({
            'success': True,
            'created_alerts': created_alerts,
            'created_requests': created_requests,
            'message': f'Predicted maintenance for {len(components)} components',
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_200_OK)
    except Exception as e:
        logger.error(f"Error in predict_maintenance: {str(e)}")
        return Response(
            {'error': f'Server error: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )