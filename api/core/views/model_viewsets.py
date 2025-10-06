from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.pagination import PageNumberPagination
from django.shortcuts import get_object_or_404
from django.db.models import Avg, Count, StdDev, Sum, Max, Min
from django.utils import timezone
from django.db.models import Q
import uuid
from dateutil.relativedelta import relativedelta
import logging
from core.models import *
from core.serializers import *
from core.permissions import RoleBasedPermission
from .notification_service import NotificationService
from django.conf import settings

logger = logging.getLogger(__name__)

class StandardResultsSetPagination(PageNumberPagination):
    page_size = 10
    page_size_query_param = 'page_size'
    max_page_size = 100

class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [RoleBasedPermission]

    def perform_create(self, serializer):
        """Create a user and automatically create a Profile with default values."""
        user = serializer.save()
        Profile.objects.create(
            user=user,
            full_name=user.username,
            organization="",
            address=""
        )
        logger.info(f"User {user.username} created with default profile")
        return user

    @action(detail=False, methods=['get', 'patch', 'post', 'delete'], permission_classes=[IsAuthenticated, RoleBasedPermission])
    def profile(self, request):
        user = request.user
        try:
            profile = Profile.objects.get(user=user)
        except Profile.DoesNotExist:
            # If profile doesn't exist, create one for POST or PATCH requests
            if request.method in ['POST', 'PATCH']:
                profile = Profile.objects.create(
                    user=user,
                    full_name=user.username,
                    organization="",
                    address=""
                )
                logger.info(f"Created default profile for user {user.username}")
            else:
                return Response({
                    'error': 'Profile not found',
                    'detail': 'Please update your profile to create it'
                }, status=status.HTTP_404_NOT_FOUND)

        if request.method =="GET":
            serializer = UserSerializer(user, context={'request': request})
            return Response(serializer.data)

        elif request.method == 'POST':
            # Allow explicit profile creation (if deleted or for re-initialization)
            if Profile.objects.filter(user=user).exists():
                return Response({
                    'error': 'Profile already exists',
                    'detail': 'Use PATCH to update the existing profile'
                }, status=status.HTTP_400_BAD_REQUEST)
            profile_data = request.data
            profile_serializer = ProfileSerializer(data=profile_data)
            if profile_serializer.is_valid():
                profile = profile_serializer.save(user=user)
                logger.info(f"Profile created for user {user.username} via POST")
                return Response(UserSerializer(user, context={'request': request}).data, status=status.HTTP_201_CREATED)
            return Response(profile_serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        elif request.method == 'PATCH':
            user_data = {}
            profile_data = {}
            for key, value in request.data.items():
                if key in ['username', 'email']:
                    user_data[key] = value
                elif key in ['full_name', 'organization', 'address', 'profile_picture']:
                    profile_data[key] = value

            user_serializer = UserSerializer(user, data=user_data, partial=True, context={'request': request})
            profile_serializer = ProfileSerializer(profile, data=profile_data, partial=True)

            errors = {}
            if user_data and not user_serializer.is_valid():
                errors.update(user_serializer.errors)
            if profile_data and not profile_serializer.is_valid():
                errors.update(profile_serializer.errors)

            if errors:
                return Response(errors, status=status.HTTP_400_BAD_REQUEST)

            if user_data:
                user_serializer.save()
            if profile_data:
                profile_serializer.save()

            logger.info(f"Profile updated for user {user.username}")
            return Response(UserSerializer(user, context={'request': request}).data, status=status.HTTP_200_OK)

        elif request.method == 'DELETE':
            # Allow profile deletion (admin or user themselves)
            if request.user != user and request.user.role not in ['admin', 'superadmin']:
                return Response({
                    'error': 'Permission denied',
                    'detail': 'You can only delete your own profile unless you are an admin'
                }, status=status.HTTP_403_FORBIDDEN)
            profile.delete()
            logger.info(f"Profile deleted for user {user.username}")
            return Response({'status': 'Profile deleted'}, status=status.HTTP_204_NO_CONTENT)

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
        instance.generate_qr_code()
        logger.info(f"Equipment created: {instance.id} - {instance.name}")

class ComponentViewSet(viewsets.ModelViewSet):
    queryset = Component.objects.select_related('equipment').all()
    serializer_class = ComponentSerializer
    permission_classes = [RoleBasedPermission]
    def get_queryset(self):
        queryset = super().get_queryset()
        user = self.request.user
        if hasattr(user, 'role') and user.role == 'client':
            return queryset.filter(equipment__maintenancerequest__user=user).distinct()
        return queryset

class SensorLogViewSet(viewsets.ModelViewSet):
    queryset = SensorLog.objects.select_related('equipment', 'component').order_by('-recorded_at')
    serializer_class = SensorLogSerializer
    permission_classes = [RoleBasedPermission]
    def get_queryset(self):
        queryset = super().get_queryset()
        user = self.request.user
        if hasattr(user, 'role') and user.role == 'client':
            queryset = queryset.filter(equipment__maintenancerequest__user=user).distinct()
        
        room_id = self.request.query_params.get('room_id')
        component_id = self.request.query_params.get('component_id')
        period_start = self.request.query_params.get('period_start')
        period_end = self.request.query_params.get('period_end')
        
        if room_id:
            try:
                uuid.UUID(room_id)
                queryset = queryset.filter(equipment__room_id=room_id)
            except ValueError:
                logger.error(f"Invalid room_id format: {room_id}")
                raise ValueError("Invalid room_id format. Must be a valid UUID")
        if component_id:
            try:
                uuid.UUID(component_id)
                queryset = queryset.filter(component_id=component_id)
            except ValueError:
                logger.error(f"Invalid component_id format: {component_id}")
                raise ValueError("Invalid component_id format. Must be a valid UUID")
        if period_start:
            try:
                period_start = timezone.datetime.fromisoformat(period_start.replace('Z', '+00:00'))
                queryset = queryset.filter(recorded_at__gte=period_start)
            except ValueError:
                logger.error(f"Invalid period_start format: {period_start}")
                raise ValueError("Invalid period_start format. Use ISO format")
        if period_end:
            try:
                period_end = timezone.datetime.fromisoformat(period_end.replace('Z', '+00:00'))
                queryset = queryset.filter(recorded_at__lte=period_end)
            except ValueError:
                logger.error(f"Invalid period_end format: {period_end}")
                raise ValueError("Invalid period_end format. Use ISO format")
        
        return queryset

class HeartbeatLogViewSet(viewsets.ModelViewSet):
    queryset = HeartbeatLog.objects.select_related('equipment').order_by('-recorded_at')
    serializer_class = HeartbeatLogSerializer
    permission_classes = [RoleBasedPermission]
    def get_queryset(self):
        queryset = super().get_queryset()
        user = self.request.user
        if hasattr(user, 'role') and user.role == 'client':
            return queryset.filter(equipment__maintenancerequest__user=user).distinct()
        return queryset

class EnergySummaryViewSet(viewsets.ModelViewSet):
    queryset = EnergySummary.objects.select_related('component', 'room').order_by('-period_start')
    serializer_class = EnergySummarySerializer
    permission_classes = [RoleBasedPermission]

    def get_queryset(self):
        queryset = super().get_queryset()
        user = self.request.user
        period_type = self.request.query_params.get('period_type')
        room_id = self.request.query_params.get('room_id')
        period_start_str = self.request.query_params.get('start_time')

        if hasattr(user, 'role') and user.role == 'client':
            queryset = queryset.filter(room__maintenancerequest__user=user).distinct()

        if period_type:
            queryset = queryset.filter(period_type=period_type)

        if room_id:
            queryset = queryset.filter(room__id=room_id)

        if period_start_str:
            try:
                period_start_dt = timezone.datetime.fromisoformat(period_start_str.replace('Z', '+00:00'))
                queryset = queryset.filter(period_start__gte=period_start_dt)
            except ValueError:
                logger.error(f"Invalid start_time format: {period_start_str}")

        return queryset

    def list(self, request, *args, **kwargs):
        period_type = request.query_params.get('period_type')
        period_start_str = request.query_params.get('start_time')
        room_id = self.request.query_params.get('room_id')

        if period_start_str:
            try:
                period_start = timezone.datetime.fromisoformat(period_start_str.replace('Z', '+00:00'))
            except ValueError:
                return Response({'error': 'Invalid start_time format'}, status=status.HTTP_400_BAD_REQUEST)
        else:
            period_start = None

        if period_type in ['weekly', 'monthly']:
            if not period_start:
                return Response({'error': 'start_time is required for weekly/monthly summaries'}, status=status.HTTP_400_BAD_REQUEST)

            if period_type == 'weekly':
                period_end = period_start + timezone.timedelta(days=7)
            else:
                period_end = period_start + relativedelta(months=1)

            daily_qs = EnergySummary.objects.filter(
                period_type='daily',
                period_start__gte=period_start,
                period_end__lte=period_end,
            )
            if room_id:
                daily_qs = daily_qs.filter(room__id=room_id)

            if not daily_qs.exists():
                zero_data = {
                    'id': None,
                    'component': None,
                    'room': room_id,
                    'period_start': period_start.isoformat(),
                    'period_end': period_end.isoformat(),
                    'period_type': period_type,
                    'total_energy': 0.0,
                    'avg_power': 0.0,
                    'peak_power': 0.0,
                    'reading_count': 0,
                    'anomaly_count': 0,
                    'total_cost': 0.0,
                    'currency': 'PHP',
                    'effective_rate': 0.0,
                }
                return Response([zero_data])

            agg = daily_qs.aggregate(
                total_energy=Sum('total_energy'),
                avg_power=Avg('avg_power'),
                peak_power=Max('peak_power'),
                reading_count=Sum('reading_count'),
                anomaly_count=Sum('anomaly_count'),
                total_cost=Sum('total_cost'),
            )

            effective_rate = agg['total_cost'] / agg['total_energy'] if agg['total_energy'] else 0.0
            currency = daily_qs.first().currency

            aggregated_data = {
                'id': None,
                'component': None,
                'room': room_id,
                'period_start': period_start.isoformat(),
                'period_end': period_end.isoformat(),
                'period_type': period_type,
                'total_energy': agg['total_energy'] or 0.0,
                'avg_power': agg['avg_power'] or 0.0,
                'peak_power': agg['peak_power'] or 0.0,
                'reading_count': agg['reading_count'] or 0,
                'anomaly_count': agg['anomaly_count'] or 0,
                'total_cost': agg['total_cost'] or 0.0,
                'currency': currency,
                'effective_rate': effective_rate,
            }
            return Response([aggregated_data])

        queryset = self.filter_queryset(self.get_queryset())
        if not queryset.exists() and period_type == 'daily':
            zero_data = {
                'id': None,
                'component': None,
                'room': room_id,
                'period_start': period_start.isoformat() if period_start else timezone.now().isoformat(),
                'period_end': (period_start + timezone.timedelta(days=1)).isoformat() if period_start else timezone.now().isoformat(),
                'period_type': 'daily',
                'total_energy': 0.0,
                'avg_power': 0.0,
                'peak_power': 0.0,
                'reading_count': 0,
                'anomaly_count': 0,
                'total_cost': 0.0,
                'currency': 'PHP',
                'effective_rate': 0.0,
            }
            return Response([zero_data])

        page = self.paginate_queryset(queryset)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)

        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

class PredictiveAlertViewSet(viewsets.ModelViewSet):
    queryset = PredictiveAlert.objects.select_related('component', 'component__equipment').order_by('-triggered_at')
    serializer_class = PredictiveAlertSerializer
    permission_classes = [RoleBasedPermission]
    def get_queryset(self):
        queryset = super().get_queryset()
        user = self.request.user
        if hasattr(user, 'role') and user.role == 'client':
            return queryset.filter(component__equipment__maintenancerequest__user=user).distinct()
        resolved = self.request.query_params.get('resolved')
        if resolved is not None:
            resolved_bool = resolved.lower() == 'true'
            queryset = queryset.filter(resolved=resolved_bool)
        return queryset

class BillingRateViewSet(viewsets.ModelViewSet):
    queryset = BillingRate.objects.select_related('room').order_by('-created_at')
    serializer_class = BillingRateSerializer
    permission_classes = [RoleBasedPermission]
    
    def get_queryset(self):
        queryset = super().get_queryset()
        user = self.request.user
        if hasattr(user, 'role') and user.role == 'client':
            return queryset.filter(room__maintenancerequest__user=user).distinct()
        room_id = self.request.query_params.get('room_id')
        if room_id:
            return queryset.filter(room__id=room_id)
        return queryset
    
    @action(detail=False, methods=['get'], permission_classes=[RoleBasedPermission])
    def debug_test(self, request):
        logger.info("Debug test endpoint hit with params: %s", request.query_params)
        return Response({
            'success': True,
            'message': 'BillingRateViewSet debug endpoint working',
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_200_OK)
    
    @action(detail=False, methods=['get'], permission_classes=[RoleBasedPermission])
    def calculate_energy_cost(self, request):
        logger.info("Energy cost calculation requested with params: %s", request.query_params)
        try:
            room_id = request.query_params.get('room_id')
            equipment_id = request.query_params.get('equipment_id')
            component_id = request.query_params.get('component')
            period_start = request.query_params.get('period_start')
            period_end = request.query_params.get('period_end')
            period_type = request.query_params.get('period_type')

            if not period_start or not period_end or not period_type:
                logger.error("Missing required query parameters: period_start, period_end, period_type")
                return Response(
                    {'error': 'period_start, period_end, and period_type are required'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            try:
                period_start = timezone.datetime.fromisoformat(period_start.replace('Z', '+00:00'))
                period_end = timezone.datetime.fromisoformat(period_end.replace('Z', '+00:00'))
                period_end = period_end + timezone.timedelta(seconds=1)
            except ValueError:
                logger.error("Invalid date format: period_start=%s, period_end=%s", period_start, period_end)
                return Response(
                    {'error': 'Invalid date format. Use ISO format (e.g., 2025-09-27T00:00:00Z)'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            from core.models import PERIOD_TYPE_CHOICES
            if period_type not in [choice[0] for choice in PERIOD_TYPE_CHOICES]:
                logger.error(f"Invalid period_type: {period_type}")
                return Response(
                    {'error': f"Invalid period_type. Must be one of: {', '.join([choice[0] for choice in PERIOD_TYPE_CHOICES])}"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            energy_summaries = EnergySummary.objects.filter(
                period_start__gte=period_start,
                period_end__lte=period_end,
                period_type='daily'
            )
            logger.info("Initial query count: %s", energy_summaries.count())
            if room_id:
                try:
                    uuid.UUID(room_id)
                    energy_summaries = energy_summaries.filter(room__id=room_id)
                    logger.info("After room_id filter (%s): %s", room_id, energy_summaries.count())
                except ValueError:
                    logger.error(f"Invalid room_id format: {room_id}")
                    return Response(
                        {'error': 'Invalid room_id format. Must be a valid UUID'},
                        status=status.HTTP_400_BAD_REQUEST
                    )
            if equipment_id:
                try:
                    uuid.UUID(equipment_id)
                    energy_summaries = energy_summaries.filter(component__equipment_id=equipment_id)
                    logger.info("After equipment_id filter (%s): %s", equipment_id, energy_summaries.count())
                except ValueError:
                    logger.error(f"Invalid equipment_id format: {equipment_id}")
                    return Response(
                        {'error': 'Invalid equipment_id format. Must be a valid UUID'},
                        status=status.HTTP_400_BAD_REQUEST
                    )
            if component_id:
                try:
                    uuid.UUID(component_id)
                    energy_summaries = energy_summaries.filter(component_id=component_id)
                    logger.info("After component_id filter (%s): %s", component_id, energy_summaries.count())
                except ValueError:
                    logger.error(f"Invalid component_id format: {component_id}")
                    return Response(
                        {'error': 'Invalid component_id format. Must be a valid UUID'},
                        status=status.HTTP_400_BAD_REQUEST
                    )

            all_summaries = EnergySummary.objects.filter(
                period_type='daily',
                room__id=room_id if room_id else None,
                component_id=component_id
            ).values('id', 'period_start', 'period_end', 'total_energy', 'total_cost')
            logger.info("All matching EnergySummaries: %s", list(all_summaries))

            if not energy_summaries.exists():
                logger.info("No daily energy summaries found for criteria: room_id=%s, equipment_id=%s, component_id=%s, period_start=%s, period_end=%s",
                           room_id, equipment_id, component_id, period_start.isoformat(), period_end.isoformat())
                return Response(
                    {'error': 'No energy summaries found for the specified criteria'},
                    status=status.HTTP_404_NOT_FOUND
                )

            total_cost = 0
            total_energy = 0
            details = []
            for summary in energy_summaries:
                rate = BillingRate.objects.filter(
                    Q(room=summary.room) | Q(room__isnull=True),
                    Q(valid_from__lte=summary.period_start) | Q(valid_from__isnull=True),
                    Q(valid_to__gte=summary.period_start) | Q(valid_to__isnull=True)
                ).order_by('-created_at').first()

                if not rate:
                    logger.warning(f"No billing rate found for room {summary.room.name} on %s", summary.period_start)
                    default_rate_per_kwh = 10.00
                    if summary.total_energy >= 0.1:
                        default_rate_per_kwh = 15.00
                    elif summary.total_energy >= 0.01:
                        default_rate_per_kwh = 12.50
                    cost = summary.total_energy * default_rate_per_kwh
                    total_cost += cost
                    total_energy += summary.total_energy
                    details.append({
                        'room_id': str(summary.room.id),
                        'room_name': summary.room.name,
                        'component_id': str(summary.component.id),
                        'component_type': summary.component.component_type,
                        'total_energy': summary.total_energy,
                        'rate_per_kwh': default_rate_per_kwh,
                        'effective_rate': default_rate_per_kwh,
                        'currency': 'PHP',
                        'cost': round(cost, 2),
                        'period_start': summary.period_start.isoformat(),
                        'period_end': summary.period_end.isoformat(),
                    })
                    continue

                cost = summary.total_energy * rate.get_rate_for_time(summary.period_start)
                total_cost += cost
                total_energy += summary.total_energy
                details.append({
                    'room_id': str(summary.room.id),
                    'room_name': summary.room.name,
                    'component_id': str(summary.component.id),
                    'component_type': summary.component.component_type,
                    'total_energy': summary.total_energy,
                    'rate_per_kwh': rate.rate_per_kwh,
                    'effective_rate': rate.get_rate_for_time(summary.period_start),
                    'currency': rate.currency,
                    'cost': round(cost, 2),
                    'period_start': summary.period_start.isoformat(),
                    'period_end': summary.period_end.isoformat(),
                })

            effective_rate = total_cost / total_energy if total_energy > 0 else 0
            logger.info(f"Calculated total_cost=%s, total_energy=%s, effective_rate=%s, currency=%s for %s summaries",
                       total_cost, total_energy, effective_rate, rate.currency if rate else 'PHP', len(details))
            return Response({
                'success': True,
                'data': {
                    'total_cost': round(total_cost, 2),
                    'effective_rate': round(effective_rate, 2),
                    'currency': rate.currency if rate else 'PHP',
                    'details': details
                },
                'timestamp': timezone.now().isoformat()
            }, status=status.HTTP_200_OK)

        except Exception as e:
            logger.exception(f"Error in calculate_energy_cost: {str(e)}")
            return Response(
                {'error': f'Server error: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=False, methods=['get'], permission_classes=[RoleBasedPermission])
    def energy_cost_simple(self, request):
        logger.info("Simple energy cost calculation requested with params: %s", request.query_params)
        try:
            room_id = request.query_params.get('room_id')
            period_type = request.query_params.get('period_type')
            date = request.query_params.get('date')

            if not room_id or not period_type or not date:
                logger.error("Missing required query parameters")
                return Response(
                    {'error': 'room_id, period_type, and date are required'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            try:
                date = timezone.datetime.fromisoformat(date.replace('Z', '+00:00')).date()
            except ValueError:
                logger.error("Invalid date format: %s", date)
                return Response(
                    {'error': 'Invalid date format. Use ISO format (e.g., 2025-09-27)'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            from core.models import PERIOD_TYPE_CHOICES
            if period_type not in [choice[0] for choice in PERIOD_TYPE_CHOICES]:
                logger.error(f"Invalid period_type: {period_type}")
                return Response(
                    {'error': f"Invalid period_type. Must be one of: {', '.join([choice[0] for choice in PERIOD_TYPE_CHOICES])}"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            try:
                uuid.UUID(room_id)
            except ValueError:
                logger.error(f"Invalid room_id format: {room_id}")
                return Response(
                    {'error': 'Invalid room_id format. Must be a valid UUID'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            summary = EnergySummary.objects.filter(
                room__id=room_id,
                period_type=period_type,
                period_start__date=date
            ).select_related('room', 'component').first()

            if not summary:
                logger.info(f"No energy summary found for room %s, period %s, date %s", room_id, period_type, date)
                return Response(
                    {'error': 'No data for this period'},
                    status=status.HTTP_404_NOT_FOUND
                )

            rate = BillingRate.objects.filter(
                Q(room=summary.room) | Q(room__isnull=True),
                Q(valid_from__lte=summary.period_start) | Q(valid_from__isnull=True),
                Q(valid_to__gte=summary.period_start) | Q(valid_to__isnull=True)
            ).order_by('-created_at').first()

            total_cost = 0
            effective_rate = 0
            rate_per_kwh = 0
            currency = 'PHP'
            if rate:
                effective_rate = rate.get_rate_for_time(summary.period_start)
                rate_per_kwh = rate.rate_per_kwh
                total_cost = round(summary.total_energy * effective_rate, 2)
                currency = rate.currency
            else:
                logger.warning(f"No applicable billing rate found for room %s", summary.room.name)

            data = {
                'room_id': str(summary.room.id),
                'room_name': summary.room.name,
                'component_id': str(summary.component.id),
                'component_type': summary.component.component_type,
                'period_type': summary.period_type,
                'period_start': summary.period_start.isoformat(),
                'period_end': summary.period_end.isoformat(),
                'total_energy': summary.total_energy,
                'rate_per_kwh': rate_per_kwh,
                'effective_rate': effective_rate,
                'currency': currency,
                'total_cost': total_cost,
            }

            logger.info(f"Simple energy cost: %s %s for room %s, period %s, date %s", total_cost, currency, room_id, period_type, date)
            return Response({
                'success': True,
                'data': data,
                'timestamp': timezone.now().isoformat()
            }, status=status.HTTP_200_OK)

        except Exception as e:
            logger.exception(f"Error in energy_cost_simple: {str(e)}")
            return Response(
                {'error': f'Server error: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class AlertViewSet(viewsets.ModelViewSet):
    queryset = Alert.objects.select_related('equipment').all()
    serializer_class = AlertSerializer
    permission_classes = [RoleBasedPermission]

    def get_queryset(self):
        queryset = super().get_queryset()
        user = self.request.user
        if hasattr(user, 'role') and user.role == 'client':
            queryset = queryset.filter(equipment__maintenancerequest__user=user).distinct()
        resolved = self.request.query_params.get('resolved')
        severity = self.request.query_params.get('severity')
        alert_type = self.request.query_params.get('type')
        if resolved is not None:
            resolved_bool = resolved.lower() == 'true'
            queryset = queryset.filter(resolved=resolved_bool)
        if severity:
            queryset = queryset.filter(severity=severity)
        if alert_type:
            queryset = queryset.filter(type=alert_type)
        return queryset

class MaintenanceAttachmentViewSet(viewsets.ModelViewSet):
    queryset = MaintenanceAttachment.objects.select_related('maintenance_request', 'uploaded_by').all()
    serializer_class = MaintenanceAttachmentSerializer
    permission_classes = [RoleBasedPermission]
    def get_queryset(self):
        queryset = super().get_queryset()
        user = self.request.user
        if hasattr(user, 'role') and user.role == 'client':
            return queryset.filter(maintenance_request__user=user)
        return queryset

class MaintenanceRequestViewSet(viewsets.ModelViewSet):
    queryset = MaintenanceRequest.objects.select_related('user', 'equipment', 'assigned_to').prefetch_related('attachments').all()
    serializer_class = MaintenanceRequestSerializer
    permission_classes = [RoleBasedPermission]
    def get_queryset(self):
        queryset = super().get_queryset()
        user = self.request.user
        if hasattr(user, 'role'):
            if user.role == 'client':
                return queryset.filter(user=user)
            elif user.role == 'employee':
                return queryset.filter(assigned_to=user)
        return queryset
    def perform_create(self, serializer):
        instance = serializer.save(user=self.request.user)
        logger.info(f"Maintenance request created: {instance.id} by {self.request.user.username}")
        NotificationService.notify_maintenance_request_created(instance, self.request)
    def perform_update(self, serializer):
        logger.info(f"Updating maintenance request {self.get_object().id} by user {self.request.user.username}")
        old_assigned_to = self.get_object().assigned_to
        instance = serializer.save()
        assigned_changed = 'assigned_to' in serializer.validated_data and instance.assigned_to != old_assigned_to
        logger.info(f"Updated maintenance request {instance.id} with status {instance.status}")
        NotificationService.notify_maintenance_request_updated(instance, self.request, assigned_changed)
    @action(detail=True, methods=['post'], permission_classes=[RoleBasedPermission])
    def respond(self, request, pk=None):
        logger.info(f"Response requested for maintenance request {pk}")
        try:
            maintenance_request = self.get_object()
            response_text = request.data.get('response')
            assigned_to_id = request.data.get('assigned_to')
            if not response_text:
                logger.error("Missing response field")
                return Response(
                    {'error': 'Response field is required'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            old_assigned_to = maintenance_request.assigned_to
            if assigned_to_id:
                try:
                    new_assigned_to = User.objects.get(id=assigned_to_id)
                    maintenance_request.assigned_to = new_assigned_to
                except User.DoesNotExist:
                    logger.error(f"User with id {assigned_to_id} not found")
                    return Response(
                        {'error': f'User with id {assigned_to_id} not found'},
                        status=status.HTTP_400_BAD_REQUEST
                    )
            current_time = timezone.now().strftime('%Y-%m-%d %H:%M:%S')
            new_comment = f"\n[{current_time}] {request.user.username} (Admin): {response_text}"
            maintenance_request.comments = (maintenance_request.comments or '') + new_comment
            maintenance_request.save()
            NotificationService.notify_maintenance_request_responded(maintenance_request, response_text, request)
            if assigned_to_id and maintenance_request.assigned_to != old_assigned_to:
                NotificationService.notify_maintenance_request_updated(maintenance_request, request, assigned_changed=True)
            logger.info(f"Response added to maintenance request {pk} by {request.user.username}")
            return Response(
                MaintenanceRequestSerializer(maintenance_request).data,
                status=status.HTTP_200_OK
            )
        except Exception as e:
            logger.error(f"Error adding response: {str(e)}")
            return Response(
                {'error': f'Server error: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    @action(detail=True, methods=['post'], permission_classes=[RoleBasedPermission])
    def upload_attachment(self, request, pk=None):
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
            NotificationService.notify_maintenance_attachment_uploaded(maintenance_request, attachment, request)
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
    queryset = Notification.objects.select_related('user').order_by('-created_at')
    serializer_class = NotificationSerializer
    permission_classes = [RoleBasedPermission]
    pagination_class = StandardResultsSetPagination

    def get_queryset(self):
        user = self.request.user
        if hasattr(user, 'role') and user.role == 'client':
            return self.queryset.filter(user=user)
        return self.queryset

    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated])
    def mark_all_read(self, request):
        user = request.user
        if hasattr(user, 'role') and user.role == 'client':
            notifications = Notification.objects.filter(user=user, read=False)
        else:
            notifications = Notification.objects.filter(read=False)
        count = notifications.update(read=True)
        logger.info(f"Marked {count} notifications as read for {user.username} (User ID: {user.id})")
        return Response({'status': f'{count} notifications marked as read'})

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def mark_read(self, request, pk=None):
        notification = get_object_or_404(Notification, pk=pk)
        if request.user.role == 'client' and notification.user != request.user:
            logger.warning(f"User {request.user.username} (ID: {request.user.id}) attempted to mark notification {pk} as read without permission")
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)
        notification.read = True
        notification.save()
        logger.info(f"Notification {pk} marked as read for {request.user.username} (User ID: {request.user.id})")
        return Response({'status': 'Notification marked as read'})

    def destroy(self, request, pk=None):
        """
        Delete a specific notification by ID, with permission checks.
        Clients can only delete their own notifications; admins/superadmins can delete any.
        """
        try:
            notification = get_object_or_404(Notification, pk=pk)
            if request.user.role == 'client' and notification.user != request.user:
                logger.warning(f"User {request.user.username} (ID: {request.user.id}) attempted to delete notification {pk} without permission")
                return Response(
                    {'error': 'Permission denied'},
                    status=status.HTTP_403_FORBIDDEN
                )
            notification.delete()
            logger.info(f"Notification {pk} deleted by {request.user.username} (User ID: {request.user.id})")
            return Response(
                {'status': 'Notification deleted'},
                status=status.HTTP_200_OK
            )
        except Exception as e:
            logger.error(f"Error deleting notification {pk} by {request.user.username} (User ID: {request.user.id}): {str(e)}")
            return Response(
                {'error': f'Server error: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class LLMQueryViewSet(viewsets.ModelViewSet):
    queryset = LLMQuery.objects.select_related('user').all()
    serializer_class = LLMQuerySerializer
    permission_classes = [RoleBasedPermission]

class LLMSummaryViewSet(viewsets.ModelViewSet):
    queryset = LLMSummary.objects.all()
    serializer_class = LLMSummarySerializer
    permission_classes = [RoleBasedPermission]

class AuthTokenViewSet(viewsets.ModelViewSet):
    queryset = AuthToken.objects.select_related('user').all()
    serializer_class = AuthTokenSerializer
    permission_classes = [RoleBasedPermission]