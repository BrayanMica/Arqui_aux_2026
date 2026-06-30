# config.py
import urllib.parse

# --- MONGODB ATLAS CONFIGURATION ---
_user = "JOSE2011"
_pass = urllib.parse.quote_plus("E7;*@#")
MONGO_URI = f"mongodb+srv://{_user}:{_pass}@cluster0.fxcf5g8.mongodb.net/?appName=Cluster0"
MONGO_DB_NAME = "Raspberry"

MONGO_COLLECTION_ARM64 = "arm64_resultados"
MONGO_COLLECTION_SENSORS = "lectura_sensores"
MONGO_COLLECTION_ACTUATORS = "registro_actuadores"
MONGO_COLLECTION_STATUS = "estado_sistema"
MONGO_COLLECTION_EVENTS = "eventos"
MONGO_COLLECTION_COMMANDS = "comandos"

# --- MQTT CONFIGURATION ---
MQTT_BROKER = "broker.emqx.io"
MQTT_PORT = 1883
MQTT_CLIENT_ID = "Raspberry_Invernadero_G3"
MQTT_ROOT_TOPIC = "invernaderoG32026"

# --- HARDWARE CONFIGURATION ---
PCF8591_ADDR = 0x48
RELE_ACTIVO_EN_HIGH = True

# --- GPIO PINS (BCM Mode) ---
PIN_DHT = 17

PIN_RELAY_PUMP = 22
PIN_RELAY_FAN = 23
PIN_BUZZER = 27

PIN_LED_WHITE = 24   
PIN_LED_GREEN = 6    
PIN_LED_YELLOW = 25  
PIN_LED_RED = 5      

PIN_BTN_MODE = 13     
PIN_BTN_PUMP = 26     
PIN_BTN_LIGHTS = 12    
PIN_BTN_SILENCE = 16  

INTERVAL_MQTT_PUB = 1.0
INTERVAL_MONGO_SAVE = 5.0

# --- CONSTANTES ELÉCTRICAS ---
V_REF = 5.0       
ADC_RES = 255.0   
R_LOAD_MQ2 = 5.0  
R0_MQ2 = 10.0     
LDR_A = 500.0     
LDR_B = -1.4      

# --- UMBRALES FÍSICOS ---
HUMEDAD_SUELO_SECO = 25.0       
HUMEDAD_SUELO_SATURADO = 80.0   
UMBRAL_GAS_ADVERTENCIA = 300.0  
UMBRAL_GAS_EMERGENCIA = 500.0   
UMBRAL_TEMPERATURA_VENTILADOR = 28.0 
UMBRAL_LUZ_BAJA = 500.0

# --- CONTROL MANUAL Y SEGURIDAD ---
DURACION_RIEGO = 10.0  
BUZZER_FREQUENCY = 1000  
BUZZER_DUTY_CYCLE = 50  