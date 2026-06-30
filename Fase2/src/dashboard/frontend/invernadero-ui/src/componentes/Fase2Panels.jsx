import { useState } from 'react';
import {
  Activity,
  AlertTriangle,
  BarChart3,
  FileSearch,
  History,
  LineChart,
  ShieldAlert
} from 'lucide-react';
import { FRONTEND_CONFIG } from '../servicios/api';

const RISK_STYLES = {
  LOW: { bg: 'bg-emerald-100', text: 'text-emerald-700', label: 'BAJO' },
  NORMAL: { bg: 'bg-emerald-100', text: 'text-emerald-700', label: 'BAJO' },
  MEDIUM: { bg: 'bg-amber-100', text: 'text-amber-700', label: 'MEDIO' },
  HIGH: { bg: 'bg-rose-100', text: 'text-rose-700', label: 'ALTO' },
  CRITICAL: { bg: 'bg-purple-100', text: 'text-purple-700', label: 'CRITICO' }
};

function deriveDecision(armData) {
  if (!armData || !armData.modules_data) return null;

  const anomaly = armData.modules_data.ANOMALY_DETECTION;
  const prediction = armData.modules_data.PREDICTION;
  const trend = armData.modules_data.ADVANCED_TREND;
  const mean = armData.modules_data.WEIGHTED_MEAN;

  const rawRisk = anomaly?.SYSTEM_RISK?.toUpperCase() || 'LOW';
  const risk = rawRisk === 'NORMAL' ? 'LOW' : rawRisk;

  let action = 'MONITOREAR';
  if (risk === 'HIGH' || risk === 'CRITICAL') action = 'ACTUAR';
  else if (risk === 'MEDIUM') action = 'REVISAR';

  const trendLabel = trend?.TREND === 'UP' ? 'SUBIENDO'
    : trend?.TREND === 'DOWN' ? 'BAJANDO'
    : 'ESTABLE';

  const anomalyCount = anomaly?.ANOMALIES ?? 0;
  const reason = anomalyCount > 0
    ? `${anomalyCount} anomalia(s) detectada(s), tendencia ${trendLabel}`
    : `Sin anomalias, tendencia ${trendLabel}`;

  return {
    ACTION: action,
    TARGET: armData.target_column || '-',
    RISK: risk,
    REASON: reason,
    VALUE: mean?.WEIGHTED_MEAN != null ? Number(mean.WEIGHTED_MEAN).toFixed(2) : '-',
    INDICATOR: trendLabel,
    STATUS: 'OK',
    timestamp: armData.timestamp
      ? new Date(armData.timestamp * 1000).toLocaleString()
      : null
  };
}

function EmptyPanel({
  icon,
  title,
  children
}) {
  return (
    <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-5 min-h-40">
      <div className="flex items-start gap-3">
        <div className="p-2 rounded-lg bg-slate-100 text-slate-600">
          {icon}
        </div>

        <div className="space-y-2">
          <h3 className="font-bold text-slate-800">
            {title}
          </h3>

          <div className="text-sm text-slate-500 leading-6">
            {children}
          </div>
        </div>
      </div>
    </div>
  );
}

export function LiveArmDecisionPanel({ armData, loading, error }) {
  if (loading) {
    return (
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-5 min-h-40 flex items-center justify-center gap-2 text-slate-400">
        <Activity className="w-5 h-5 animate-spin text-emerald-500" />
        <span className="text-sm font-semibold">Cargando decision ARM64...</span>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-white rounded-2xl shadow-sm border border-rose-200 p-5 min-h-40">
        <div className="flex items-start gap-3">
          <div className="p-2 rounded-lg bg-rose-100 text-rose-600">
            <AlertTriangle className="w-5 h-5" />
          </div>
          <div>
            <h3 className="font-bold text-slate-800">Error al obtener decisiones ARM64</h3>
            <p className="text-sm text-rose-600 mt-1">{error}</p>
          </div>
        </div>
      </div>
    );
  }

  const decision = deriveDecision(armData);

  if (!decision) {
    return (
      <EmptyPanel
        icon={<ShieldAlert className="w-5 h-5" />}
        title="Ultima decision ARM64 en vivo"
      >
        <p>Sin decisiones ARM64 disponibles. Se mostraran cuando el motor ARM64 genere resultados.</p>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3 pt-3">
          {['ACTION', 'TARGET', 'RISK', 'STATUS'].map((item) => (
            <div key={item} className="rounded-lg border border-slate-200 bg-slate-50 p-3">
              <p className="text-xs font-semibold text-slate-400">{item}</p>
              <p className="font-bold text-slate-700">-</p>
            </div>
          ))}
        </div>
      </EmptyPanel>
    );
  }

  const riskStyle = RISK_STYLES[decision.RISK] || RISK_STYLES.LOW;

  const fields = [
    { key: 'ACTION', label: 'Accion', value: decision.ACTION },
    { key: 'TARGET', label: 'Objetivo', value: decision.TARGET },
    { key: 'VALUE', label: 'Valor', value: decision.VALUE },
    { key: 'INDICATOR', label: 'Indicador', value: decision.INDICATOR },
    { key: 'STATUS', label: 'Estado', value: decision.STATUS }
  ];

  return (
    <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-5 space-y-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-lg bg-indigo-100 text-indigo-600">
            <ShieldAlert className="w-5 h-5" />
          </div>
          <h3 className="font-bold text-slate-800">Ultima decision ARM64 en vivo</h3>
        </div>
        <span className={`px-3 py-1 rounded-full text-sm font-bold ${riskStyle.bg} ${riskStyle.text}`}>
          RIESGO: {riskStyle.label}
        </span>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
        {fields.map((f) => (
          <div key={f.key} className="rounded-lg border border-slate-200 bg-slate-50 p-3">
            <p className="text-xs font-semibold text-slate-400">{f.label}</p>
            <p className="font-bold text-slate-700">{f.value}</p>
          </div>
        ))}
      </div>

      <div className="rounded-lg border border-slate-200 bg-slate-50 p-3">
        <p className="text-xs font-semibold text-slate-400">Razon</p>
        <p className="text-sm font-semibold text-slate-700">{decision.REASON}</p>
      </div>

      {decision.timestamp && (
        <p className="text-xs text-slate-400 text-right">
          Generado: {decision.timestamp}
        </p>
      )}
    </div>
  );
}

export function ArmHistoryPanel({ history, loading, error, onRefresh }) {
  const rows = (history || []).map(entry => deriveDecision(entry)).filter(Boolean);

  return (
    <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-5 space-y-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-lg bg-slate-100 text-slate-600">
            <History className="w-5 h-5" />
          </div>
          <h3 className="font-bold text-slate-800">Historial de decisiones ARM64</h3>
        </div>
        <button
          onClick={onRefresh}
          disabled={loading}
          className="inline-flex items-center gap-2 rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-sm font-semibold text-slate-600 hover:bg-slate-50 disabled:opacity-50"
        >
          {loading && <Activity className="w-4 h-4 animate-spin" />}
          Refrescar
        </button>
      </div>

      {error && (
        <div className="flex items-center gap-2 rounded-lg bg-rose-50 px-3 py-2 text-sm font-semibold text-rose-700">
          <AlertTriangle className="w-4 h-4" />
          {error}
        </div>
      )}

      {loading && rows.length === 0 ? (
        <div className="flex items-center justify-center gap-2 py-8 text-slate-400">
          <Activity className="w-5 h-5 animate-spin text-emerald-500" />
          <span className="text-sm font-semibold">Cargando historial...</span>
        </div>
      ) : rows.length === 0 ? (
        <div className="text-center py-8 text-sm text-slate-400">
          Sin decisiones ARM64 registradas en esta sesion. Seleccione una variable en la seccion de resultados ARM64 para generar decisiones.
        </div>
      ) : (
        <div className="overflow-x-auto overflow-y-auto max-h-72">
          <table className="min-w-full divide-y divide-slate-200">
            <thead className="bg-slate-50 sticky top-0 z-10">
              <tr>
                <th className="px-4 py-2 text-left text-xs font-medium text-slate-500 uppercase">Fecha</th>
                <th className="px-4 py-2 text-left text-xs font-medium text-slate-500 uppercase">Accion</th>
                <th className="px-4 py-2 text-left text-xs font-medium text-slate-500 uppercase">Objetivo</th>
                <th className="px-4 py-2 text-left text-xs font-medium text-slate-500 uppercase">Riesgo</th>
                <th className="px-4 py-2 text-left text-xs font-medium text-slate-500 uppercase">Motivo</th>
                <th className="px-4 py-2 text-left text-xs font-medium text-slate-500 uppercase">Valor</th>
                <th className="px-4 py-2 text-left text-xs font-medium text-slate-500 uppercase">Indicador</th>
                <th className="px-4 py-2 text-left text-xs font-medium text-slate-500 uppercase">Estado</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-slate-100">
              {rows.map((d, i) => {
                const rs = RISK_STYLES[d.RISK] || RISK_STYLES.LOW;
                return (
                  <tr key={i} className="hover:bg-slate-50 transition-colors">
                    <td className="px-4 py-3 whitespace-nowrap text-sm text-slate-500">{d.timestamp || '-'}</td>
                    <td className="px-4 py-3 whitespace-nowrap text-sm font-semibold text-slate-700">{d.ACTION}</td>
                    <td className="px-4 py-3 whitespace-nowrap text-sm text-slate-700">{d.TARGET}</td>
                    <td className="px-4 py-3 whitespace-nowrap">
                      <span className={`px-2 py-1 rounded-full text-xs font-bold ${rs.bg} ${rs.text}`}>{rs.label}</span>
                    </td>
                    <td className="px-4 py-3 text-sm text-slate-600 max-w-xs truncate">{d.REASON}</td>
                    <td className="px-4 py-3 whitespace-nowrap text-sm font-semibold text-slate-700">{d.VALUE}</td>
                    <td className="px-4 py-3 whitespace-nowrap text-sm text-slate-700">{d.INDICATOR}</td>
                    <td className="px-4 py-3 whitespace-nowrap">
                      <span className={`px-2 py-1 rounded-full text-xs font-bold ${d.STATUS === 'OK' ? 'bg-emerald-100 text-emerald-700' : 'bg-rose-100 text-rose-700'}`}>{d.STATUS}</span>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

const COLUMNAS_PERMITIDAS = [
  { value: 'TEMP', label: 'Temperatura' },
  { value: 'HUM_AIRE', label: 'Humedad Ambiental' },
  { value: 'HUM_SUELO_1', label: 'Humedad Suelo 1' },
  { value: 'LUZ', label: 'Luz' },
  { value: 'GAS', label: 'Gas' }
];

export function HistoricalAnalysisRequestPanel({ onSubmit }) {
  const [archivo, setArchivo] = useState('lecturas.csv');
  const [lineaInicial, setLineaInicial] = useState('');
  const [lineaFinal, setLineaFinal] = useState('');
  const [columna, setColumna] = useState('TEMP');
  const [errors, setErrors] = useState({});
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState('');
  const [submitOk, setSubmitOk] = useState(false);

  const validate = () => {
    const e = {};
    if (!archivo.trim()) e.archivo = 'El archivo es obligatorio.';
    const li = Number(lineaInicial);
    const lf = Number(lineaFinal);
    if (!lineaInicial || !Number.isInteger(li) || li < 1) e.lineaInicial = 'Debe ser un entero >= 1.';
    if (!lineaFinal || !Number.isInteger(lf) || lf < 1) e.lineaFinal = 'Debe ser un entero >= 1.';
    else if (li && lf < li) e.lineaFinal = 'Debe ser >= linea inicial.';
    if (!COLUMNAS_PERMITIDAS.some(c => c.value === columna)) e.columna = 'Columna no valida.';
    return e;
  };

  const handleSubmit = async (ev) => {
    ev.preventDefault();
    const e = validate();
    setErrors(e);
    setSubmitError('');
    setSubmitOk(false);
    if (Object.keys(e).length > 0) return;

    setSubmitting(true);
    try {
      if (onSubmit) {
        await onSubmit({ archivo: archivo.trim(), lineaInicial: Number(lineaInicial), lineaFinal: Number(lineaFinal), columna });
      }
      setSubmitOk(true);
    } catch (err) {
      setSubmitError(err?.message || 'Error al enviar la solicitud.');
    } finally {
      setSubmitting(false);
    }
  };

  const inputClass = (field) =>
    `rounded-lg border px-3 py-2 text-sm ${errors[field] ? 'border-rose-400 bg-rose-50' : 'border-slate-200 bg-white'}`;

  return (
    <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-5 space-y-4">
      <div className="flex items-center gap-3">
        <div className="p-2 rounded-lg bg-slate-100 text-slate-600">
          <FileSearch className="w-5 h-5" />
        </div>
        <h3 className="font-bold text-slate-800">Solicitud de analisis historico</h3>
      </div>

      <form onSubmit={handleSubmit} className="space-y-4">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
          <div>
            <input
              value={archivo}
              onChange={(e) => setArchivo(e.target.value)}
              className={inputClass('archivo')}
              placeholder="archivo.csv"
            />
            {errors.archivo && <p className="text-xs text-rose-600 mt-1">{errors.archivo}</p>}
          </div>
          <div>
            <input
              type="number"
              min="1"
              value={lineaInicial}
              onChange={(e) => setLineaInicial(e.target.value)}
              className={inputClass('lineaInicial')}
              placeholder="Linea inicial"
            />
            {errors.lineaInicial && <p className="text-xs text-rose-600 mt-1">{errors.lineaInicial}</p>}
          </div>
          <div>
            <input
              type="number"
              min="1"
              value={lineaFinal}
              onChange={(e) => setLineaFinal(e.target.value)}
              className={inputClass('lineaFinal')}
              placeholder="Linea final"
            />
            {errors.lineaFinal && <p className="text-xs text-rose-600 mt-1">{errors.lineaFinal}</p>}
          </div>
          <div>
            <select
              value={columna}
              onChange={(e) => setColumna(e.target.value)}
              className={inputClass('columna')}
            >
              {COLUMNAS_PERMITIDAS.map(c => (
                <option key={c.value} value={c.value}>{c.label}</option>
              ))}
            </select>
            {errors.columna && <p className="text-xs text-rose-600 mt-1">{errors.columna}</p>}
          </div>
        </div>

        <div className="flex items-center gap-3">
          <button
            type="submit"
            disabled={submitting}
            className="inline-flex items-center gap-2 rounded-lg bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-700 disabled:opacity-50"
          >
            {submitting && <Activity className="w-4 h-4 animate-spin" />}
            {submitting ? 'Enviando...' : 'Enviar solicitud'}
          </button>

          {submitOk && (
            <span className="text-sm font-semibold text-emerald-600">Solicitud enviada correctamente.</span>
          )}
        </div>

        {submitError && (
          <div className="flex items-center gap-2 rounded-lg bg-rose-50 px-3 py-2 text-sm font-semibold text-rose-700">
            <AlertTriangle className="w-4 h-4" />
            {submitError}
          </div>
        )}
      </form>
    </div>
  );
}

export function StructuredErrorsPanel({ errors }) {
  const list = errors || [];

  if (list.length === 0) {
    return (
      <EmptyPanel
        icon={<AlertTriangle className="w-5 h-5" />}
        title="Errores estructurados ARM64"
      >
        <p>
          Sin errores ARM64 recibidos. Los errores del motor en vivo y del
          analizador historico apareceran aqui separados de los resultados OK.
        </p>
      </EmptyPanel>
    );
  }

  return (
    <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-5 space-y-4">
      <div className="flex items-center gap-3">
        <div className="p-2 rounded-lg bg-rose-100 text-rose-600">
          <AlertTriangle className="w-5 h-5" />
        </div>
        <h3 className="font-bold text-slate-800">
          Errores estructurados ARM64
        </h3>
        <span className="px-2 py-1 rounded-full text-xs font-bold bg-rose-100 text-rose-700">
          {list.length}
        </span>
      </div>

      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-slate-200">
          <thead className="bg-slate-50">
            <tr>
              <th className="px-4 py-2 text-left text-xs font-medium text-slate-500 uppercase">Fecha</th>
              <th className="px-4 py-2 text-left text-xs font-medium text-slate-500 uppercase">Fuente</th>
              <th className="px-4 py-2 text-left text-xs font-medium text-slate-500 uppercase">Modulo</th>
              <th className="px-4 py-2 text-left text-xs font-medium text-slate-500 uppercase">Status</th>
              <th className="px-4 py-2 text-left text-xs font-medium text-slate-500 uppercase">Error</th>
              <th className="px-4 py-2 text-left text-xs font-medium text-slate-500 uppercase">Detalle</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-slate-100">
            {list.map((err) => (
              <tr key={err.id} className="hover:bg-rose-50 transition-colors">
                <td className="px-4 py-3 whitespace-nowrap text-sm text-slate-500">{err.timestamp}</td>
                <td className="px-4 py-3 whitespace-nowrap text-sm font-semibold text-slate-700">{err.source}</td>
                <td className="px-4 py-3 whitespace-nowrap text-sm text-slate-600">{err.module || '-'}</td>
                <td className="px-4 py-3 whitespace-nowrap">
                  <span className="px-2 py-1 rounded-full text-xs font-bold bg-rose-100 text-rose-700">{err.status}</span>
                </td>
                <td className="px-4 py-3 text-sm text-rose-700 max-w-xs truncate">{err.error}</td>
                <td className="px-4 py-3 text-sm text-slate-500 max-w-xs truncate">
                  {[err.input && `Archivo: ${err.input}`, err.rango && `Rango: ${err.rango}`, err.columna && `Col: ${err.columna}`].filter(Boolean).join(' | ') || '-'}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export function GrafanaPanel() {
  const grafanaUrl = FRONTEND_CONFIG.grafanaUrl;

  return (
    <EmptyPanel
      icon={<BarChart3 className="w-5 h-5" />}
      title="Grafana"
    >
      {grafanaUrl ? (
        <a
          href={grafanaUrl}
          target="_blank"
          rel="noreferrer"
          className="inline-flex items-center rounded-lg bg-slate-900 px-4 py-2 font-semibold text-white hover:bg-slate-700"
        >
          Abrir Grafana
        </a>
      ) : (
        <p>
          Grafana no configurado. Define `VITE_GRAFANA_URL` cuando el equipo
          tenga la URL publica o local del dashboard.
        </p>
      )}
    </EmptyPanel>
  );
}

function ResultField({ label, value }) {
  if (value === undefined || value === null) return null;
  const display = typeof value === 'number' ? value.toFixed(4) : String(value);
  return (
    <div className="rounded-lg border border-slate-200 bg-slate-50 p-3">
      <p className="text-xs font-semibold text-slate-400">{label}</p>
      <p className="font-bold text-slate-700">{display}</p>
    </div>
  );
}

export function HistoricalArmResultsPanel({ result, loading, error }) {
  if (loading) {
    return (
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-5 min-h-40 flex items-center justify-center gap-2 text-slate-400">
        <Activity className="w-5 h-5 animate-spin text-emerald-500" />
        <span className="text-sm font-semibold">Ejecutando analisis ARM64...</span>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-white rounded-2xl shadow-sm border border-rose-200 p-5 min-h-40">
        <div className="flex items-start gap-3">
          <div className="p-2 rounded-lg bg-rose-100 text-rose-600">
            <AlertTriangle className="w-5 h-5" />
          </div>
          <div>
            <h3 className="font-bold text-slate-800">Error en analisis historico</h3>
            <p className="text-sm text-rose-600 mt-1">{error}</p>
          </div>
        </div>
      </div>
    );
  }

  if (!result || !result.modules_data) {
    return (
      <EmptyPanel
        icon={<LineChart className="w-5 h-5" />}
        title="Resultados ARM64 historicos"
      >
        <p>
          Sin resultados todavia. Use el formulario de solicitud de analisis historico
          para ejecutar un analisis por rango y columna.
        </p>
      </EmptyPanel>
    );
  }

  const req = result._request || {};
  const mean = result.modules_data.WEIGHTED_MEAN;
  const variance = result.modules_data.VARIANCE;
  const anomaly = result.modules_data.ANOMALY_DETECTION;
  const prediction = result.modules_data.PREDICTION;
  const trend = result.modules_data.ADVANCED_TREND;
  const rmse = result.modules_data.RMSE;
  const regresion = result.modules_data.LINEAR_REGRESSION;
  const predFutura = result.modules_data.PREDICTION_M3;
  const integral = result.modules_data.ERROR_INTEGRAL;
  const derivada = result.modules_data.LOCAL_DERIVATIVE;

  const totalValues = mean?.TOTAL_VALUES ?? variance?.TOTAL_VALUES ?? '-';

  return (
    <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-5 space-y-4">
      <div className="flex items-center gap-3">
        <div className="p-2 rounded-lg bg-indigo-100 text-indigo-600">
          <LineChart className="w-5 h-5" />
        </div>
        <h3 className="font-bold text-slate-800">Resultados del analisis historico</h3>
        <span className="px-2 py-1 rounded-full text-xs font-bold bg-emerald-100 text-emerald-700">OK</span>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <ResultField label="Columna analizada" value={result.target_column || req.columna} />
        <ResultField label="Linea inicial" value={req.lineaInicial} />
        <ResultField label="Linea final" value={req.lineaFinal} />
        <ResultField label="Datos procesados" value={totalValues} />
        <ResultField label="Estado" value="OK" />
      </div>

      <div>
        <h4 className="text-xs font-bold uppercase tracking-wide text-indigo-600 mb-2">
          Fase 1 - Modulos actualizados (sec. 4.17)
        </h4>
        <div className="grid grid-cols-1 md:grid-cols-5 gap-3">
          <ResultField label="Media ponderada (modulo_1_media)" value={mean?.WEIGHTED_MEAN} />
          <ResultField label="Varianza (modulo_2_varianza)" value={variance?.VARIANCE} />
          <ResultField label="Anomalias detectadas (modulo_3_anomalias)" value={anomaly?.ANOMALIES} />
          <ResultField label="Prediccion simple (modulo_4_prediccion)" value={prediction?.NEXT_VALUE} />
          <ResultField label="Tendencia general (modulo_5_tendencia)" value={trend?.TREND} />
        </div>
      </div>

      <div>
        <h4 className="text-xs font-bold uppercase tracking-wide text-emerald-600 mb-2">
          Fase 2 - Nuevos calculos ARM64 (sec. 4.19)
        </h4>
        <div className="grid grid-cols-1 md:grid-cols-5 gap-3">
          <ResultField label="RMSE (modulo_1_rmse, Rutina 1)" value={rmse?.RMSE} />
          <ResultField label="Regresion lineal (modulo_2_regresion, Rutina 2)" value={regresion?.SLOPE_X100} />
          <ResultField label="Prediccion futura (modulo_3_prediccion, Rutina 3)" value={predFutura?.PREDICTED_5} />
          <ResultField label="Integral del error (modulo_4_integral_error, Rutina 4)" value={integral?.ERROR_INTEGRAL} />
          <ResultField label="Derivada local (modulo_5_derivada_local, Rutina 5)" value={derivada?.MAX_LOCAL_SLOPE_X100} />
        </div>
      </div>

      {(anomaly?.SYSTEM_RISK || prediction?.NEXT_VALUE != null) && (
        <ResultField label="Riesgo del sistema" value={anomaly?.SYSTEM_RISK} />
      )}

      {(anomaly?.SYSTEM_RISK || prediction?.NEXT_VALUE != null) && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {anomaly?.SYSTEM_RISK && (
            <div className="rounded-lg border border-slate-200 bg-slate-50 p-3">
              <p className="text-xs font-semibold text-slate-400">Recomendacion</p>
              <p className="font-bold text-slate-700">
                {anomaly.SYSTEM_RISK === 'NORMAL' || anomaly.SYSTEM_RISK === 'LOW'
                  ? 'Sistema estable, continuar monitoreo normal.'
                  : anomaly.SYSTEM_RISK === 'MEDIUM'
                    ? 'Revisar lecturas, posibles valores fuera de rango.'
                    : 'Accion inmediata requerida, riesgo elevado.'}
              </p>
            </div>
          )}
          {anomaly?.SYSTEM_RISK && (
            <div className="rounded-lg border border-slate-200 bg-slate-50 p-3">
              <p className="text-xs font-semibold text-slate-400">Razon tecnica</p>
              <p className="font-bold text-slate-700">
                {anomaly.ANOMALIES ?? 0} anomalia(s) en {totalValues} lecturas,
                riesgo {anomaly.SYSTEM_RISK}, tendencia {trend?.TREND || '-'}.
              </p>
            </div>
          )}
        </div>
      )}

      <details className="rounded-lg border border-slate-200 bg-slate-50">
        <summary className="px-3 py-2 text-sm font-semibold text-slate-600 cursor-pointer">
          Salida completa (JSON para defensa)
        </summary>
        <pre className="px-3 py-2 text-xs text-slate-600 overflow-x-auto max-h-64">
          {JSON.stringify(result.modules_data, null, 2)}
        </pre>
      </details>
    </div>
  );
}
