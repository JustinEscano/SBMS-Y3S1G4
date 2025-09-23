from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    UserViewSet, RoomViewSet, EquipmentViewSet, SensorLogViewSet, AlertViewSet,
    MaintenanceRequestViewSet, NotificationViewSet, LLMQueryViewSet, LLMSummaryViewSet,
    AuthTokenViewSet, MaintenanceAttachmentViewSet, RegisterView,
    dashboard_summary, room_realtime, check_anomalies, esp32_sensor_data,
    esp32_health_check, latest_sensor_data, esp32_heartbeat, equipment_field_options
)

router = DefaultRouter()
router.register(r'users', UserViewSet)
router.register(r'rooms', RoomViewSet)
router.register(r'equipment', EquipmentViewSet)
router.register(r'sensorlog', SensorLogViewSet)
router.register(r'alert', AlertViewSet)
router.register(r'maintenancerequest', MaintenanceRequestViewSet)
router.register(r'notification', NotificationViewSet)
router.register(r'llmquery', LLMQueryViewSet)
router.register(r'llmsummary', LLMSummaryViewSet)
router.register(r'authtoken', AuthTokenViewSet)
router.register(r'maintenanceattachment', MaintenanceAttachmentViewSet)

urlpatterns = [
    path('', include(router.urls)),
    path('register/', RegisterView.as_view(), name='register'),
    
    # Dashboard endpoints
    path('dashboard/summary/', dashboard_summary, name='dashboard_summary'),
    path('rooms/<uuid:pk>/realtime/', room_realtime, name='room_realtime'),
    
    # Anomaly check
    path('check-anomalies/', check_anomalies, name='check_anomalies'),
    
    # ESP32 specific endpoints
    path('esp32/sensor-data/', esp32_sensor_data, name='esp32_sensor_data'),
    path('esp32/health/', esp32_health_check, name='esp32_health_check'),
    path('esp32/latest/', latest_sensor_data, name='latest_sensor_data'),
    path('esp32/heartbeat/', esp32_heartbeat, name='esp32_heartbeat'),
    
    # New endpoint for field options
    path('equipment/field-options/', equipment_field_options, name='equipment_field_options'),
]