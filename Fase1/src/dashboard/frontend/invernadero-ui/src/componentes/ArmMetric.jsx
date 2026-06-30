export function ArmMetric({
  titulo,
  valor
}) {
  return (
    <div className="bg-white rounded-2xl border p-5 shadow-sm">
      <p className="text-sm text-slate-500">
        {titulo}
      </p>

      <p className="text-3xl font-bold text-indigo-700 mt-2">
        {valor}
      </p>
    </div>
  );
}