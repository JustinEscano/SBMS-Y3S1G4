const int pirPin = 7;

void setup() {
    Serial.begin(9600);
    pinMode(pirPin, INPUT);
}

void loop() {
    int val = digitalRead(pirPin);
    // Check if motion is detected 1 for motion detected, 0 for motion detected
    if (val) {
        Serial.println("Motion Detected");
    } else {
        Serial.println("No Motion...");
    }

    delay(500); // Give half a second delay for each data send
}