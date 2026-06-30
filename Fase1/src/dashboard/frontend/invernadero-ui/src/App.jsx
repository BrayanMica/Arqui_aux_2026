import { useState, useEffect } from 'react';
import {
  Thermometer, Droplets, Sun, Wind, Bell, AlertTriangle,
  CheckCircle, Server, Activity, Database, Flame, Power
} from 'lucide-react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ReferenceLine } from 'recharts';

// Importación de componentes modularizados
import { MetricCard } from './componentes/MetricCard';
import { ActuatorToggle } from './componentes/ActuatorToggle';

import { ArmMetric } from './componentes/ArmMetric';
import { GraphCard } from './componentes/GraphCard';

// Importación del servicio de endpoints
import {
  conectarMqttInvernadero,
  fetchHistoricalData,
  fetchLogsData,
  updateActuatorState,
  fetchArmAnalytics,
  publicarModoControl
} from './servicios/api';

import ArmAnalytics
  from './componentes/ArmAnalytics';

function App() {
  const [data, setData] = useState(null);
  const [errorConexion, setErrorConexion] = useState(false);

  const [selectedColumn,
    setSelectedColumn] =
    useState("TEMPERATURA");

  const [armData,
    setArmData] =
    useState(null);

  const [controlMode, setControlMode] = useState("AUTOMATICO");

  const cambiarModo = (modo) => {

    setControlMode(modo);

    publicarModoControl(modo);
  };

  useEffect(() => {
    let mqttClient = null;

    const inicializarSistema = async () => {
      try {
        // Traemos lo histórico y los logs (HTTP) en paralelo al arrancar la app
        const [analytics, eventLogs] = await Promise.all([
          fetchHistoricalData('1h'),
          fetchLogsData()
        ]);

        // Inicializamos el estado base de la interfaz
        setData({
          current: {
            status: 'NORMAL',
            temperature: 0,
            humidity: 0,
            soilMoistureArea: 0,
            lightLevel: 0,
            gasLevel: 0,
          },
          actuators: {
            riego_1: { active: false },
            ventilador: { active: false },
            luces: { active: false },
            alarma: { active: false }
          },
          charts: analytics?.charts || [],
          armAnalysis: {
          },
          logs: eventLogs
        });
        setErrorConexion(false);

        // Activamos la escucha en tiempo real por MQTTX
        mqttClient = conectarMqttInvernadero(
          (nuevoEstado) => {

            setControlMode(
              nuevoEstado.controlMode
            );


            setData(prev => {
              if (!prev) return prev;

              return {
                ...prev,

                current: {
                  ...prev.current,

                  status: nuevoEstado.status,
                  temperature: nuevoEstado.temperature,
                  humidity: nuevoEstado.humidity,
                  soilMoistureArea:
                    nuevoEstado.soilMoistureArea,
                  lightLevel:
                    nuevoEstado.lightLevel,
                  gasLevel:
                    nuevoEstado.gasLevel
                },

                actuators: {
                  riego_1: {
                    active:
                      nuevoEstado.actuators.riego_1
                  },

                  ventilador: {
                    active:
                      nuevoEstado.actuators.ventilador
                  },

                  luces: {
                    active:
                      nuevoEstado.actuators.luces
                  },

                  alarma: {
                    active:
                      nuevoEstado.actuators.alarma
                  }
                }
              };
            });

          }
        );

      } catch (error) {
        console.error("Error cargando los servicios iniciales:", error);
        setErrorConexion(true);
      }
    };

    inicializarSistema();

    // Cuando el usuario cierre o recargue la pestaña, cerramos la sesión de MQTT limpia
    return () => {
      if (mqttClient) {
        mqttClient.end();
      }
    };
  }, []);

  useEffect(() => {

    const loadArm = async () => {

      const data =
        await fetchArmAnalytics(
          selectedColumn
        );

      setArmData(data);
    };

    loadArm();

  }, [selectedColumn]);

  //Manejador para encender/apagar actuadores físicos
  const toggleActuator = (actuatorKey) => {
    if (!data) return;

    const targetActuator = data.actuators[actuatorKey];
    const targetNewState = !targetActuator.active;

    // Se actualiza el estado de React inmediatamente
    setData(prev => ({
      ...prev,
      actuators: {
        ...prev.actuators,
        [actuatorKey]: { ...prev.actuators[actuatorKey], active: targetNewState }
      }
    }));

    // Se dispara el comando por MQTT de forma directa
    updateActuatorState(actuatorKey, targetNewState);
  };

  const getStatusColor = (status) => {
    switch (status?.toUpperCase()) {
      case 'NORMAL': return 'bg-emerald-500 text-white';
      case 'ALERTA': return 'bg-amber-500 text-white';
      case 'EMERGENCIA': return 'bg-rose-500 text-white';
      default: return 'bg-slate-500 text-white';
    }
  };

  // Pantalla de carga inicial mientras se resuelve la primera petición
  if (!data) {
    return (
      <div className="min-h-screen bg-slate-50 flex flex-col items-center justify-center text-slate-500 gap-3">
        <Activity className="animate-spin w-8 h-8 text-emerald-500" />
        <p className="font-semibold">Conectando con el servidor Node.js y la Base de Datos...</p>
        {errorConexion && (
          <span className="text-xs text-rose-500 font-medium">
            Verifica que tu API esté corriendo en el puerto 5000 y CORS esté activo.
          </span>
        )}
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-50 text-slate-800 font-sans">

      {/* Encabezado */}
      <header className="bg-white border-b border-slate-200 shadow-sm sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Droplets className="text-emerald-500 w-8 h-8" />
            <h1 className="text-xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-emerald-600 to-teal-800">
              Invernadero Inteligente IoT
            </h1>
          </div>
          <div className={`px-4 py-1.5 rounded-full flex items-center gap-2 text-sm font-semibold shadow-sm transition-colors duration-500 ${getStatusColor(data.current.status)}`}>
            {data.current.status === 'NORMAL' && <CheckCircle className="w-4 h-4" />}
            {data.current.status === 'ALERTA' && <AlertTriangle className="w-4 h-4" />}
            {data.current.status === 'EMERGENCIA' && <Flame className="w-4 h-4" />}
            SISTEMA: {data.current.status}
          </div>
        </div>
      </header>

      {/* Contenido Principal */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-8">

        {/* Sección superior: Tarjetas de Sensores y Panel de Control */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">

          {/* Bloque de Monitoreo */}
          <div className="lg:col-span-2 space-y-4">
            <h2 className="text-lg font-bold flex items-center gap-2 text-slate-700">
              <Activity className="w-5 h-5 text-blue-500" /> Monitoreo en Tiempo Real
            </h2>
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
              <MetricCard title="Temperatura" value={Number(data.current.temperature).toFixed(1)} unit="°C" icon={<Thermometer className="w-6 h-6 text-orange-500" />} color="border-orange-200 bg-orange-50" />
              <MetricCard title="Humedad Amb." value={Number(data.current.humidity).toFixed(1)} unit="%" icon={<Wind className="w-6 h-6 text-blue-500" />} color="border-blue-200 bg-blue-50" />
              <MetricCard title="Hum. Suelo" value={Number(data.current.soilMoistureArea).toFixed(1)} unit="%" icon={<Droplets className="w-6 h-6 text-sky-500" />} color="border-sky-200 bg-sky-50" />
              <MetricCard title="Luz (LDR)" value={Number(data.current.lightLevel).toFixed(0)} unit=" lx" icon={<Sun className="w-6 h-6 text-amber-500" />} color="border-amber-200 bg-amber-50" />
            </div>

            {/* Monitor de Monóxido / Humo */}
            <div className={`p-4 rounded-xl border-l-4 flex items-center justify-between transition-all ${data.current.gasLevel > 500 ? 'border-rose-500 bg-rose-50' : 'border-slate-300 bg-white shadow-sm'}`}>
              <div className="flex items-center gap-3">
                <div className={`p-3 rounded-full ${data.current.gasLevel > 500 ? 'bg-rose-200 text-rose-600' : 'bg-slate-100 text-slate-500'}`}><Flame className="w-6 h-6" /></div>
                <div>
                  <p className="text-sm font-semibold text-slate-500">Nivel de Gas / Humo (MQ)</p>
                  <p className="text-2xl font-bold text-slate-800">{data.current.gasLevel} PPM</p>
                </div>
              </div>
              <div className="text-right">
                <span className={`text-sm font-semibold px-3 py-1 rounded-full ${data.current.gasLevel > 500 ? 'bg-rose-500 text-white' : 'bg-emerald-100 text-emerald-700'}`}>
                  {data.current.gasLevel > 500 ? 'PELIGRO' : 'SEGURO'}
                </span>
              </div>
            </div>
          </div>


          {/* Bloque de Control Interno (Actuadores) */}
          <div className="space-y-4">
            <h2 className="text-lg font-bold flex items-center gap-2 text-slate-700">
              <Power className="w-5 h-5 text-emerald-500" /> Panel de Control
            </h2>
            <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-5 space-y-4">

              <div className="bg-slate-50 rounded-xl p-4">

                <h3 className="font-semibold mb-3">
                  Modo de Operación
                </h3>

                <div className="flex gap-4">

                  <button
                    onClick={() =>
                      cambiarModo(
                        "AUTOMATICO"
                      )
                    }
                    className={`
                flex-1 py-2 rounded-lg
                ${controlMode ===
                        "AUTOMATICO"
                        ? "bg-green-600 text-white"
                        : "bg-white border"
                      }
            `}
                  >
                    Automático
                  </button>

                  <button
                    onClick={() =>
                      cambiarModo(
                        "MANUAL"
                      )
                    }
                    className={`
                flex-1 py-2 rounded-lg
                ${controlMode ===
                        "MANUAL"
                        ? "bg-blue-600 text-white"
                        : "bg-white border"
                      }
            `}
                  >
                    Manual
                  </button>

                </div>

              </div>




              {/* Riego 1 */}
              <ActuatorToggle
                label="Sistema de Riego 1"
                state={data.actuators.riego_1.active}
                onChange={() => toggleActuator('riego_1')}
                subtitle={data.actuators.riego_1.mode === 'auto' ? 'Modo Automático' : 'Modo Manual'}
                disabled={
                  controlMode ===
                  "AUTOMATICO"
                }
              />

              <ActuatorToggle label="Ventilador / Extractor" state={data.actuators.ventilador.active} onChange={() => toggleActuator('ventilador')} disabled={
                controlMode ===
                "AUTOMATICO"
              } />
              <ActuatorToggle label="Iluminación LEDs" state={data.actuators.luces.active} onChange={() => toggleActuator('luces')} disabled={
                controlMode ===
                "AUTOMATICO"
              } />

              <div className="pt-4 border-t border-slate-100">
                <button
                  onClick={() => toggleActuator('alarma')}
                  disabled={controlMode === "AUTOMATICO"}
                  className={`w-full py-2.5 rounded-lg flex items-center justify-center gap-2 font-semibold transition-colors${controlMode === "AUTOMATICO"
                    ? "bg-slate-200 text-slate-400 cursor-not-allowed"
                    : data.actuators.alarma.active
                      ? "bg-rose-100 text-rose-700 hover:bg-rose-200"
                      : "bg-slate-100 text-slate-600 hover:bg-slate-200"
                    }`}
                >
                  <Bell className="w-5 h-5" />

                  {controlMode === "AUTOMATICO"
                    ? "Bloqueado (Modo Automático)"
                    : data.actuators.alarma.active
                      ? "SILENCIAR ALARMA"
                      : "Alarma Inactiva"}
                </button>
              </div>


            </div>
          </div>
        </div>

        {/* Sección de Analítica y Gráficas de Rendimiento */}
        <div className="space-y-4">

          <h2 className="text-lg font-bold flex items-center gap-2">
            <Activity className="w-5 h-5 text-blue-500" />
            Gráficas (Datos de la última hora)
          </h2>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">

            <GraphCard
              titulo="Temperatura"
              color="#f97316"
              data={data.charts}
              dataKey="TEMPERATURA"
              unidad="°C"
            />

            <GraphCard
              titulo="Humedad Aire"
              color="#3b82f6"
              data={data.charts}
              dataKey="HUMEDAD_AMBIENTAL"
              unidad="%"
            />

            <GraphCard
              titulo="Humedad Suelo"
              color="#06b6d4"
              data={data.charts}
              dataKey="HUMEDAD_SUELO"
              unidad="%"
            />

            <GraphCard
              titulo="Luz"
              color="#eab308"
              data={data.charts}
              dataKey="LUZ"
              unidad="lx"
            />

            <GraphCard
              titulo="Gas"
              color="#ef4444"
              data={data.charts}
              dataKey="GAS"
              unidad="ppm"
            />

          </div>

        </div>

        <div className="space-y-4">

          <h2 className="text-lg font-bold flex items-center gap-2 text-indigo-700 bg-indigo-50 w-fit px-4 py-1.5 rounded-full border border-indigo-100">
            <Server className="w-5 h-5" />
            Analítica Avanzada ARM64
          </h2>

          <ArmAnalytics
            selectedColumn={selectedColumn}
            setSelectedColumn={setSelectedColumn}
            armData={armData}
          />

        </div>

        {/* Historial de Eventos Completo de MongoDB */}
        <div className="space-y-4 pb-12">
          <h2 className="text-lg font-bold flex items-center gap-2 text-slate-700">
            <Database className="w-5 h-5 text-slate-500" /> Historial de Eventos (Logs)
          </h2>
          <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden">
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-slate-200">
                <thead className="bg-slate-50">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase">Fecha / Hora</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase">Tipo</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase">Mensaje</th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-slate-100">
                  {data.logs.length === 0 ? (
                    <tr>
                      <td colSpan="3" className="px-6 py-8 text-center text-sm text-slate-400">
                        No hay logs registrados en la base de datos.
                      </td>
                    </tr>
                  ) : (
                    data.logs.map(log => (
                      <tr key={log.id} className="hover:bg-slate-50 transition-colors">
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-slate-500">{log.timestamp}</td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span
                            className={`px-2 py-1 rounded-full text-xs font-semibold

                              ${log.type === "EMERGENCIA"
                                ? "bg-red-100 text-red-700"

                                : log.type === "RIEGO_ACTIVO"
                                  ? "bg-blue-100 text-blue-700"

                                  : log.type === "NORMAL"
                                    ? "bg-green-100 text-green-700"

                                    : log.type === "INICIANDO"
                                      ? "bg-purple-100 text-purple-700"

                                      : log.type === "COMANDO"
                                        ? "bg-yellow-100 text-yellow-700"

                                        : log.type === "ACTUADOR"
                                          ? "bg-cyan-100 text-cyan-700"

                                          : "bg-slate-100 text-slate-700"
                              }`}
                          >
                            {log.type}
                          </span>
                        </td>
                        <td className="px-6 py-4 text-sm text-slate-700">{log.message}</td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>

      </main>
    </div>
  );
}

export default App;