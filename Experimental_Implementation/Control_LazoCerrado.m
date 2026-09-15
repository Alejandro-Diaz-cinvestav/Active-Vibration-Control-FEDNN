%% Lector, Registrador y Controlador MRAC - Vicon DataStream SDK
clc; 

% Cargamos las matrices W2, Psi2, P y Gamma desde el archivo de la red offline.
load('Control.mat'); 
close all;

%Carga el SDK
fprintf('Cargando el SDK de Vicon...\n');
ruta_sdk = 'C:\Program Files\Vicon\DataStream SDK\Win64\dotNET';
addpath(ruta_sdk);
ruta_dll = fullfile(ruta_sdk, 'ViconDataStreamSDK_DotNET.dll');

if ~isfile(ruta_dll)
    error('No se encontró el archivo .dll en la ruta: %s', ruta_dll);
end

NET.addAssembly(ruta_dll);
vicon = ViconDataStreamSDK.DotNET.Client();

fprintf('Conectando a Nexus en localhost:801...\n');
vicon.Connect('localhost:801');

if ~vicon.IsConnected().Connected
    error('No se pudo conectar. Verifica que Nexus esté abierto y en modo Live.');
end

vicon.EnableMarkerData();
vicon.SetStreamMode(ViconDataStreamSDK.DotNET.StreamMode.ClientPull);
fprintf('Conexión con Vicon exitosa.\n');

% --- INICIALIZACIÓN DEL ARDUINO ---
fprintf('Conectando al Arduino Uno para control PWM...\n');
ard = arduino(); 
fprintf('¡Arduino conectado en el puerto %s!\n', ard.Port);

% --- PARÁMETROS DEL EXPERIMENTO ---
SubjectName = 'VigaMRAC'; 
N_nodos = 20;
tiempo_grabacion = 180; % Tiempo total
tiempo_activacion_control = 60; % Segundo  en el que entra el MRAC

% Preasignación de memoria (asumiendo ~100-150 FPS del MoCap)
max_muestras = tiempo_grabacion * 150; 
X_historial = zeros(N_nodos, max_muestras);
tiempo_historial = zeros(1, max_muestras);
X_posiciones = zeros(N_nodos, 1); 
u_historial=zeros(1,max_muestras);

% --- AUTO-CALIBRACIÓN DEL OFFSET ---
fprintf('Calibrando la posición cero. Por favor, NO toque la viga...\n');
muestras_calibracion = 200;
suma_posiciones = zeros(N_nodos, 1);

for c = 1:muestras_calibracion
    while vicon.GetFrame().Result ~= ViconDataStreamSDK.DotNET.Result.Success
    end
    for i = 1:N_nodos
        nombre_marcador = ['Nodo', num2str(i)];
        out = vicon.GetMarkerGlobalTranslation(SubjectName, nombre_marcador);
        if strcmp(char(out.Result.ToString()), 'Success') && ~out.Occluded
            suma_posiciones(21 - i) = suma_posiciones(21 - i) + out.Translation(1);
        end
    end
end
offset = suma_posiciones / muestras_calibracion;
fprintf('Calibración exitosa. El offset ha sido calculado.\n');

load('Ruta')
X_m = X_generada;
Theta = zeros(20,1);

fprintf('\nIniciando experimento físico por %d segundos...\n', tiempo_grabacion);
fprintf('NOTA: El control MRAC se activará en t = %d s\n\n', tiempo_activacion_control);

% --- BUCLE PRINCIPAL ---
contador = 1;
tStart = tic; % Inicia el cronómetro global del experimento
t_last = tic; % Inicia el cronómetro del integrador

while toc(tStart) < tiempo_grabacion
    
    while vicon.GetFrame().Result ~= ViconDataStreamSDK.DotNET.Result.Success
    end
    
    for i = 1:N_nodos
        nombre_marcador = ['Nodo', num2str(i)];
        out = vicon.GetMarkerGlobalTranslation(SubjectName, nombre_marcador);
        
        if strcmp(char(out.Result.ToString()), 'Success') && ~out.Occluded
            indice_matematico = 21 - i; 
            X_posiciones(indice_matematico) = out.Translation(1);
        end
    end
    
    % Quito el offset agregado por el origin de Vicon
    X = (X_posiciones - offset); 
    
    %=============================================================
    % 1.- Cálculo del tiempo transcurrido (dt)
    %=============================================================
    dt = toc(t_last);   
    t_last = tic;       
    tiempo_actual = toc(tStart);

     %=============================================================
    % 2.- Cálculo de la velocidad (Con Filtro)
    %=============================================================
    if contador == 1
        V = zeros(20,1);
        V_filtrada = zeros(20,1);
    else 
        V_cruda = (X - X_prev) / dt;
        alpha = 0.15; % Factor de suavizado (0 a 1). Menor valor = más suave.
        V_filtrada = (alpha * V_cruda) + ((1 - alpha) * V_filtrada);
        V = V_filtrada;
    end

    X_prev = X;
    X_full = [X; V];
    %=============================================================
    % 3.- Lógica de Activación del Control MRAC
    %=============================================================
    if tiempo_actual >= tiempo_activacion_control
        % --- FASE ACTIVA (t >= 30s) ---
        e = X - X_m(contador); 
        Phi = calcular_Phi(X);

        % Ley adaptación dinámica (FEDNN)
        sigmoide_V = 1 ./ (1 + exp(-Psi2 * X_full));
        B = W2 * sigmoide_V;

       % Dinámica de Theta
        acelerador_Gamma = 10;
        factor_error = 5;
        e_ponderado = e * factor_error;
        sigma_val = 0.05; 
        
        % Agregamos el término de fuga al final de la derivada
        Theta_dot = -(acelerador_Gamma * Gamma) * Phi * (e_ponderado' * P * B) - (sigma_val * Gamma * Theta);
        
        % Integrador de Euler
        Theta = Theta + (Theta_dot * dt);
        
        % Anti-Windup Duro
        % Forzamos a que los pesos de la red nunca pasen de un límite físico lógico (+/- 10)
        limite_Theta = 10.0;
        Theta = min(max(Theta, -limite_Theta), limite_Theta);

        % Esfuerzo de control
        u = Theta' * Phi;
    else
        % --- FASE PASIVA / PERTURBACIÓN (t < 30s) ---
        u = 0; % El controlador está apagado
        % Theta se mantiene en su condición inicial (zeros)
    end

    %=============================================================
    % 4. ENVÍO AL ARDUINO (Mapeo a PWM)
    %=============================================================
    ganancia_pwm = 1; 
    u_pwm = u * ganancia_pwm; 
    
    if u_pwm >= 0
        pwm_val = min(u_pwm, 1.0);
        writePWMDutyCycle(ard, 'D9', pwm_val);
        writePWMDutyCycle(ard, 'D10', 0);
    else
        pwm_val = min(abs(u_pwm), 1.0);
        writePWMDutyCycle(ard, 'D9', 0);
        writePWMDutyCycle(ard, 'D10', pwm_val);
    end

    % Guardar los datos en el historial para poder graficar
    tiempo_historial(contador) = tiempo_actual;
    u_historial(contador) =u;
    X_historial(:, contador) = X;
    
    contador = contador + 1;
end

% --- APAGADO SEGURO DEL HARDWARE ---
writePWMDutyCycle(ard, 'D9', 0);
writePWMDutyCycle(ard, 'D10', 0);
clear ard; % Libera el puerto serial

vicon.Disconnect();
fprintf('Experimento de 60s finalizado. Generando gráficas...\n');

% --- LIMPIEZA Y GRAFICACIÓN ---
X_historial = X_historial(:, 1:contador-1);
tiempo_historial = tiempo_historial(1:contador-1);

% --- Recortar el historial de control ---
u_historial = u_historial(1:contador-1);

% Generación de gráficas omitida  

% ==========================================================
% FUNCIONES LOCALES
% ==========================================================
function Phi_x = calcular_Phi(x)
    Phi_x = zeros(20,1);
    for i = 1:10 
        Phi_x(2*i-1) = sin(x(i))*cos(x(i));      %Componente impar
        Phi_x(2*i)   = cos(x(i))*sin(x(i));      %Componente par
    end
end