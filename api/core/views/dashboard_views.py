from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone
from django.shortcuts import get_object_or_404
from django.db.models import Avg, Count, Q
import logging
from core.models import Room, Equipment, Component, SensorLog, Alert, PredictiveAlert, EnergySummary, BillingRate
from core.serializers import SensorLogSerializer, AlertSerializer, PredictiveAlertSerializer
from core.permissions import RoleBasedPermission

logger = logging.getLogger(__name__)

@api_view(['GET'])
@permission_classes([IsAuthenticated, RoleBasedPermission])
def dashboard_summary(request):
    logger.info("Dashboard summary requested")
    try:
        total_rooms = Room.objects.count()
        total_equipment = Equipment.objects.count()
        online_equipment = Equipment.objects.filter(status='online').count()
        total_components = Component.objects.count()
        avg_temp = SensorLog.objects.filter(dht22_recorded_at__isnull=False).aggregate(avg_temp=Avg('temperature'))['avg_temp'] or 0
        total_alerts = Alert.objects.count()
        unresolved_alerts = Alert.objects.filter(resolved=False).count()
        predictive_alerts = PredictiveAlert.objects.filter(resolved=False).count()
        recent_logs = SensorLog.objects.select_related('equipment', 'component').order_by('-recorded_at')[:5]
        
        today = timezone.now().date()
        energy_summaries = EnergySummary.objects.filter(
            period_start__date=today,
            period_type='daily'
        ).select_related('room')
        total_cost = 0
        for summary in energy_summaries:
            rate = BillingRate.objects.filter(
                Q(room=summary.room) | Q(room__isnull=True),
                Q(valid_from__lte=summary.period_start) | Q(valid_from__isnull=True),
                Q(valid_to__gte=summary.period_start) | Q(valid_to__isnull=True)
            ).order_by('-created_at').first()
            if rate:
                total_cost += summary.total_energy * rate.get_rate_for_time(summary.period_start)
        
        summary_data = {
            'total_rooms': total_rooms,
            'total_equipment': total_equipment,
            'online_equipment': online_equipment,
            'total_components': total_components,
            'avg_temperature': round(avg_temp, 2),
            'total_alerts': total_alerts,
            'unresolved_alerts': unresolved_alerts,
            'predictive_alerts': predictive_alerts,
            'daily_energy_cost': round(total_cost, 2),
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
    logger.info(f"Room realtime data requested for {pk}")
    try:
        room = get_object_or_404(Room, pk=pk)
        equipments = Equipment.objects.filter(room=room, type='esp32').prefetch_related('components')
        realtime_data = []
        for equipment in equipments:
            for component in equipment.components.all():
                latest_log = SensorLog.objects.filter(component=component).order_by('-recorded_at').first()
                if latest_log:
                    data = {
                        'equipment_id': str(equipment.id),
                        'equipment_name': equipment.name,
                        'component_id': str(component.id),
                        'component_type': component.component_type,
                        'device_id': equipment.device_id,
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
                    data['alerts'] = AlertSerializer(Alert.objects.filter(equipment=equipment, resolved=False), many=True).data
                    data['predictive_alerts'] = PredictiveAlertSerializer(PredictiveAlert.objects.filter(component=component, resolved=False), many=True).data
                    realtime_data.append(data)
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