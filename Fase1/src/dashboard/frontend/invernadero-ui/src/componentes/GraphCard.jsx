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
  unidad
}) {
  return (
    <div className="bg-white rounded-2xl shadow-sm border p-5">
      <h3 className="font-bold text-slate-800 mb-4">
        {titulo}
      </h3>

      <div className="h-64">
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
      </div>
    </div>
  );
}