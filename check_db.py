import os
import sys
import django
from datetime import timedelta
from django.utils import timezone

sys.path.append('c:\\SBMS-Y3S1G4\\api')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'api.settings')
django.setup()

from core.models import SensorLog, Component

now = timezone.now()
yesterday = now - timedelta(days=1)

count_24h = SensorLog.objects.filter(recorded_at__gte=yesterday).count()
total_count = SensorLog.objects.count()

latest_log = SensorLog.objects.order_by('-recorded_at').first()

print(f"Total SensorLogs: {total_count}")
print(f"SensorLogs in last 24 hours: {count_24h}")
if latest_log:
    print(f"Latest log recorded at: {latest_log.recorded_at}")
    print(f"Latest log data: pow={latest_log.power}, temp={latest_log.temperature}")

pzem_count = SensorLog.objects.filter(power__isnull=False).count()
print(f"Total PZEM logs (with power): {pzem_count}")
