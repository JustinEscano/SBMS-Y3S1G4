import os
import sys
import django
import psycopg2
import pandas as pd
from datetime import datetime
import logging

# Add the Django project to the Python path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..', 'api'))

# Configure Django settings
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'dbmsAPI.settings')
django.setup()

# Now import Django models
from core.models import SensorLog, Equipment, Room

logger = logging.getLogger(__name__)

class DatabaseAdapter:
    """
    Adapter class to connect the LLM analyzer to PostgreSQL database
    using Django ORM and direct SQL queries
    """
    
    def __init__(self):
        self.connection = None
        self._connect_to_db()
    
    def _connect_to_db(self):
        """Establish direct PostgreSQL connection for complex queries"""
        try:
            self.connection = psycopg2.connect(
                host='localhost',
                database='sbmsdb',
                user='postgres',
                password='9609',
                port='5432'
            )
            logger.info("Successfully connected to PostgreSQL database")
        except Exception as e:
            logger.error(f"Error connecting to database: {e}")
            raise
    
    def get_sensor_data_as_dataframe(self, limit=None, start_date=None, end_date=None):
        """
        Retrieve sensor data from database and convert to DataFrame format
        compatible with the existing LLM analyzer
        """
        try:
            # Build query with optional filters
            query = """
            SELECT 
                sl.recorded_at as timestamp,
                CASE WHEN sl.motion_detected THEN 'occupied' ELSE 'unoccupied' END as occupancy_status,
                CASE WHEN sl.motion_detected THEN 1 ELSE 0 END as occupancy_count,
                sl.energy_usage as energy_consumption_kwh,
                sl.light_level * 10 as "power_consumption_watts.lighting",
                sl.energy_usage * 0.3 as "power_consumption_watts.hvac_fan",
                sl.energy_usage * 0.2 as "power_consumption_watts.air_conditioner_compressor",
                0 as "power_consumption_watts.projector",
                0 as "power_consumption_watts.computer",
                sl.energy_usage * 0.1 as "power_consumption_watts.standby_misc",
                sl.energy_usage as "power_consumption_watts.total",
                CASE WHEN sl.light_level > 50 THEN 8 ELSE 0 END as "equipment_usage.lights_on_hours",
                CASE WHEN sl.temperature > 25 THEN 6 ELSE 0 END as "equipment_usage.air_conditioner_on_hours",
                0 as "equipment_usage.projector_on_hours",
                0 as "equipment_usage.computer_on_hours",
                sl.temperature as "environmental_data.temperature_celsius",
                sl.humidity as "environmental_data.humidity_percent",
                e.name as equipment_name,
                r.name as room_name
            FROM core_sensorlog sl
            JOIN core_equipment e ON sl.equipment_id = e.id
            LEFT JOIN core_room r ON e.room_id = r.id
            WHERE 1=1
            """
            
            params = []
            
            if start_date:
                query += " AND sl.recorded_at >= %s"
                params.append(start_date)
            
            if end_date:
                query += " AND sl.recorded_at <= %s"
                params.append(end_date)
            
            query += " ORDER BY sl.recorded_at DESC"
            
            if limit:
                query += " LIMIT %s"
                params.append(limit)
            
            # Execute query and create DataFrame
            df = pd.read_sql_query(query, self.connection, params=params)
            
            # Convert timestamp to datetime
            df['timestamp'] = pd.to_datetime(df['timestamp'])
            
            # Ensure numeric columns are properly typed
            numeric_cols = [
                'occupancy_count', 'energy_consumption_kwh',
                'power_consumption_watts.lighting', 'power_consumption_watts.hvac_fan',
                'power_consumption_watts.air_conditioner_compressor', 'power_consumption_watts.projector',
                'power_consumption_watts.computer', 'power_consumption_watts.standby_misc',
                'power_consumption_watts.total', 'equipment_usage.lights_on_hours',
                'equipment_usage.air_conditioner_on_hours', 'equipment_usage.projector_on_hours',
                'equipment_usage.computer_on_hours', 'environmental_data.temperature_celsius',
                'environmental_data.humidity_percent'
            ]
            
            for col in numeric_cols:
                if col in df.columns:
                    df[col] = pd.to_numeric(df[col], errors='coerce')
            
            logger.info(f"Retrieved {len(df)} sensor records from database")
            return df
            
        except Exception as e:
            logger.error(f"Error retrieving sensor data: {e}")
            raise
    
    def get_room_logs_json_format(self, limit=None, start_date=None, end_date=None):
        """
        Get sensor data in the same JSON format as the original room_logs.json
        for backward compatibility with existing LLM analyzer
        """
        try:
            df = self.get_sensor_data_as_dataframe(limit, start_date, end_date)
            
            # Convert DataFrame to the expected JSON structure
            logs = []
            for _, row in df.iterrows():
                log_entry = {
                    "timestamp": row['timestamp'].isoformat(),
                    "occupancy_status": row['occupancy_status'],
                    "occupancy_count": int(row['occupancy_count']),
                    "energy_consumption_kwh": float(row['energy_consumption_kwh']),
                    "power_consumption_watts": {
                        "lighting": float(row['power_consumption_watts.lighting']),
                        "hvac_fan": float(row['power_consumption_watts.hvac_fan']),
                        "air_conditioner_compressor": float(row['power_consumption_watts.air_conditioner_compressor']),
                        "projector": float(row['power_consumption_watts.projector']),
                        "computer": float(row['power_consumption_watts.computer']),
                        "standby_misc": float(row['power_consumption_watts.standby_misc']),
                        "total": float(row['power_consumption_watts.total'])
                    },
                    "equipment_usage": {
                        "lights_on_hours": float(row['equipment_usage.lights_on_hours']),
                        "air_conditioner_on_hours": float(row['equipment_usage.air_conditioner_on_hours']),
                        "projector_on_hours": float(row['equipment_usage.projector_on_hours']),
                        "computer_on_hours": float(row['equipment_usage.computer_on_hours'])
                    },
                    "environmental_data": {
                        "temperature_celsius": float(row['environmental_data.temperature_celsius']),
                        "humidity_percent": float(row['environmental_data.humidity_percent'])
                    },
                    "equipment_name": row.get('equipment_name', 'Unknown'),
                    "room_name": row.get('room_name', 'Unknown')
                }
                logs.append(log_entry)
            
            return {"logs": logs}
            
        except Exception as e:
            logger.error(f"Error creating JSON format data: {e}")
            raise
    
    def save_llm_query(self, user_id, query, response):
        """Save LLM query and response to database"""
        try:
            from core.models import LLMQuery, User
            
            user = User.objects.get(id=user_id)
            llm_query = LLMQuery.objects.create(
                user=user,
                query=query,
                response=response
            )
            logger.info(f"Saved LLM query for user {user.username}")
            return llm_query.id
            
        except Exception as e:
            logger.error(f"Error saving LLM query: {e}")
            raise
    
    def get_equipment_list(self):
        """Get list of all equipment"""
        try:
            equipment = Equipment.objects.select_related('room').all()
            equipment_list = []
            for eq in equipment:
                equipment_list.append({
                    'id': str(eq.id),
                    'name': eq.name,
                    'type': eq.type,
                    'status': eq.status,
                    'room': eq.room.name if eq.room else 'No Room',
                    'device_id': eq.device_id
                })
            return equipment_list
        except Exception as e:
            logger.error(f"Error getting equipment list: {e}")
            raise
    
    def get_rooms_list(self):
        """Get list of all rooms"""
        try:
            rooms = Room.objects.all()
            rooms_list = []
            for room in rooms:
                rooms_list.append({
                    'id': str(room.id),
                    'name': room.name,
                    'floor': room.floor,
                    'capacity': room.capacity,
                    'type': room.type
                })
            return rooms_list
        except Exception as e:
            logger.error(f"Error getting rooms list: {e}")
            raise
    
    def get_latest_sensor_readings(self, equipment_id=None, limit=10):
        """Get latest sensor readings"""
        try:
            query = SensorLog.objects.select_related('equipment', 'equipment__room')
            
            if equipment_id:
                query = query.filter(equipment_id=equipment_id)
            
            readings = query.order_by('-recorded_at')[:limit]
            
            readings_list = []
            for reading in readings:
                readings_list.append({
                    'id': str(reading.id),
                    'equipment': reading.equipment.name,
                    'room': reading.equipment.room.name if reading.equipment.room else 'No Room',
                    'temperature': reading.temperature,
                    'humidity': reading.humidity,
                    'light_level': reading.light_level,
                    'motion_detected': reading.motion_detected,
                    'energy_usage': reading.energy_usage,
                    'recorded_at': reading.recorded_at.isoformat()
                })
            
            return readings_list
        except Exception as e:
            logger.error(f"Error getting sensor readings: {e}")
            raise
    
    def close_connection(self):
        """Close database connection"""
        if self.connection:
            self.connection.close()
            logger.info("Database connection closed")