#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <PZEM004Tv30.h>
#include <time.h>

// WiFi credentials - UPDATE THESE TO YOUR NETWORK
const char* ssid = "SKYWORTH-FA13";
const char* password = "281892655";

// Django API endpoints - UPDATED TO NEW IP
const char* serverURL = "http://192.168.0.44:8000/api/esp32/sensor-data/";
const char* healthURL = "http://192.168.0.44:8000/api/esp32/health/";
const char* heartbeatURL = "http://192.168.0.44:8000/api/esp32/heartbeat/";

// Device configuration - MUST MATCH Django equipment device_id
const char* deviceID = "BEDROOM1";

// Sensor pin configuration
#define DHT_PIN 5          // DHT22 OUT pin → ESP32 D5 (GPIO 5)
#define DHT_TYPE DHT22     // DHT22 sensor type
#define LED_PIN 2          // Built-in LED pin
#define PIR_PIN 18         // PIR sensor DO pin → ESP32 D18 (GPIO 18)
#define PHOTO_PIN 19       // Photosensitive module DO pin → ESP32 D19 (GPIO 19)
#define PZEM_RX_PIN 16     // PZEM RX pin → ESP32 GPIO 16
#define PZEM_TX_PIN 17     // PZEM TX pin → ESP32 GPIO 17

// Initialize sensors
DHT dht(DHT_PIN, DHT_TYPE);
PZEM004Tv30 pzem(Serial2, PZEM_RX_PIN, PZEM_TX_PIN);

// Timing variables
unsigned long lastDataSend = 0;
unsigned long lastHealthCheck = 0;
unsigned long lastHeartbeat = 0;
unsigned long lastSensorRead = 0;
unsigned long lastPIRPrint = 0;
unsigned long lastWiFiAttempt = 0;
const unsigned long SEND_INTERVAL = 10000;      // Send data every 10 seconds
const unsigned long HEALTH_INTERVAL = 60000;    // Health check every 60 seconds
const unsigned long HEARTBEAT_INTERVAL = 30000; // Heartbeat every 30 seconds
const unsigned long SENSOR_READ_INTERVAL = 3000; // Read sensor every 3 seconds
const unsigned long PIR_PRINT_INTERVAL = 1000;  // Print PIR status every 1 second
const unsigned long WIFI_RETRY_INTERVAL = 10000; // Retry WiFi every 10 seconds

// Sensor data variables
float temperature = 0.0;
float humidity = 0.0;
bool lightDetected = false;
bool motionDetected = false;
float voltage = 0.0;
float current = 0.0;
float power = 0.0;
float energy = 0.0;

// Sensor status tracking
bool wifiConnected = false;
bool serverConnected = false;
bool dht22Working = false;
bool pzemWorking = false;
bool pirWorking = false;
bool photoresistorWorking = false;
int sensorReadAttempts = 0;
int successfulReads = 0;

// Data validation - store last valid readings
float lastValidTemp = 22.0;
float lastValidHumidity = 50.0;
float lastValidPower = 0.0;

void setup() {
    Serial.begin(115200);
    Serial.println("=== ESP32 Smart Building DHT22, PZEM, PIR & Photosensitive Module ===");
    Serial.println("Device ID: " + String(deviceID));
    Serial.println("Version: 2.6.4 - Fixed JSON typo, WiFi stability");
    Serial.println("Wire Colors (DHT22): Red=Power, Brown=Ground, Orange=Data");
    Serial.println("Wire Colors (PZEM): TX/RX to GPIO 16/17");
    Serial.println("Wire Colors (Photoresistor): VCC=3.3V, DO=GPIO 19, GND=Ground");
    Serial.println("Wire Colors (PIR): VCC=5V, DO=GPIO 18, GND=Ground");
    Serial.println("===================================================");

    // Initialize built-in LED
    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, LOW);

    // Configure GPIO 5 with internal pull-up resistor for DHT22
    pinMode(DHT_PIN, INPUT_PULLUP);
    Serial.println("🔧 Configured GPIO 5 with internal pull-up resistor for DHT22");

    // Initialize DHT22 3-pin module
    Serial.println("🌡️ Initializing DHT22 3-pin module on GPIO 5...");
    dht.begin();
    delay(2000); // Reduced from 5000 for faster startup

    // Initialize PZEM-004T
    Serial.println("⚡ Initializing PZEM-004T on Serial2 (GPIO 16 RX, 17 TX)...");
    Serial2.begin(9600);
    pzem.setAddress(0x42);
    delay(1000); // Reduced from 2000
    Serial.println("🔧 PZEM initialization complete");

    // Initialize PIR sensor
    Serial.println("🚶 Initializing PIR sensor on GPIO 18...");
    pinMode(PIR_PIN, INPUT);

    // Initialize Photosensitive module
    Serial.println("💡 Initializing Photosensitive module on GPIO 19...");
    pinMode(PHOTO_PIN, INPUT);

    // Connect to WiFi FIRST
    Serial.println("Before WiFi connect");
    connectToWiFi();
    Serial.println("After WiFi connect");

    // Initialize NTP client AFTER WiFi
    if (wifiConnected) {
        Serial.println("⏰ Initializing NTP client...");
        configTime(0, 0, "pool.ntp.org"); // Simplified to one reliable server
        time_t now = time(nullptr);
        int ntpAttempts = 0;
        while (now < 1000000000 && ntpAttempts < 10) { // Timeout after 5 seconds
            delay(500);
            now = time(nullptr);
            Serial.print(".");
            ntpAttempts++;
        }
        Serial.println(now >= 1000000000 ? "\n✅ NTP synchronized" : "\n❌ NTP sync failed, using fallback timestamp");
    } else {
        Serial.println("❌ Skipping NTP initialization - no WiFi connection");
    }

    // Startup sequence
    startupSequence();

    // Test server connection
    testServerConnection();

    // Test sensors
    testDHT22Module();
    testPZEMModule();
    testPIRSensor();
    testPhotoresistor();

    // Send initial heartbeat
    if (wifiConnected && serverConnected) {
        sendHeartbeat();
    }

    Serial.println("=== ESP32 Ready for Operation ===");
    Serial.println("📊 Reading sensors every " + String(SENSOR_READ_INTERVAL/1000) + " seconds");
    Serial.println("📤 Sending data to server every " + String(SEND_INTERVAL/1000) + " seconds");
    Serial.println("===============================================");
}

void loop() {
    unsigned long currentTime = millis();

    // Check WiFi connection
    if (WiFi.status() != WL_CONNECTED && currentTime - lastWiFiAttempt >= WIFI_RETRY_INTERVAL) {
        wifiConnected = false;
        Serial.println("⚠️ WiFi disconnected, attempting to reconnect...");
        connectToWiFi();
        lastWiFiAttempt = currentTime;
    } else if (WiFi.status() == WL_CONNECTED) {
        wifiConnected = true;
    }

    // Read sensors every SENSOR_READ_INTERVAL
    if (currentTime - lastSensorRead >= SENSOR_READ_INTERVAL) {
        readDHT22Module();
        readPZEMModule();
        readPIRSensor();
        readPhotoresistor();
        lastSensorRead = currentTime;
    }

    // Debug print PIR and Photoresistor status every 1 second
    if (currentTime - lastPIRPrint >= PIR_PRINT_INTERVAL) {
        Serial.println("🚶 PIR Status: " + String(motionDetected ? "Motion Detected!" : "No Motion") + " (RAW: " + String(digitalRead(PIR_PIN)) + ")");
        Serial.println("💡 Photoresistor Status: " + String(lightDetected ? "Light Detected!" : "No Light") + " (RAW: " + String(digitalRead(PHOTO_PIN)) + ")");
        lastPIRPrint = currentTime;
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

    delay(100); // Reduced for better responsiveness
}

void startupSequence() {
    Serial.println("🚀 Running startup sequence...");
    for (int i = 0; i < 5; i++) {
        digitalWrite(LED_PIN, HIGH);
        delay(100);
        digitalWrite(LED_PIN, LOW);
        delay(100);
    }
    Serial.println("✅ Startup sequence complete");
}

void connectToWiFi() {
    Serial.print("🔗 Connecting to WiFi: ");
    Serial.println(ssid);

    WiFi.disconnect(true); // Reset WiFi stack
    delay(100);
    WiFi.begin(ssid, password);

    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20) { // 10 seconds timeout
        delay(500);
        Serial.print(". Status: ");
        Serial.println(WiFi.status());
        digitalWrite(LED_PIN, attempts % 2);
        attempts++;
    }

    if (WiFi.status() == WL_CONNECTED) {
        wifiConnected = true;
        Serial.println("\n✅ WiFi connected successfully!");
        Serial.print("📡 IP address: ");
        Serial.println(WiFi.localIP());
        Serial.println("📶 Signal strength: " + String(WiFi.RSSI()) + " dBm");
        for (int i = 0; i < 5; i++) {
            digitalWrite(LED_PIN, HIGH);
            delay(50);
            digitalWrite(LED_PIN, LOW);
            delay(50);
        }
    } else {
        wifiConnected = false;
        Serial.println("\n❌ WiFi connection failed!");
        Serial.println("🔧 Please check your WiFi credentials or signal strength");
        digitalWrite(LED_PIN, HIGH);
    }
}

void testServerConnection() {
    if (!wifiConnected) {
        Serial.println("❌ Cannot test server - no WiFi");
        return;
    }

    Serial.println("🔍 Testing server connection...");

    HTTPClient http;
    http.begin(healthURL);
    http.setTimeout(5000);

    int httpResponseCode = http.GET();

    if (httpResponseCode == 200) {
        String response = http.getString();
        serverConnected = true;
        Serial.println("✅ Server connection OK");
        Serial.println("📄 Response: " + response);
    } else {
        serverConnected = false;
        Serial.println("❌ Server connection failed: " + String(httpResponseCode));
        Serial.println("💡 Make sure Django server is running: python manage.py runserver 0.0.0.0:8000");
    }

    http.end();
}

void testDHT22Module() {
    Serial.println("🌡️ Testing DHT22 3-pin module on GPIO 5...");
    delay(2000);

    for (int attempt = 1; attempt <= 3; attempt++) {
        Serial.println("📊 Test attempt " + String(attempt) + "/3...");
        delay(1000);

        float testTemp = dht.readTemperature();
        float testHumidity = dht.readHumidity();

        Serial.println("🔍 Raw readings: Temp=" + String(testTemp) + ", Humidity=" + String(testHumidity));

        if (!isnan(testTemp) && !isnan(testHumidity)) {
            if (testTemp >= -40 && testTemp <= 80 && testHumidity >= 0 && testHumidity <= 100) {
                dht22Working = true;
                Serial.println("✅ DHT22 3-pin module working perfectly on GPIO 5!");
                Serial.println("🌡️ Test temperature: " + String(testTemp, 1) + "°C");
                Serial.println("💧 Test humidity: " + String(testHumidity, 1) + "%");
                lastValidTemp = testTemp;
                lastValidHumidity = testHumidity;
                return;
            } else {
                Serial.println("⚠️ Readings out of range: " + String(testTemp, 1) + "°C, " + String(testHumidity, 1) + "%");
            }
        } else {
            Serial.println("❌ Attempt " + String(attempt) + " failed - NaN readings");
        }
        delay(1000);
    }

    dht22Working = false;
    Serial.println("❌ DHT22 3-pin module test failed after 3 attempts!");
    Serial.println("🔧 Check your wiring...");
}

void testPZEMModule() {
    Serial.println("⚡ Testing PZEM-004T on Serial2...");

    for (int attempt = 1; attempt <= 3; attempt++) {
        Serial.println("📊 Test attempt " + String(attempt) + "/3...");
        delay(1000);

        float testVoltage = pzem.voltage();
        float testCurrent = pzem.current();
        float testPower = pzem.power();
        float testEnergy = pzem.energy();

        Serial.println("🔍 Raw readings: Voltage=" + String(testVoltage) + "V, Current=" + String(testCurrent) + "A, Power=" + String(testPower) + "W, Energy=" + String(testEnergy) + "kWh");

        if (!isnan(testVoltage) && !isnan(testCurrent) && !isnan(testPower) && !isnan(testEnergy)) {
            if (testVoltage >= 80 && testVoltage <= 260 && testCurrent >= 0 && testPower >= 0) {
                pzemWorking = true;
                Serial.println("✅ PZEM-004T working perfectly on Serial2!");
                Serial.println("⚡ Test voltage: " + String(testVoltage, 1) + "V");
                Serial.println("⚡ Test current: " + String(testCurrent, 2) + "A");
                Serial.println("⚡ Test power: " + String(testPower, 1) + "W");
                Serial.println("⚡ Test energy: " + String(testEnergy, 3) + "kWh");
                lastValidPower = testPower;
                return;
            } else {
                Serial.println("⚠️ Readings out of range...");
            }
        } else {
            Serial.println("❌ Attempt " + String(attempt) + " failed - NaN or invalid readings");
        }
        delay(1000);
    }

    pzemWorking = false;
    Serial.println("❌ PZEM-004T test failed after 3 attempts!");
    Serial.println("🔧 Check your wiring...");
}

void testPIRSensor() {
    Serial.println("🚶 Testing PIR sensor on GPIO 18...");
    Serial.println("⏳ Waiting 2 seconds for PIR sensor to stabilize...");
    for (int i = 0; i < 2; i++) {
        digitalWrite(LED_PIN, HIGH);
        delay(500);
        digitalWrite(LED_PIN, LOW);
        delay(500);
    }

    int pirState = digitalRead(PIR_PIN);
    if (pirState == HIGH || pirState == LOW) {
        pirWorking = true;
        Serial.println("✅ PIR sensor initialized! Initial state: " + String(pirState == HIGH ? "Motion Detected" : "No Motion"));
    } else {
        pirWorking = false;
        Serial.println("❌ PIR sensor test failed!");
        Serial.println("🔧 Check wiring...");
    }
}

void testPhotoresistor() {
    Serial.println("💡 Testing Photosensitive module on GPIO 19...");
    Serial.println("⏳ Waiting 2 seconds for module to stabilize...");
    delay(2000);

    int photoState = digitalRead(PHOTO_PIN);
    if (photoState == HIGH || photoState == LOW) {
        photoresistorWorking = true;
        Serial.println("✅ Photosensitive module initialized! Initial state: " + String(photoState == HIGH ? "Light Detected" : "No Light"));
    } else {
        photoresistorWorking = false;
        Serial.println("❌ Photosensitive module test failed!");
        Serial.println("🔧 Check wiring...");
    }
}

void readDHT22Module() {
    sensorReadAttempts++;
    delay(100);

    float newTemp = dht.readTemperature();
    float newHumidity = dht.readHumidity();

    if (sensorReadAttempts % 20 == 0) {
        Serial.println("🔍 Debug - Raw DHT22 readings: Temp=" + String(newTemp) + ", Humidity=" + String(newHumidity));
    }

    if (!isnan(newTemp) && !isnan(newHumidity)) {
        if (newTemp >= -40 && newTemp <= 80 && newHumidity >= 0 && newHumidity <= 100) {
            temperature = newTemp;
            humidity = newHumidity;
            lastValidTemp = newTemp;
            lastValidHumidity = newHumidity;
            dht22Working = true;
            successfulReads++;
            if (successfulReads % 5 == 0) {
                Serial.println("📊 DHT22 readings (every 5th): " + String(temperature, 1) + "°C, " + String(humidity, 1) + "%");
            }
        } else {
            Serial.println("⚠️ DHT22 readings out of range...");
            temperature = lastValidTemp;
            humidity = lastValidHumidity;
        }
    } else {
        dht22Working = false;
        temperature = lastValidTemp;
        humidity = lastValidHumidity;
        if (sensorReadAttempts % 10 == 0) {
            Serial.println("❌ DHT22 read failed (attempt " + String(sensorReadAttempts) + "), using last valid values");
        }
    }
}

void readPZEMModule() {
    sensorReadAttempts++;
    delay(100);

    int retryCount = 0;
    const int MAX_RETRIES = 3;
    float newVoltage = 0.0, newCurrent = 0.0, newPower = 0.0, newEnergy = 0.0;

    while (retryCount < MAX_RETRIES) {
        newVoltage = pzem.voltage();
        newCurrent = pzem.current();
        newPower = pzem.power();
        newEnergy = pzem.energy();

        if (sensorReadAttempts % 20 == 0 || retryCount > 0) {
            Serial.println("🔍 Debug - PZEM Raw readings (attempt " + String(retryCount + 1) + "): Voltage=" + String(newVoltage) + "V, Current=" + String(newCurrent) + "A, Power=" + String(newPower) + "W, Energy=" + String(newEnergy) + "kWh");
        }

        if (!isnan(newVoltage) && !isnan(newCurrent) && !isnan(newPower) && !isnan(newEnergy)) {
            break;
        }

        retryCount++;
        delay(500);
    }

    if (!isnan(newVoltage) && !isnan(newCurrent) && !isnan(newPower) && !isnan(newEnergy)) {
        if (newVoltage >= 80 && newVoltage <= 260 && newCurrent >= 0 && newPower >= 0) {
            voltage = newVoltage;
            current = newCurrent;
            power = newPower;
            energy = newEnergy;
            pzemWorking = true;
            Serial.println("✅ PZEM readings updated: Voltage=" + String(voltage, 1) + "V, Current=" + String(current, 2) + "A, Power=" + String(power, 1) + "W");
        } else {
            Serial.println("⚠️ PZEM readings out of range...");
            pzemWorking = false;
        }
    } else {
        pzemWorking = false;
        if (sensorReadAttempts % 10 == 0) {
            Serial.println("❌ PZEM read failed (attempt " + String(sensorReadAttempts) + "), using last valid power");
        }
    }
}

void readPIRSensor() {
    static bool lastState = false;
    static unsigned long lastChangeTime = 0;
    const unsigned long DEBOUNCE_TIME = 50;

    bool currentState = digitalRead(PIR_PIN);
    if (currentState != lastState && millis() - lastChangeTime > DEBOUNCE_TIME) {
        motionDetected = currentState;
        lastState = currentState;
        lastChangeTime = millis();
        if (motionDetected) {
            Serial.println("🚨 MOTION DETECTED! (Debounced)");
        }
    }
}

void readPhotoresistor() {
    static bool lastState = false;
    static unsigned long lastChangeTime = 0;
    const unsigned long DEBOUNCE_TIME = 50;

    bool currentState = digitalRead(PHOTO_PIN);
    if (currentState != lastState && millis() - lastChangeTime > DEBOUNCE_TIME) {
        lightDetected = currentState;
        lastState = currentState;
        lastChangeTime = millis();
        if (lightDetected) {
            Serial.println("💡 LIGHT DETECTED! (Debounced)");
        } else {
            Serial.println("💡 NO LIGHT DETECTED! (Debounced)");
        }
        photoresistorWorking = true;
    }
}

String getISOTimestamp() {
    time_t now = time(nullptr);
    if (now < 1000000000) {
        Serial.println("⚠️ NTP not synced, using fallback timestamp");
        return "2025-09-30T00:00:00Z";
    }
    char timeStr[25];
    strftime(timeStr, sizeof(timeStr), "%Y-%m-%dT%H:%M:%SZ", gmtime(&now));
    return String(timeStr);
}

void prepareSensorData() {
    Serial.println("=== Preparing Sensor Data for Django Server ===");
    Serial.println("🌡️ Temperature: " + String(temperature, 1) + "°C " + (dht22Working ? "(REAL DHT22)" : "(LAST VALID)"));
    Serial.println("💧 Humidity: " + String(humidity, 1) + "% " + (dht22Working ? "(REAL DHT22)" : "(LAST VALID)"));
    Serial.println("💡 Light: " + String(lightDetected ? "Detected" : "None") + " " + (photoresistorWorking ? "(REAL PHOTORESISTOR)" : "(INIT FAILED)"));
    Serial.println("🚶 Motion: " + String(motionDetected ? "Detected" : "None") + " " + (pirWorking ? "(REAL PIR)" : "(INIT FAILED)"));
    Serial.println("⚡ Voltage: " + String(voltage, 1) + "V " + (pzemWorking ? "(REAL PZEM)" : "(LAST VALID)"));
    Serial.println("⚡ Current: " + String(current, 2) + "A " + (pzemWorking ? "(REAL PZEM)" : "(LAST VALID)"));
    Serial.println("⚡ Power: " + String(power, 1) + "W " + (pzemWorking ? "(REAL PZEM)" : "(LAST VALID)"));
    Serial.println("⚡ Energy: " + String(energy, 3) + "kWh " + (pzemWorking ? "(REAL PZEM)" : "(LAST VALID)"));
    Serial.println("📶 WiFi Signal: " + String(WiFi.RSSI()) + " dBm");
    Serial.println("📈 DHT22 Success Rate: " + String(sensorReadAttempts > 0 ? (float)successfulReads / sensorReadAttempts * 100 : 0, 1) + "%");
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
    http.setTimeout(5000);

    DynamicJsonDocument doc(1024);
    doc["device_id"] = deviceID;
    JsonArray components = doc.createNestedArray("components");

    if (pzemWorking) {
        JsonObject pzemData = components.createNestedObject();
        pzemData["component_type"] = "pzem";
        pzemData["identifier"] = "PZEM_SERIAL2";
        pzemData["recorded_at"] = getISOTimestamp();
        pzemData["voltage"] = round(voltage * 10) / 10.0;
        pzemData["current"] = round(current * 100) / 100.0;
        pzemData["power"] = round(power * 10) / 10.0;
        pzemData["energy"] = round(energy * 1000) / 1000.0;
    }

    if (dht22Working) {
        JsonObject dhtData = components.createNestedObject();
        dhtData["component_type"] = "dht22";
        dhtData["identifier"] = "DHT22_3PIN_MODULE_GPIO5";
        dhtData["recorded_at"] = getISOTimestamp();
        dhtData["temperature"] = round(temperature * 10) / 10.0;
        dhtData["humidity"] = round(humidity * 10) / 10.0;
    }

    if (photoresistorWorking) {
        JsonObject photoData = components.createNestedObject();
        photoData["component_type"] = "photoresistor";
        photoData["identifier"] = "PHOTO_GPIO19";
        photoData["recorded_at"] = getISOTimestamp();
        photoData["light_detected"] = lightDetected; // Fixed typo: was pzemData
    }

    if (pirWorking) {
        JsonObject motionData = components.createNestedObject();
        motionData["component_type"] = "motion";
        motionData["identifier"] = "MOTION_GPIO18";
        motionData["recorded_at"] = getISOTimestamp();
        motionData["motion_detected"] = motionDetected;
    }

    String jsonString;
    serializeJson(doc, jsonString);

    Serial.println("📤 Sending Sensor Data to Django Server");
    Serial.println("🌐 URL: " + String(serverURL));
    Serial.println("📋 JSON: " + jsonString);

    int httpResponseCode = http.POST(jsonString);

    if (httpResponseCode > 0) {
        String response = http.getString();
        Serial.println("📊 HTTP Response Code: " + String(httpResponseCode));
        Serial.println("📄 Response: " + response);

        if (httpResponseCode == 201) {
            serverConnected = true;
            Serial.println("✅ SUCCESS - Sensor data sent to server!");
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
    if (!wifiConnected) {
        Serial.println("❌ Cannot send heartbeat - no WiFi");
        return;
    }

    HTTPClient http;
    http.begin(heartbeatURL);
    http.addHeader("Content-Type", "application/json");
    http.setTimeout(5000);

    StaticJsonDocument<400> doc;
    doc["device_id"] = deviceID;
    doc["timestamp"] = millis();
    doc["dht22_working"] = dht22Working;
    doc["pzem_working"] = pzemWorking;
    doc["photoresistor_working"] = photoresistorWorking;
    doc["pir_working"] = pirWorking;
    doc["success_rate"] = sensorReadAttempts > 0 ? (float)successfulReads / sensorReadAttempts * 100 : 0;
    doc["wifi_signal"] = WiFi.RSSI();
    doc["uptime"] = millis() / 1000;
    doc["sensor_type"] = "PZEM_SERIAL2,DHT22_3PIN_MODULE_GPIO5,PHOTO_GPIO19,MOTION_GPIO18";
    doc["current_temp"] = temperature;
    doc["current_humidity"] = humidity;
    doc["current_power"] = power;

    String jsonString;
    serializeJson(doc, jsonString);

    Serial.println("💓 Sending Heartbeat: " + jsonString);
    int httpResponseCode = http.POST(jsonString);

    if (httpResponseCode == 200 || httpResponseCode == 201) {
        Serial.println("💓 Heartbeat sent successfully");
    } else {
        Serial.println("⚠️ Heartbeat failed: " + String(httpResponseCode));
        Serial.println("🔍 Error: " + http.errorToString(httpResponseCode));
    }

    http.end();
}

void updateLEDStatus() {
    if (wifiConnected && serverConnected && dht22Working && pzemWorking && pirWorking && photoresistorWorking) {
        digitalWrite(LED_PIN, (millis() / 2000) % 2);
    } else if (wifiConnected && serverConnected) {
        digitalWrite(LED_PIN, (millis() / 1000) % 2);
    } else if (wifiConnected) {
        digitalWrite(LED_PIN, (millis() / 500) % 2);
    } else {
        digitalWrite(LED_PIN, HIGH);
    }

    if (motionDetected || lightDetected) {
        digitalWrite(LED_PIN, HIGH);
        delay(50);
        digitalWrite(LED_PIN, LOW);
    }
}