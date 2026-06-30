# main.py
import sys
import os
import time
from datetime import datetime, timezone

# Forzar la inclusión de la ruta local para importaciones limpias en la misma carpeta
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

if sys.platform.startswith('win'):
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')

import paho.mqtt.client as mqtt
from pymongo import MongoClient
import config
from hardware import GreenhouseHardware

class GreenhouseIoT:
    def __init__(self):
        self.running = True

        self.shared_data = {
            "sensores": {
                "temperatura": None,
                "humedad_ambiente": None,
                "humedad_suelo": None,
                "luz": None,
                "gas": None
            },
            "actuadores": {
                "riego": "OFF",
                "ventilador": "OFF",
                "luces": "OFF",
                "alarma": "OFF"
            },
            "control": {
                "modo": "AUTOMATICO", 
                "silenciado": False
            },
            "estado_global": "INICIANDO"
        }

        # --- MONGODB ATLAS SETUP ---
        try:
            self.mongo_client = MongoClient(config.MONGO_URI, serverSelectionTimeoutMS=5000)
            self.mongo_client.server_info()  
            self.db = self.mongo_client[config.MONGO_DB_NAME]
            
            self.col_sensor_readings = self.db[config.MONGO_COLLECTION_SENSORS]
            self.col_actuators = self.db[config.MONGO_COLLECTION_ACTUATORS]
            self.col_status = self.db[config.MONGO_COLLECTION_STATUS]
            self.col_events = self.db[config.MONGO_COLLECTION_EVENTS]
            self.col_commands = self.db[config.MONGO_COLLECTION_COMMANDS]
            print("✅ [MongoDB] Conectado exitosamente a Atlas.")
        except Exception as e:
            print(f"❌ [MongoDB] Error de conexión: {e}")
            self.mongo_client = None

        self.last_actuators_state = {"riego": "OFF", "ventilador": "OFF", "luces": "OFF", "alarma": "OFF"}
        self.last_status_state = None

        # --- MQTT SETUP ---
        self.mqtt_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, config.MQTT_CLIENT_ID)
        self.mqtt_client.on_connect = self.on_mqtt_connect
        self.mqtt_client.on_message = self.on_mqtt_message

        # --- HARDWARE SETUP ---
        self.hw = GreenhouseHardware(self.shared_data, self.publish_hardware_event)

        self.last_mqtt_pub = time.time()
        self.last_mongo_save = time.time()

    def publish_hardware_event(self, sub_topic, payload):
        if self.mqtt_client.is_connected():
            topic = f"{config.MQTT_ROOT_TOPIC}/{sub_topic}"
            self.mqtt_client.publish(topic, payload, retain=True)

    def on_mqtt_connect(self, client, userdata, flags, reason_code, properties):
        if not reason_code.is_failure:
            print(" [MQTT] Conectado exitosamente al Broker.")
            client.subscribe(f"{config.MQTT_ROOT_TOPIC}/control/remoto")
            client.subscribe(f"{config.MQTT_ROOT_TOPIC}/control/manual")
        else:
            print(f"❌ [MQTT] Error de conexión: {reason_code}")

    def on_mqtt_message(self, client, userdata, msg):
        try:
            payload = msg.payload.decode("utf-8").strip()
            
            # --- MENSAJES DE CONTROL REMOTO (Dashboard/App) ---
            if "control/remoto" in msg.topic:
                print(f"📥 [MQTT] Control Remoto: {payload}")
                
                if self.mongo_client:
                    self.col_commands.insert_one({
                        "TIMESTAMP": datetime.now(timezone.utc),
                        "COMANDO": payload,
                        "ORIGEN": "MQTT_REMOTO"
                    })

                # Cambios de modo globales
                if payload == "MANUAL":
                    self.shared_data["control"]["modo"] = "MANUAL"
                    return
                elif payload == "AUTOMATICO":
                    self.shared_data["control"]["modo"] = "AUTOMATICO"
                    # Resetear luces al volver a automático
                    self.shared_data["actuadores"]["luces"] = "OFF"
                    return

                # Ejecución de mandos manuales si corresponde
                if self.shared_data["control"]["modo"] == "MANUAL":
                    if payload == "RIEGO_ON": self.shared_data["actuadores"]["riego"] = "ON"
                    elif payload == "RIEGO_OFF": self.shared_data["actuadores"]["riego"] = "OFF"
                    elif payload == "VENTILADOR_ON": self.shared_data["actuadores"]["ventilador"] = "ON"
                    elif payload == "VENTILADOR_OFF": self.shared_data["actuadores"]["ventilador"] = "OFF"
                    elif payload == "LUCES_ON": self.shared_data["actuadores"]["luces"] = "ON"
                    elif payload == "LUCES_OFF": self.shared_data["actuadores"]["luces"] = "OFF"
            
            # --- MENSAJES DE CONTROL MANUAL (Botones Físicos) ---
            elif "control/manual" in msg.topic:
                print(f"📥 [MQTT] Control Manual (Botones): {payload}")
                
                if self.mongo_client:
                    self.col_commands.insert_one({
                        "TIMESTAMP": datetime.now(timezone.utc),
                        "COMANDO": payload,
                        "ORIGEN": "BOTONES_FISICOS"
                    })
                    
        except Exception as e:
            print(f"❌ [MQTT] Error procesando mensaje: {e}")

    def evaluate_state_machine(self):
        sensores = self.shared_data["sensores"]

        if any(v is None for v in sensores.values()):
            self.shared_data["estado_global"] = "INICIANDO"
            return

        # Prioridad Absoluta 1: Emergencia por Gas (Aplica en AUTOMÁTICO y MANUAL por seguridad)
        if sensores["gas"] >= config.UMBRAL_GAS_EMERGENCIA:
            self.shared_data["estado_global"] = "EMERGENCIA"
            self.shared_data["actuadores"]["alarma"] = "ON" if not self.shared_data["control"]["silenciado"] else "OFF"
            self.shared_data["actuadores"]["ventilador"] = "ON"
            self.shared_data["actuadores"]["riego"] = "OFF"
            return

        # Si está en modo Manual, saltarse la automatización de riego, clima y luces
        if self.shared_data["control"]["modo"] == "MANUAL":
            self.shared_data["estado_global"] = "MODO_MANUAL"
            self.shared_data["actuadores"]["alarma"] = "OFF"
            return

        # --- LÓGICA AUTOMÁTICA ---
        estado = "NORMAL"

        if sensores["humedad_suelo"] < config.HUMEDAD_SUELO_SECO:
            self.shared_data["actuadores"]["riego"] = "ON"
            estado = "RIEGO_ACTIVO"
        else:
            self.shared_data["actuadores"]["riego"] = "OFF"

        if sensores["temperatura"] >= config.UMBRAL_TEMPERATURA_VENTILADOR or sensores["gas"] >= config.UMBRAL_GAS_ADVERTENCIA:
            self.shared_data["actuadores"]["ventilador"] = "ON"
            if estado == "NORMAL": estado = "ADVERTENCIA"
        else:
            self.shared_data["actuadores"]["ventilador"] = "OFF"

        if sensores["luz"] < config.UMBRAL_LUZ_BAJA:
            self.shared_data["actuadores"]["luces"] = "ON"
        else:
            self.shared_data["actuadores"]["luces"] = "OFF"

        self.shared_data["actuadores"]["alarma"] = "OFF"
        self.shared_data["estado_global"] = estado
           
    def publish_mqtt(self):
        # Imprimir en consola lo que se está a punto de enviar
        sens = self.shared_data["sensores"]
        act = self.shared_data["actuadores"]
        print(f"📡 [MQTT] Publicando Sensores -> Temp:{sens['temperatura']}C | Hum:{sens['humedad_ambiente']}% | Suelo:{sens['humedad_suelo']}% | Luz:{sens['luz']} | Gas:{sens['gas']}")
        print(f"   └─ Actuadores -> Riego:{act['riego']} | Vent:{act['ventilador']} | Luces:{act['luces']} | Modo:{self.shared_data['control']['modo']}")
        
        if self.mqtt_client.is_connected():
            for sensor, valor in self.shared_data["sensores"].items():
                if valor is not None:
                    # --- CORRECCIÓN DE TÓPICO DE HUMEDAD DE SUELO ---
                    if sensor == "humedad_suelo":
                        topic_sensor = "humedad_suelo_area1"
                    else:
                        topic_sensor = sensor
                        
                    self.mqtt_client.publish(f"{config.MQTT_ROOT_TOPIC}/sensores/{topic_sensor}", str(valor))

            for act, valor in self.shared_data["actuadores"].items():
                self.mqtt_client.publish(f"{config.MQTT_ROOT_TOPIC}/actuadores/{act}", str(valor))

            # Cambios de Tópicos Solicitados
            self.mqtt_client.publish(f"{config.MQTT_ROOT_TOPIC}/estado/global", self.shared_data["estado_global"])
            self.mqtt_client.publish(f"{config.MQTT_ROOT_TOPIC}/control/remoto", self.shared_data["control"]["modo"], retain=True)
            # Publicar modo en control/manual también para sincronización de botones
            self.mqtt_client.publish(f"{config.MQTT_ROOT_TOPIC}/control/manual/modo", self.shared_data["control"]["modo"])


    def save_sensors_mongodb(self):
        if not self.mongo_client: return
        sensores = self.shared_data["sensores"]
        if any(v is None for v in sensores.values()): return 
            
        try:
            riego_val = 1 if self.shared_data["actuadores"]["riego"] == "ON" else 0
            self.col_sensor_readings.insert_one({
                "GAS": int(sensores["gas"]),
                "HUMEDAD_AMBIENTAL": int(sensores["humedad_ambiente"]),
                "HUMEDAD_SUELO": int(sensores["humedad_suelo"]),
                "TEMPERATURA": float(sensores["temperatura"]),  
                "TIMESTAMP": datetime.now(timezone.utc),
                "LUZ": int(sensores["luz"]),
                "RIEGO": riego_val
            })
        except Exception as e:
            print(f"❌ [MongoDB] Error al guardar sensores: {e}")

    def check_and_log_actuators_mongodb(self):
        if not self.mongo_client: return
        actuator_mappings = {"riego": "BOMBA_AGUA", "ventilador": "VENTILADOR", "luces": "LUCES", "alarma": "ALARMA"}
        for key, name in actuator_mappings.items():
            current_state = self.shared_data["actuadores"].get(key, "OFF")
            if current_state != self.last_actuators_state[key]:
                try:
                    self.col_actuators.insert_one({
                        "ACCION": current_state,
                        "ACTUADOR": name,
                        "MODO": self.shared_data["control"]["modo"],
                        "TIMESTAMP": datetime.now(timezone.utc)
                    })
                    print(f" [MongoDB] Registro de actuador: {name} -> {current_state}")
                except Exception as e:
                    print(f"❌ [MongoDB] Error en actuador {name}: {e}")
                self.last_actuators_state[key] = current_state

    def check_and_log_status_mongodb(self):
        if not self.mongo_client: return
        current_status = self.shared_data.get("estado_global", "INICIANDO")
        
        if self.last_status_state is None or current_status != self.last_status_state:
            try:
                motivo = "TODOS LOS SENSORES DENTRO DE RANGOS SEGUROS"
                if current_status == "EMERGENCIA": motivo = "GAS POR ENCIMA DEL UMBRAL CRITICO"
                elif current_status == "ADVERTENCIA": motivo = "TEMPERATURA O GAS FUERA DE RANGO OPTIMO"
                elif current_status == "RIEGO_ACTIVO": motivo = "HUMEDAD DE SUELO BAJA"
                elif current_status == "MODO_MANUAL": motivo = "CONTROL MANUAL ACTIVADO"

                self.col_status.insert_one({
                    "TIMESTAMP": datetime.now(timezone.utc),
                    "ESTADO_GLOBAL": current_status,
                    "MOTIVO": motivo
                })
                print(f"💾 [MongoDB] Cambio de estado general a: {current_status}")
                self.check_and_log_event(current_status)
            except Exception as e:
                print(f"❌ [MongoDB] Error al registrar estado: {e}")
            self.last_status_state = current_status

    def check_and_log_event(self, status):
        if status not in ["ADVERTENCIA", "EMERGENCIA", "RIEGO_ACTIVO", "NORMAL"]: return
        tipo_evento = "INFO"; descripcion = "Operación normal."; valor = 0
        
        if status == "EMERGENCIA":
            tipo_evento = "EMERGENCIA"; descripcion = "GAS CRITICO DETECTADO"; valor = self.shared_data["sensores"]["gas"] or 0
        elif status == "ADVERTENCIA":
            tipo_evento = "ALERTA"
            if (self.shared_data["sensores"]["gas"] or 0) >= config.UMBRAL_GAS_ADVERTENCIA:
                descripcion = "ADVERTENCIA POR GAS"; valor = self.shared_data["sensores"]["gas"] or 0
            else:
                descripcion = "TEMPERATURA ALTA"; valor = self.shared_data["sensores"]["temperatura"] or 0
        elif status == "RIEGO_ACTIVO":
            tipo_evento = "ACTIVACION"; descripcion = "RIEGO AUTOMATICO DISPARADO"; valor = self.shared_data["sensores"]["humedad_suelo"] or 0
        elif status == "NORMAL":
            tipo_evento = "SISTEMA"; descripcion = "RETORNO A PARAMETROS NORMALES"; valor = 0

        try:
            self.col_events.insert_one({
                "TIMESTAMP": datetime.now(timezone.utc),
                "TIPO_EVENTO": tipo_evento,
                "DESCRIPCION": descripcion,
                "VALOR ": float(valor)
            })
        except Exception as e:
            print(f"❌ [MongoDB] Error en evento: {e}")

    def start(self):
        try:
            self.mqtt_client.connect(config.MQTT_BROKER, config.MQTT_PORT, 60)
            self.mqtt_client.loop_start()
            print(" Sistema IoT Iniciado de manera Asíncrona.")

            while self.running:
                current_time = time.time()
                self.hw.read_sensors()
                self.evaluate_state_machine()
                self.hw.apply_actuators()
                self.check_and_log_actuators_mongodb()
                self.check_and_log_status_mongodb()

                if current_time - self.last_mqtt_pub >= config.INTERVAL_MQTT_PUB:
                    self.publish_mqtt()
                    self.last_mqtt_pub = current_time

                if current_time - self.last_mongo_save >= config.INTERVAL_MONGO_SAVE:
                    self.save_sensors_mongodb()
                    self.last_mongo_save = current_time

                time.sleep(0.01)
        except KeyboardInterrupt:
            print("\n Deteniendo script...")
        finally:
            self.running = False
            self.mqtt_client.loop_stop()
            self.mqtt_client.disconnect()
            if self.mongo_client: self.mongo_client.close()
            self.hw.cleanup()
            print("🏁 Finalizado.")

if __name__ == "__main__":
    app = GreenhouseIoT()
    app.start()
