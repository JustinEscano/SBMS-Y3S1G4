# database_adapter.py
import os
import sys
import django
import psycopg2
import pandas as pd
from datetime import datetime
import logging
from sqlalchemy import create_engine

# Add the Django project to the Python path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..', 'api'))

# Configure Django settings
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'dbmsAPI.settings')
django.setup()

# Now import Django models
from core.models import SensorLog, Equipment, Room, MaintenanceRequest, Alert, EnergySummary, BillingRate

logger = logging.getLogger(__name__)

class DatabaseAdapter:
    """
    Adapter class to connect the LLM analyzer to PostgreSQL database
    using Django ORM and direct SQL queries
    """
    
    def __init__(self):
        self.connection = None
        self.engine = None
        self._connect_to_db()
    
    def _connect_to_db(self):
        """Establish PostgreSQL connection using SQLAlchemy for pandas compatibility"""
        try:
            # Create SQLAlchemy engine for pandas compatibility
            connection_string = "postgresql://postgres:9609@localhost:5432/sbmsdb"
            self.engine = create_engine(connection_string)
            
            # Also maintain psycopg2 connection for execute_query method
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
                CASE WHEN sl.light_detected THEN 10 ELSE 0 END as "power_consumption_watts.lighting",
                sl.energy_usage * 0.3 as "power_consumption_watts.hvac_fan",
                sl.energy_usage * 0.2 as "power_consumption_watts.air_conditioner_compressor",
                0 as "power_consumption_watts.projector",
                0 as "power_consumption_watts.computer",
                sl.energy_usage * 0.1 as "power_consumption_watts.standby_misc",
                sl.energy_usage as "power_consumption_watts.total",
                CASE WHEN sl.light_detected THEN 8 ELSE 0 END as "equipment_usage.lights_on_hours",
                CASE WHEN sl.temperature > 25 THEN 6 ELSE 0 END as "equipment_usage.air_conditioner_on_hours",
                0 as "equipment_usage.projector_on_hours",
                0 as "equipment_usage.computer_on_hours",
                sl.temperature as "environmental_data.temperature_celsius",
                sl.humidity as "environmental_data.humidity_percent",
                e.name as equipment_name,
                COALESCE(r.name, CONCAT('Equipment ', e.id, ' Location')) as room_name
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
            
            # Execute query and create DataFrame using SQLAlchemy engine
            df = pd.read_sql_query(query, self.engine, params=tuple(params) if params else None)
            
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

    def get_alerts_data_as_dataframe(self, limit=None, resolved_only=False, unresolved_only=False, days_back=30):
        """Fetch alerts data from core_alert table for anomaly detection"""
        try:
            # Calculate cutoff date
            cutoff_date = datetime.now() - pd.Timedelta(days=days_back)
            
            query = """
            SELECT 
                id,
                type AS alert_type,
                message,
                severity AS severity_level,
                triggered_at AS created_at,
                resolved AS is_resolved,
                resolved_at,
                equipment_id
            FROM core_alert 
            WHERE triggered_at >= %s
            """
            
            params = [cutoff_date]
            
            if resolved_only:
                query += " AND resolved = true"
            elif unresolved_only:
                query += " AND resolved = false"
            
            query += " ORDER BY created_at DESC"
            
            if limit:
                query += " LIMIT %s"
                params.append(limit)
            
            df = pd.read_sql_query(query, self.engine, params=tuple(params) if params else None)
            
            # Convert timestamp columns
            if 'created_at' in df.columns:
                df['created_at'] = pd.to_datetime(df['created_at'])
            if 'resolved_at' in df.columns:
                df['resolved_at'] = pd.to_datetime(df['resolved_at'])
            
            logger.info(f"Retrieved {len(df)} alerts from database for anomaly analysis")
            
            if not df.empty:
                logger.info(f"Alert types distribution: {df['alert_type'].value_counts().to_dict()}")
                logger.info(f"Severity distribution: {df['severity_level'].value_counts().to_dict()}")
                logger.info(f"Resolution status: {df['is_resolved'].value_counts().to_dict()}")
            
            return df
            
        except Exception as e:
            logger.error(f"Error fetching alerts data: {e}")
            return pd.DataFrame()

    def get_maintenance_requests_as_dataframe(self, limit=None, status_filter=None):
        """Get maintenance requests from core_maintenancerequest table with user information"""
        try:
            # Join with user and equipment tables to get complete information
            query = """
            SELECT 
                mr.id, 
                mr.issue as issue_description, 
                mr.status, 
                mr.scheduled_date as requested_date, 
                mr.resolved_at as resolved_date, 
                mr.created_at, 
                mr.equipment_id,
                mr.user_id as requested_by_id,
                u.username as requested_by_username,
                u.email as requested_by_email,
                u.role as requested_by_role,
                mr.assigned_to_id,
                au.username as assigned_to_username,
                au.email as assigned_to_email,
                mr.comments as notes,
                e.name as equipment_name,
                e.type as equipment_type,
                e.status as equipment_status,
                r.name as room_name,
                r.floor as room_floor,
                r.type as room_type
            FROM core_maintenancerequest mr
            LEFT JOIN core_user u ON mr.user_id = u.id
            LEFT JOIN core_user au ON mr.assigned_to_id = au.id
            LEFT JOIN core_equipment e ON mr.equipment_id = e.id
            LEFT JOIN core_room r ON e.room_id = r.id
            WHERE 1=1
            """
            
            params = []
            if status_filter:
                query += " AND mr.status = %s"
                params.append(status_filter)
            
            query += " ORDER BY mr.created_at DESC"
            
            if limit:
                query += " LIMIT %s"
                params.append(limit)
            
            df = pd.read_sql_query(query, self.engine, params=tuple(params) if params else None)
            
            # Convert date columns to datetime
            date_columns = ['requested_date', 'resolved_date', 'created_at']
            for col in date_columns:
                if col in df.columns:
                    df[col] = pd.to_datetime(df[col], errors='coerce')
            
            logger.info(f"Retrieved {len(df)} maintenance requests from database")
            logger.info(f"Maintenance data columns: {list(df.columns)}")
            if not df.empty:
                logger.info(f"Sample maintenance data: {df[['issue_description', 'status', 'requested_by_username', 'room_name']].head(2).to_dict('records')}")
                logger.info(f"Status distribution: {df['status'].value_counts().to_dict()}")
            
            return df
        except Exception as e:
            logger.error(f"Error fetching maintenance requests: {e}")
            return pd.DataFrame()

    def get_maintenance_requests_using_django(self, limit=None):
        """Alternative method using Django ORM to get maintenance requests"""
        try:
            maintenance_requests = MaintenanceRequest.objects.select_related(
                'equipment', 'user', 'assigned_to'
            ).all().order_by('-created_at')
            
            if limit:
                maintenance_requests = maintenance_requests[:limit]
            
            data = []
            for mr in maintenance_requests:
                data.append({
                    'id': str(mr.id),
                    'issue_description': mr.issue,
                    'status': mr.status,
                    'requested_date': mr.scheduled_date,
                    'resolved_date': mr.resolved_at,
                    'created_at': mr.created_at,
                    'equipment_id': str(mr.equipment_id) if mr.equipment_id else None,
                    'requested_by_id': str(mr.user_id) if mr.user_id else None,
                    'assigned_to_id': str(mr.assigned_to_id) if mr.assigned_to_id else None,
                    'notes': mr.comments,
                    'equipment_name': mr.equipment.name if mr.equipment else 'No Equipment'
                })
            
            df = pd.DataFrame(data)
            logger.info(f"Retrieved {len(df)} maintenance requests using Django ORM")
            return df
            
        except Exception as e:
            logger.error(f"Error fetching maintenance requests with Django: {e}")
            return None
    
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
    
    def get_alerts_with_equipment_info(self, limit=None, days_back=60):
        """Get alerts with equipment and room information for detailed analysis"""
        try:
            cutoff_date = datetime.now() - pd.Timedelta(days=days_back)
            
            query = """
            SELECT 
                a.id,
                a.type AS alert_type,
                a.message,
                a.severity AS severity_level,
                a.triggered_at AS created_at,
                a.resolved AS is_resolved,
                a.resolved_at,
                a.equipment_id,
                e.name as equipment_name,
                e.type as equipment_type,
                r.name as room_name,
                r.type as room_type
            FROM core_alert a
            LEFT JOIN core_equipment e ON a.equipment_id = e.id
            LEFT JOIN core_room r ON e.room_id = r.id
            WHERE a.triggered_at >= %s
            ORDER BY a.triggered_at DESC
            """
            
            params = [cutoff_date]
            
            if limit:
                query += " LIMIT %s"
                params.append(limit)
            
            df = pd.read_sql_query(query, self.engine, params=tuple(params) if params else None)
            
            # Convert timestamp columns
            if 'created_at' in df.columns:
                df['created_at'] = pd.to_datetime(df['created_at'])
            if 'resolved_at' in df.columns:
                df['resolved_at'] = pd.to_datetime(df['resolved_at'])
            
            logger.info(f"Retrieved {len(df)} alerts with equipment information")
            return df
            
        except Exception as e:
            logger.error(f"Error fetching alerts with equipment info: {e}")
            return pd.DataFrame()
    
    def get_alert_statistics(self, days_back=30):
        """Get quick statistics about alerts for dashboard display"""
        try:
            cutoff_date = datetime.now() - pd.Timedelta(days=days_back)
            
            query = """
            SELECT 
                COUNT(*) as total_alerts,
                COUNT(CASE WHEN resolved = false THEN 1 END) as unresolved_alerts,
                COUNT(CASE WHEN severity = 'high' THEN 1 END) as high_severity_alerts,
                COUNT(CASE WHEN severity = 'medium' THEN 1 END) as medium_severity_alerts,
                COUNT(CASE WHEN severity = 'low' THEN 1 END) as low_severity_alerts,
                COUNT(CASE WHEN type = 'temperature_high' OR type = 'temperature_low' THEN 1 END) as temperature_alerts,
                COUNT(CASE WHEN type = 'energy_anomaly' THEN 1 END) as energy_alerts,
                COUNT(CASE WHEN type = 'motion' THEN 1 END) as motion_alerts,
                COUNT(CASE WHEN type LIKE 'humidity%' THEN 1 END) as humidity_alerts
            FROM core_alert 
            WHERE triggered_at >= %s
            """
            
            df = pd.read_sql_query(query, self.engine, params=(cutoff_date,))
            
            if not df.empty:
                stats = df.iloc[0].to_dict()
                
                # Calculate resolution rate
                if stats['total_alerts'] > 0:
                    stats['resolution_rate'] = (stats['total_alerts'] - stats['unresolved_alerts']) / stats['total_alerts'] * 100
                else:
                    stats['resolution_rate'] = 0
                
                logger.info(f"Alert statistics calculated: {stats}")
                return stats
            else:
                return {
                    'total_alerts': 0,
                    'unresolved_alerts': 0,
                    'high_severity_alerts': 0,
                    'resolution_rate': 0
                }
                
        except Exception as e:
            logger.error(f"Error calculating alert statistics: {e}")
            return {
                'total_alerts': 0,
                'unresolved_alerts': 0,
                'high_severity_alerts': 0,
                'resolution_rate': 0
            }
    
    def get_alert_trends(self, days_back=30):
        """Get daily alert trends for time-series analysis"""
        try:
            cutoff_date = datetime.now() - pd.Timedelta(days=days_back)
            
            query = """
            SELECT 
                DATE(triggered_at) as date,
                COUNT(*) as daily_alerts,
                COUNT(CASE WHEN severity = 'high' THEN 1 END) as high_severity,
                COUNT(CASE WHEN severity = 'medium' THEN 1 END) as medium_severity,
                COUNT(CASE WHEN severity = 'low' THEN 1 END) as low_severity,
                COUNT(CASE WHEN resolved = true THEN 1 END) as resolved_alerts
            FROM core_alert 
            WHERE triggered_at >= %s
            GROUP BY DATE(triggered_at)
            ORDER BY date
            """
            
            df = pd.read_sql_query(query, self.engine, params=(cutoff_date,))
            
            if not df.empty:
                df['date'] = pd.to_datetime(df['date'])
                logger.info(f"Retrieved alert trends for {len(df)} days")
                return df
            else:
                return pd.DataFrame()
                
        except Exception as e:
            logger.error(f"Error fetching alert trends: {e}")
            return pd.DataFrame()
    
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
                    'light_detected': reading.light_detected,
                    'motion_detected': reading.motion_detected,
                    'energy_usage': reading.energy_usage,
                    'recorded_at': reading.recorded_at.isoformat()
                })
            
            return readings_list
        except Exception as e:
            logger.error(f"Error getting sensor readings: {e}")
            raise

    def get_energy_summary_dataframe(self, start_date=None, end_date=None, room_id=None, component_id=None, limit=None):
        """Read aggregated energy summaries from core_energysummary for analytics."""
        try:
            query = """
            SELECT 
                es.id,
                es.period_start,
                es.period_end,
                es.period_type,
                es.total_energy,
                es.avg_power,
                es.peak_power,
                es.reading_count,
                es.anomaly_count,
                es.created_at,
                es.component_id,
                es.room_id,
                es.currency,
                es.total_cost,
                COALESCE(r.name, CONCAT('Room ', es.room_id)) as room_name
            FROM core_energysummary es
            LEFT JOIN core_room r ON es.room_id = r.id
            WHERE 1=1
            """
            params = []
            if start_date:
                query += " AND period_end >= %s"
                params.append(start_date)
            if end_date:
                query += " AND period_start <= %s"
                params.append(end_date)
            if room_id:
                query += " AND room_id = %s"
                params.append(room_id)
            if component_id:
                query += " AND component_id = %s"
                params.append(component_id)
            query += " ORDER BY period_start DESC"
            if limit:
                query += " LIMIT %s"
                params.append(limit)

            df = pd.read_sql_query(query, self.engine, params=tuple(params) if params else None)
            # Normalize datetime columns
            for col in ["period_start", "period_end", "created_at"]:
                if col in df.columns:
                    df[col] = pd.to_datetime(df[col], errors='coerce')
            return df
        except Exception as e:
            logger.error(f"Error reading energy summary: {e}")
            return pd.DataFrame()
        
    def get_energy_summary_data(self, start_date=None, end_date=None, room_id=None, component_id=None, period_type=None, limit=None):
        """Read aggregated energy summaries from core_energysummary for analytics."""
        try:
            query = """
            SELECT 
                es.id,
                es.period_start,
                es.period_end,
                es.period_type,
                es.total_energy,
                es.avg_power,
                es.peak_power,
                es.reading_count,
                es.anomaly_count,
                es.created_at,
                es.component_id,
                es.room_id,
                es.currency,
                es.total_cost,
                COALESCE(r.name, CONCAT('Room ', es.room_id)) as room_name
            FROM core_energysummary es
            LEFT JOIN core_room r ON es.room_id = r.id
            WHERE 1=1
            """
            params = []
            if start_date:
                query += " AND period_end >= %s"
                params.append(start_date)
            if end_date:
                query += " AND period_start <= %s"
                params.append(end_date)
            if room_id:
                query += " AND room_id = %s"
                params.append(room_id)
            if component_id:
                query += " AND component_id = %s"
                params.append(component_id)
            if period_type:
                query += " AND period_type = %s"
                params.append(period_type)
            query += " ORDER BY period_start DESC"
            if limit:
                query += " LIMIT %s"
                params.append(limit)

            df = pd.read_sql_query(query, self.engine, params=tuple(params) if params else None)
            # Normalize datetime columns
            for col in ["period_start", "period_end", "created_at"]:
                if col in df.columns:
                    df[col] = pd.to_datetime(df[col], errors='coerce')
            return df
        except Exception as e:
            logger.error(f"Error reading energy summary: {e}")
            return pd.DataFrame()
        

    def get_billing_rates_dataframe(self, room_id=None, active_at=None):
        """Read billing rates, defaulting currency to PHP when missing."""
        try:
            query = """
            SELECT 
                id,
                rate_per_kwh,
                created_at,
                room_id,
                COALESCE(currency, 'PHP') AS currency,
                end_time,
                start_time,
                valid_from,
                valid_to
            FROM core_billingrate
            WHERE 1=1
            """
            params = []
            if room_id:
                query += " AND (room_id = %s OR room_id IS NULL)"
                params.append(room_id)
            if active_at:
                query += " AND (valid_from IS NULL OR valid_from <= %s) AND (valid_to IS NULL OR valid_to >= %s)"
                params.extend([active_at, active_at])
            query += " ORDER BY created_at DESC"

            df = pd.read_sql_query(query, self.engine, params=tuple(params) if params else None)
            for col in ["created_at", "valid_from", "valid_to"]:
                if col in df.columns:
                    df[col] = pd.to_datetime(df[col], errors='coerce')
            # Fallback: if no active rates found, get latest without time filters
            if (df is None or df.empty) and active_at is not None:
                fallback_query = """
                SELECT 
                    id,
                    rate_per_kwh,
                    created_at,
                    room_id,
                    COALESCE(currency, 'PHP') AS currency,
                    end_time,
                    start_time,
                    valid_from,
                    valid_to
                FROM core_billingrate
                WHERE 1=1
                """
                fallback_params = []
                if room_id:
                    fallback_query += " AND (room_id = %s OR room_id IS NULL)"
                    fallback_params.append(room_id)
                fallback_query += " ORDER BY created_at DESC"
                df = pd.read_sql_query(fallback_query, self.engine, params=tuple(fallback_params) if fallback_params else None)
                for col in ["created_at", "valid_from", "valid_to"]:
                    if col in df.columns:
                        df[col] = pd.to_datetime(df[col], errors='coerce')
            return df
        except Exception as e:
            logger.error(f"Error reading billing rates: {e}")
            return pd.DataFrame()
    
    def execute_query(self, query, params=None):
        """Execute a raw SQL query and return results"""
        try:
            cursor = self.connection.cursor()
            if params:
                cursor.execute(query, params)
            else:
                cursor.execute(query)
            results = cursor.fetchall()
            cursor.close()
            return results
        except Exception as e:
            logger.error(f"Error executing query: {e}")
            return None
    
    def get_rooms_detailed(self):
        """Get detailed room information with equipment and sensor data"""
        try:
            query = """
            SELECT 
                r.id,
                r.name,
                r.floor,
                r.capacity,
                r.type,
                r.occupancy_pattern,
                r.typical_energy_usage,
                r.created_at,
                COUNT(DISTINCT e.id) as equipment_count,
                COUNT(DISTINCT sl.id) as sensor_reading_count,
                AVG(sl.temperature) as avg_temperature,
                AVG(sl.humidity) as avg_humidity,
                AVG(sl.energy_usage) as avg_energy_usage,
                MAX(sl.recorded_at) as last_reading
            FROM core_room r
            LEFT JOIN core_equipment e ON r.id = e.room_id
            LEFT JOIN core_sensorlog sl ON e.id = sl.equipment_id
            GROUP BY r.id, r.name, r.floor, r.capacity, r.type, r.occupancy_pattern, r.typical_energy_usage, r.created_at
            ORDER BY r.floor, r.name
            """
            
            df = pd.read_sql_query(query, self.engine)
            
            # Convert timestamp columns
            if 'created_at' in df.columns:
                df['created_at'] = pd.to_datetime(df['created_at'])
            if 'last_reading' in df.columns:
                df['last_reading'] = pd.to_datetime(df['last_reading'])
            
            logger.info(f"Retrieved {len(df)} rooms with detailed information")
            return df
            
        except Exception as e:
            logger.error(f"Error getting detailed room information: {e}")
            return pd.DataFrame()
    
    def close_connection(self):
        """Close database connection"""
        if self.connection:
            self.connection.close()
            logger.info("Database connection closed")

# Test function to verify the new alert functionality
def test_alert_functionality():
    """Test the new alert-related functionality"""
    try:
        adapter = DatabaseAdapter()
        
        print("🧪 Testing Alert Functionality")
        print("=" * 50)
        
        # Test basic alerts data
        alerts_df = adapter.get_alerts_data_as_dataframe(limit=5)
        print(f"📊 Alerts Data: {len(alerts_df)} records")
        if not alerts_df.empty:
            print(f"   Columns: {list(alerts_df.columns)}")
            print(f"   Alert types: {alerts_df['alert_type'].value_counts().to_dict()}")
        
        # Test alerts with equipment info
        detailed_alerts = adapter.get_alerts_with_equipment_info(limit=5)
        print(f"🔍 Detailed Alerts: {len(detailed_alerts)} records")
        if not detailed_alerts.empty:
            print(f"   Equipment info available: {'equipment_name' in detailed_alerts.columns}")
        
        # Test alert statistics
        stats = adapter.get_alert_statistics(days_back=7)
        print(f"📈 Alert Statistics:")
        print(f"   Total alerts: {stats.get('total_alerts', 0)}")
        print(f"   Unresolved: {stats.get('unresolved_alerts', 0)}")
        print(f"   High severity: {stats.get('high_severity_alerts', 0)}")
        print(f"   Resolution rate: {stats.get('resolution_rate', 0):.1f}%")
        
        # Test alert trends
        trends = adapter.get_alert_trends(days_back=7)
        print(f"📅 Alert Trends: {len(trends)} days of data")
        
        adapter.close_connection()
        print("✅ Alert functionality test completed successfully")
        
    except Exception as e:
        print(f"❌ Error testing alert functionality: {e}")

if __name__ == "__main__":
    test_alert_functionality()