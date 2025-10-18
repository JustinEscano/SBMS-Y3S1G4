from django.apps import AppConfig
import logging

logger = logging.getLogger(__name__)

class CoreConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'core'

    def ready(self):
        try:
            import core.views.signals  # Register signals from core/views/signals.py
            logger.info("Successfully imported core.views.signals")
        except ImportError as e:
            logger.error(f"Failed to import core.views.signals: {str(e)}")