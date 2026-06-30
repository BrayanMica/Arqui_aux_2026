# hardware.py
import time
import math
import smbus
import board
import adafruit_dht
import RPi.GPIO as GPIO
import config

class GreenhouseHardware:
    def __init__(self, shared_data, on_hardware_change_callback=None):
        self.shared_data = shared_data
        self.on_hardware_change_callback = on_hardware_change_callback
        self.dht_device = None
        self.bus = None
        self.last_dht_read = 0

        # --- PARÁMETROS PANTALLA LCD I2C ---
        self.LCD_CHR = 1
        self.LCD_CMD = 0
        self.LCD_LINE_1 = 0x80
        self.LCD_LINE_2 = 0xC0
        self.LCD_BACKLIGHT = 0x08
        self.ENABLE = 0b00000100

        # --- CONTROL DE RIEGO MANUAL (TIMER) ---
        self.riego_timer_start = None
        self.riego_timer_duration = config.DURACION_RIEGO

        # --- CONTROL DE BUZZER CON PWM ---
        self.buzzer_pwm = None

        # --- BUFFER DE PANTALLA LCD ---
        self.last_lcd_line1 = ""
        self.last_lcd_line2 = ""
        
        # Estado previo de relés para detectar EMI y reiniciar LCD
        self.last_actuators_for_lcd = {"riego": "OFF", "ventilador": "OFF", "luces": "OFF"}

        self.setup_gpio()
        self.lcd_init()

    def setup_gpio(self):
        GPIO.setmode(GPIO.BCM)
        GPIO.setwarnings(False)
        
        # Inicialización del bus con manejo de reintentos
        try:
            self.bus = smbus.SMBus(1)
            time.sleep(0.1)
        except Exception as e:
            print(f"❌ [HARDWARE] Error al abrir el Bus I2C: {e}")

        # Configurar Salidas
        outputs = [
            config.PIN_RELAY_PUMP, config.PIN_RELAY_FAN,
            config.PIN_LED_WHITE, config.PIN_BUZZER,
            config.PIN_LED_GREEN, config.PIN_LED_YELLOW,
            config.PIN_LED_RED
        ]
        for pin in outputs:
            GPIO.setup(pin, GPIO.OUT)
            if config.RELE_ACTIVO_EN_HIGH:
                GPIO.output(pin, GPIO.LOW)
            else:
                GPIO.output(pin, GPIO.HIGH)

        # --- CONFIGURAR PWM PARA BUZZER (Mayor volumen) ---
        self.buzzer_pwm = GPIO.PWM(config.PIN_BUZZER, config.BUZZER_FREQUENCY)
        self.buzzer_pwm.start(0)  # Inicia con 0% (apagado)

        # Configurar Botones
        buttons = [config.PIN_BTN_MODE, config.PIN_BTN_PUMP, config.PIN_BTN_LIGHTS, config.PIN_BTN_SILENCE]
        for pin in buttons:
            GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)
            GPIO.add_event_detect(pin, GPIO.FALLING, callback=self.button_callback, bouncetime=350)

        # Inicializar DHT22
        try:
            pin_attr = getattr(board, f"D{config.PIN_DHT}")
            self.dht_device = adafruit_dht.DHT22(pin_attr)
        except Exception as e:
            print(f"⚠️ [HARDWARE] No se pudo cargar el módulo DHT: {e}")
            self.dht_device = None

    # --- TIMINGS OPTIMIZADOS PARA EVITAR SATURACIÓN Y PANTALLA BASURA ---
    def lcd_toggle_enable(self, bits):
        time.sleep(0.0005)
        self.bus.write_byte(0x27, bits | self.ENABLE)
        time.sleep(0.0005)
        self.bus.write_byte(0x27, bits & ~self.ENABLE)
        time.sleep(0.0005)

    def lcd_byte(self, bits, mode):
        addr = 0x27
        high_bits = mode | (bits & 0xF0) | self.LCD_BACKLIGHT
        low_bits = mode | ((bits << 4) & 0xF0) | self.LCD_BACKLIGHT
        try:
            self.bus.write_byte(addr, high_bits)
            self.lcd_toggle_enable(high_bits)
            self.bus.write_byte(addr, low_bits)
            self.lcd_toggle_enable(low_bits)
            time.sleep(0.001) # Pausa de cortesía para el controlador del LCD
        except OSError:
            pass

    def lcd_init(self):
        try:
            self.lcd_byte(0x33, self.LCD_CMD)
            self.lcd_byte(0x32, self.LCD_CMD)
            self.lcd_byte(0x06, self.LCD_CMD)
            self.lcd_byte(0x0C, self.LCD_CMD)
            self.lcd_byte(0x28, self.LCD_CMD)
            self.lcd_byte(0x01, self.LCD_CMD) # Limpiar pantalla
            time.sleep(0.05)
            print("📟 [HARDWARE] Pantalla LCD reinicializada correctamente (0x27)")
        except Exception:
            print("⚠️ [HARDWARE] Alerta: No se pudo comunicar con el LCD 0x27.")

    def lcd_message(self, message, line):
        message = message.ljust(16, " ")
        self.lcd_byte(line, self.LCD_CMD)
        for char in message[:16]:
            self.lcd_byte(ord(char), self.LCD_CHR)

    def button_callback(self, channel):
        """Manejo de botones físicos con lógica de seguridad"""
        
        # --- BOTÓN 1: Cambiar Modo (GPIO 13) ---
        if channel == config.PIN_BTN_MODE:
            actual = self.shared_data["control"]["modo"]
            nuevo = "MANUAL" if actual == "AUTOMATICO" else "AUTOMATICO"
            self.shared_data["control"]["modo"] = nuevo
            print(f"🔘 [BOTÓN 1] Modo cambiado a: {nuevo}")
            
            # Si cambia de MANUAL a AUTOMATICO, apagar luces manuales
            if nuevo == "AUTOMATICO":
                self.shared_data["actuadores"]["luces"] = "OFF"
                print(f"   └─ Luces apagadas (retornando control a sensores)")
            
            if self.on_hardware_change_callback:
                self.on_hardware_change_callback("control/manual", f"MODO_{nuevo}")

        # --- BOTÓN 2: Riego Manual (GPIO 26) ---
        elif channel == config.PIN_BTN_PUMP:
            if self.shared_data["control"]["modo"] == "MANUAL":
                # SEGURIDAD: Verificar que el suelo NO esté saturado
                humedad_suelo = self.shared_data["sensores"]["humedad_suelo"]
                if humedad_suelo is not None and humedad_suelo >= config.HUMEDAD_SUELO_SATURADO:
                    print(f"❌ [BOTÓN 2] Riego bloqueado: Suelo saturado ({humedad_suelo:.1f}% >= {config.HUMEDAD_SUELO_SATURADO}%)")
                    if self.on_hardware_change_callback:
                        self.on_hardware_change_callback("control/manual", "RIEGO_BLOQUEADO_SATURACION")
                    return
                
                # Activar riego con timer
                self.shared_data["actuadores"]["riego"] = "ON"
                self.riego_timer_start = time.time()
                print(f"🔘 [BOTÓN 2] Riego manual activado por {config.DURACION_RIEGO}s")
                if self.on_hardware_change_callback:
                        self.on_hardware_change_callback("control/manual", "RIEGO_ON")

        elif channel == config.PIN_BTN_LIGHTS:
            if self.shared_data["control"]["modo"] == "AUTOMATICO":
                print("🔘 Boton 3 ignorado: activa primero MODO REMOTO")
            else:
                estado_actual = self.shared_data["actuadores"]["luces"]
                nuevo_estado = "OFF" if estado_actual == "ON" else "ON"
                self.shared_data["actuadores"]["luces"] = nuevo_estado
                print(f"🔘 Botón Luces: Cambiado a {nuevo_estado}")
                if self.on_hardware_change_callback:
                    self.on_hardware_change_callback("control/manual", f"LUCES_{nuevo_estado}")

        elif channel == config.PIN_BTN_SILENCE:
            actual = self.shared_data["control"]["silenciado"]
            self.shared_data["control"]["silenciado"] = not actual
            print(f"🔘 Botón Silenciar Alarma: {'Activado' if not actual else 'Desactivado'}")
            
            # Apagar inmediatamente el buzzer si se está silenciando
            if not actual and self.buzzer_pwm is not None: 
                self.buzzer_pwm.ChangeDutyCycle(0)
            
            if self.on_hardware_change_callback:
                self.on_hardware_change_callback("control/manual", "SILENCIO_ON" if not actual else "SILENCIO_OFF")

    def read_sensors(self):
        def read_adc(canal):
            try:
                # Escribir canal a leer
                self.bus.write_byte(config.PCF8591_ADDR, 0x40 | canal)
                time.sleep(0.005) # Pequeña espera para estabilizar el ADC
                # El primer read_byte devuelve el dato anterior de la conversión, se ejecuta y se ignora
                self.bus.read_byte(config.PCF8591_ADDR)
                time.sleep(0.005)
                # El segundo read_byte ya trae el valor real actual del canal solicitado
                return self.bus.read_byte(config.PCF8591_ADDR)
            except Exception:
                return None

        # AIN0 = Luz (LDR)
        val_ldr = read_adc(0)
        if val_ldr is not None:
            if val_ldr == 0: luxes = 0.0
            else:
                v_out = (val_ldr * config.V_REF) / config.ADC_RES
                divisor = config.V_REF - v_out
                if divisor <= 0: luxes = 0.0
                else:
                    r_ldr = (10000.0 * v_out) / divisor
                    luxes = config.LDR_A * ((r_ldr / 1000.0) ** config.LDR_B) if r_ldr > 0 else 0.0
            self.shared_data["sensores"]["luz"] = round(luxes, 1)

        time.sleep(0.002) # Separación de ráfaga I2C entre canales

        
        # AIN1 = Humedad de suelo (% Volumétrico calibrado unificado)
        val_suelo = read_adc(1)
        if val_suelo is not None:
            adc_seco = 210.0
            adc_saturado = 60.0
            
            # Forzar límites para evitar porcentajes negativos o mayores a 100
            if val_suelo >= adc_seco: 
                porcentaje_suelo = 0.0
            elif val_suelo <= adc_saturado: 
                porcentaje_suelo = 100.0
            else:
                # Tu fórmula matemática original (Interpolación inversa limpia)
                porcentaje_suelo = ((adc_seco - val_suelo) / (adc_seco - adc_saturado)) * 100.0
            
            self.shared_data["sensores"]["humedad_suelo"] = round(porcentaje_suelo, 1)
        else:
            # Respaldo crítico: Si el bus falla un milisegundo, mantiene el valor anterior 
            # en lugar de dejarlo en None para que main.py NO se quede trabado en "INICIANDO"
            if self.shared_data["sensores"]["humedad_suelo"] is None:
                self.shared_data["sensores"]["humedad_suelo"] = 0.0
        

        # AIN2 = Gas (MQ-2)
        val_gas = read_adc(2)
        if val_gas is not None:
            if val_gas == 0: ppm = 0.0
            else:
                v_out = (val_gas * config.V_REF) / config.ADC_RES
                if v_out >= config.V_REF: v_out = config.V_REF - 0.01
                r_sensor = ((config.V_REF - v_out) * config.R_LOAD_MQ2) / v_out
                if r_sensor <= 0: ppm = 0.0
                else:
                    try: ppm = 1000.0 * math.pow(r_sensor / config.R0_MQ2, -2.1)
                    except: ppm = self.shared_data["sensores"]["gas"] or 0.0
            self.shared_data["sensores"]["gas"] = round(ppm, 1)

        # DHT22 (Cada 3 segundos) - No usa I2C, usa pin digital directo
        tiempo_actual = time.time()
        if tiempo_actual - self.last_dht_read >= 3:
            self.last_dht_read = tiempo_actual
            if self.dht_device:
                try:
                    self.shared_data["sensores"]["temperatura"] = self.dht_device.temperature
                    self.shared_data["sensores"]["humedad_ambiente"] = self.dht_device.humidity
                except RuntimeError: pass
                except Exception: pass

    def set_hardware_pin(self, pin, state_str):
        if config.RELE_ACTIVO_EN_HIGH:
            state = GPIO.HIGH if state_str == "ON" else GPIO.LOW
        else:
            state = GPIO.LOW if state_str == "ON" else GPIO.HIGH
        GPIO.output(pin, state)

    def apply_actuators(self):
        actuadores = self.shared_data["actuadores"]
        glob = self.shared_data["estado_global"]
        modo = self.shared_data["control"]["modo"]
        sens = self.shared_data["sensores"]
        
        # Lógica de Timer para Riego Manual
        if modo == "MANUAL" and actuadores["riego"] == "ON" and self.riego_timer_start is not None:
            if time.time() - self.riego_timer_start >= self.riego_timer_duration:
                self.shared_data["actuadores"]["riego"] = "OFF"
                self.riego_timer_start = None
                print("⏱️ Temporizador de riego manual finalizado. Bomba apagada.")
                if self.on_hardware_change_callback:
                    self.on_hardware_change_callback("control/manual", "RIEGO_OFF")

        # Recuperación de EMI (Interferencia Electromagnética):
        # Cuando un relé se activa/desactiva, el pico de voltaje puede "crashear" la pantalla LCD I2C.
        # Si detectamos un cambio en los relés, reiniciamos el controlador de la pantalla LCD.
        relay_changed = False
        for act in ["riego", "ventilador", "luces"]:
            if actuadores[act] != self.last_actuators_for_lcd[act]:
                relay_changed = True
                self.last_actuators_for_lcd[act] = actuadores[act]
                
        if relay_changed:
            time.sleep(0.05) # Esperar a que pase el pico de ruido eléctrico del relé
            self.lcd_init() # Reinicializar el controlador HD44780
            self.last_lcd_line1 = "" # Forzar redibujado de la línea 1
            self.last_lcd_line2 = "" # Forzar redibujado de la línea 2

        # Escritura de Pines Físicos
        self.set_hardware_pin(config.PIN_RELAY_PUMP, actuadores["riego"])
        self.set_hardware_pin(config.PIN_RELAY_FAN, actuadores["ventilador"])
        self.set_hardware_pin(config.PIN_LED_WHITE, actuadores["luces"])

        if actuadores["alarma"] == "OFF" or glob == "NORMAL" or self.shared_data["control"]["silenciado"]:
            if self.buzzer_pwm: self.buzzer_pwm.ChangeDutyCycle(0)
        else:
            fase = time.monotonic() % 1.0
            if glob == "EMERGENCIA":
                if self.buzzer_pwm:
                    self.buzzer_pwm.ChangeDutyCycle(config.BUZZER_DUTY_CYCLE if fase < 0.5 else 0)
            elif glob == "ADVERTENCIA":
                if self.buzzer_pwm:
                    self.buzzer_pwm.ChangeDutyCycle(config.BUZZER_DUTY_CYCLE if fase < 0.8 else 0)

        self.set_hardware_pin(config.PIN_LED_GREEN, "ON" if glob in ["NORMAL", "RIEGO_ACTIVO", "MODO_MANUAL"] else "OFF")
        self.set_hardware_pin(config.PIN_LED_YELLOW, "ON" if glob in ["ADVERTENCIA", "MODO_MANUAL"] else "OFF")
        self.set_hardware_pin(config.PIN_LED_RED, "ON" if glob == "EMERGENCIA" else "OFF")

        # Renderizado en pantalla con validaciones (con buffer para no bloquear I2C)
        modo_txt = "MAN" if modo == "MANUAL" else "AUT"
        line1 = f"M:{modo_txt} EST:{glob[:8]}"
        if line1 != self.last_lcd_line1:
            self.lcd_message(line1, self.LCD_LINE_1)
            self.last_lcd_line1 = line1
        
        t_str = f"{int(sens['temperatura'])}C" if sens["temperatura"] is not None else "--C"
        s_str = f"{int(sens['humedad_suelo'])}%" if sens["humedad_suelo"] is not None else "--%"
        g_str = f"{int(sens['gas'])}" if sens["gas"] is not None else "--"
        line2 = f"T:{t_str} S:{s_str} G:{g_str}"
        if line2 != self.last_lcd_line2:
            self.lcd_message(line2, self.LCD_LINE_2)
            self.last_lcd_line2 = line2

    def cleanup(self):
        if self.buzzer_pwm:
            self.buzzer_pwm.stop()
        GPIO.cleanup()
        if self.dht_device:
            try: self.dht_device.exit()
            except: pass
