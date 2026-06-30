export function ActuatorToggle({
    label,
    state,
    onChange,
    subtitle,
    disabled = false
}) {

    return (
        <div className={`flex items-center justify-between p-3 rounded-lg transition-colors
            ${disabled
                ? 'opacity-50 bg-slate-100'
                : 'hover:bg-slate-50 '
            }`}>

            <div>
                <p className="font-semibold text-slate-800">
                    {label}
                </p>

                {subtitle && (
                    <p className="text-xs text-slate-500">
                        {subtitle}
                    </p>
                )}

                {disabled && (
                    <p className="text-xs text-red-500 mt-1">
                        Disponible solo en modo manual
                    </p>
                )}
            </div>

            <button
                onClick={onChange}
                disabled={disabled}
                className={`relative inline-flex h-7 w-12 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:ring-offset-2

                ${
                    disabled
                        ? 'bg-slate-200 cursor-not-allowed'
                        : state
                            ? 'bg-emerald-500'
                            : 'bg-slate-300'
                }`}
            >
                <span
                    className={`inline-block h-5 w-5 transform rounded-full bg-white transition-transform shadow-sm

                    ${
                        state
                            ? 'translate-x-6'
                            : 'translate-x-1'
                    }`}
                />
            </button>

        </div>
    );
}
