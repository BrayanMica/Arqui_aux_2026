import { Activity, AlertTriangle, BarChart3 } from 'lucide-react';
import {
  ResponsiveContainer,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip
} from "recharts";

export function GraphCard({
  titulo,
  color,
  data,
  dataKey,
  unidad,
  loading,
  error
}) {
  const hasData = Array.isArray(data) && data.length > 0;
  const hasValues = hasData && data.some(
    (d) => d[dataKey] !== undefined && d[dataKey] !== null
  );

  return (
    <div className="bg-white rounded-2xl shadow-sm border p-5">
      <h3 className="font-bold text-slate-800 mb-4">
        {titulo}
      </h3>

      <div className="h-64 flex items-center justify-center">
        {loading ? (
          <div className="flex flex-col items-center gap-2 text-slate-400">
            <Activity className="w-6 h-6 animate-spin text-emerald-500" />
            <span className="text-sm font-semibold">Cargando datos...</span>
          </div>
        ) : error ? (
          <div className="flex flex-col items-center gap-2 text-rose-500">
            <AlertTriangle className="w-6 h-6" />
            <span className="text-sm font-semibold">Error al cargar datos</span>
            <span className="text-xs text-slate-400">{error}</span>
          </div>
        ) : !hasValues ? (
          <div className="flex flex-col items-center gap-2 text-slate-400">
            <BarChart3 className="w-6 h-6" />
            <span className="text-sm font-semibold">Sin datos disponibles</span>
            <span className="text-xs">No hay registros para este sensor en el rango seleccionado.</span>
          </div>
        ) : (
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={data}>
              <CartesianGrid strokeDasharray="3 3" />

              <XAxis
                dataKey="hora"
                tick={{ fontSize: 11 }}
              />

              <YAxis />

              <Tooltip
                formatter={(value) => [
                  `${value} ${unidad}`,
                  titulo
                ]}
              />

              <Line
                type="monotone"
                dataKey={dataKey}
                stroke={color}
                strokeWidth={2}
                dot={false}
              />
            </LineChart>
          </ResponsiveContainer>
        )}
      </div>
    </div>
  );
}