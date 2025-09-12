#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <PZEM004Tv30.h>

// WiFi credentials - UPDATE THESE TO YOUR NETWORK
const char* ssid = "SKYWORTH-FA13";
const char* password = "281892655";

// Django API endpoints - UPDATE YOUR_COMPUTER_IP
const char* serverURL = "http://192.168.0.12:8000/api/esp32/sensor-data/";
const char* healthURL = "http://192.168.0.12:8000/api/esp32/health/";
const char* heartbeatURL = "http://192.168.0.12:8000/api/esp32/heartbeat/";

// Device configuration - MUST MATCH Django equipment device_id
const char* deviceID = "ESP32_001";

// DHT22 3-pin module configuration
#define DHT_PIN 5          // Orange wire: DHT22 OUT pin → ESP32 D5 (GPIO 5)
#define DHT_TYPE DHT22     // DHT22 sensor type
#define LED_PIN 2          // Built-in LED pin - CHANGED TO AVOID CONFLICT

// PZEM-004T configuration - UPDATED TO USE MORE RELIABLE PINS
#define PZEM_RX_PIN 4      // ESP32 GPIO4 → PZEM-004T TX
#define PZEM_TX_PIN 15     // ESP32 GPIO15 → PZEM-004T RX

// Initialize sensors
DHT dht(DHT_PIN, DHT_TYPE);
PZEM004Tv30 pzem(Serial2, PZEM_RX_PIN, PZEM_TX_PIN);

// UPDATED WIRE COLOR MAPPING:
// 🟢 GREEN  = PZEM VCC  → ESP32 VIN (5V)
// 🔵 BLUE   = PZEM GND  → ESP32 GND (shared)
// 🟣 PURPLE = PZEM TX   → ESP32 GPIO4
// ⚪ WHITE  = PZEM RX   → ESP32 GPIO15

// Timing variables
unsigned long lastDataSend = 0;
unsigned long lastHealthCheck = 0;
unsigned long lastHeartbeat = 0;
unsigned long lastSensorRead = 0;
unsigned long lastPZEMRead = 0;
const unsigned long SEND_INTERVAL = 15000;      // Send data every 15 seconds
const unsigned long HEALTH_INTERVAL = 60000;    // Health check every 60 seconds
const unsigned long HEARTBEAT_INTERVAL = 30000; // Heartbeat every 30 seconds
const unsigned long SENSOR_READ_INTERVAL = 3000; // Read DHT22 every 3 seconds
const unsigned long PZEM_READ_INTERVAL = 2000;   // Read PZEM every 2 seconds

// DHT22 sensor data variables
float temperature = 0.0;
float humidity = 0.0;
int lightLevel = 0;
bool motionDetected = false;

// PZEM-004T energy data variables
float voltage = 0.0;
float current = 0.0;
float power = 0.0;
float energy = 0.0;
float frequency = 0.0;
float powerFactor = 0.0;

// Sensor status tracking
bool wifiConnected = false;
bool serverConnected = false;
bool dht22Working = false;
bool pzemWorking = false;
int sensorReadAttempts = 0;
int successfulReads = 0;
int pzemReadAttempts = 0;
int pzemSuccessfulReads = 0;

// Data validation - store last valid readings
float lastValidTemp = 22.0;
float lastValidHumidity = 50.0;
float lastValidVoltage = 220.0;
float lastValidCurrent = 0.0;
float lastValidPower = 0.0;

void setup() {
  Serial.begin(115200);
  Serial2.begin(9600, SERIAL_8N1, PZEM_RX_PIN, PZEM_TX_PIN);
  
  Serial.println("=== ESP32 Smart Building with Energy Monitor ===");
  Serial.println("Device ID: " + String(deviceID));
  Serial.println("Version: 3.1.0 - DHT22 + PZEM-004T (GPIO4/15)");
  Serial.println("DHT22: GPIO5 | PZEM-004T: RX=GPIO4, TX=GPIO15");
  Serial.println("===============================================");
  
  // Initialize built-in LED - using different pin to avoid conflict
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  
  // Configure GPIO 5 with internal pull-up resistor for DHT22
  pinMode(DHT_PIN, INPUT_PULLUP);
  Serial.println("🔧 Configured GPIO 5 with internal pull-up resistor for DHT22");
  
  // Initialize DHT22
  Serial.println("🌡️ Initializing DHT22 on GPIO 5...");
  dht.begin();
  delay(3000);
  
  // Initialize PZEM-004T
  Serial.println("⚡ Initializing PZEM-004T energy monitor...");
  Serial.println("📋 UPDATED WIRE COLOR SETUP:");
  Serial.println("   🟢 GREEN wire  = PZEM VCC  → ESP32 VIN (5V)");
  Serial.println("   🔵 BLUE wire   = PZEM GND  → ESP32 GND (SHARED)");
  Serial.println("   🟣 PURPLE wire = PZEM TX   → ESP32 GPIO4");
  Serial.println("   ⚪ WHITE wire  = PZEM RX   → ESP32 GPIO15");
  Serial.println("   DHT22 BROWN wire → Same ESP32 GND (shared ground)");
  Serial.println("   CT Coil terminals → Connect to PZEM CT inputs");
  Serial.println("⚠️  MOVE YOUR WIRES TO GPIO4 and GPIO15!");
  
  // Startup sequence
  startupSequence();
  
  // Connect to WiFi
  connectToWiFi();
  
  // Test server connection
  testServerConnection();
  
  // Test sensors
  testDHT22Module();
  testPZEMModule();
  
  // Send initial heartbeat
  if (wifiConnected && serverConnected) {
    sendHeartbeat();
  }
  
  Serial.println("=== ESP32 Ready for Operation ===");
  Serial.println("📊 Reading sensors every few seconds");
  Serial.println("📤 Sending data every " + String(SEND_INTERVAL/1000) + " seconds");
  Serial.println("⚡ Energy monitoring with PZEM-004T on GPIO4/15!");
  Serial.println("===============================================");
}

void loop() {
  unsigned long currentTime = millis();
  
  // Check WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    wifiConnected = false;
    Serial.println("⚠️ WiFi disconnected, attempting to reconnect...");
    connectToWiFi();
  } else {
    wifiConnected = true;
  }
  
  // Read DHT22 sensor
  if (currentTime - lastSensorRead >= SENSOR_READ_INTERVAL) {
    readDHT22Module();
    lastSensorRead = currentTime;
  }
  
  // Read PZEM-004T energy monitor
  if (currentTime - lastPZEMRead >= PZEM_READ_INTERVAL) {
    readPZEMModule();
    lastPZEMRead = currentTime;
  }
  
  // Send sensor data
  if (currentTime - lastDataSend >= SEND_INTERVAL && wifiConnected) {
    prepareSensorData();
    sendSensorData();
    lastDataSend = currentTime;
  }
  
  // Health check
  if (currentTime - lastHealthCheck >= HEALTH_INTERVAL && wifiConnected) {
    testServerConnection();
    lastHealthCheck = currentTime;
  }
  
  // Send heartbeat
  if (currentTime - lastHeartbeat >= HEARTBEAT_INTERVAL && wifiConnected) {
    sendHeartbeat();
    lastHeartbeat = currentTime;
  }
  
  // Update LED status indicator
  updateLEDStatus();
  
  delay(500);
}

void startupSequence() {
  Serial.println("🚀 Running startup sequence...");
  
  // LED startup pattern - 5 blinks
  for (int i = 0; i < 5; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(200);
    digitalWrite(LED_PIN, LOW);
    delay(200);
  }
  
  Serial.println("✅ Startup sequence complete");
}

void connectToWiFi() {
  Serial.print("🔗 Connecting to WiFi: ");
  Serial.println(ssid);
  
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
    digitalWrite(LED_PIN, attempts % 2);
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    wifiConnected = true;
    Serial.println();
    Serial.println("✅ WiFi connected successfully!");
    Serial.print("📡 IP address: ");
    Serial.println(WiFi.localIP());
    Serial.print("📶 Signal strength: ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
    
    for (int i = 0; i < 10; i++) {
      digitalWrite(LED_PIN, HIGH);
      delay(50);
      digitalWrite(LED_PIN, LOW);
      delay(50);
    }
  } else {
    wifiConnected = false;
    Serial.println();
    Serial.println("❌ WiFi connection failed!");
    digitalWrite(LED_PIN, HIGH);
  }
}

void testServerConnection() {
  if (!wifiConnected) return;
  
  Serial.println("🔍 Testing server connection...");
  
  HTTPClient http;
  http.begin(healthURL);
  http.setTimeout(10000);
  
  int httpResponseCode = http.GET();
  
  if (httpResponseCode == 200) {
    String response = http.getString();
    serverConnected = true;
    Serial.println("✅ Server connection OK");
  } else {
    serverConnected = false;
    Serial.println("❌ Server connection failed: " + String(httpResponseCode));
  }
  
  http.end();
}

void testDHT22Module() {
  Serial.println("🌡️ Testing DHT22 module...");
  delay(5000);
  
  for (int attempt = 1; attempt <= 3; attempt++) {
    float testTemp = dht.readTemperature();
    float testHumidity = dht.readHumidity();
    
    if (!isnan(testTemp) && !isnan(testHumidity)) {
      if (testTemp >= -40 && testTemp <= 80 && testHumidity >= 0 && testHumidity <= 100) {
        dht22Working = true;
        Serial.println("✅ DHT22 working: " + String(testTemp, 1) + "°C, " + String(testHumidity, 1) + "%");
        lastValidTemp = testTemp;
        lastValidHumidity = testHumidity;
        return;
      }
    }
    delay(3000);
  }
  
  dht22Working = false;
  Serial.println("❌ DHT22 test failed - check wiring!");
}

void testPZEMModule() {
  Serial.println("⚡ Testing PZEM-004T energy monitor on GPIO4/15...");
  Serial.println("🔧 IMPORTANT: Move your wires to new pins!");
  Serial.println("   🟣 PURPLE wire → GPIO4 (find pin labeled '4' or 'D4')");
  Serial.println("   ⚪ WHITE wire  → GPIO15 (find pin labeled '15' or 'D15')");
  
  delay(5000);
  
  for (int attempt = 1; attempt <= 5; attempt++) {
    Serial.println("🔍 PZEM test attempt " + String(attempt) + "/5 on GPIO4/15...");
    
    float testVoltage = pzem.voltage();
    delay(100);
    float testCurrent = pzem.current();
    delay(100);
    float testPower = pzem.power();
    
    Serial.println("📊 Raw PZEM readings:");
    Serial.println("   Voltage: " + String(testVoltage, 2) + "V");
    Serial.println("   Current: " + String(testCurrent, 3) + "A");
    Serial.println("   Power: " + String(testPower, 2) + "W");
    
    // Check if we got valid readings (even 0.00 is good without CT coil)
    if (!isnan(testVoltage)) {
      pzemWorking = true;
      Serial.println("✅ PZEM-004T communication working on GPIO4/15!");
      Serial.println("⚡ Voltage reading: " + String(testVoltage, 2) + "V");
      
      if (!isnan(testCurrent)) {
        Serial.println("⚡ Current: " + String(testCurrent, 3) + "A");
      }
      if (!isnan(testPower)) {
        Serial.println("⚡ Power: " + String(testPower, 2) + "W");
      }
      
      lastValidVoltage = testVoltage;
      lastValidCurrent = !isnan(testCurrent) ? testCurrent : 0.0;
      lastValidPower = !isnan(testPower) ? testPower : 0.0;
      return;
    } else {
      Serial.println("⚠️ Attempt " + String(attempt) + " - Still getting NaN readings");
      Serial.println("   Make sure wires are on GPIO4 and GPIO15!");
    }
    
    delay(3000);
  }
  
  pzemWorking = false;
  Serial.println("❌ PZEM-004T still not working!");
  Serial.println("🔧 Double-check wire connections to GPIO4 and GPIO15");
  Serial.println("💡 Or try a different PZEM module if available");
}

void readDHT22Module() {
  sensorReadAttempts++;
  
  float newTemp = dht.readTemperature();
  float newHumidity = dht.readHumidity();
  
  if (!isnan(newTemp) && !isnan(newHumidity)) {
    if (newTemp >= -40 && newTemp <= 80 && newHumidity >= 0 && newHumidity <= 100) {
      temperature = newTemp;
      humidity = newHumidity;
      lastValidTemp = newTemp;
      lastValidHumidity = newHumidity;
      dht22Working = true;
      successfulReads++;
    } else {
      temperature = lastValidTemp;
      humidity = lastValidHumidity;
    }
  } else {
    dht22Working = false;
    temperature = lastValidTemp;
    humidity = lastValidHumidity;
  }
}

void readPZEMModule() {
  pzemReadAttempts++;
  
  // Read PZEM values with delays between readings
  float newVoltage = pzem.voltage();
  delay(50);
  float newCurrent = pzem.current();
  delay(50);
  float newPower = pzem.power();
  delay(50);
  float newEnergy = pzem.energy();
  delay(50);
  float newFrequency = pzem.frequency();
  delay(50);
  float newPF = pzem.pf();
  
  // Debug output every 10 attempts
  if (pzemReadAttempts % 10 == 0) {
    Serial.println("🔍 PZEM Debug (GPIO4/15) - V:" + String(newVoltage, 1) + 
                   " I:" + String(newCurrent, 3) + 
                   " P:" + String(newPower, 1) + "W");
  }
  
  // Accept any non-NaN voltage reading (even 0.00 is valid without CT coil)
  if (!isnan(newVoltage)) {
    voltage = newVoltage;
    lastValidVoltage = newVoltage;
    pzemWorking = true;
    pzemSuccessfulReads++;
    
    // Update other values if valid
    current = (!isnan(newCurrent)) ? newCurrent : 0.0;
    power = (!isnan(newPower)) ? newPower : 0.0;
    energy = (!isnan(newEnergy) && newEnergy >= 0) ? newEnergy : energy;
    frequency = (!isnan(newFrequency) && newFrequency > 40 && newFrequency < 70) ? newFrequency : 50.0;
    powerFactor = (!isnan(newPF) && newPF >= 0 && newPF <= 1) ? newPF : 1.0;
    
    lastValidCurrent = current;
    lastValidPower = power;
    
    // Success message every 20 reads
    if (pzemSuccessfulReads % 20 == 0) {
      Serial.println("⚡ PZEM readings (GPIO4/15): " + String(voltage, 1) + "V, " + 
                     String(current, 3) + "A, " + String(power, 1) + "W");
    }
  } else {
    pzemWorking = false;
    voltage = lastValidVoltage;
    current = lastValidCurrent;
    power = lastValidPower;
    
    // Error message every 10 attempts
    if (pzemReadAttempts % 10 == 0) {
      Serial.println("❌ PZEM read failed on GPIO4/15, check wire connections");
    }
  }
}

void prepareSensorData() {
  // Simulate additional sensors
  lightLevel = 300 + random(0, 700);
  motionDetected = random(0, 10) > 7;
  
  Serial.println("=== Preparing Complete Sensor Data ===");
  Serial.println("🌡️ Temperature: " + String(temperature, 1) + "°C " + (dht22Working ? "(REAL)" : "(LAST)"));
  Serial.println("💧 Humidity: " + String(humidity, 1) + "% " + (dht22Working ? "(REAL)" : "(LAST)"));
  Serial.println("💡 Light Level: " + String(lightLevel) + " (simulated)");
  Serial.println("🚶 Motion: " + String(motionDetected ? "Yes" : "No") + " (simulated)");
  Serial.println("=== ENERGY MONITOR DATA (GPIO4/15) ===");
  Serial.println("⚡ Voltage: " + String(voltage, 1) + "V " + (pzemWorking ? "(REAL)" : "(LAST)"));
  Serial.println("⚡ Current: " + String(current, 3) + "A " + (pzemWorking ? "(REAL)" : "(LAST)"));
  Serial.println("⚡ Power: " + String(power, 1) + "W " + (pzemWorking ? "(REAL)" : "(LAST)"));
  Serial.println("⚡ Energy: " + String(energy, 2) + "kWh");
  Serial.println("⚡ Frequency: " + String(frequency, 1) + "Hz");
  Serial.println("⚡ Power Factor: " + String(powerFactor, 2));
  Serial.println("📊 DHT22 Success: " + String((float)successfulReads/sensorReadAttempts*100, 1) + "%");
  Serial.println("📊 PZEM Success: " + String((float)pzemSuccessfulReads/pzemReadAttempts*100, 1) + "%");
  Serial.println();
}

void sendSensorData() {
  if (!wifiConnected) {
    Serial.println("❌ Cannot send data - WiFi not connected");
    return;
  }
  
  HTTPClient http;
  http.begin(serverURL);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(15000);
  
  // Create comprehensive JSON payload
  StaticJsonDocument<800> doc;
  doc["device_id"] = deviceID;
  
  // Environmental data
  doc["temperature"] = round(temperature * 10) / 10.0;
  doc["humidity"] = round(humidity * 10) / 10.0;
  doc["light_level"] = lightLevel;
  doc["motion_detected"] = motionDetected;
  
  // Energy monitoring data
  doc["voltage"] = round(voltage * 10) / 10.0;
  doc["current"] = round(current * 1000) / 1000.0;
  doc["power"] = round(power * 10) / 10.0;
  doc["energy"] = round(energy * 100) / 100.0;
  doc["frequency"] = round(frequency * 10) / 10.0;
  doc["power_factor"] = round(powerFactor * 100) / 100.0;
  
  // Status indicators
  doc["dht22_working"] = dht22Working;
  doc["pzem_working"] = pzemWorking;
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  Serial.println("📤 Sending Complete Sensor + Energy Data");
  Serial.println("🌐 URL: " + String(serverURL));
  Serial.println("📋 JSON: " + jsonString);
  
  int httpResponseCode = http.POST(jsonString);
  
  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.println("📊 HTTP Response: " + String(httpResponseCode));
    
    if (httpResponseCode == 201) {
      serverConnected = true;
      Serial.println("✅ SUCCESS - Complete data sent!");
      Serial.println("📱 App shows: Environment + Energy data from GPIO4/15!");
      
      // Success pattern
      for (int i = 0; i < 3; i++) {
        digitalWrite(LED_PIN, HIGH);
        delay(100);
        digitalWrite(LED_PIN, LOW);
        delay(100);
      }
    } else {
      serverConnected = false;
      Serial.println("❌ Server error: " + String(httpResponseCode));
    }
  } else {
    serverConnected = false;
    Serial.println("❌ HTTP Error: " + String(httpResponseCode));
  }
  
  http.end();
  Serial.println("===============================================");
}

void sendHeartbeat() {
  if (!wifiConnected) return;
  
  HTTPClient http;
  http.begin(heartbeatURL);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(5000);
  
  StaticJsonDocument<600> doc;
  doc["device_id"] = deviceID;
  doc["timestamp"] = millis();
  doc["dht22_working"] = dht22Working;
  doc["pzem_working"] = pzemWorking;
  doc["dht22_success_rate"] = (float)successfulReads/sensorReadAttempts*100;
  doc["pzem_success_rate"] = (float)pzemSuccessfulReads/pzemReadAttempts*100;
  doc["wifi_signal"] = WiFi.RSSI();
  doc["uptime"] = millis() / 1000;
  doc["sensor_type"] = "DHT22_PZEM004T_GPIO4_15";
  doc["current_temp"] = temperature;
  doc["current_voltage"] = voltage;
  doc["current_power"] = power;
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  int httpResponseCode = http.POST(jsonString);
  
  if (httpResponseCode == 200 || httpResponseCode == 201) {
    Serial.println("💓 Heartbeat with energy data sent");
  } else {
    Serial.println("⚠️ Heartbeat failed: " + String(httpResponseCode));
  }
  
  http.end();
}

void updateLEDStatus() {
  if (wifiConnected && serverConnected && dht22Working && pzemWorking) {
    // All systems working - very slow blink
    digitalWrite(LED_PIN, (millis() / 3000) % 2);
  } else if (wifiConnected && serverConnected && (dht22Working || pzemWorking)) {
    // WiFi, server OK, one sensor working - slow blink
    digitalWrite(LED_PIN, (millis() / 2000) % 2);
  } else if (wifiConnected && serverConnected) {
    // WiFi and server OK, sensors issues - medium blink
    digitalWrite(LED_PIN, (millis() / 1000) % 2);
  } else if (wifiConnected) {
    // WiFi OK, server issues - fast blink
    digitalWrite(LED_PIN, (millis() / 500) % 2);
  } else {
    // WiFi issues - solid on
    digitalWrite(LED_PIN, HIGH);
  }
}