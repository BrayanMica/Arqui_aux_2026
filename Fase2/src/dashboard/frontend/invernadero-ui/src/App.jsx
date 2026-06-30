import { useState, useEffect } from 'react';
import {
  Thermometer, Droplets, Sun, Wind, Bell, AlertTriangle,
  CheckCircle, Server, Activity, Database, Flame, Power,
  LogOut
} from 'lucide-react';

// Importación de componentes modularizados
import { MetricCard } from './componentes/MetricCard';
import { ActuatorToggle } from './componentes/ActuatorToggle';
import { GraphCard } from './componentes/GraphCard';
import { DashboardSection } from './componentes/DashboardSection';
import {
  ArmHistoryPanel,
  GrafanaPanel,
  HistoricalAnalysisRequestPanel,
  HistoricalArmResultsPanel,
  LiveArmDecisionPanel,
  StructuredErrorsPanel
} from './componentes/Fase2Panels';

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
import { LoginScreen, TEST_USER } from './componentes/LoginScreen';

const SESSION_KEY = 'invernadero_dashboard_session';
const COMMAND_LABELS = {
  riego_1: 'Riego area 1',
  riego_2: 'Riego area 2',
  ventilador: 'Ventilador',
  luces: 'Luces',
  alarma: 'Alarma'
};

const STATUS_STYLES = {
  NORMAL: 'bg-emerald-500 text-white',
  ADVERTENCIA: 'bg-amber-500 text-white',
  ALERTA: 'bg-amber-500 text-white',
  EMERGENCIA: 'bg-rose-500 text-white',
  RIEGO_ACTIVO: 'bg-sky-500 text-white',
  MODO_MANUAL: 'bg-blue-600 text-white',
  INICIANDO: 'bg-violet-500 text-white'
};

const STATUS_LABELS = [
  'NORMAL',
  'ADVERTENCIA',
  'EMERGENCIA',
  'RIEGO_ACTIVO',
  'MODO_MANUAL',
  'INICIANDO'
];

const formatSensorValue = (value, decimals = 1) => {
  const numericValue = Number(value);

  if (
    value === null ||
    value === undefined ||
    Number.isNaN(numericValue)
  ) {
    return 'Pendiente';
  }

  return numericValue.toFixed(decimals);
};

function App() {
  const [session, setSession] = useState(() => {
    const savedSession = window.sessionStorage.getItem(SESSION_KEY);
    return savedSession ? JSON.parse(savedSession) : null;
  });

  const [data, setData] = useState(null);
  const [errorConexion, setErrorConexion] = useState(false);

  const [selectedColumn,
    setSelectedColumn] =
    useState("TEMPERATURA");

  const [armData,
    setArmData] =
    useState(null);

  const [armLoading, setArmLoading] = useState(false);
  const [armError, setArmError] = useState('');
  const [armHistory, setArmHistory] = useState([]);

  const [controlMode, setControlMode] = useState("AUTOMATICO");
  const [mqttConnected, setMqttConnected] = useState(false);
  const [lastCommand, setLastCommand] = useState(null);
  const [commandError, setCommandError] = useState('');
  const [lastUpdate, setLastUpdate] = useState(null);

  const [chartRange, setChartRange] = useState('24h');
  const [chartsLoading, setChartsLoading] = useState(false);
  const [chartsError, setChartsError] = useState('');

  const [analysisResult, setAnalysisResult] = useState(null);
  const [analysisLoading, setAnalysisLoading] = useState(false);
  const [analysisError, setAnalysisError] = useState('');

  const [structuredErrors, setStructuredErrors] = useState([]);

  const addStructuredError = (source, detail, extra = {}) => {
    setStructuredErrors(prev => [{
      id: Date.now(),
      timestamp: new Date().toLocaleString(),
      source,
      status: 'ERROR',
      error: detail,
      ...extra
    }, ...prev].slice(0, 50));
  };

  const handleAnalysisSubmit = async (params) => {
    setAnalysisLoading(true);
    setAnalysisError('');
    setAnalysisResult(null);
    try {
      const result = await fetchArmAnalytics(params.columna, params.lineaInicial, params.lineaFinal);
      if (!result) throw new Error('Sin respuesta del motor ARM64.');
      setAnalysisResult({
        ...result,
        _request: params
      });
    } catch (err) {
      const msg = err?.message || 'Error al ejecutar el analisis.';
      setAnalysisError(msg);
      addStructuredError('Analizador historico', msg, {
        module: 'handleAnalysisSubmit',
        columna: params.columna,
        rango: `${params.lineaInicial}-${params.lineaFinal}`,
        input: params.archivo
      });
      throw err;
    } finally {
      setAnalysisLoading(false);
    }
  };

  const cambiarModo = (modo) => {
    if (!publicarModoControl(modo)) {
      setCommandError('No hay conexion MQTT para cambiar el modo.');
      return;
    }

    setControlMode(modo);
    setCommandError('');
    setLastCommand({
      label: 'Modo de operacion',
      action: modo,
      timestamp: new Date().toLocaleTimeString()
    });
  };

  const iniciarSesion = (sessionData) => {
    window.sessionStorage.setItem(
      SESSION_KEY,
      JSON.stringify(sessionData)
    );
    setSession(sessionData);
  };

  const cerrarSesion = () => {
    window.sessionStorage.removeItem(SESSION_KEY);
    setSession(null);
    setData(null);
    setArmData(null);
    setMqttConnected(false);
    setLastCommand(null);
    setCommandError('');
    setLastUpdate(null);
  };

  useEffect(() => {
    if (!session) return undefined;

    let mqttClient = null;

    const inicializarSistema = async () => {
      try {
        // Traemos lo histórico y los logs (HTTP) en paralelo al arrancar la app
        const [analytics, eventLogs] = await Promise.all([
          fetchHistoricalData('24h'),
          fetchLogsData()
        ]);

        // Inicializamos el estado base de la interfaz
        setData({
          current: {
            status: 'NORMAL',
            temperature: null,
            humidity: null,
            soilMoistureArea: null,
            soilMoistureArea2: null,
            lightLevel: null,
            gasLevel: null,
          },
          actuators: {
            riego_1: { active: false },
            riego_2: { active: false },
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
        setLastUpdate(new Date());

        // Activamos la escucha en tiempo real por MQTTX
        mqttClient = conectarMqttInvernadero(
          (nuevoEstado) => {

            if (nuevoEstado.controlMode === 'AUTOMATICO' || nuevoEstado.controlMode === 'MANUAL') {
              setControlMode(nuevoEstado.controlMode);
            }
            setLastUpdate(new Date());


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
                  soilMoistureArea2:
                    nuevoEstado.soilMoistureArea2,
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

                  riego_2: {
                    active:
                      nuevoEstado.actuators.riego_2 || false
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

          },
          setMqttConnected
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
  }, [session]);

  const fetchArm = async (column) => {
    setArmLoading(true);
    setArmError('');
    try {
      const result = await fetchArmAnalytics(column);
      setArmData(result);
      if (!result) {
        setArmError('No se pudo obtener datos ARM64.');
        addStructuredError('Motor ARM64 en vivo', 'Sin respuesta del motor ARM64.', { module: 'fetchArm', columna: column });
      } else if (result.modules_data) {
        setArmHistory(prev => {
          const entry = {
            ...result,
            _fetchedAt: Date.now(),
            _column: column
          };
          const filtered = prev.filter(
            h => h._column !== column
          );
          return [entry, ...filtered].slice(0, 20);
        });
      }
    } catch {
      setArmError('Error al consultar el motor ARM64.');
      addStructuredError('Motor ARM64 en vivo', 'Error de conexion con el backend ARM64.', { module: 'fetchArm', columna: column });
    } finally {
      setArmLoading(false);
    }
  };

  useEffect(() => {
    if (!session) return;
    fetchArm(selectedColumn);
  }, [selectedColumn, session]);

  useEffect(() => {
    if (!session || !data) return;

    const loadCharts = async () => {
      setChartsLoading(true);
      setChartsError('');
      try {
        const result = await fetchHistoricalData(chartRange);
        setData(prev => prev ? { ...prev, charts: result?.charts || [] } : prev);
      } catch {
        setChartsError('No se pudieron cargar las graficas.');
      } finally {
        setChartsLoading(false);
      }
    };

    loadCharts();
  }, [chartRange, session]);

  //Manejador para encender/apagar actuadores físicos
  const toggleActuator = (actuatorKey) => {
    if (!data) return;

    const targetActuator = data.actuators[actuatorKey];
    const targetNewState = !targetActuator.active;
    const published = updateActuatorState(actuatorKey, targetNewState);

    if (!published) {
      setCommandError('No hay conexion MQTT para enviar el comando.');
      return;
    }

    // Se actualiza el estado de React inmediatamente
    setData(prev => ({
      ...prev,
      actuators: {
        ...prev.actuators,
        [actuatorKey]: { ...prev.actuators[actuatorKey], active: targetNewState }
      }
    }));

    setCommandError('');
    setLastCommand({
      label: COMMAND_LABELS[actuatorKey] || actuatorKey,
      action: targetNewState ? 'ON' : 'OFF',
      timestamp: new Date().toLocaleTimeString()
    });
  };

  const getStatusColor = (status) => {
    return STATUS_STYLES[status?.toUpperCase()] ||
      'bg-slate-500 text-white';
  };

  if (!session) {
    return (
      <LoginScreen onLogin={iniciarSesion} />
    );
  }

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
            {['ALERTA', 'ADVERTENCIA'].includes(data.current.status) && <AlertTriangle className="w-4 h-4" />}
            {data.current.status === 'EMERGENCIA' && <Flame className="w-4 h-4" />}
            SISTEMA: {data.current.status}
          </div>
          <div className="flex items-center gap-3">
            <span className="hidden sm:inline text-sm font-semibold text-slate-500">
              {TEST_USER}
            </span>
            <button
              onClick={cerrarSesion}
              className="inline-flex items-center gap-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-50"
            >
              <LogOut className="w-4 h-4" />
              Cerrar sesion
            </button>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-10">
        <DashboardSection
          id="estado-actual"
          icon={<CheckCircle className="w-5 h-5 text-emerald-500" />}
          title="Estado actual del sistema"
          description="Resumen operativo para defensa y monitoreo rapido."
        >
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-5">
              <p className="text-sm font-semibold text-slate-500">Estado global</p>
              <span className={`mt-3 inline-flex px-3 py-1 rounded-full text-sm font-bold ${getStatusColor(data.current.status)}`}>
                {data.current.status}
              </span>
            </div>

            <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-5">
              <p className="text-sm font-semibold text-slate-500">Modo de control</p>
              <p className="mt-3 text-2xl font-bold text-slate-800">
                {controlMode}
              </p>
            </div>

            <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-5">
              <p className="text-sm font-semibold text-slate-500">Conexion MQTT</p>
              <p className={`mt-3 text-2xl font-bold ${mqttConnected ? 'text-emerald-600' : 'text-rose-600'}`}>
                {mqttConnected ? 'Conectada' : 'Desconectada'}
              </p>
            </div>

            <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-5">
              <p className="text-sm font-semibold text-slate-500">API / Backend</p>
              <p className={`mt-3 text-2xl font-bold ${errorConexion ? 'text-rose-600' : 'text-emerald-600'}`}>
                {errorConexion ? 'Con error' : 'Disponible'}
              </p>
            </div>
          </div>

          <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-5 space-y-4">
            <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
              <p className="text-sm font-semibold text-slate-500">
                Ultima actualizacion recibida
              </p>
              <p className="font-bold text-slate-800">
                {lastUpdate
                  ? lastUpdate.toLocaleString()
                  : 'Pendiente'}
              </p>
            </div>

            <div className="flex flex-wrap gap-2">
              {STATUS_LABELS.map((status) => (
                <span
                  key={status}
                  className={`rounded-full px-3 py-1 text-xs font-bold ${data.current.status === status
                    ? getStatusColor(status)
                    : 'bg-slate-100 text-slate-600'
                    }`}
                >
                  {status}
                </span>
              ))}
            </div>
          </div>
        </DashboardSection>

        <DashboardSection
          id="lecturas-recientes"
          icon={<Activity className="w-5 h-5 text-blue-500" />}
          title="Lecturas recientes"
          description="Valores actuales recibidos por MQTT o por la carga inicial del sistema."
        >
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <MetricCard title="Temperatura" value={formatSensorValue(data.current.temperature, 1)} unit="°C" icon={<Thermometer className="w-6 h-6 text-orange-500" />} color="border-orange-200 bg-orange-50" />
            <MetricCard title="Humedad Amb." value={formatSensorValue(data.current.humidity, 1)} unit="%" icon={<Wind className="w-6 h-6 text-blue-500" />} color="border-blue-200 bg-blue-50" />
            <MetricCard title="Suelo Área 1" value={formatSensorValue(data.current.soilMoistureArea, 1)} unit="%" icon={<Droplets className="w-6 h-6 text-sky-500" />} color="border-sky-200 bg-sky-50" />
            <MetricCard title="Luz (LDR)" value={formatSensorValue(data.current.lightLevel, 0)} unit="lx" icon={<Sun className="w-6 h-6 text-amber-500" />} color="border-amber-200 bg-amber-50" />
          </div>

          <div className={`p-4 rounded-xl border-l-4 flex items-center justify-between transition-all ${Number(data.current.gasLevel) > 500 ? 'border-rose-500 bg-rose-50' : 'border-slate-300 bg-white shadow-sm'}`}>
            <div className="flex items-center gap-3">
              <div className={`p-3 rounded-full ${Number(data.current.gasLevel) > 500 ? 'bg-rose-200 text-rose-600' : 'bg-slate-100 text-slate-500'}`}><Flame className="w-6 h-6" /></div>
              <div>
                <p className="text-sm font-semibold text-slate-500">Nivel de Gas / Humo (MQ)</p>
                <p className="text-2xl font-bold text-slate-800">
                  {formatSensorValue(data.current.gasLevel, 0)}
                  {formatSensorValue(data.current.gasLevel, 0) !== 'Pendiente' && ' PPM'}
                </p>
              </div>
            </div>
            <div className="text-right">
              <span className={`text-sm font-semibold px-3 py-1 rounded-full ${Number(data.current.gasLevel) > 500 ? 'bg-rose-500 text-white' : 'bg-emerald-100 text-emerald-700'}`}>
                {Number(data.current.gasLevel) > 500 ? 'PELIGRO' : 'SEGURO'}
              </span>
            </div>
          </div>
        </DashboardSection>

        <DashboardSection
          id="control-remoto"
          icon={<Power className="w-5 h-5 text-emerald-500" />}
          title="Control remoto autorizado"
          description="Controles manuales protegidos por el modo de operacion del sistema."
        >
          <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-5 space-y-4">
            <div className="bg-slate-50 rounded-xl p-4">
              <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between mb-3">
                <h3 className="font-semibold">
                  Modo de Operación
                </h3>

                <div className="flex flex-wrap items-center gap-2 text-xs font-bold">
                  <span className="rounded-full bg-white border border-slate-200 px-2 py-1 text-slate-700">
                    Actual: {controlMode}
                  </span>
                  <span className={`rounded-full px-2 py-1 ${mqttConnected
                    ? 'bg-emerald-100 text-emerald-700'
                    : 'bg-rose-100 text-rose-700'
                    }`}>
                    MQTT {mqttConnected ? 'conectado' : 'desconectado'}
                  </span>
                </div>
              </div>

              <div className="flex gap-4">
                <button
                  onClick={() => cambiarModo("AUTOMATICO")}
                  className={`flex-1 py-2 rounded-lg ${controlMode === "AUTOMATICO"
                    ? "bg-green-600 text-white"
                    : "bg-white border"
                    }`}
                >
                  Automático
                </button>

                <button
                  onClick={() => cambiarModo("MANUAL")}
                  className={`flex-1 py-2 rounded-lg ${controlMode === "MANUAL"
                    ? "bg-blue-600 text-white"
                    : "bg-white border"
                    }`}
                >
                  Manual
                </button>
              </div>
            </div>

            <ActuatorToggle
              label="Sistema de Riego 1"
              state={data.actuators.riego_1.active}
              onChange={() => toggleActuator('riego_1')}
              subtitle={data.actuators.riego_1.mode === 'auto' ? 'Modo Automático' : 'Modo Manual'}
              disabled={controlMode === "AUTOMATICO"}
            />

            <ActuatorToggle label="Ventilador / Extractor" state={data.actuators.ventilador.active} onChange={() => toggleActuator('ventilador')} disabled={controlMode === "AUTOMATICO"} />
            <ActuatorToggle label="Iluminación LEDs" state={data.actuators.luces.active} onChange={() => toggleActuator('luces')} disabled={controlMode === "AUTOMATICO"} />

            <div className="pt-4 border-t border-slate-100">
              <button
                onClick={() => toggleActuator('alarma')}
                disabled={controlMode === "AUTOMATICO"}
                className={`w-full py-2.5 rounded-lg flex items-center justify-center gap-2 font-semibold transition-colors ${controlMode === "AUTOMATICO"
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

            <div className="rounded-xl border border-slate-200 bg-slate-50 p-4 text-sm">
              <p className="font-semibold text-slate-700">
                Ultimo comando enviado
              </p>
              <p className="mt-1 text-slate-500">
                {lastCommand
                  ? `${lastCommand.label}: ${lastCommand.action} (${lastCommand.timestamp})`
                  : 'Sin comandos enviados en esta sesion.'}
              </p>

              {commandError && (
                <p className="mt-3 rounded-lg bg-rose-50 px-3 py-2 font-semibold text-rose-700">
                  {commandError}
                </p>
              )}
            </div>
          </div>
        </DashboardSection>

        <DashboardSection
          id="graficas-historicas"
          icon={<Activity className="w-5 h-5 text-blue-500" />}
          title="Graficas historicas"
          description="Datos historicos obtenidos desde la API del dashboard."
        >
          <div className="flex flex-wrap items-center gap-2 mb-2">
            <span className="text-sm font-semibold text-slate-500">Rango:</span>
            {[
              { value: '24h', label: '24 horas' },
              { value: '7d', label: '7 dias' },
              { value: '30d', label: '30 dias' }
            ].map((opt) => (
              <button
                key={opt.value}
                onClick={() => setChartRange(opt.value)}
                className={`px-3 py-1.5 rounded-lg text-sm font-semibold transition-colors ${chartRange === opt.value
                  ? 'bg-blue-600 text-white'
                  : 'bg-white border border-slate-200 text-slate-600 hover:bg-slate-50'
                }`}
              >
                {opt.label}
              </button>
            ))}
          </div>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <GraphCard titulo="Temperatura" color="#f97316" data={data.charts} dataKey="TEMPERATURA" unidad="°C" loading={chartsLoading} error={chartsError} />
            <GraphCard titulo="Humedad Aire" color="#3b82f6" data={data.charts} dataKey="HUMEDAD_AMBIENTAL" unidad="%" loading={chartsLoading} error={chartsError} />
            <GraphCard titulo="Humedad Suelo" color="#06b6d4" data={data.charts} dataKey="HUMEDAD_SUELO" unidad="%" loading={chartsLoading} error={chartsError} />
            <GraphCard titulo="Luz" color="#eab308" data={data.charts} dataKey="LUZ" unidad="lx" loading={chartsLoading} error={chartsError} />
            <GraphCard titulo="Gas" color="#ef4444" data={data.charts} dataKey="GAS" unidad="ppm" loading={chartsLoading} error={chartsError} />
          </div>
        </DashboardSection>

        <DashboardSection
          id="decisiones-arm64"
          icon={<Server className="w-5 h-5 text-indigo-600" />}
          title="Decisiones ARM64 en vivo"
        >
          <LiveArmDecisionPanel armData={armData} loading={armLoading} error={armError} />
          <ArmHistoryPanel
            history={armHistory}
            loading={armLoading}
            error={armError}
            onRefresh={() => fetchArm(selectedColumn)}
          />
        </DashboardSection>

        <DashboardSection
          id="resultados-arm64"
          icon={<Server className="w-5 h-5 text-indigo-600" />}
          title="Resultados ARM64 historicos"
          description="Analitica ARM64 disponible hoy y espacio preparado para los nuevos calculos de Fase 2."
        >
          <HistoricalArmResultsPanel result={analysisResult} loading={analysisLoading} error={analysisError} />
          <ArmAnalytics
            selectedColumn={selectedColumn}
            setSelectedColumn={setSelectedColumn}
            armData={armData}
          />
        </DashboardSection>

        <DashboardSection
          id="solicitud-analisis"
          icon={<Server className="w-5 h-5 text-slate-600" />}
          title="Solicitud de analisis historico"
        >
          <HistoricalAnalysisRequestPanel onSubmit={handleAnalysisSubmit} />
        </DashboardSection>

        <DashboardSection
          id="errores-estructurados"
          icon={<AlertTriangle className="w-5 h-5 text-amber-500" />}
          title="Errores estructurados"
        >
          <StructuredErrorsPanel errors={structuredErrors} />
        </DashboardSection>

        <DashboardSection
          id="grafana"
          icon={<Activity className="w-5 h-5 text-slate-600" />}
          title="Grafana"
        >
          <GrafanaPanel />
        </DashboardSection>

        <DashboardSection
          id="historial-logs"
          icon={<Database className="w-5 h-5 text-slate-500" />}
          title="Historial / logs"
          description="Eventos recientes unificados desde los endpoints actuales del backend."
        >
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
                            className={`px-2 py-1 rounded-full text-xs font-semibold ${log.type === "EMERGENCIA"
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
        </DashboardSection>
      </main>
    </div>
  );
}

export default App;
