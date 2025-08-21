from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import *

router = DefaultRouter()
router.register(r'users', UserViewSet)
router.register(r'rooms', RoomViewSet)
router.register(r'equipment', EquipmentViewSet)
router.register(r'sensorlog', SensorLogViewSet)
router.register(r'maintenancerequest', MaintenanceRequestViewSet)
router.register(r'llmquery', LLMQueryViewSet)
router.register(r'llmsummary', LLMSummaryViewSet)
router.register(r'authtoken', AuthTokenViewSet)

urlpatterns = [
    path('', include(router.urls)),
    path('register/', RegisterView.as_view(), name='register'),
    
    # ESP32 specific endpoints
    path('esp32/sensor-data/', esp32_sensor_data, name='esp32_sensor_data'),
    path('esp32/health/', esp32_health_check, name='esp32_health_check'),
    path('esp32/latest/', latest_sensor_data, name='latest_sensor_data'),
    path('esp32/heartbeat/', esp32_heartbeat, name='esp32_heartbeat'),
]