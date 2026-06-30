export function DashboardSection({
  id,
  icon,
  title,
  description,
  children
}) {
  return (
    <section
      id={id}
      className="space-y-4 scroll-mt-24"
    >
      <div className="flex flex-col gap-1">
        <h2 className="text-lg font-bold flex items-center gap-2 text-slate-800">
          {icon}
          {title}
        </h2>

        {description && (
          <p className="text-sm text-slate-500">
            {description}
          </p>
        )}
      </div>

      {children}
    </section>
  );
}
