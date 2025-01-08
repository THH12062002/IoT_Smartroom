#include <ESP8266WiFi.h>
#include <WiFiClientSecure.h>  // Thêm thư viện WiFiClientSecure
#include <Adafruit_MQTT.h>
#include <Adafruit_MQTT_Client.h>
#include <DHT.h>
#include <ArduinoJson.h>

// WiFi configuration
const char* ssid = "Tro PTH Tang 4_5G";
const char* password = "0909947517";

// Adafruit IO configuration
#define AIO_SERVER "io.adafruit.com"
#define AIO_SERVERPORT 1883  // Port không dùng SSL/TLS
#define AIO_USERNAME "thh1206"
#define AIO_KEY "aio_Bfhc956eiPipCUP8kYM4DfFzmO8y"

// MQTT Client
WiFiClient client;  // Sử dụng WiFiClient cho MQTT không dùng SSL
Adafruit_MQTT_Client mqtt(&client, AIO_SERVER, AIO_SERVERPORT, AIO_USERNAME, AIO_KEY);

// Feeds for sensor and button
Adafruit_MQTT_Publish temperatureFeed = Adafruit_MQTT_Publish(&mqtt, AIO_USERNAME "/feeds/sensor1");
Adafruit_MQTT_Publish humidityFeed = Adafruit_MQTT_Publish(&mqtt, AIO_USERNAME "/feeds/sensor2");
Adafruit_MQTT_Publish heatIndexFeed = Adafruit_MQTT_Publish(&mqtt, AIO_USERNAME "/feeds/sensor3");

Adafruit_MQTT_Subscribe button1Feed = Adafruit_MQTT_Subscribe(&mqtt, AIO_USERNAME "/feeds/button1");
Adafruit_MQTT_Subscribe button2Feed = Adafruit_MQTT_Subscribe(&mqtt, AIO_USERNAME "/feeds/button2");

// Pin configuration
#define LED_PIN D4
#define FAN_PIN D5
#define DHT_PIN D7
#define DHT_TYPE DHT11

DHT dht(DHT_PIN, DHT_TYPE);

void connectToWiFi() {
  Serial.print("Connecting to WiFi...");
  WiFi.begin(ssid, password);
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(1000);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nFailed to connect to WiFi");
  }
}

void MQTT_connect() {
  int8_t ret;

  // Kết nối lại nếu kết nối MQTT bị ngắt
  if (mqtt.connected()) {
    return;
  }

  Serial.print("Connecting to MQTT... ");

  while ((ret = mqtt.connect()) != 0) { // Kết nối lại nếu kết nối thất bại
    Serial.println(mqtt.connectErrorString(ret));
    Serial.println("Retrying MQTT connection in 5 seconds...");
    mqtt.disconnect();
    delay(5000);  // Chờ 5 giây trước khi thử lại
  }
  Serial.println("MQTT Connected!");
}

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  pinMode(FAN_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  digitalWrite(FAN_PIN, LOW);

  dht.begin();
  connectToWiFi();
  mqtt.subscribe(&button1Feed);
  mqtt.subscribe(&button2Feed);
}

void loop() {
  MQTT_connect();
  mqtt.processPackets(1000);
  mqtt.ping();

  // Read sensor data
  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();
  float heatIndex = dht.computeHeatIndex(temperature, humidity, false);

  // Check for sensor errors
  if (isnan(temperature) || isnan(humidity) || isnan(heatIndex)) {
    Serial.println("Failed to read from DHT sensor!");
  } else {
    // Print sensor data to Serial Monitor
    Serial.print("Temperature: ");
    Serial.println(temperature);
    Serial.print("Humidity: ");
    Serial.println(humidity);
    Serial.print("Heat Index: ");
    Serial.println(heatIndex);

    // Publish sensor data to Adafruit IO
    temperatureFeed.publish(temperature);
    humidityFeed.publish(humidity);
    heatIndexFeed.publish(heatIndex);
  }

  // Check button state (button1 & button2) via MQTT
  Adafruit_MQTT_Subscribe *subscription;
  while ((subscription = mqtt.readSubscription(10000))) {
    if (subscription == &button1Feed) {
      String payload1 = (char *)button1Feed.lastread;
      Serial.print("Button1 Feed: ");
      Serial.println(payload1);
      int lightState = payload1.toInt();
      digitalWrite(LED_PIN, lightState);  // Turn light ON or OFF based on feed value
    }
    
    if (subscription == &button2Feed) {
      String payload2 = (char *)button2Feed.lastread;
      Serial.print("Button2 Feed: ");
      Serial.println(payload2);
      int fanState = payload2.toInt();
      digitalWrite(FAN_PIN, fanState);  // Turn fan ON or OFF based on feed value
    }
  }

  //delay(10000);  // Wait before reading sensor data again
}
