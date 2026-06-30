import sys
import os
import time
import subprocess
from datetime import datetime, timezone

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

ARM64_PROGRAM = "./build/motor"


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

        try:
            self.mongo_client = MongoClient(config.MONGO_URI, serverSelectionTimeoutMS=5000)
            self.mongo_client.server_info()
            self.db = self.mongo_client[config.MONGO_DB_NAME]
            self.col_sensor_readings = self.db[config.MONGO_COLLECTION_SENSORS]
            self.col_actuators = self.db[config.MONGO_COLLECTION_ACTUATORS]
            self.col_status = self.db[config.MONGO_COLLECTION_STATUS]
            self.col_events = self.db[config.MONGO_COLLECTION_EVENTS]
            self.col_commands = self.db[config.MONGO_COLLECTION_COMMANDS]
            self.col_motor_arm = self.db[config.MONGO_COLLECTION_MOTOR_ARM]
            print("[MongoDB] Conectado exitosamente a Atlas.")
        except Exception as e:
            print(f"[MongoDB] Error de conexion: {e}")
            self.mongo_client = None

        self.last_actuators_state = {"riego": "OFF", "ventilador": "OFF", "luces": "OFF", "alarma": "OFF"}
        self.last_status_state = None

        self.mqtt_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, config.MQTT_CLIENT_ID)
        self.mqtt_client.on_connect = self.on_mqtt_connect
        self.mqtt_client.on_message = self.on_mqtt_message

        self.hw = GreenhouseHardware(self.shared_data, self.publish_hardware_event)

        self.last_mqtt_pub = time.time()
        self.last_mongo_save = time.time()

        self.arm64_process = None

    def start_arm64(self):
        self.arm64_process = subprocess.Popen(
            [ARM64_PROGRAM],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1
        )
        print("[ARM64] Motor vivo iniciado.")

    def query_arm64(self):
        sensores = self.shared_data["sensores"]
        if any(v is None for v in sensores.values()):
            return None

        if self.arm64_process is None or self.arm64_process.poll() is not None:
            print("[ARM64] Proceso no disponible, reiniciando...")
            self.start_arm64()

        gas = int(sensores["gas"])
        soil1 = int(sensores["humedad_suelo"])
        luz = int(sensores["luz"])
        temp = int(sensores["temperatura"])
        hum = int(sensores["humedad_ambiente"])

        line = f"{gas},{soil1},{luz},{temp},{hum}\n"

        try:
            self.arm64_process.stdin.write(line)
            self.arm64_process.stdin.flush()

            response = {}
            while True:
                resp_line = self.arm64_process.stdout.readline().strip()
                if resp_line == "END" or resp_line == "":
                    break
                if "=" in resp_line:
                    key, val = resp_line.split("=", 1)
                    response[key] = val

            return response
        except Exception as e:
            print(f"[ARM64] Error de comunicacion: {e}")
            return None

    def apply_arm64_action(self, action):
        self.shared_data["actuadores"]["riego"] = "OFF"
        self.shared_data["actuadores"]["ventilador"] = "OFF"
        self.shared_data["actuadores"]["luces"] = "OFF"
        self.shared_data["actuadores"]["alarma"] = "OFF"

        if action == "ALARM_ON":
            if not self.shared_data["control"]["silenciado"]:
                self.shared_data["actuadores"]["alarma"] = "ON"
            self.shared_data["actuadores"]["ventilador"] = "ON"
        elif action == "RIEGO_1_ON":
            self.shared_data["actuadores"]["riego"] = "ON"
        elif action == "LIGHT_ON":
            self.shared_data["actuadores"]["luces"] = "ON"
        elif action == "FAN_ON":
            self.shared_data["actuadores"]["ventilador"] = "ON"

    def determine_state(self, action):
        if action == "ALARM_ON":
            return "EMERGENCIA"
        elif action == "RIEGO_1_ON":
            return "RIEGO_ACTIVO"
        elif action == "FAN_ON":
            return "ADVERTENCIA"
        elif action == "LED_GREEN":
            return "NORMAL"
        return "NORMAL"

    def evaluate_with_arm64(self):
        sensores = self.shared_data["sensores"]
        if any(v is None for v in sensores.values()):
            self.shared_data["estado_global"] = "INICIANDO"
            return

        response = self.query_arm64()

        if response is None or response.get("STATUS") != "OK":
            return

        action = response.get("ACTION", "NONE")
        modo = self.shared_data["control"]["modo"]

        if modo == "AUTOMATICO":
            self.apply_arm64_action(action)
            self.shared_data["estado_global"] = self.determine_state(action)
            accion_ejecutada = action
            ignorada = False
        else:
            self.shared_data["estado_global"] = "MODO_MANUAL"
            self.shared_data["actuadores"]["alarma"] = "OFF"
            accion_ejecutada = "IGNORADA"
            ignorada = True

        self.save_arm64_result(response, accion_ejecutada, ignorada)

    def save_arm64_result(self, response, accion_ejecutada, ignorada):
        if not self.mongo_client:
            return
        try:
            sensores = self.shared_data["sensores"]
            indicadores = {}
            for key in ["GAS_AVG", "GAS_TREND", "GAS_AMP",
                        "SOIL1_AVG", "SOIL1_TREND", "SOIL1_AMP",
                        "LUZ_AVG", "LUZ_TREND", "LUZ_AMP",
                        "TEMP_AVG", "TEMP_TREND", "TEMP_AMP",
                        "HUM_AVG", "HUM_TREND", "HUM_AMP"]:
                val = response.get(key, "0")
                if val in ("UP", "DOWN", "STABLE"):
                    indicadores[key] = val
                else:
                    try:
                        indicadores[key] = int(val)
                    except ValueError:
                        indicadores[key] = val

            self.col_motor_arm.insert_one({
                "TIMESTAMP": datetime.now(timezone.utc),
                "SENSORES_RAW": {
                    "gas": int(sensores["gas"]),
                    "soil1": int(sensores["humedad_suelo"]),
                    "luz": int(sensores["luz"]),
                    "temp": int(sensores["temperatura"]),
                    "hum": int(sensores["humedad_ambiente"])
                },
                "INDICADORES_ARM64": indicadores,
                "DECISION_ARM64": response.get("ACTION", "NONE"),
                "REASON": response.get("REASON", "UNKNOWN"),
                "ACCION_EJECUTADA": accion_ejecutada,
                "MODO": self.shared_data["control"]["modo"],
                "IGNORADA_POR_MANUAL": ignorada
            })
        except Exception as e:
            print(f"[MongoDB] Error al guardar resultado ARM64: {e}")

    def publish_hardware_event(self, sub_topic, payload):
        if self.mqtt_client.is_connected():
            topic = f"{config.MQTT_ROOT_TOPIC}/{sub_topic}"
            self.mqtt_client.publish(topic, payload, retain=True)

    def on_mqtt_connect(self, client, userdata, flags, reason_code, properties):
        if not reason_code.is_failure:
            print("[MQTT] Conectado exitosamente al Broker.")
            client.subscribe(f"{config.MQTT_ROOT_TOPIC}/control/remoto")
            client.subscribe(f"{config.MQTT_ROOT_TOPIC}/control/manual")
        else:
            print(f"[MQTT] Error de conexion: {reason_code}")

    def on_mqtt_message(self, client, userdata, msg):
        try:
            payload = msg.payload.decode("utf-8").strip()

            if "control/remoto" in msg.topic:
                print(f"[MQTT] Control Remoto: {payload}")

                if self.mongo_client:
                    self.col_commands.insert_one({
                        "TIMESTAMP": datetime.now(timezone.utc),
                        "COMANDO": payload,
                        "ORIGEN": "MQTT_REMOTO"
                    })

                if payload == "MANUAL":
                    self.shared_data["control"]["modo"] = "MANUAL"
                    return
                elif payload == "AUTOMATICO":
                    self.shared_data["control"]["modo"] = "AUTOMATICO"
                    self.shared_data["actuadores"]["luces"] = "OFF"
                    return
                if payload == "ALARMA_ON":
                    self.shared_data["control"]["silenciado"] = False
                    
                    print("[MQTT] Silencio desactivado desde dashboard")
                    return
                elif payload == "ALARMA_OFF":
                    self.shared_data["control"]["silenciado"] = True
                    print("[MQTT] Alarma silenciada desde dashboard")
                    return

                if self.shared_data["control"]["modo"] == "MANUAL":
                    if payload == "RIEGO_ON": self.shared_data["actuadores"]["riego"] = "ON"
                    elif payload == "RIEGO_OFF": self.shared_data["actuadores"]["riego"] = "OFF"
                    elif payload == "VENTILADOR_ON": self.shared_data["actuadores"]["ventilador"] = "ON"
                    elif payload == "VENTILADOR_OFF": self.shared_data["actuadores"]["ventilador"] = "OFF"
                    elif payload == "LUCES_ON": self.shared_data["actuadores"]["luces"] = "ON"
                    elif payload == "LUCES_OFF": self.shared_data["actuadores"]["luces"] = "OFF"

            elif "control/manual" in msg.topic:
                print(f"[MQTT] Control Manual (Botones): {payload}")

                if self.mongo_client:
                    self.col_commands.insert_one({
                        "TIMESTAMP": datetime.now(timezone.utc),
                        "COMANDO": payload,
                        "ORIGEN": "BOTONES_FISICOS"
                    })

        except Exception as e:
            print(f"[MQTT] Error procesando mensaje: {e}")

    def publish_mqtt(self):
        sens = self.shared_data["sensores"]
        act = self.shared_data["actuadores"]
        print(f"[MQTT] Sensores -> Temp:{sens['temperatura']}C | Hum:{sens['humedad_ambiente']}% | Suelo:{sens['humedad_suelo']}% | Luz:{sens['luz']} | Gas:{sens['gas']}")
        print(f"  Actuadores -> Riego:{act['riego']} | Vent:{act['ventilador']} | Luces:{act['luces']} | Modo:{self.shared_data['control']['modo']}")

        if self.mqtt_client.is_connected():
            for sensor, valor in self.shared_data["sensores"].items():
                if valor is not None:
                    if sensor == "humedad_suelo":
                        topic_sensor = "humedad_suelo_area1"
                    else:
                        topic_sensor = sensor
                    self.mqtt_client.publish(f"{config.MQTT_ROOT_TOPIC}/sensores/{topic_sensor}", str(valor))

            for act_name, valor in self.shared_data["actuadores"].items():
                self.mqtt_client.publish(f"{config.MQTT_ROOT_TOPIC}/actuadores/{act_name}", str(valor))

            self.mqtt_client.publish(f"{config.MQTT_ROOT_TOPIC}/estado/global", self.shared_data["estado_global"])
            self.mqtt_client.publish(f"{config.MQTT_ROOT_TOPIC}/control/remoto", self.shared_data["control"]["modo"], retain=True)
            self.mqtt_client.publish(f"{config.MQTT_ROOT_TOPIC}/control/manual/modo", self.shared_data["control"]["modo"])

    def save_sensors_mongodb(self):
        if not self.mongo_client:
            return
        sensores = self.shared_data["sensores"]
        if any(v is None for v in sensores.values()):
            return

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
            print(f"[MongoDB] Error al guardar sensores: {e}")

    def check_and_log_actuators_mongodb(self):
        if not self.mongo_client:
            return
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
                    print(f"[MongoDB] Registro de actuador: {name} -> {current_state}")
                except Exception as e:
                    print(f"[MongoDB] Error en actuador {name}: {e}")
                self.last_actuators_state[key] = current_state

    def check_and_log_status_mongodb(self):
        if not self.mongo_client:
            return
        current_status = self.shared_data.get("estado_global", "INICIANDO")

        if self.last_status_state is None or current_status != self.last_status_state:
            try:
                motivo = "TODOS LOS SENSORES DENTRO DE RANGOS SEGUROS"
                if current_status == "EMERGENCIA":
                    motivo = "GAS POR ENCIMA DEL UMBRAL CRITICO"
                elif current_status == "ADVERTENCIA":
                    motivo = "TEMPERATURA O GAS FUERA DE RANGO OPTIMO"
                elif current_status == "RIEGO_ACTIVO":
                    motivo = "HUMEDAD DE SUELO BAJA"
                elif current_status == "MODO_MANUAL":
                    motivo = "CONTROL MANUAL ACTIVADO"

                self.col_status.insert_one({
                    "TIMESTAMP": datetime.now(timezone.utc),
                    "ESTADO_GLOBAL": current_status,
                    "MOTIVO": motivo
                })
                print(f"[MongoDB] Cambio de estado general a: {current_status}")
                self.check_and_log_event(current_status)
            except Exception as e:
                print(f"[MongoDB] Error al registrar estado: {e}")
            self.last_status_state = current_status

    def check_and_log_event(self, status):
        if status not in ["ADVERTENCIA", "EMERGENCIA", "RIEGO_ACTIVO", "NORMAL"]:
            return
        tipo_evento = "INFO"
        descripcion = "Operacion normal."
        valor = 0

        if status == "EMERGENCIA":
            tipo_evento = "EMERGENCIA"
            descripcion = "GAS CRITICO DETECTADO"
            valor = self.shared_data["sensores"]["gas"] or 0
        elif status == "ADVERTENCIA":
            tipo_evento = "ALERTA"
            if (self.shared_data["sensores"]["gas"] or 0) >= config.UMBRAL_GAS_ADVERTENCIA:
                descripcion = "ADVERTENCIA POR GAS"
                valor = self.shared_data["sensores"]["gas"] or 0
            else:
                descripcion = "TEMPERATURA ALTA"
                valor = self.shared_data["sensores"]["temperatura"] or 0
        elif status == "RIEGO_ACTIVO":
            tipo_evento = "ACTIVACION"
            descripcion = "RIEGO AUTOMATICO DISPARADO"
            valor = self.shared_data["sensores"]["humedad_suelo"] or 0
        elif status == "NORMAL":
            tipo_evento = "SISTEMA"
            descripcion = "RETORNO A PARAMETROS NORMALES"
            valor = 0

        try:
            self.col_events.insert_one({
                "TIMESTAMP": datetime.now(timezone.utc),
                "TIPO_EVENTO": tipo_evento,
                "DESCRIPCION": descripcion,
                "VALOR ": float(valor)
            })
        except Exception as e:
            print(f"[MongoDB] Error en evento: {e}")

    def start(self):
        try:
            self.start_arm64()
            self.mqtt_client.connect(config.MQTT_BROKER, config.MQTT_PORT, 60)
            self.mqtt_client.loop_start()
            print("Sistema IoT con motor ARM64 iniciado.")

            while self.running:
                current_time = time.time()
                self.hw.read_sensors()
                self.evaluate_with_arm64()
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
            print("\nDeteniendo script...")
        finally:
            self.running = False
            self.mqtt_client.loop_stop()
            self.mqtt_client.disconnect()
            if self.arm64_process:
                self.arm64_process.stdin.close()
                self.arm64_process.wait()
                print("[ARM64] Motor detenido.")
            if self.mongo_client:
                self.mongo_client.close()
            self.hw.cleanup()
            print("Finalizado.")


if __name__ == "__main__":
    app = GreenhouseIoT()
    app.start()
