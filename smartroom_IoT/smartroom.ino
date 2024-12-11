#include <ESP8266WiFi.h>
#include <Adafruit_MQTT.h>
#include <Adafruit_MQTT_Client.h>
#include <DHT.h>

// Thông tin WiFi
const char* ssid = "HSU_Students";
const char* password = "dhhs12cnvch";

// Thông tin Adafruit IO
#define AIO_SERVER "io.adafruit.com"
#define AIO_SERVERPORT 1883 // MQTT Port
#define AIO_USERNAME "thh1206"
#define AIO_KEY "aio_LBOt55WXcUX5QPPFi1Joa6GbLTL2"

// MQTT Client
WiFiClient client;
Adafruit_MQTT_Client mqtt(&client, AIO_SERVER, AIO_SERVERPORT, AIO_USERNAME, AIO_KEY);

// Feeds trên Adafruit IO cho sensor
Adafruit_MQTT_Publish temperatureFeed = Adafruit_MQTT_Publish(&mqtt, AIO_USERNAME "/feeds/sensor1");
Adafruit_MQTT_Publish humidityFeed = Adafruit_MQTT_Publish(&mqtt, AIO_USERNAME "/feeds/sensor2");
Adafruit_MQTT_Publish heatIndexFeed = Adafruit_MQTT_Publish(&mqtt, AIO_USERNAME "/feeds/sensor3");

// Feeds trên Adafruit IO cho button
Adafruit_MQTT_Subscribe button1Feed = Adafruit_MQTT_Subscribe(&mqtt, AIO_USERNAME "/feeds/button1");
Adafruit_MQTT_Subscribe button2Feed = Adafruit_MQTT_Subscribe(&mqtt, AIO_USERNAME "/feeds/button2");

// Định nghĩa chân LED, FAN và DHT Sensor
#define LED_PIN D4    // Chân kết nối LED (Light)
#define FAN_PIN D5    // Chân kết nối FAN
#define DHT_PIN D7    // Chân DATA của DHT Sensor
#define DHT_TYPE DHT11

// Khởi tạo DHT sensor
DHT dht(DHT_PIN, DHT_TYPE);

void connectToWiFi() {
  Serial.print("Connecting to WiFi...");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());
}

void connectToMQTT() {
  while (!mqtt.connected()) {
    Serial.print("Connecting to MQTT...");
    if (mqtt.connect()) {
      Serial.println("connected!");
      mqtt.subscribe(&button1Feed);
      mqtt.subscribe(&button2Feed);
    } else {
      Serial.println("failed. Retrying in 5 seconds...");
      delay(5000);
    }
  }
}

void setup() {
  Serial.begin(115200);

  // Cấu hình chân LED và FAN
  pinMode(LED_PIN, OUTPUT);
  pinMode(FAN_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  digitalWrite(FAN_PIN, LOW);

  // Bắt đầu cảm biến DHT
  dht.begin();

  connectToWiFi();
  connectToMQTT();
}

void loop() {
  // Kết nối lại MQTT nếu bị mất kết nối
  if (!mqtt.connected()) {
    connectToMQTT();
  }
  mqtt.processPackets(10000);

  // Đọc dữ liệu từ cảm biến DHT
  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();
  float heatIndex = dht.computeHeatIndex(temperature, humidity, false);

  // Kiểm tra lỗi đọc dữ liệu từ cảm biến
  if (isnan(temperature) || isnan(humidity) || isnan(heatIndex)) {
    Serial.println("Failed to read from DHT sensor!");
  } else {
    // In dữ liệu cảm biến ra Serial Monitor
    Serial.print("Temperature: ");
    Serial.print(temperature);
    Serial.println(" °C");

    Serial.print("Humidity: ");
    Serial.print(humidity);
    Serial.println(" %");

    Serial.print("Heat Index: ");
    Serial.print(heatIndex);
    Serial.println(" °C");

    // Gửi dữ liệu lên Adafruit IO
    if (!temperatureFeed.publish(temperature)) {
      Serial.println("Failed to publish temperature");
    }
    if (!humidityFeed.publish(humidity)) {
      Serial.println("Failed to publish humidity");
    }
    if (!heatIndexFeed.publish(heatIndex)) {
      Serial.println("Failed to publish heat index");
    }
  }

  // Đọc trạng thái từ button1 (điều khiển LED)
  Adafruit_MQTT_Subscribe *subscription;
  while ((subscription = mqtt.readSubscription(10000))) {
    if (subscription == &button1Feed) {
      int lightState = atoi((char *)button1Feed.lastread);
      if (lightState == 1) {
        digitalWrite(LED_PIN, HIGH);
        Serial.println("Light ON");
      } else {
        digitalWrite(LED_PIN, LOW);
        Serial.println("Light OFF");
      }
    }

    // Đọc trạng thái từ button2 (điều khiển FAN)
    if (subscription == &button2Feed) {
      int fanState = atoi((char *)button2Feed.lastread);
      if (fanState == 1) {
        digitalWrite(FAN_PIN, HIGH);
        Serial.println("Fan ON");
      } else {
        digitalWrite(FAN_PIN, LOW);
        Serial.println("Fan OFF");
      }
    }
  }

  // Chờ 5 giây trước khi đọc lại dữ liệu từ cảm biến
  delay(10000);
}
