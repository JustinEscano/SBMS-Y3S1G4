import os, sys, django, json
try:
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "finshield.settings")
    django.setup()
except Exception:
    pass
try:
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "core.settings")
    django.setup()
except Exception:
    pass
try:
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "api.settings")
    django.setup()
except Exception:
    pass

from core.models import SensorLog, Equipment
logs = list(SensorLog.objects.filter(equipment__name__icontains='BedroomSensor').values('power', 'energy', 'component__component_type', 'recorded_at')[:5])
for log in logs:
    log['recorded_at'] = str(log['recorded_at'])
with open('logs.json', 'w') as f:
    json.dump(logs, f, indent=2)
