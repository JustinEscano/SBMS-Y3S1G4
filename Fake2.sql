-- more_fake_data.sql
-- Extended Fake Data Insertion Script for PostgreSQL Database
-- This script inserts more sample fake data (5-10 records per table) into each table, respecting the schema, constraints, and foreign keys.
-- UUIDs are generated manually (in a real scenario, use uuid_generate_v4() if extension is enabled).
-- Timestamps are set around the current date (October 04, 2025).
-- Ensuring relationships (e.g., foreign keys) are valid.
-- Run this after the schema is created. Assumes no data exists yet.
-- Note: Passwords are hashed placeholders (use proper hashing in production, e.g., Django's make_password).
-- For auth tables, I've added more minimal data beyond what's in the dump.

-- Insert into core_user (5 users)
INSERT INTO public.core_user (id, username, email, role, password, last_login, created_at) VALUES
('a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 'admin_user', 'admin@example.com', 'admin', 'pbkdf2_sha256$260000$abc$def==', '2025-10-04 10:00:00+00', '2025-10-01 09:00:00+00'),
('b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e', 'regular_user1', 'user1@example.com', 'user', 'pbkdf2_sha256$260000$xyz$abc==', NULL, '2025-10-02 10:00:00+00'),
('c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', 'maintenance_user', 'maint@example.com', 'maintenance', 'pbkdf2_sha256$260000$def$ghi==', '2025-10-03 11:00:00+00', '2025-10-03 09:00:00+00'),
('d4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a', 'regular_user2', 'user2@example.com', 'user', 'pbkdf2_sha256$260000$jkl$mno==', '2025-10-04 12:00:00+00', '2025-10-04 09:00:00+00'),
('e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b', 'admin_user2', 'admin2@example.com', 'admin', 'pbkdf2_sha256$260000$pqr$stu==', NULL, '2025-10-01 10:00:00+00');

-- Insert into core_room (5 rooms)
INSERT INTO public.core_room (id, name, floor, capacity, type, created_at, occupancy_pattern, typical_energy_usage) VALUES
('f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8a9b0c', 'Conference Room A', 1, 20, 'meeting', '2025-10-01 09:00:00+00', 'weekdays 9-5', 50.5),
('a7b8c9d0-e1f2-4a3b-4c5d-6e7f8a9b0c1d', 'Office Room B', 2, 10, 'office', '2025-10-02 10:00:00+00', 'daily 8-6', 30.2),
('b8c9d0e1-f2a3-4b4c-5d6e-7f8a9b0c1d2e', 'Lab Room C', 3, 15, 'lab', '2025-10-03 11:00:00+00', 'weekdays 10-4', 60.0),
('c9d0e1f2-a3b4-4c5d-6e7f-8a9b0c1d2e3f', 'Break Room D', 1, 8, 'break', '2025-10-04 12:00:00+00', 'daily 9-5', 20.5),
('d0e1f2a3-b4c5-4d6e-7f8a-9b0c1d2e3f4a', 'Conference Room E', 4, 25, 'meeting', '2025-10-01 13:00:00+00', 'weekdays 8-6', 55.0);

-- Insert into core_equipment (references core_room, 10 equipments)
INSERT INTO public.core_equipment (id, name, type, status, qr_code, created_at, room_id, device_id) VALUES
('e1f2a3b4-c5d6-4e7f-8a9b-0c1d2e3f4a5b', 'Sensor Device 1', 'sensor', 'active', 'QR12345', '2025-10-01 09:00:00+00', 'f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8a9b0c', 'DEV001'),
('f2a3b4c5-d6e7-4f8a-9b0c-1d2e3f4a5b6c', 'Sensor Device 2', 'sensor', 'inactive', 'QR67890', '2025-10-02 10:00:00+00', 'a7b8c9d0-e1f2-4a3b-4c5d-6e7f8a9b0c1d', 'DEV002'),
('a3b4c5d6-e7f8-4a9b-0c1d-2e3f4a5b6c7d', 'Monitor Device 3', 'monitor', 'active', 'QR11111', '2025-10-03 11:00:00+00', 'b8c9d0e1-f2a3-4b4c-5d6e-7f8a9b0c1d2e', 'DEV003'),
('b4c5d6e7-f8a9-4b0c-1d2e-3f4a5b6c7d8e', 'Sensor Device 4', 'sensor', 'maintenance', 'QR22222', '2025-10-04 12:00:00+00', 'c9d0e1f2-a3b4-4c5d-6e7f-8a9b0c1d2e3f', 'DEV004'),
('c5d6e7f8-a9b0-4c1d-2e3f-4a5b6c7d8e9f', 'Camera Device 5', 'camera', 'active', 'QR33333', '2025-10-01 13:00:00+00', 'd0e1f2a3-b4c5-4d6e-7f8a-9b0c1d2e3f4a', 'DEV005'),
('d6e7f8a9-b0c1-4d2e-3f4a-5b6c7d8e9f0a', 'Sensor Device 6', 'sensor', 'active', 'QR44444', '2025-10-02 14:00:00+00', 'f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8a9b0c', 'DEV006'),
('e7f8a9b0-c1d2-4e3f-4a5b-6c7d8e9f0a1b', 'Monitor Device 7', 'monitor', 'inactive', 'QR55555', '2025-10-03 15:00:00+00', 'a7b8c9d0-e1f2-4a3b-4c5d-6e7f8a9b0c1d', 'DEV007'),
('f8a9b0c1-d2e3-4f4a-5b6c-7d8e9f0a1b2c', 'Sensor Device 8', 'sensor', 'active', 'QR66666', '2025-10-04 16:00:00+00', 'b8c9d0e1-f2a3-4b4c-5d6e-7f8a9b0c1d2e', 'DEV008'),
('a9b0c1d2-e3f4-4a5b-6c7d-8e9f0a1b2c3d', 'Camera Device 9', 'camera', 'maintenance', 'QR77777', '2025-10-01 17:00:00+00', 'c9d0e1f2-a3b4-4c5d-6e7f-8a9b0c1d2e3f', 'DEV009'),
('b0c1d2e3-f4a5-4b6c-7d8e-9f0a1b2c3d4e', 'Sensor Device 10', 'sensor', 'active', 'QR88888', '2025-10-02 18:00:00+00', 'd0e1f2a3-b4c5-4d6e-7f8a-9b0c1d2e3f4a', 'DEV010');

-- Insert into core_component (references core_equipment, 10 components)
INSERT INTO public.core_component (id, component_type, identifier, status, created_at, equipment_id) VALUES
('c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f', 'DHT22', 'COMP001', 'operational', '2025-10-01 09:00:00+00', 'e1f2a3b4-c5d6-4e7f-8a9b-0c1d2e3f4a5b'),
('d2e3f4a5-b6c7-4d8e-9f0a-1b2c3d4e5f6a', 'PZEM', 'COMP002', 'operational', '2025-10-02 10:00:00+00', 'f2a3b4c5-d6e7-4f8a-9b0c-1d2e3f4a5b6c'),
('e3f4a5b6-c7d8-4e9f-0a1b-2c3d4e5f6a7b', 'Photoresistor', 'COMP003', 'faulty', '2025-10-03 11:00:00+00', 'a3b4c5d6-e7f8-4a9b-0c1d-2e3f4a5b6c7d'),
('f4a5b6c7-d8e9-4f0a-1b2c-3d4e5f6a7b8c', 'DHT22', 'COMP004', 'operational', '2025-10-04 12:00:00+00', 'b4c5d6e7-f8a9-4b0c-1d2e-3f4a5b6c7d8e'),
('a5b6c7d8-e9f0-4a1b-2c3d-4e5f6a7b8c9d', 'PZEM', 'COMP005', 'operational', '2025-10-01 13:00:00+00', 'c5d6e7f8-a9b0-4c1d-2e3f-4a5b6c7d8e9f'),
('b6c7d8e9-f0a1-4b2c-3d4e-5f6a7b8c9d0e', 'Motion Sensor', 'COMP006', 'operational', '2025-10-02 14:00:00+00', 'd6e7f8a9-b0c1-4d2e-3f4a-5b6c7d8e9f0a'),
('c7d8e9f0-a1b2-4c3d-4e5f-6a7b8c9d0e1f', 'DHT22', 'COMP007', 'faulty', '2025-10-03 15:00:00+00', 'e7f8a9b0-c1d2-4e3f-4a5b-6c7d8e9f0a1b'),
('d8e9f0a1-b2c3-4d4e-5f6a-7b8c9d0e1f2a', 'PZEM', 'COMP008', 'operational', '2025-10-04 16:00:00+00', 'f8a9b0c1-d2e3-4f4a-5b6c-7d8e9f0a1b2c'),
('e9f0a1b2-c3d4-4e5f-6a7b-8c9d0e1f2a3b', 'Photoresistor', 'COMP009', 'operational', '2025-10-01 17:00:00+00', 'a9b0c1d2-e3f4-4a5b-6c7d-8e9f0a1b2c3d'),
('f0a1b2c3-d4e5-4f6a-7b8c-9d0e1f2a3b4c', 'Motion Sensor', 'COMP010', 'operational', '2025-10-02 18:00:00+00', 'b0c1d2e3-f4a5-4b6c-7d8e-9f0a1b2c3d4e');

-- Insert into core_sensorlog (references core_equipment and core_component, 10 logs)
INSERT INTO public.core_sensorlog (id, temperature, humidity, motion_detected, energy_usage, recorded_at, equipment_id, current, energy, power, voltage, light_detected, dht22_recorded_at, motion_recorded_at, photoresistor_recorded_at, pzem_recorded_at, component_id, reset_flag) VALUES
('a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 22.5, 45.0, true, 10.2, '2025-10-03 12:00:00+00', 'e1f2a3b4-c5d6-4e7f-8a9b-0c1d2e3f4a5b', 1.5, 5.0, 100.0, 220.0, true, '2025-10-03 12:00:00+00', '2025-10-03 12:00:00+00', '2025-10-03 12:00:00+00', '2025-10-03 12:00:00+00', 'c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f', false),
('b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e', 23.0, 50.0, false, 8.5, '2025-10-04 13:00:00+00', 'f2a3b4c5-d6e7-4f8a-9b0c-1d2e3f4a5b6c', 1.2, 4.0, 90.0, 230.0, false, '2025-10-04 13:00:00+00', '2025-10-04 13:00:00+00', '2025-10-04 13:00:00+00', '2025-10-04 13:00:00+00', 'd2e3f4a5-b6c7-4d8e-9f0a-1b2c3d4e5f6a', false),
('c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', 21.0, 40.0, true, 12.0, '2025-10-03 14:00:00+00', 'a3b4c5d6-e7f8-4a9b-0c1d-2e3f4a5b6c7d', 1.8, 6.0, 110.0, 225.0, true, '2025-10-03 14:00:00+00', '2025-10-03 14:00:00+00', '2025-10-03 14:00:00+00', '2025-10-03 14:00:00+00', 'e3f4a5b6-c7d8-4e9f-0a1b-2c3d4e5f6a7b', true),
('d4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a', 24.5, 55.0, false, 9.0, '2025-10-04 15:00:00+00', 'b4c5d6e7-f8a9-4b0c-1d2e-3f4a5b6c7d8e', 1.4, 4.5, 95.0, 235.0, false, '2025-10-04 15:00:00+00', '2025-10-04 15:00:00+00', '2025-10-04 15:00:00+00', '2025-10-04 15:00:00+00', 'f4a5b6c7-d8e9-4f0a-1b2c-3d4e5f6a7b8c', false),
('e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b', 20.0, 35.0, true, 11.5, '2025-10-03 16:00:00+00', 'c5d6e7f8-a9b0-4c1d-2e3f-4a5b6c7d8e9f', 1.6, 5.5, 105.0, 215.0, true, '2025-10-03 16:00:00+00', '2025-10-03 16:00:00+00', '2025-10-03 16:00:00+00', '2025-10-03 16:00:00+00', 'a5b6c7d8-e9f0-4a1b-2c3d-4e5f6a7b8c9d', false),
('f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8a9b0c', 25.0, 60.0, false, 7.5, '2025-10-04 17:00:00+00', 'd6e7f8a9-b0c1-4d2e-3f4a-5b6c7d8e9f0a', 1.1, 3.5, 85.0, 240.0, false, '2025-10-04 17:00:00+00', '2025-10-04 17:00:00+00', '2025-10-04 17:00:00+00', '2025-10-04 17:00:00+00', 'b6c7d8e9-f0a1-4b2c-3d4e-5f6a7b8c9d0e', true),
('a7b8c9d0-e1f2-4a3b-4c5d-6e7f8a9b0c1d', 19.5, 30.0, true, 13.0, '2025-10-03 18:00:00+00', 'e7f8a9b0-c1d2-4e3f-4a5b-6c7d8e9f0a1b', 1.9, 6.5, 115.0, 210.0, true, '2025-10-03 18:00:00+00', '2025-10-03 18:00:00+00', '2025-10-03 18:00:00+00', '2025-10-03 18:00:00+00', 'c7d8e9f0-a1b2-4c3d-4e5f-6a7b8c9d0e1f', false),
('b8c9d0e1-f2a3-4b4c-5d6e-7f8a9b0c1d2e', 26.0, 65.0, false, 6.0, '2025-10-04 19:00:00+00', 'f8a9b0c1-d2e3-4f4a-5b6c-7d8e9f0a1b2c', 1.0, 3.0, 80.0, 245.0, false, '2025-10-04 19:00:00+00', '2025-10-04 19:00:00+00', '2025-10-04 19:00:00+00', '2025-10-04 19:00:00+00', 'd8e9f0a1-b2c3-4d4e-5f6a-7b8c9d0e1f2a', false),
('c9d0e1f2-a3b4-4c5d-6e7f-8a9b0c1d2e3f', 18.0, 25.0, true, 14.0, '2025-10-03 20:00:00+00', 'a9b0c1d2-e3f4-4a5b-6c7d-8e9f0a1b2c3d', 2.0, 7.0, 120.0, 205.0, true, '2025-10-03 20:00:00+00', '2025-10-03 20:00:00+00', '2025-10-03 20:00:00+00', '2025-10-03 20:00:00+00', 'e9f0a1b2-c3d4-4e5f-6a7b-8c9d0e1f2a3b', true),
('d0e1f2a3-b4c5-4d6e-7f8a-9b0c1d2e3f4a', 27.0, 70.0, false, 5.5, '2025-10-04 21:00:00+00', 'b0c1d2e3-f4a5-4b6c-7d8e-9f0a1b2c3d4e', 0.9, 2.5, 75.0, 250.0, false, '2025-10-04 21:00:00+00', '2025-10-04 21:00:00+00', '2025-10-04 21:00:00+00', '2025-10-04 21:00:00+00', 'f0a1b2c3-d4e5-4f6a-7b8c-9d0e1f2a3b4c', false);

-- Insert into core_heartbeatlog (references core_equipment, 10 logs)
INSERT INTO public.core_heartbeatlog (id, "timestamp", dht22_working, pzem_working, success_rate, wifi_signal, uptime, sensor_type, current_temp, current_humidity, current_power, recorded_at, equipment_id, photoresistor_working, failed_readings, pzem_error_count, voltage_stability) VALUES
('e1f2a3b4-c5d6-4e7f-8a9b-0c1d2e3f4a5b', 1728057600, true, true, 99.5, -50, 3600, 'multi', 22.5, 45.0, 100.0, '2025-10-03 12:00:00+00', 'e1f2a3b4-c5d6-4e7f-8a9b-0c1d2e3f4a5b', true, 0, 0, 0.99),
('f2a3b4c5-d6e7-4f8a-9b0c-1d2e3f4a5b6c', 1728144000, true, false, 95.0, -60, 7200, 'multi', 23.0, 50.0, 90.0, '2025-10-04 13:00:00+00', 'f2a3b4c5-d6e7-4f8a-9b0c-1d2e3f4a5b6c', false, 1, 1, 0.95),
('a3b4c5d6-e7f8-4a9b-0c1d-2e3f4a5b6c7d', 1728230400, false, true, 98.0, -55, 10800, 'multi', 21.0, 40.0, 110.0, '2025-10-03 14:00:00+00', 'a3b4c5d6-e7f8-4a9b-0c1d-2e3f4a5b6c7d', true, 0, 0, 0.98),
('b4c5d6e7-f8a9-4b0c-1d2e-3f4a5b6c7d8e', 1728316800, true, true, 96.5, -65, 14400, 'multi', 24.5, 55.0, 95.0, '2025-10-04 15:00:00+00', 'b4c5d6e7-f8a9-4b0c-1d2e-3f4a5b6c7d8e', false, 2, 1, 0.96),
('c5d6e7f8-a9b0-4c1d-2e3f-4a5b6c7d8e9f', 1728403200, true, true, 97.0, -45, 18000, 'multi', 20.0, 35.0, 105.0, '2025-10-03 16:00:00+00', 'c5d6e7f8-a9b0-4c1d-2e3f-4a5b6c7d8e9f', true, 0, 0, 0.97),
('d6e7f8a9-b0c1-4d2e-3f4a-5b6c7d8e9f0a', 1728489600, false, false, 94.0, -70, 21600, 'multi', 25.0, 60.0, 85.0, '2025-10-04 17:00:00+00', 'd6e7f8a9-b0c1-4d2e-3f4a-5b6c7d8e9f0a', false, 3, 2, 0.94),
('e7f8a9b0-c1d2-4e3f-4a5b-6c7d8e9f0a1b', 1728576000, true, true, 99.0, -52, 25200, 'multi', 19.5, 30.0, 115.0, '2025-10-03 18:00:00+00', 'e7f8a9b0-c1d2-4e3f-4a5b-6c7d8e9f0a1b', true, 1, 0, 0.99),
('f8a9b0c1-d2e3-4f4a-5b6c-7d8e9f0a1b2c', 1728662400, true, false, 93.5, -62, 28800, 'multi', 26.0, 65.0, 80.0, '2025-10-04 19:00:00+00', 'f8a9b0c1-d2e3-4f4a-5b6c-7d8e9f0a1b2c', false, 4, 2, 0.93),
('a9b0c1d2-e3f4-4a5b-6c7d-8e9f0a1b2c3d', 1728748800, false, true, 98.5, -48, 32400, 'multi', 18.0, 25.0, 120.0, '2025-10-03 20:00:00+00', 'a9b0c1d2-e3f4-4a5b-6c7d-8e9f0a1b2c3d', true, 0, 0, 0.98),
('b0c1d2e3-f4a5-4b6c-7d8e-9f0a1b2c3d4e', 1728835200, true, true, 96.0, -68, 36000, 'multi', 27.0, 70.0, 75.0, '2025-10-04 21:00:00+00', 'b0c1d2e3-f4a5-4b6c-7d8e-9f0a1b2c3d4e', false, 2, 1, 0.96);

-- Insert into core_alert (references core_equipment, 10 alerts)
INSERT INTO public.core_alert (id, type, message, severity, triggered_at, resolved, resolved_at, equipment_id) VALUES
('c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f', 'temperature_high', 'High temperature detected', 'high', '2025-10-03 12:00:00+00', false, NULL, 'e1f2a3b4-c5d6-4e7f-8a9b-0c1d2e3f4a5b'),
('d2e3f4a5-b6c7-4d8e-9f0a-1b2c3d4e5f6a', 'motion', 'Motion detected', 'medium', '2025-10-04 13:00:00+00', true, '2025-10-04 14:00:00+00', 'f2a3b4c5-d6e7-4f8a-9b0c-1d2e3f4a5b6c'),
('e3f4a5b6-c7d8-4e9f-0a1b-2c3d4e5f6a7b', 'energy_anomaly', 'Energy usage anomaly', 'low', '2025-10-03 14:00:00+00', false, NULL, 'a3b4c5d6-e7f8-4a9b-0c1d-2e3f4a5b6c7d'),
('f4a5b6c7-d8e9-4f0a-1b2c-3d4e5f6a7b8c', 'humidity_high', 'High humidity detected', 'medium', '2025-10-04 15:00:00+00', true, '2025-10-04 16:00:00+00', 'b4c5d6e7-f8a9-4b0c-1d2e-3f4a5b6c7d8e'),
('a5b6c7d8-e9f0-4a1b-2c3d-4e5f6a7b8c9d', 'temperature_low', 'Low temperature detected', 'high', '2025-10-03 16:00:00+00', false, NULL, 'c5d6e7f8-a9b0-4c1d-2e3f-4a5b6c7d8e9f'),
('b6c7d8e9-f0a1-4b2c-3d4e-5f6a7b8c9d0e', 'motion', 'Motion detected', 'medium', '2025-10-04 17:00:00+00', true, '2025-10-04 18:00:00+00', 'd6e7f8a9-b0c1-4d2e-3f4a-5b6c7d8e9f0a'),
('c7d8e9f0-a1b2-4c3d-4e5f-6a7b8c9d0e1f', 'energy_anomaly', 'Energy usage anomaly', 'low', '2025-10-03 18:00:00+00', false, NULL, 'e7f8a9b0-c1d2-4e3f-4a5b-6c7d8e9f0a1b'),
('d8e9f0a1-b2c3-4d4e-5f6a-7b8c9d0e1f2a', 'humidity_low', 'Low humidity detected', 'medium', '2025-10-04 19:00:00+00', true, '2025-10-04 20:00:00+00', 'f8a9b0c1-d2e3-4f4a-5b6c-7d8e9f0a1b2c'),
('e9f0a1b2-c3d4-4e5f-6a7b-8c9d0e1f2a3b', 'temperature_high', 'High temperature detected', 'high', '2025-10-03 20:00:00+00', false, NULL, 'a9b0c1d2-e3f4-4a5b-6c7d-8e9f0a1b2c3d'),
('f0a1b2c3-d4e5-4f6a-7b8c-9d0e1f2a3b4c', 'motion', 'Motion detected', 'medium', '2025-10-04 21:00:00+00', true, '2025-10-04 22:00:00+00', 'b0c1d2e3-f4a5-4b6c-7d8e-9f0a1b2c3d4e');

-- Insert into core_predictivealert (references core_component, 10 alerts)
INSERT INTO public.core_predictivealert (id, prediction, confidence, triggered_at, resolved, resolved_at, component_id) VALUES
('a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 'Potential failure in sensor', 0.85, '2025-10-03 12:00:00+00', false, NULL, 'c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f'),
('b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e', 'Overheating risk', 0.90, '2025-10-04 13:00:00+00', true, '2025-10-04 14:00:00+00', 'd2e3f4a5-b6c7-4d8e-9f0a-1b2c3d4e5f6a'),
('c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', 'Low battery prediction', 0.75, '2025-10-03 14:00:00+00', false, NULL, 'e3f4a5b6-c7d8-4e9f-0a1b-2c3d4e5f6a7b'),
('d4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a', 'Connection loss risk', 0.80, '2025-10-04 15:00:00+00', true, '2025-10-04 16:00:00+00', 'f4a5b6c7-d8e9-4f0a-1b2c-3d4e5f6a7b8c'),
('e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b', 'Sensor degradation', 0.88, '2025-10-03 16:00:00+00', false, NULL, 'a5b6c7d8-e9f0-4a1b-2c3d-4e5f6a7b8c9d'),
('f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8a9b0c', 'High usage alert', 0.92, '2025-10-04 17:00:00+00', true, '2025-10-04 18:00:00+00', 'b6c7d8e9-f0a1-4b2c-3d4e-5f6a7b8c9d0e'),
('a7b8c9d0-e1f2-4a3b-4c5d-6e7f8a9b0c1d', 'Potential failure', 0.82, '2025-10-03 18:00:00+00', false, NULL, 'c7d8e9f0-a1b2-4c3d-4e5f-6a7b8c9d0e1f'),
('b8c9d0e1-f2a3-4b4c-5d6e-7f8a9b0c1d2e', 'Overheating risk', 0.87, '2025-10-04 19:00:00+00', true, '2025-10-04 20:00:00+00', 'd8e9f0a1-b2c3-4d4e-5f6a-7b8c9d0e1f2a'),
('c9d0e1f2-a3b4-4c5d-6e7f-8a9b0c1d2e3f', 'Low battery prediction', 0.78, '2025-10-03 20:00:00+00', false, NULL, 'e9f0a1b2-c3d4-4e5f-6a7b-8c9d0e1f2a3b'),
('d0e1f2a3-b4c5-4d6e-7f8a-9b0c1d2e3f4a', 'Connection loss risk', 0.83, '2025-10-04 21:00:00+00', true, '2025-10-04 22:00:00+00', 'f0a1b2c3-d4e5-4f6a-7b8c-9d0e1f2a3b4c');

-- Insert into core_energysummary (references core_component and core_room, 10 summaries)
INSERT INTO public.core_energysummary (id, period_start, period_end, period_type, total_energy, avg_power, peak_power, reading_count, anomaly_count, created_at, component_id, room_id, currency, total_cost) VALUES
('1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d', '2025-10-03 00:00:00+00', '2025-10-03 23:59:59+00', 'daily', 100.5, 50.0, 150.0, 24, 1, '2025-10-04 00:00:00+00', 'c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f', 'f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8a9b0c', 'PHP', 582.90),
('2b3c4d5e-6f7a-8b9c-0d1e-2f3a4b5c6d7e', '2025-10-04 00:00:00+00', '2025-10-04 23:59:59+00', 'daily', 80.0, 40.0, 120.0, 24, 0, '2025-10-05 00:00:00+00', 'd2e3f4a5-b6c7-4d8e-9f0a-1b2c3d4e5f6a', 'a7b8c9d0-e1f2-4a3b-4c5d-6e7f8a9b0c1d', 'PHP', 464.00),
('3c4d5e6f-7a8b-9c0d-1e2f-3a4b5c6d7e8f', '2025-10-03 00:00:00+00', '2025-10-03 23:59:59+00', 'daily', 110.0, 55.0, 160.0, 24, 2, '2025-10-04 01:00:00+00', 'e3f4a5b6-c7d8-4e9f-0a1b-2c3d4e5f6a7b', 'b8c9d0e1-f2a3-4b4c-5d6e-7f8a9b0c1d2e', 'PHP', 638.00),
('4d5e6f7a-8b9c-0d1e-2f3a-4b5c6d7e8f9a', '2025-10-04 00:00:00+00', '2025-10-04 23:59:59+00', 'daily', 90.0, 45.0, 130.0, 24, 1, '2025-10-05 01:00:00+00', 'f4a5b6c7-d8e9-4f0a-1b2c-3d4e5f6a7b8c', 'c9d0e1f2-a3b4-4c5d-6e7f-8a9b0c1d2e3f', 'PHP', 522.00),
('5e6f7a8b-9c0d-1e2f-3a4b-5c6d7e8f9a0b', '2025-10-03 00:00:00+00', '2025-10-03 23:59:59+00', 'daily', 105.0, 52.5, 155.0, 24, 0, '2025-10-04 02:00:00+00', 'a5b6c7d8-e9f0-4a1b-2c3d-4e5f6a7b8c9d', 'd0e1f2a3-b4c5-4d6e-7f8a-9b0c1d2e3f4a', 'PHP', 609.00),
('6f7a8b9c-0d1e-2f3a-4b5c-6d7e8f9a0b1c', '2025-10-04 00:00:00+00', '2025-10-04 23:59:59+00', 'daily', 85.0, 42.5, 125.0, 24, 3, '2025-10-05 02:00:00+00', 'b6c7d8e9-f0a1-4b2c-3d4e-5f6a7b8c9d0e', 'f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8a9b0c', 'PHP', 493.00),
('7a8b9c0d-1e2f-3a4b-5c6d-7e8f9a0b1c2d', '2025-10-03 00:00:00+00', '2025-10-03 23:59:59+00', 'daily', 115.0, 57.5, 165.0, 24, 1, '2025-10-04 03:00:00+00', 'c7d8e9f0-a1b2-4c3d-4e5f-6a7b8c9d0e1f', 'a7b8c9d0-e1f2-4a3b-4c5d-6e7f8a9b0c1d', 'PHP', 667.00),
('8b9c0d1e-2f3a-4b5c-6d7e-8f9a0b1c2d3e', '2025-10-04 00:00:00+00', '2025-10-04 23:59:59+00', 'daily', 75.0, 37.5, 115.0, 24, 0, '2025-10-05 03:00:00+00', 'd8e9f0a1-b2c3-4d4e-5f6a-7b8c9d0e1f2a', 'b8c9d0e1-f2a3-4b4c-5d6e-7f8a9b0c1d2e', 'PHP', 435.00),
('9c0d1e2f-3a4b-5c6d-7e8f-9a0b1c2d3e4f', '2025-10-03 00:00:00+00', '2025-10-03 23:59:59+00', 'daily', 120.0, 60.0, 170.0, 24, 2, '2025-10-04 04:00:00+00', 'e9f0a1b2-c3d4-4e5f-6a7b-8c9d0e1f2a3b', 'c9d0e1f2-a3b4-4c5d-6e7f-8a9b0c1d2e3f', 'PHP', 696.00),
('0d1e2f3a-4b5c-6d7e-8f9a-0b1c2d3e4f5a', '2025-10-04 00:00:00+00', '2025-10-04 23:59:59+00', 'daily', 70.0, 35.0, 110.0, 24, 1, '2025-10-05 04:00:00+00', 'f0a1b2c3-d4e5-4f6a-7b8c-9d0e1f2a3b4c', 'd0e1f2a3-b4c5-4d6e-7f8a-9b0c1d2e3f4a', 'PHP', 406.00);

-- Insert into core_billingrate (references core_room, 5 rates)
INSERT INTO public.core_billingrate (id, rate_per_kwh, created_at, room_id, currency, end_time, start_time, valid_from, valid_to) VALUES
('c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f', 0.15, '2025-10-01 09:00:00+00', 'f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8a9b0c', 'USD', '18:00:00', '09:00:00', '2025-10-01 00:00:00+00', '2025-12-31 23:59:59+00'),
('d2e3f4a5-b6c7-4d8e-9f0a-1b2c3d4e5f6a', 0.20, '2025-10-02 10:00:00+00', 'a7b8c9d0-e1f2-4a3b-4c5d-6e7f8a9b0c1d', 'USD', '20:00:00', '08:00:00', '2025-10-01 00:00:00+00', '2025-12-31 23:59:59+00'),
('e3f4a5b6-c7d8-4e9f-0a1b-2c3d4e5f6a7b', 0.18, '2025-10-03 11:00:00+00', 'b8c9d0e1-f2a3-4b4c-5d6e-7f8a9b0c1d2e', 'USD', '19:00:00', '10:00:00', '2025-10-01 00:00:00+00', '2025-12-31 23:59:59+00'),
('f4a5b6c7-d8e9-4f0a-1b2c-3d4e5f6a7b8c', 0.12, '2025-10-04 12:00:00+00', 'c9d0e1f2-a3b4-4c5d-6e7f-8a9b0c1d2e3f', 'USD', '17:00:00', '09:00:00', '2025-10-01 00:00:00+00', '2025-12-31 23:59:59+00'),
('a5b6c7d8-e9f0-4a1b-2c3d-4e5f6a7b8c9d', 0.22, '2025-10-01 13:00:00+00', 'd0e1f2a3-b4c5-4d6e-7f8a-9b0c1d2e3f4a', 'USD', '21:00:00', '07:00:00', '2025-10-01 00:00:00+00', '2025-12-31 23:59:59+00');

-- Insert into core_maintenancerequest (references core_equipment, core_user, 10 requests)
INSERT INTO public.core_maintenancerequest (id, issue, status, scheduled_date, resolved_at, created_at, equipment_id, user_id, assigned_to_id, comments) VALUES
('b6c7d8e9-f0a1-4b2c-3d4e-5f6a7b8c9d0e', 'Sensor malfunction', 'pending', '2025-10-05', NULL, '2025-10-03 12:00:00+00', 'e1f2a3b4-c5d6-4e7f-8a9b-0c1d2e3f4a5b', 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', 'Check wiring'),
('c7d8e9f0-a1b2-4c3d-4e5f-6a7b8c9d0e1f', 'High energy usage', 'resolved', '2025-10-04', '2025-10-04 14:00:00+00', '2025-10-04 13:00:00+00', 'f2a3b4c5-d6e7-4f8a-9b0c-1d2e3f4a5b6c', 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e', 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', 'Fixed issue'),
('d8e9f0a1-b2c3-4d4e-5f6a-7b8c9d0e1f2a', 'Temperature sensor error', 'pending', '2025-10-06', NULL, '2025-10-03 14:00:00+00', 'a3b4c5d6-e7f8-4a9b-0c1d-2e3f4a5b6c7d', 'd4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a', 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', 'Replace sensor'),
('e9f0a1b2-c3d4-4e5f-6a7b-8c9d0e1f2a3b', 'Humidity calibration needed', 'resolved', '2025-10-05', '2025-10-05 16:00:00+00', '2025-10-04 15:00:00+00', 'b4c5d6e7-f8a9-4b0c-1d2e-3f4a5b6c7d8e', 'e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b', 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', 'Calibrated'),
('f0a1b2c3-d4e5-4f6a-7b8c-9d0e1f2a3b4c', 'Motion detector fault', 'pending', '2025-10-07', NULL, '2025-10-03 16:00:00+00', 'c5d6e7f8-a9b0-4c1d-2e3f-4a5b6c7d8e9f', 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', 'Inspect hardware'),
('a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 'Power supply issue', 'resolved', '2025-10-06', '2025-10-06 18:00:00+00', '2025-10-04 17:00:00+00', 'd6e7f8a9-b0c1-4d2e-3f4a-5b6c7d8e9f0a', 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e', 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', 'Replaced supply'),
('b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e', 'Sensor malfunction', 'pending', '2025-10-08', NULL, '2025-10-03 18:00:00+00', 'e7f8a9b0-c1d2-4e3f-4a5b-6c7d8e9f0a1b', 'd4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a', 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', 'Check connections'),
('c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', 'High energy usage', 'resolved', '2025-10-07', '2025-10-07 20:00:00+00', '2025-10-04 19:00:00+00', 'f8a9b0c1-d2e3-4f4a-5b6c-7d8e9f0a1b2c', 'e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b', 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', 'Optimized settings'),
('d4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a', 'Temperature sensor error', 'pending', '2025-10-09', NULL, '2025-10-03 20:00:00+00', 'a9b0c1d2-e3f4-4a5b-6c7d-8e9f0a1b2c3d', 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', 'Replace unit'),
('e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b', 'Humidity calibration needed', 'resolved', '2025-10-08', '2025-10-08 22:00:00+00', '2025-10-04 21:00:00+00', 'b0c1d2e3-f4a5-4b6c-7d8e-9f0a1b2c3d4e', 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e', 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', 'Recalibrated');

-- Insert into core_maintenanceattachment (references core_maintenancerequest, core_user, 10 attachments)
INSERT INTO public.core_maintenanceattachment (id, file, file_name, file_type, uploaded_at, maintenance_request_id, uploaded_by_id) VALUES
('f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8a9b0c', '/path/to/file1.jpg', 'photo1.jpg', 'image/jpeg', '2025-10-03 12:00:00+00', 'b6c7d8e9-f0a1-4b2c-3d4e-5f6a7b8c9d0e', 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'),
('a7b8c9d0-e1f2-4a3b-4c5d-6e7f8a9b0c1d', '/path/to/file2.pdf', 'report1.pdf', 'application/pdf', '2025-10-04 13:00:00+00', 'c7d8e9f0-a1b2-4c3d-4e5f-6a7b8c9d0e1f', 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e'),
('b8c9d0e1-f2a3-4b4c-5d6e-7f8a9b0c1d2e', '/path/to/file3.jpg', 'photo2.jpg', 'image/jpeg', '2025-10-03 14:00:00+00', 'd8e9f0a1-b2c3-4d4e-5f6a-7b8c9d0e1f2a', 'd4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a'),
('c9d0e1f2-a3b4-4c5d-6e7f-8a9b0c1d2e3f', '/path/to/file4.pdf', 'report2.pdf', 'application/pdf', '2025-10-04 15:00:00+00', 'e9f0a1b2-c3d4-4e5f-6a7b-8c9d0e1f2a3b', 'e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b'),
('d0e1f2a3-b4c5-4d6e-7f8a-9b0c1d2e3f4a', '/path/to/file5.jpg', 'photo3.jpg', 'image/jpeg', '2025-10-03 16:00:00+00', 'f0a1b2c3-d4e5-4f6a-7b8c-9d0e1f2a3b4c', 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'),
('e1f2a3b4-c5d6-4e7f-8a9b-0c1d2e3f4a5b', '/path/to/file6.pdf', 'report3.pdf', 'application/pdf', '2025-10-04 17:00:00+00', 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e'),
('f2a3b4c5-d6e7-4f8a-9b0c-1d2e3f4a5b6c', '/path/to/file7.jpg', 'photo4.jpg', 'image/jpeg', '2025-10-03 18:00:00+00', 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e', 'd4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a'),
('a3b4c5d6-e7f8-4a9b-0c1d-2e3f4a5b6c7d', '/path/to/file8.pdf', 'report4.pdf', 'application/pdf', '2025-10-04 19:00:00+00', 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', 'e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b'),
('b4c5d6e7-f8a9-4b0c-1d2e-3f4a5b6c7d8e', '/path/to/file9.jpg', 'photo5.jpg', 'image/jpeg', '2025-10-03 20:00:00+00', 'd4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a', 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'),
('c5d6e7f8-a9b0-4c1d-2e3f-4a5b6c7d8e9f', '/path/to/file10.pdf', 'report5.pdf', 'application/pdf', '2025-10-04 21:00:00+00', 'e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b', 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e');

-- Insert into core_notification (references core_user, 10 notifications)
INSERT INTO public.core_notification (id, title, message, read, created_at, user_id) VALUES
('d6e7f8a9-b0c1-4d2e-3f4a-5b6c7d8e9f0a', 'Alert: High Temp', 'High temperature in Room A', false, '2025-10-03 12:00:00+00', 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'),
('e7f8a9b0-c1d2-4e3f-4a5b-6c7d8e9f0a1b', 'Maintenance Scheduled', 'Maintenance for Device 2', true, '2025-10-04 13:00:00+00', 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e'),
('f8a9b0c1-d2e3-4f4a-5b6c-7d8e9f0a1b2c', 'Alert: Energy Anomaly', 'Energy anomaly in Lab C', false, '2025-10-03 14:00:00+00', 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f'),
('a9b0c1d2-e3f4-4a5b-6c7d-8e9f0a1b2c3d', 'System Update', 'System update available', true, '2025-10-04 15:00:00+00', 'd4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a'),
('b0c1d2e3-f4a5-4b6c-7d8e-9f0a1b2c3d4e', 'Alert: Low Humidity', 'Low humidity in Break Room', false, '2025-10-03 16:00:00+00', 'e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b'),
('c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f', 'Maintenance Complete', 'Maintenance for Device 5 complete', true, '2025-10-04 17:00:00+00', 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'),
('d2e3f4a5-b6c7-4d8e-9f0a-1b2c3d4e5f6a', 'Alert: Motion Detected', 'Motion detected in Office B', false, '2025-10-03 18:00:00+00', 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e'),
('e3f4a5b6-c7d8-4e9f-0a1b-2c3d4e5f6a7b', 'New User Registered', 'New user registered', true, '2025-10-04 19:00:00+00', 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f'),
('f4a5b6c7-d8e9-4f0a-1b2c-3d4e5f6a7b8c', 'Alert: High Energy', 'High energy usage in Conference E', false, '2025-10-03 20:00:00+00', 'd4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a'),
('a5b6c7d8-e9f0-4a1b-2c3d-4e5f6a7b8c9d', 'System Downtime Scheduled', 'System downtime on Oct 10', true, '2025-10-04 21:00:00+00', 'e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b');

-- Insert into core_llmquery (references core_user, 10 queries)
INSERT INTO public.core_llmquery (id, query, response, created_at, user_id) VALUES
('b6c7d8e9-f0a1-4b2c-3d4e-5f6a7b8c9d0e', 'What is the energy usage?', 'Total energy: 100kWh', '2025-10-03 12:00:00+00', 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'),
('c7d8e9f0-a1b2-4c3d-4e5f-6a7b8c9d0e1f', 'Predict failure', 'High risk', '2025-10-04 13:00:00+00', 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e'),
('d8e9f0a1-b2c3-4d4e-5f6a-7b8c9d0e1f2a', 'Room occupancy pattern?', 'Weekdays 9-5', '2025-10-03 14:00:00+00', 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f'),
('e9f0a1b2-c3d4-4e5f-6a7b-8c9d0e1f2a3b', 'Anomaly count?', '2 anomalies', '2025-10-04 15:00:00+00', 'd4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a'),
('f0a1b2c3-d4e5-4f6a-7b8c-9d0e1f2a3b4c', 'What is the total cost?', '10.05 USD', '2025-10-03 16:00:00+00', 'e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b'),
('a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 'Predict overheating', 'Medium risk', '2025-10-04 17:00:00+00', 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'),
('b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e', 'Energy summary for room B', '80kWh', '2025-10-03 18:00:00+00', 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e'),
('c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', 'Failure prediction for component 3', 'Low risk', '2025-10-04 19:00:00+00', 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f'),
('d4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a', 'What is the peak power?', '170W', '2025-10-03 20:00:00+00', 'd4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a'),
('e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b', 'Room capacity query', '25 people', '2025-10-04 21:00:00+00', 'e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b');

-- Insert into core_llmsummary (5 summaries)
INSERT INTO public.core_llmsummary (id, generated_for, summary, created_at) VALUES
('f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8a9b0c', '2025-10-03', 'Daily summary: Normal operations', '2025-10-04 00:00:00+00'),
('a7b8c9d0-e1f2-4a3b-4c5d-6e7f8a9b0c1d', '2025-10-04', 'Daily summary: One alert resolved', '2025-10-05 00:00:00+00'),
('b8c9d0e1-f2a3-4b4c-5d6e-7f8a9b0c1d2e', '2025-10-03', 'Daily summary: Two anomalies detected', '2025-10-04 01:00:00+00'),
('c9d0e1f2-a3b4-4c5d-6e7f-8a9b0c1d2e3f', '2025-10-04', 'Daily summary: Maintenance completed', '2025-10-05 01:00:00+00'),
('d0e1f2a3-b4c5-4d6e-7f8a-9b0c1d2e3f4a', '2025-10-03', 'Daily summary: High energy usage', '2025-10-04 02:00:00+00');

-- Insert into core_authtoken (references core_user, 5 tokens)
INSERT INTO public.core_authtoken (id, token, expires_at, user_id) VALUES
('e1f2a3b4-c5d6-4e7f-8a9b-0c1d2e3f4a5b', 'token123', '2025-10-10 00:00:00+00', 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'),
('f2a3b4c5-d6e7-4f8a-9b0c-1d2e3f4a5b6c', 'token456', '2025-10-11 00:00:00+00', 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e'),
('a3b4c5d6-e7f8-4a9b-0c1d-2e3f4a5b6c7d', 'token789', '2025-10-12 00:00:00+00', 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f'),
('b4c5d6e7-f8a9-4b0c-1d2e-3f4a5b6c7d8e', 'token101', '2025-10-13 00:00:00+00', 'd4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a'),
('c5d6e7f8-a9b0-4c1d-2e3f-4a5b6c7d8e9f', 'token112', '2025-10-14 00:00:00+00', 'e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b');

-- Insert into auth_group (5 groups)
INSERT INTO public.auth_group (id, name) VALUES
(1, 'Admins'),
(2, 'Users'),
(3, 'Maintenance'),
(4, 'Guests'),
(5, 'Superusers');

-- Insert into auth_group_permissions (references auth_group and auth_permission, 10 permissions assignments)
-- Assuming permissions ids 1-84 exist
INSERT INTO public.auth_group_permissions (id, group_id, permission_id) VALUES
(1, 1, 1),
(2, 1, 2),
(3, 2, 21),
(4, 3, 45),
(5, 4, 24),
(6, 5, 1),
(7, 1, 3),
(8, 2, 22),
(9, 3, 46),
(10, 4, 25);

-- Insert into django_migrations (5 migrations)
INSERT INTO public.django_migrations (id, app, name, applied) VALUES
(1, 'core', '0001_initial', '2025-10-01 09:00:00+00'),
(2, 'auth', '0001_initial', '2025-10-01 09:00:00+00'),
(3, 'core', '0002_alter', '2025-10-02 10:00:00+00'),
(4, 'auth', '0002_alter', '2025-10-03 11:00:00+00'),
(5, 'core', '0003_add_fields', '2025-10-04 12:00:00+00');

-- Insert into django_admin_log (references django_content_type and core_user, 10 logs)
-- Assuming content_type_id 7 is for equipment, etc.
INSERT INTO public.django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) VALUES
(1, '2025-10-03 12:00:00+00', 'e1f2a3b4-c5d6-4e7f-8a9b-0c1d2e3f4a5b', 'Sensor Device 1', 1, 'Added', 7, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'),
(2, '2025-10-04 13:00:00+00', 'f2a3b4c5-d6e7-4f8a-9b0c-1d2e3f4a5b6c', 'Sensor Device 2', 2, 'Changed status', 7, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'),
(3, '2025-10-03 14:00:00+00', 'a3b4c5d6-e7f8-4a9b-0c1d-2e3f4a5b6c7d', 'Monitor Device 3', 1, 'Added', 7, 'e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b'),
(4, '2025-10-04 15:00:00+00', 'b4c5d6e7-f8a9-4b0c-1d2e-3f4a5b6c7d8e', 'Sensor Device 4', 3, 'Deleted', 7, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'),
(5, '2025-10-03 16:00:00+00', 'c5d6e7f8-a9b0-4c1d-2e3f-4a5b6c7d8e9f', 'Camera Device 5', 2, 'Updated type', 7, 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e'),
(6, '2025-10-04 17:00:00+00', 'd6e7f8a9-b0c1-4d2e-3f4a-5b6c7d8e9f0a', 'Sensor Device 6', 1, 'Added', 7, 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f'),
(7, '2025-10-03 18:00:00+00', 'e7f8a9b0-c1d2-4e3f-4a5b-6c7d8e9f0a1b', 'Monitor Device 7', 2, 'Changed status', 7, 'd4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a'),
(8, '2025-10-04 19:00:00+00', 'f8a9b0c1-d2e3-4f4a-5b6c-7d8e9f0a1b2c', 'Sensor Device 8', 1, 'Added', 7, 'e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b'),
(9, '2025-10-03 20:00:00+00', 'a9b0c1d2-e3f4-4a5b-6c7d-8e9f0a1b2c3d', 'Camera Device 9', 3, 'Deleted', 7, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'),
(10, '2025-10-04 21:00:00+00', 'b0c1d2e3-f4a5-4b6c-7d8e-9f0a1b2c3d4e', 'Sensor Device 10', 2, 'Updated qr_code', 7, 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e');

-- Insert into django_session (5 sessions)
INSERT INTO public.django_session (session_key, session_data, expire_date) VALUES
('sessionkey1', 'eyJ1c2VyX2lkIjoiYTEifQ==', '2025-10-18 00:00:00+00'),
('sessionkey2', 'eyJ1c2VyX2lkIjoiYjIifQ==', '2025-10-19 00:00:00+00'),
('sessionkey3', 'eyJ1c2VyX2lkIjoiYzMifQ==', '2025-10-20 00:00:00+00'),
('sessionkey4', 'eyJ1c2VyX2lkIjoiZDQifQ==', '2025-10-21 00:00:00+00'),
('sessionkey5', 'eyJ1c2VyX2lkIjoiZTUifQ==', '2025-10-22 00:00:00+00');