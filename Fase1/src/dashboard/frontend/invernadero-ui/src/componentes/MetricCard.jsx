import React from 'react';

export function MetricCard({ title, value, unit, icon, color }) {
    return (
        <div className={`p-4 rounded-xl border shadow-sm flex flex-col justify-between h-32 bg-white ${color.replace('bg-', 'hover:bg-').split(' ')[0]}`}>
            <div className="flex justify-between items-start">
                <h3 className="text-sm font-semibold text-slate-500">{title}</h3>
                <div className={`p-2 rounded-lg ${color}`}>{icon}</div>
            </div>
            <div>
                <span className="text-3xl font-bold text-slate-800">{value}</span>
                <span className="text-sm font-semibold text-slate-500 ml-1">{unit}</span>
            </div>
        </div>
    );
}