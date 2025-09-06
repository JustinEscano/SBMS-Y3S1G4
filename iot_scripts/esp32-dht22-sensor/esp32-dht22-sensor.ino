#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <DHT.h>

// WiFi credentials - UPDATE THESE TO YOUR NETWORK
const char* ssid = "Ace's A55";
const char* password = "123456789";

// Django API endpoints - UPDATE YOUR_COMPUTER_IP
const char* serverURL = "http://10.147.134.29:8000/api/esp32/sensor-data/";
const char* healthURL = "http://10.147.134.29:8000/api/esp32/health/";
const char* heartbeatURL = "http://10.147.134.29:8000/api/esp32/heartbeat/";

// Device configuration - MUST MATCH Django equipment device_id
const char* deviceID = "ESP32_001";

// DHT22 3-pin module configuration - CORRECTED TO GPIO 5
#define DHT_PIN 5          // Orange wire: DHT22 OUT pin → ESP32 D5 (GPIO 5)
#define DHT_TYPE DHT22     // DHT22 sensor type
#define LED_PIN 2          // Built-in LED pin

// Initialize DHT sensor
DHT dht(DHT_PIN, DHT_TYPE);

// Timing variables
unsigned long lastDataSend = 0;
unsigned long lastHealthCheck = 0;
unsigned long lastHeartbeat = 0;
unsigned long lastSensorRead = 0;
const unsigned long SEND_INTERVAL = 15000;      // Send data every 15 seconds
const unsigned long HEALTH_INTERVAL = 60000;    // Health check every 60 seconds
const unsigned long HEARTBEAT_INTERVAL = 30000; // Heartbeat every 30 seconds
const unsigned long SENSOR_READ_INTERVAL = 3000; // Read sensor every 3 seconds

// Sensor data variables
float temperature = 0.0;
float humidity = 0.0;
int lightLevel = 0;
bool motionDetected = false;
float energyUsage = 0.0;

// Sensor status tracking
bool wifiConnected = false;
bool serverConnected = false;
bool dht22Working = false;
int sensorReadAttempts = 0;
int successfulReads = 0;

// Data validation - store last valid readings
float lastValidTemp = 22.0;
float lastValidHumidity = 50.0;

void setup() {
  Serial.begin(115200);
  Serial.println("=== ESP32 Smart Building DHT22 Module (GPIO 5) ===");
  Serial.println("Device ID: " + String(deviceID));
  Serial.println("Version: 2.4.0 - GPIO 5 Optimized for DHT22");
  Serial.println("Wire Colors: Red=Power, Brown=Ground, Orange=Data");
  Serial.println("===================================================");
  
  // Initialize built-in LED
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  
  // Configure GPIO 5 with internal pull-up resistor
  pinMode(DHT_PIN, INPUT_PULLUP);
  Serial.println("🔧 Configured GPIO 5 with internal pull-up resistor");
  
  // Initialize DHT22 3-pin module
  Serial.println("🌡️ Initializing DHT22 3-pin module on GPIO 5...");
  Serial.println("📋 Your Wiring Configuration:");
  Serial.println("   Red wire (DHT22 +)     → Red rail (+) → ESP32 3.3V");
  Serial.println("   Orange wire (DHT22 OUT) → ESP32 D5 (GPIO 5)");
  Serial.println("   Brown wire (DHT22 -)    → Blue rail (-) → ESP32 GND");
  
  dht.begin();
  delay(5000); // Give DHT22 extra time to stabilize
  
  // Startup sequence
  startupSequence();
  
  // Connect to WiFi
  connectToWiFi();
  
  // Test server connection
  testServerConnection();
  
  // Test DHT22 3-pin module
  testDHT22Module();
  
  // Send initial heartbeat
  if (wifiConnected && serverConnected) {
    sendHeartbeat();
  }
  
  Serial.println("=== ESP32 Ready for Operation ===");
  Serial.println("📊 Reading DHT22 sensor data every " + String(SENSOR_READ_INTERVAL/1000) + " seconds");
  Serial.println("📤 Sending data to Flutter app every " + String(SEND_INTERVAL/1000) + " seconds");
  Serial.println("📱 Your Flutter app will show live environmental data!");
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
  
  // Read DHT22 sensor every SENSOR_READ_INTERVAL
  if (currentTime - lastSensorRead >= SENSOR_READ_INTERVAL) {
    readDHT22Module();
    lastSensorRead = currentTime;
  }
  
  // Send sensor data every SEND_INTERVAL
  if (currentTime - lastDataSend >= SEND_INTERVAL && wifiConnected) {
    prepareSensorData();
    sendSensorData();
    lastDataSend = currentTime;
  }
  
  // Health check every HEALTH_INTERVAL
  if (currentTime - lastHealthCheck >= HEALTH_INTERVAL && wifiConnected) {
    testServerConnection();
    lastHealthCheck = currentTime;
  }
  
  // Send heartbeat every HEARTBEAT_INTERVAL
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
    
    // Blink LED during connection
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
    
    // Success pattern - fast blinks
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
    Serial.println("🔧 Please check your WiFi credentials");
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
    Serial.println("📄 Response: " + response);
  } else {
    serverConnected = false;
    Serial.println("❌ Server connection failed: " + String(httpResponseCode));
    Serial.println("💡 Make sure Django server is running:");
    Serial.println("   python manage.py runserver 0.0.0.0:8000");
  }
  
  http.end();
}

void testDHT22Module() {
  Serial.println("🌡️ Testing DHT22 3-pin module on GPIO 5...");
  
  // Wait for module to stabilize
  delay(5000);
  
  // Try multiple readings for stability
  for (int attempt = 1; attempt <= 5; attempt++) {
    Serial.println("📊 Test attempt " + String(attempt) + "/5...");
    
    // Force a fresh reading
    delay(2000);
    
    float testTemp = dht.readTemperature();
    float testHumidity = dht.readHumidity();
    
    Serial.println("🔍 Raw readings: Temp=" + String(testTemp) + ", Humidity=" + String(testHumidity));
    
    if (!isnan(testTemp) && !isnan(testHumidity)) {
      // Validate reasonable ranges
      if (testTemp >= -40 && testTemp <= 80 && testHumidity >= 0 && testHumidity <= 100) {
        dht22Working = true;
        Serial.println("✅ DHT22 3-pin module working perfectly on GPIO 5!");
        Serial.println("🌡️ Test temperature: " + String(testTemp, 1) + "°C");
        Serial.println("💧 Test humidity: " + String(testHumidity, 1) + "%");
        Serial.println("🔧 GPIO 5 configuration successful!");
        
        // Store as last valid readings
        lastValidTemp = testTemp;
        lastValidHumidity = testHumidity;
        return; // Success, exit function
      } else {
        Serial.println("⚠️ Readings out of range: " + String(testTemp, 1) + "°C, " + String(testHumidity, 1) + "%");
      }
    } else {
      Serial.println("❌ Attempt " + String(attempt) + " failed - NaN readings");
    }
    
    delay(3000); // Wait between attempts
  }
  
  // If we get here, all attempts failed
  dht22Working = false;
  Serial.println("❌ DHT22 3-pin module test failed after 5 attempts!");
  Serial.println("🔧 Check your wiring:");
  Serial.println("   Red wire (DHT22 +)     → Red rail (+) → ESP32 3.3V");
  Serial.println("   Orange wire (DHT22 OUT) → ESP32 D5 (GPIO 5)");
  Serial.println("   Brown wire (DHT22 -)    → Blue rail (-) → ESP32 GND");
  Serial.println("💡 Try these solutions:");
  Serial.println("   1. Check if DHT22 module is working (try different module)");
  Serial.println("   2. Check breadboard connections are secure");
  Serial.println("   3. Try shorter jumper wires");
  Serial.println("   4. Try a different DHT22 module");
  Serial.println("⚠️ Will use default values until sensor is fixed");
}

void readDHT22Module() {
  sensorReadAttempts++;
  
  // Add small delay before reading
  delay(100);
  
  // Read DHT22 3-pin module
  float newTemp = dht.readTemperature();
  float newHumidity = dht.readHumidity();
  
  // Debug output every 20 attempts
  if (sensorReadAttempts % 20 == 0) {
    Serial.println("🔍 Debug - Raw readings: Temp=" + String(newTemp) + ", Humidity=" + String(newHumidity));
  }
  
  // Validate readings
  if (!isnan(newTemp) && !isnan(newHumidity)) {
    // Additional validation - check for reasonable values
    if (newTemp >= -40 && newTemp <= 80 && newHumidity >= 0 && newHumidity <= 100) {
      temperature = newTemp;
      humidity = newHumidity;
      lastValidTemp = newTemp;
      lastValidHumidity = newHumidity;
      dht22Working = true;
      successfulReads++;
      
      // Print successful reads more frequently for debugging
      if (successfulReads % 5 == 0) {
        Serial.println("📊 DHT22 readings (every 5th): " + String(temperature, 1) + "°C, " + String(humidity, 1) + "%");
      }
    } else {
      Serial.println("⚠️ DHT22 readings out of range: " + String(newTemp, 1) + "°C, " + String(newHumidity, 1) + "%");
      temperature = lastValidTemp;
      humidity = lastValidHumidity;
    }
  } else {
    dht22Working = false;
    temperature = lastValidTemp;
    humidity = lastValidHumidity;
    
    // Print error every 10 attempts for better debugging
    if (sensorReadAttempts % 10 == 0) {
      Serial.println("❌ DHT22 read failed (attempt " + String(sensorReadAttempts) + "), using last valid values");
      Serial.println("💡 Current success rate: " + String((float)successfulReads/sensorReadAttempts*100, 1) + "%");
    }
  }
}

void prepareSensorData() {
  // Simulate other sensors (you can add real sensors later)
  lightLevel = 300 + random(0, 700);            // Simulated light: 300-1000
  motionDetected = random(0, 10) > 7;           // 30% chance of motion
  energyUsage = 10.0 + random(0, 100) / 10.0;  // Simulated energy: 10-20W
  
  Serial.println("=== Preparing Sensor Data for Flutter App ===");
  Serial.println("🌡️ Temperature: " + String(temperature, 1) + "°C " + (dht22Working ? "(REAL DHT22)" : "(LAST VALID)"));
  Serial.println("💧 Humidity: " + String(humidity, 1) + "% " + (dht22Working ? "(REAL DHT22)" : "(LAST VALID)"));
  Serial.println("💡 Light Level: " + String(lightLevel) + " (simulated)");
  Serial.println("🚶 Motion: " + String(motionDetected ? "Detected" : "None") + " (simulated)");
  Serial.println("⚡ Energy Usage: " + String(energyUsage, 1) + "W (simulated)");
  Serial.println("📶 WiFi Signal: " + String(WiFi.RSSI()) + " dBm");
  Serial.println("📈 DHT22 Success Rate: " + String((float)successfulReads/sensorReadAttempts*100, 1) + "%");
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
  
  // Create JSON payload for Flutter app
  StaticJsonDocument<500> doc;
  doc["device_id"] = deviceID;
  doc["temperature"] = round(temperature * 10) / 10.0;
  doc["humidity"] = round(humidity * 10) / 10.0;
  doc["light_level"] = lightLevel;
  doc["motion_detected"] = motionDetected;
  doc["energy_usage"] = round(energyUsage * 10) / 10.0;
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  Serial.println("📤 Sending DHT22 Data to Your Perfect Flutter App");
  Serial.println("🌐 URL: " + String(serverURL));
  Serial.println("📋 JSON: " + jsonString);
  
  int httpResponseCode = http.POST(jsonString);
  
  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.println("📊 HTTP Response Code: " + String(httpResponseCode));
    Serial.println("📄 Response: " + response);
    
    if (httpResponseCode == 201) {
      serverConnected = true;
      Serial.println("✅ SUCCESS - DHT22 data sent to your Flutter app!");
      Serial.println("📱 Check your Flutter app dashboard for live environmental data!");
      Serial.println("🎯 Your app will show: Temperature, Humidity, Light, Motion, Energy");
      
      // Success pattern - 3 quick blinks
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
    Serial.println("🔍 Error details: " + http.errorToString(httpResponseCode));
  }
  
  http.end();
  Serial.println("================================================");
}

void sendHeartbeat() {
  if (!wifiConnected) return;
  
  HTTPClient http;
  http.begin(heartbeatURL);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(5000);
  
  StaticJsonDocument<400> doc;
  doc["device_id"] = deviceID;
  doc["timestamp"] = millis();
  doc["dht22_working"] = dht22Working;
  doc["success_rate"] = (float)successfulReads/sensorReadAttempts*100;
  doc["wifi_signal"] = WiFi.RSSI();
  doc["uptime"] = millis() / 1000;
  doc["sensor_type"] = "DHT22_3PIN_MODULE_GPIO5";
  doc["current_temp"] = temperature;
  doc["current_humidity"] = humidity;
  doc["gpio_pin"] = DHT_PIN;
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  int httpResponseCode = http.POST(jsonString);
  
  if (httpResponseCode == 200 || httpResponseCode == 201) {
    Serial.println("💓 Heartbeat sent successfully");
  } else {
    Serial.println("⚠️ Heartbeat failed: " + String(httpResponseCode));
  }
  
  http.end();
}

void updateLEDStatus() {
  if (wifiConnected && serverConnected && dht22Working) {
    // All systems working - slow blink (2 second cycle)
    digitalWrite(LED_PIN, (millis() / 2000) % 2);
  } else if (wifiConnected && serverConnected) {
    // WiFi and server OK, DHT22 issues - medium blink (1 second cycle)
    digitalWrite(LED_PIN, (millis() / 1000) % 2);
  } else if (wifiConnected) {
    // WiFi OK, server issues - fast blink (0.5 second cycle)
    digitalWrite(LED_PIN, (millis() / 500) % 2);
  } else {
    // WiFi issues - solid on
    digitalWrite(LED_PIN, HIGH);
  }
}