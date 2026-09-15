// Pines de control conectados al driver L298N
const int pinIN1 = 9;  // Controla la polaridad positiva (Atracción)
const int pinIN2 = 10; // Controla la polaridad negativa (Repulsión)

// Parámetros de la perturbación
const float omega = 5.0; // Frecuencia en rad/sec
const unsigned long tiempo_inicio = 13000; // 13 segundos en milisegundos

void setup() {
  // Configurar los pines PWM como salidas
  pinMode(pinIN1, OUTPUT);
  pinMode(pinIN2, OUTPUT);
  
  // Asegurarnos de que el electroimán inicie apagado
  analogWrite(pinIN1, 0);
  analogWrite(pinIN2, 0);
}

void loop() {
  // Obtener el tiempo actual de ejecución del Arduino
  unsigned long tiempo_actual = millis();

  // Verificar si ya pasaron los 13 segundos
  if (tiempo_actual >= tiempo_inicio) {
    
    // Calcular el tiempo efectivo de la perturbación en segundos
    float t = (tiempo_actual - tiempo_inicio) / 1000.0;
    
    // Calcular el valor de la onda senoidal: sin(5 * t)
    // Esto nos dará un valor entre -1.0 y 1.0
    float valor_seno = sin(omega * t);
    
    // Mapear la amplitud del seno (0 a 1) al rango PWM del Arduino (0 a 255)
    // Usamos abs() porque el PWM siempre debe ser positivo
    int senal_pwm = (int)(abs(valor_seno) * 255);
    
    // Lógica direccional "Push-Pull" (Atracción / Repulsión)
    if (valor_seno >= 0) {
      // Ciclo positivo de la onda
      analogWrite(pinIN1, senal_pwm);
      analogWrite(pinIN2, 0);
    } else {
      // Ciclo negativo de la onda
      analogWrite(pinIN1, 0);
      analogWrite(pinIN2, senal_pwm);
    }
    
  } else {
    // Si aún no llegamos a t=13s, mantenemos el electroimán apagado
    analogWrite(pinIN1, 0);
    analogWrite(pinIN2, 0);
  }
}