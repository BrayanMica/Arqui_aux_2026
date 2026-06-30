const API_BASE_URL = 'http://localhost:5000/api/invernadero';

import mqtt from 'mqtt';

const MQTT_BROKER_URL = 'wss://broker.emqx.io:8084/mqtt';

// Variable modular para reutilizar la conexión activa
let mqttClientGlobal = null;

// Objeto en memoria local para estructurar los datos
let estadoInvernadero = {
  status: 'NORMAL',
  temperature: 0,
  humidity: 0,
  soilMoistureArea: 0,
  lightLevel: 0,
  gasLevel: 0,

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
export const conectarMqttInvernadero = (onDataUpdate) => {

  // Evita duplicar conexiones si ya existe una activa
  if (!mqttClientGlobal) {
    mqttClientGlobal = mqtt.connect(MQTT_BROKER_URL);
  }

  mqttClientGlobal.on('connect', () => {
    console.log('¡Conectado a MQTTX mediante WebSockets!');

    mqttClientGlobal.subscribe(
      'invernaderoG32026/estado/global',
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
      'invernaderoG32026/sensores/+',
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
      'invernaderoG32026/actuadores/+',
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
      'invernaderoG32026/control/remoto',
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

    if (topic === 'invernaderoG32026/estado/global') {

      estadoInvernadero.status =
        payload.toUpperCase().trim();

    } else if (topic === 'invernaderoG32026/control/remoto') {

      estadoInvernadero.controlMode =
        payload.toUpperCase().trim();

    } else {

      const valor = parseFloat(payload) || 0;

      switch (topic) {

        // Sensores
        case 'invernaderoG32026/sensores/temperatura':
          estadoInvernadero.temperature = valor;
          break;

        case 'invernaderoG32026/sensores/humedad_ambiente':
          estadoInvernadero.humidity = valor;
          break;

        case 'invernaderoG32026/sensores/humedad_suelo_area1':
          estadoInvernadero.soilMoistureArea = valor;
          break;

        case 'invernaderoG32026/sensores/luz':
          estadoInvernadero.lightLevel = valor;
          break;

        case 'invernaderoG32026/sensores/gas':
          estadoInvernadero.gasLevel = valor;
          break;

        // Actuadores
        case 'invernaderoG32026/actuadores/riego':
          estadoInvernadero.actuators.riego_1 =
            payload.toUpperCase() === 'ON';
          break;

        case 'invernaderoG32026/actuadores/ventilador':
          estadoInvernadero.actuators.ventilador =
            payload.toUpperCase() === 'ON';
          break;

        case 'invernaderoG32026/actuadores/luces':
          estadoInvernadero.actuators.luces =
            payload.toUpperCase() === 'ON';
          break;

        case 'invernaderoG32026/actuadores/alarma':
          estadoInvernadero.actuators.alarma =
            payload.toUpperCase() === 'ON';
          break;

        case 'invernaderoG32026/estado/modo':
          estadoInvernadero.actuators.alarma =
            estadoInvernadero.estado = valor;
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
  });

  return mqttClientGlobal; // Retornar el mqttClientGlobale para poder apagarlo desde el useEffect
};


// Obtiene los datos históricos y los transforma para la gráfica de Recharts
export const fetchHistoricalData = async (
  rango
) => {
  try {
    const response = await fetch(
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
    const response = await fetch(
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
      ({ rawDate, ...rest }) => rest
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

    let payload = "";

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

      default:
        return false;
    }

    mqttClientGlobal.publish(
      "invernaderoG32026/control/remoto",
      payload,
      { qos: 1 }
    );

    return true;
  };

// Modifica updateActuatorState para integrar la publicación ...
export const updateActuatorState = (actuatorId, newState) => {
  const apiActuatorNames = {
    riego_1: 'riego_area1',
    riego_2: 'riego_area2',
    ventilador: 'ventilador',
    luces: 'luces',
    alarma: 'alarma'
  };

  const nombreActuador = apiActuatorNames[actuatorId];

  // Se envia por MQTT en tiempo real para que los actuadores reaccionen de inmediato
  publicarComandoMqtt(nombreActuador, newState);
};

export const fetchArmAnalytics = async (
  columna
) => {
  try {
    const response = await fetch(
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
    "invernaderoG32026/control/remoto",
    modo,
    { qos: 1 }
  );

  return true;
};