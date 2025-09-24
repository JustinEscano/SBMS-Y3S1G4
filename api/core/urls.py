from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    UserViewSet, RoomViewSet, EquipmentViewSet, SensorLogViewSet, HeartbeatLogViewSet, AlertViewSet,
    MaintenanceRequestViewSet, NotificationViewSet, LLMQueryViewSet, LLMSummaryViewSet,
    AuthTokenViewSet, MaintenanceAttachmentViewSet, ComponentViewSet, EnergySummaryViewSet,
    PredictiveAlertViewSet, BillingRateViewSet, RegisterView,
    dashboard_summary, room_realtime, check_anomalies, esp32_sensor_data,
    esp32_health_check, latest_sensor_data, esp32_heartbeat, equipment_field_options,
    predict_maintenance
)

router = DefaultRouter()
router.register(r'users', UserViewSet)
router.register(r'rooms', RoomViewSet)
router.register(r'equipment', EquipmentViewSet)
router.register(r'components', ComponentViewSet)
router.register(r'sensorlog', SensorLogViewSet)
router.register(r'heartbeatlog', HeartbeatLogViewSet)
router.register(r'alert', AlertViewSet)
router.register(r'maintenancerequest', MaintenanceRequestViewSet)
router.register(r'notification', NotificationViewSet)
router.register(r'llmquery', LLMQueryViewSet)
router.register(r'llmsummary', LLMSummaryViewSet)
router.register(r'authtoken', AuthTokenViewSet)
router.register(r'maintenanceattachment', MaintenanceAttachmentViewSet)
router.register(r'energysummary', EnergySummaryViewSet)
router.register(r'predictivealert', PredictiveAlertViewSet)
router.register(r'billingrate', BillingRateViewSet)

urlpatterns = [
    path('', include(router.urls)),
    path('register/', RegisterView.as_view(), name='register'),
    
    # Dashboard endpoints
    path('dashboard/summary/', dashboard_summary, name='dashboard_summary'),
    path('rooms/<uuid:pk>/realtime/', room_realtime, name='room_realtime'),
    
    # Anomaly and predictive maintenance endpoints
    path('check-anomalies/', check_anomalies, name='check_anomalies'),
    path('predict-maintenance/', predict_maintenance, name='predict_maintenance'),
    
    # ESP32 specific endpoints
    path('esp32/sensor-data/', esp32_sensor_data, name='esp32_sensor_data'),
    path('esp32/health/', esp32_health_check, name='esp32_health_check'),
    path('esp32/latest/', latest_sensor_data, name='latest_sensor_data'),
    path('esp32/heartbeat/', esp32_heartbeat, name='esp32_heartbeat'),
    
    # Field options endpoint
    path('equipment/field-options/', equipment_field_options, name='equipment_field_options'),
]