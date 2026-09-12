#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_MLX90614.h>
#include "LD6002.h"

// --- MLX90614 Temperature Sensor Definitions ---
#define I2C_SDA_PIN 8
#define I2C_SCL_PIN 9
Adafruit_MLX90614 mlx = Adafruit_MLX90614();

// --- HLK-LD6002 Radar Sensor Definitions ---
// Radar TX -> ESP32 GPIO 4 (RX)
// Radar RX -> ESP32 GPIO 3 (TX)
LD6002 radar(Serial1);

// --- Non-Blocking Timer Variables ---
unsigned long previousMillis = 0;
const long interval = 1000; // 1-second interval for printing data

// Variables to store the latest radar readings
float currentHeartRate = 0;
float currentBreathRate = 0;
float currentDistance = 0;

void setup() {
  // 1. Initialize USB CDC Serial Monitor
  Serial.begin(115200);
  delay(2000); // Give USB time to start
  Serial.println("Initializing Combined Sensors...");

  // 2. Initialize Temperature Sensor (I2C)
  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);
  if (!mlx.begin()) {
    Serial.println("Error connecting to MLX sensor. Check I2C wiring.");
    while (1) { delay(1000); } // Halt if temperature sensor fails
  }
  Serial.println("MLX90614 initialized successfully!");

  // 3. Initialize Radar Sensor (UART)
  Serial1.begin(115200, SERIAL_8N1, 4, 3);
  Serial.println("LD6002 initialized successfully!");
  
  Serial.println("--------------------------------------------------");
}

void loop() {
  // 1. CONTINUOUSLY update the radar sensor
  // This must run as fast as possible without delays to catch serial packets
  radar.update();

  // If new radar data arrives, store it in our variables
  if (radar.hasNewHeartRate()) {
    currentHeartRate = radar.getHeartRate();
    radar.clearHeartRateFlag();
  }
  if (radar.hasNewBreathRate()) {
    currentBreathRate = radar.getBreathRate();
    radar.clearBreathRateFlag();
  }
  if (radar.hasNewDistance()) {
    currentDistance = radar.getDistance();
    radar.clearDistanceFlag();
  }

  // 2. Print the combined data exactly once every 1 second
  unsigned long currentMillis = millis();
  
  if (currentMillis - previousMillis >= interval) {
    // Save the last time we printed
    previousMillis = currentMillis;

    // Read Temperatures
    double ambientTemp = mlx.readAmbientTempC();
    double objectTemp = mlx.readObjectTempC();

    // Print the final combined string format
    // Format: AmbientTemp : [data] C , ObjectTemp : [data] C , HeartRate : [data] bpm , BreathRate : [data] /min
    
    Serial.print("AmbientTemp : ");
    if (isnan(ambientTemp)) {
      Serial.print("Error");
    } else {
      Serial.print(ambientTemp);
      Serial.print(" C");
    }

    Serial.print(" , ObjectTemp : ");
    if (isnan(objectTemp)) {
      Serial.print("Error");
    } else {
      Serial.print(objectTemp);
      Serial.print(" C");
    }

    Serial.print(" , HeartRate : ");
    Serial.print(currentHeartRate);
    Serial.print(" bpm");

    Serial.print(" , BreathRate : ");
    Serial.print(currentBreathRate);
    Serial.print(" /min");

    Serial.print(" , Distance : ");
    Serial.print(currentDistance);
    Serial.println(" cm");
  }
}