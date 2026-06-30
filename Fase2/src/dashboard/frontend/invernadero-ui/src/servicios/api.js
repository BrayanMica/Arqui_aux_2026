import mqtt from 'mqtt';

export const FRONTEND_CONFIG = {
  apiBaseUrl:
    import.meta.env.VITE_API_BASE_URL ||
    'http://localhost:5000/api/invernadero',
  mqttBrokerUrl:
    import.meta.env.VITE_MQTT_BROKER_URL ||
    'wss://broker.emqx.io:8084/mqtt',
  mqttTopicRoot:
    import.meta.env.VITE_MQTT_TOPIC_ROOT ||
    'invernaderoG32026',
  grafanaUrl:
    import.meta.env.VITE_GRAFANA_URL || ''
};

const API_BASE_URL = FRONTEND_CONFIG.apiBaseUrl;
const MQTT_BROKER_URL = FRONTEND_CONFIG.mqttBrokerUrl;
const MQTT_TOPIC_ROOT = FRONTEND_CONFIG.mqttTopicRoot;

const apiFetch = (url, options = {}) =>
  fetch(url, {
    ...options,
    headers: {
      ...options.headers,
      'ngrok-skip-browser-warning': 'true'
    }
  });

const mqttTopic = (...parts) => [
  MQTT_TOPIC_ROOT,
  ...parts
].join('/');

const normalizeStatus = (value) => {
  const status = value.toUpperCase().trim();
  return status === 'ALERTA' ? 'ADVERTENCIA' : status;
};

const parseSensorValue = (payload) => {
  const value = Number.parseFloat(payload);
  return Number.isFinite(value) ? value : null;
};

// Variable modular para reutilizar la conexión activa
let mqttClientGlobal = null;

// Objeto en memoria local para estructurar los datos
let estadoInvernadero = {
  status: 'NORMAL',
  temperature: null,
  humidity: null,
  soilMoistureArea: null,
  lightLevel: null,
  gasLevel: null,

  // Actuadores
  actuators: {
    riego_1: false,
    ventilador: false,
    luces: false,
    alarma: false
  },

  controlMode: 'AUTOMATICO'
};

/*
 * Se conecta por WebSockets al broker y ejecuta un callback cada vez que un sensor publica.
 */
export const conectarMqttInvernadero = (
  onDataUpdate,
  onConnectionChange
) => {

  // Evita duplicar conexiones si ya existe una activa
  if (!mqttClientGlobal) {
    mqttClientGlobal = mqtt.connect(MQTT_BROKER_URL);
  }

  mqttClientGlobal.on('connect', () => {
    console.log('¡Conectado a MQTTX mediante WebSockets!');
    onConnectionChange?.(true);

    mqttClientGlobal.subscribe(
      mqttTopic('estado', 'global'),
      (err) => {
        if (err) {
          console.error(
            'Error al suscribirse al estado global:',
            err
          );
        }
      }
    );

    mqttClientGlobal.subscribe(
      mqttTopic('sensores', '+'),
      (err) => {
        if (err) {
          console.error(
            'Error al suscribirse a los sensores:',
            err
          );
        }
      }
    );

    mqttClientGlobal.subscribe(
      mqttTopic('actuadores', '+'),
      (err) => {
        if (err) {
          console.error(
            'Error al suscribirse a los actuadores:',
            err
          );
        }
      }
    );

    mqttClientGlobal.subscribe(
      mqttTopic('control', 'remoto'),
      (err) => {
        if (err) {
          console.error(
            'Error al suscribirse al modo:',
            err
          );
        }
      }
    );

    console.log(
      'Escuchando sensores, actuadores y estado global...'
    );


  });

  mqttClientGlobal.on('message', (topic, message) => {

    const payload = message.toString();

    if (topic === mqttTopic('estado', 'global')) {

      estadoInvernadero.status =
        normalizeStatus(payload);

    } else if (topic === mqttTopic('control', 'remoto')) {

      estadoInvernadero.controlMode =
        payload.toUpperCase().trim();

    } else {

      const valor = parseSensorValue(payload);

      switch (topic) {

        // Sensores
        case mqttTopic('sensores', 'temperatura'):
          estadoInvernadero.temperature = valor;
          break;

        case mqttTopic('sensores', 'humedad_ambiente'):
          estadoInvernadero.humidity = valor;
          break;

        case mqttTopic('sensores', 'humedad_suelo_area1'):
          estadoInvernadero.soilMoistureArea = valor;
          break;

        case mqttTopic('sensores', 'luz'):
          estadoInvernadero.lightLevel = valor;
          break;

        case mqttTopic('sensores', 'gas'):
          estadoInvernadero.gasLevel = valor;
          break;

        // Actuadores
        case mqttTopic('actuadores', 'riego'):
        case mqttTopic('actuadores', 'riego_area1'):
          estadoInvernadero.actuators.riego_1 =
            payload.toUpperCase() === 'ON';
          break;

        case mqttTopic('actuadores', 'ventilador'):
          estadoInvernadero.actuators.ventilador =
            payload.toUpperCase() === 'ON';
          break;

        case mqttTopic('actuadores', 'luces'):
          estadoInvernadero.actuators.luces =
            payload.toUpperCase() === 'ON';
          break;

        case mqttTopic('actuadores', 'alarma'):
          estadoInvernadero.actuators.alarma =
            payload.toUpperCase() === 'ON';
          break;

        case mqttTopic('estado', 'modo'):
          estadoInvernadero.controlMode =
            payload.toUpperCase().trim();
          break;

        default:
          break;
      }
    }

    if (onDataUpdate) {
      onDataUpdate({
        ...estadoInvernadero
      });
    }
  });

  mqttClientGlobal.on('error', (err) => {
    console.error('Error en mqttClientGlobale MQTT:', err);
    onConnectionChange?.(false);
  });

  mqttClientGlobal.on('close', () => {
    onConnectionChange?.(false);
  });

  mqttClientGlobal.on('offline', () => {
    onConnectionChange?.(false);
  });

  return mqttClientGlobal; // Retornar el mqttClientGlobale para poder apagarlo desde el useEffect
};


// Obtiene los datos históricos y los transforma para la gráfica de Recharts
export const fetchHistoricalData = async (
  rango
) => {
  try {
    const response = await apiFetch(
      `${API_BASE_URL}/graficas?rango=${rango}`
    );

    const json = await response.json();

    console.log(json)

    const datos = json.datos || [];

    const graficas = datos.map(item => ({
      hora: new Date(item.fecha)
        .toLocaleTimeString([], {
          hour: "2-digit",
          minute: "2-digit"
        }),

      TEMPERATURA: item.TEMPERATURA,
      HUMEDAD_AMBIENTAL:
        item.HUMEDAD_AMBIENTAL,

      HUMEDAD_SUELO:
        item.HUMEDAD_SUELO,

      LUZ: item.LUZ,

      GAS: item.GAS
    }));

    return {
      charts: graficas
    };

  } catch (err) {
    console.error(err);

    return {
      charts: []
    };
  }
};


// Obtiene el historial estructurado de MongoDB y lo unifica para la tabla
export const fetchLogsData = async () => {
  try {
    const response = await apiFetch(
      `${API_BASE_URL}/historial`
    );

    if (!response.ok) {
      throw new Error(
        `Error en historial: ${response.status}`
      );
    }

    const apiData = await response.json();

    const logs = [];

    const formatter = new Intl.DateTimeFormat(
      "es-GT",
      {
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit"
      }
    );

    const formatDate = (timestamp) => {
      const d = new Date(timestamp);

      return {
        raw: d,
        text: formatter.format(d)
      };
    };

    // COMANDOS
    (apiData.ultimos_comandos || []).forEach(
      (item) => {
        const fecha = formatDate(
          item.timestamp
        );

        logs.push({
          id: item.id,
          timestamp: fecha.text,
          rawDate: fecha.raw,
          type: "COMANDO",
          message: `${item.COMANDO} (${item.ORIGEN})`
        });
      }
    );

    // ALERTAS
    (apiData.ultimas_alertas_eventos || []).forEach(
      (item) => {
        const fecha = formatDate(
          item.timestamp
        );

        logs.push({
          id: item.id,
          timestamp: fecha.text,
          rawDate: fecha.raw,
          type: item.TIPO,
          message: `Valor detectado: ${item.VALOR}`
        });
      }
    );

    // ESTADOS
    (apiData.ultimos_estados_sistema || []).forEach(
      (item) => {
        const fecha = formatDate(
          item.timestamp
        );

        logs.push({
          id: item.id,
          timestamp: fecha.text,
          rawDate: fecha.raw,
          type: item.ESTADO_GLOBAL,
          message: item.MOTIVO
        });
      }
    );

    // ACTUADORES
    (apiData.ultimas_activaciones_actuadores || []).forEach(
      (item) => {
        const fecha = formatDate(
          item.timestamp
        );

        logs.push({
          id: item.id,
          timestamp: fecha.text,
          rawDate: fecha.raw,
          type: "ACTUADOR",
          message:
            `${item.ACTUADOR} → ${item.ACCION} (${item.MODO})`
        });
      }
    );

    // ordenar por fecha descendente
    logs.sort(
      (a, b) => b.rawDate - a.rawDate
    );

    return logs.map(
      (log) => {
        const item = { ...log };
        delete item.rawDate;
        return item;
      }
    );

  } catch (error) {
    console.error(
      "Error cargando historial:",
      error
    );

    return [];
  }
};

/**
 * Función para publicar las acciones/comandos directamente al Broker
 */
export const publicarComandoMqtt =
  (
    actuador,
    estado
  ) => {

    if (
      !mqttClientGlobal ||
      !mqttClientGlobal.connected
    ) {
      return false;
    }

    let payload;

    switch (actuador) {

      case "riego_area1":
        payload = estado
          ? "RIEGO_ON"
          : "RIEGO_OFF";
        break;

      case "ventilador":
        payload = estado
          ? "VENTILADOR_ON"
          : "VENTILADOR_OFF";
        break;

      case "luces":
        payload = estado
          ? "LUCES_ON"
          : "LUCES_OFF";
        break;

      case "alarma":
        payload = estado
          ? "ALARMA_ON"
          : "ALARMA_OFF";
        break;

      default:
        return false;
    }

    mqttClientGlobal.publish(
      mqttTopic('control', 'remoto'),
      payload,
      { qos: 1 }
    );

    return true;
  };

// Modifica updateActuatorState para integrar la publicación ...
export const updateActuatorState = (actuatorId, newState) => {
  const apiActuatorNames = {
    riego_1: 'riego_area1',
    ventilador: 'ventilador',
    luces: 'luces',
    alarma: 'alarma'
  };

  const nombreActuador = apiActuatorNames[actuatorId];

  // Se envia por MQTT en tiempo real para que los actuadores reaccionen de inmediato
  return publicarComandoMqtt(nombreActuador, newState);
};

export const fetchArmAnalytics = async (
  columna
) => {
  try {
    const response = await apiFetch(
      `${API_BASE_URL}/arm64/${columna}`
    );

    if (!response.ok) {
      throw new Error("Error ARM");
    }

    return await response.json();

  } catch (error) {
    console.error(error);
    return null;
  }
};

export const publicarModoControl = (
  modo
) => {

  if (
    !mqttClientGlobal ||
    !mqttClientGlobal.connected
  ) {
    return false;
  }

  mqttClientGlobal.publish(
    mqttTopic('control', 'remoto'),
    modo,
    { qos: 1 }
  );

  return true;
};
