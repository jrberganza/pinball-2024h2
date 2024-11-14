//sudo chmod a+rw /dev/ttyACM0
#include <Arduino_FreeRTOS.h>
#include <Servo.h>
#include <Arduino.h>

// ***** Variables y constantes generales de utilidad *****
const int IRPin2 = A1;
const int IRPin1 = A0;

const int servoLeftPin = 11;
const int servoRightPin = 5;

Servo servoLeft;
Servo servoRight;
long duration;
int initialAngle = 120;

// Ancho del escenario según los sensores infrarrojos
int stageLength = 28;

TaskHandle_t TaskSensor1;
TaskHandle_t TaskSensor2;
TaskHandle_t TaskServo;

// ***** Funciones de utilidad *****

// Retorna el tiempo en segundos desde que inició el programa
double clock() {
  return (double)(xTaskGetTickCount() * (1000 / configTICK_RATE_HZ)) / 1000.0d;
}

// Mide la distancia utilizando un promedio de 40 mediciones a lo largo de 800ms
// Automáticamente compensa los 10cm extra que se le deben agregar a los sensores infrarrojos
int loops = 40;
double medirDistancia(int IRPin) {
  int result = 0;
  for (int i = 0; i < loops; i++) {
    result += analogRead(IRPin);
    vTaskDelay(pdMS_TO_TICKS(20));
  }
  double prom = result / loops;
  double distance = 4800.0d / ((double)prom - 20.0d);
  return distance - 10;
}

// ***** Estado del predictor *****

// Según la predicción, en qué X va a terminar la pelota, y en qué tiempo (según clock()) va a llegar a esa X
int flipperPos = 0;
double flipperTime = -100;

// ***** Tasks *****

// Si la distancia medida por un sensor es menor al ancho del escenario, significa que un objeto (la pelota)
// ha pasado enfrente. Se registra la X y el tiempo en las variables dadas.
int registeredDistance1 = 47;
double registeredAt1 = 0;
void TaskReadSensor1(void *pvParameters) {
  for (;;) {
    int distance = medirDistancia(IRPin1);
    if (distance < stageLength) {
      registeredDistance1 = distance;
      registeredAt1 = clock();
      Serial.print("1: distance ");
      Serial.print(registeredDistance1);
      Serial.print(" cm, time ");
      Serial.print(registeredAt1);
      Serial.println(" s");
    }
    vTaskDelay(pdMS_TO_TICKS(1));
  }
}

int registeredDistance2 = 47;
double registeredAt2 = 0;
void TaskReadSensor2(void *pvParameters) {
  for (;;) {
    // Compensación por diferencias de fábrica entre el sensor superior y el inferior
    int distance = medirDistancia(IRPin2) * 31 / 29;
    if (distance < stageLength) {
      registeredDistance2 = distance;
      registeredAt2 = clock();

      // Velocidad calculada según el movimiento rectilíneo uniforme
      double xvel = (double)(registeredDistance2 - registeredDistance1) / (registeredAt2 - registeredAt1);
      // La distancia entre ambos sensores es 7cm
      double yvel = 7.0d / (registeredAt2 - registeredAt1);

      // La distancia de los sensores a las paletas es 10cm
      double flipperTimeOffset = 10 / yvel;

      flipperTime = clock() + flipperTimeOffset;
      flipperPos = (double)registeredDistance2 + xvel * flipperTimeOffset;

      Serial.print("2: distance ");
      Serial.print(registeredDistance1);
      Serial.print(" cm, time ");
      Serial.print(registeredAt1);
      Serial.print(" s, timeToHit ");
      Serial.print(flipperTimeOffset);
      Serial.print(" s, posToHit ");
      Serial.print(flipperPos);
      Serial.print(" cm, ");
      Serial.print("vel (");
      Serial.print(xvel);
      Serial.print(", ");
      Serial.print(yvel);
      Serial.println(")");
    }
    vTaskDelay(pdMS_TO_TICKS(1));
  }
}

double stageSectionLength = (double)stageLength / 4.0d;
void TaskControlServo(void *pvParameters) {
  for (;;) {
    double currentTime = clock();
    // La posición central de las paletas en 120 grados. Se mueve 70 grados a cada dirección para realizar los golpes
    // Se dan 0.5 segundos de golpe a las paletas
    if (flipperPos < stageSectionLength && currentTime - flipperTime > 0 && currentTime - flipperTime < 0.5) {
      moverServoLeft(120 - 70);
    } else if (flipperPos >= stageSectionLength && flipperPos < stageSectionLength*2 && currentTime - flipperTime > 0 && currentTime - flipperTime < 0.5) {
      moverServoLeft(120 + 70);
    } else {
      moverServoLeft(120);
    }
    if (flipperPos >= stageSectionLength*2 && flipperPos < stageSectionLength*3 && currentTime - flipperTime > 0 && currentTime - flipperTime < 0.5) {
      moverServoRight(120 - 70);
    } else if (flipperPos >= stageSectionLength*3 && currentTime - flipperTime > 0 && currentTime - flipperTime < 0.5) {
      moverServoRight(120 + 70);
    } else {
      moverServoRight(120);
    }
    vTaskDelay(pdMS_TO_TICKS(100));
  }
}

// ***** Movilidad de los Servo *****

void moverServoLeft(int nuevoAngulo) {
  int currentAngle = servoLeft.read();
  if (currentAngle != nuevoAngulo) {
      servoLeft.write(nuevoAngulo);
  }
}

void moverServoRight(int nuevoAngulo) {
  int currentAngle = servoRight.read();
  if (currentAngle != nuevoAngulo) {
      servoRight.write(nuevoAngulo);
  }
}

// ***** Task para depuración *****

void TaskPrinter(void *pvParameters) {
  for (;;) {
    // Completamente informativo
    // Serial.print("position: ");
    // Serial.print(flipperPos);
    // Serial.print(" cm, ");
    // Serial.print("time to hit: ");
    // Serial.print(flipperTime);
    // Serial.print(" s, ");
    // Serial.print("angle: ");
    // Serial.print(currentAngle);
    // Serial.println(" degrees");
    vTaskDelay(pdMS_TO_TICKS(500));
  }
}

void setup() {
  Serial.begin(9600);

  pinMode(IRPin1, INPUT);
  pinMode(IRPin2, INPUT);

  servoLeft.attach(servoLeftPin);
  servoRight.attach(servoRightPin);

  xTaskCreate(TaskReadSensor1, "Read Sensor 1", 128, NULL, 1, &TaskSensor1);
  xTaskCreate(TaskReadSensor2, "Read Sensor 2", 128, NULL, 1, &TaskSensor2);
  xTaskCreate(TaskControlServo, "Control Servo", 128, NULL, 1, &TaskServo);
  xTaskCreate(TaskPrinter, "Printer", 128, NULL, 1, NULL);
}

void loop() {}
