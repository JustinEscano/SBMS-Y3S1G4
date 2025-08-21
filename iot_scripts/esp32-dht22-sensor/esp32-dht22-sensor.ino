#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// WiFi credentials - CHANGE THESE TO YOUR NETWORK
const char* ssid = "";
const char* password = "";

// Django API endpoint - CHANGE THIS TO YOUR COMPUTER'S IP
const char* serverURL = "http://192.168.0.100:8000/api/esp32/sensor-data/";
const char* healthURL = "http://192.168.0.100:8000/api/esp32/health/";

// Device configuration
const char* deviceID = "ESP32_001";  // Must match device_id in Django admin

// Built-in LED pin
#define LED_PIN 2  // Most ESP32 boards have built-in LED on pin 2

// Timing variables
unsigned long lastDataSend = 0;
const unsigned long SEND_INTERVAL = 15000;  // Send data every 15 seconds

// Simulated sensor data
float temperature = 22.0;
float humidity = 50.0;
int lightLevel = 500;
bool motionDetected = false;
float energyUsage = 15.0;

void setup() {
  Serial.begin(115200);
  Serial.println("=== ESP32 Smart Building Test ===");
  
  // Initialize built-in LED
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  
  // Startup blink
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(200);
    digitalWrite(LED_PIN, LOW);
    delay(200);
  }
  
  // Connect to WiFi
  connectToWiFi();
  
  // Test server connection
  testServerConnection();
  
  Serial.println("=== ESP32 Ready ===");
  Serial.println("Device ID: " + String(deviceID));
  Serial.println("Sending data every " + String(SEND_INTERVAL/1000) + " seconds");
}

void loop() {
  unsigned long currentTime = millis();
  
  // Check WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected, reconnecting...");
    connectToWiFi();
  }
  
  // Send data every SEND_INTERVAL
  if (currentTime - lastDataSend >= SEND_INTERVAL) {
    generateSensorData();  // Simulate sensor readings
    sendSensorData();
    lastDataSend = currentTime;
  }
  
  // Blink LED to show it's working
  digitalWrite(LED_PIN, (millis() / 1000) % 2);
  
  delay(1000);
}

void connectToWiFi() {
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);
  
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println();
    Serial.println("✅ WiFi connected!");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
    Serial.print("Signal strength: ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
    
    // Success blink
    for (int i = 0; i < 5; i++) {
      digitalWrite(LED_PIN, HIGH);
      delay(100);
      digitalWrite(LED_PIN, LOW);
      delay(100);
    }
  } else {
    Serial.println();
    Serial.println("❌ WiFi connection failed!");
  }
}

void testServerConnection() {
  if (WiFi.status() != WL_CONNECTED) return;
  
  Serial.println("Testing server connection...");
  
  HTTPClient http;
  http.begin(healthURL);
  http.setTimeout(5000);
  
  int httpResponseCode = http.GET();
  
  if (httpResponseCode == 200) {
    String response = http.getString();
    Serial.println("✅ Server connection OK");
    Serial.println("Response: " + response);
  } else {
    Serial.println("❌ Server connection failed: " + String(httpResponseCode));
  }
  
  http.end();
}

void generateSensorData() {
  // Simulate realistic sensor data with some variation
  temperature = 20.0 + random(-50, 80) / 10.0;  // 15°C to 27°C
  humidity = 40.0 + random(0, 300) / 10.0;      // 40% to 70%
  lightLevel = 300 + random(0, 700);            // 300 to 1000
  motionDetected = random(0, 10) > 7;           // 30% chance of motion
  energyUsage = 10.0 + random(0, 100) / 10.0;  // 10W to 20W
  
  Serial.println("=== Generated Sensor Data ===");
  Serial.println("Temperature: " + String(temperature, 1) + "°C");
  Serial.println("Humidity: " + String(humidity, 1) + "%");
  Serial.println("Light Level: " + String(lightLevel));
  Serial.println("Motion: " + String(motionDetected ? "Detected" : "None"));
  Serial.println("Energy: " + String(energyUsage, 1) + "W");
  Serial.println();
}

void sendSensorData() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Cannot send data - WiFi not connected");
    return;
  }
  
  HTTPClient http;
  http.begin(serverURL);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(10000);
  
  // Create JSON payload
  StaticJsonDocument<300> doc;
  doc["device_id"] = deviceID;
  doc["temperature"] = temperature;
  doc["humidity"] = humidity;
  doc["light_level"] = lightLevel;
  doc["motion_detected"] = motionDetected;
  doc["energy_usage"] = energyUsage;
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  Serial.println("=== Sending Data ===");
  Serial.println("URL: " + String(serverURL));
  Serial.println("JSON: " + jsonString);
  
  int httpResponseCode = http.POST(jsonString);
  
  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.println("HTTP Code: " + String(httpResponseCode));
    Serial.println("Response: " + response);
    
    if (httpResponseCode == 201) {
      Serial.println("✅ SUCCESS - Data sent!");
      
      // Success pattern - fast blinks
      for (int i = 0; i < 3; i++) {
        digitalWrite(LED_PIN, HIGH);
        delay(100);
        digitalWrite(LED_PIN, LOW);
        delay(100);
      }
    } else {
      Serial.println("❌ Server Error: " + String(httpResponseCode));
    }
  } else {
    Serial.println("❌ Connection Error: " + String(httpResponseCode));
    Serial.println("Error: " + http.errorToString(httpResponseCode));
  }
  
  http.end();
  Serial.println("=========================");
}