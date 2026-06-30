export default function ArmAnalytics({
    selectedColumn,
    setSelectedColumn,
    armData
}) {

    const mean =
        armData?.modules_data?.WEIGHTED_MEAN;

    const variance =
        armData?.modules_data?.VARIANCE;

    const anomaly =
        armData?.modules_data?.ANOMALY_DETECTION;

    const prediction =
        armData?.modules_data?.PREDICTION;

    const trend =
        armData?.modules_data?.ADVANCED_TREND;

    const riskColor = {
        NORMAL: "text-green-600",
        MEDIUM: "text-yellow-600",
        HIGH: "text-red-600"
    };

    const formatNumber = (value) => {
        if (value === undefined || value === null) {
            return "-";
        }

        return Number(value).toFixed(2);
    };

    return (
        <div className="space-y-6">

            {/* Selector */}

            <div className="bg-white rounded-2xl shadow-sm border p-5">

                <h3 className="font-bold mb-4">
                    Variable Analizada
                </h3>

                <select
                    value={selectedColumn}
                    onChange={(e) =>
                        setSelectedColumn(
                            e.target.value
                        )
                    }
                    className="w-full border rounded-lg p-3"
                >
                    <option value="TEMPERATURA">
                        Temperatura
                    </option>

                    <option value="HUMEDAD_AMBIENTAL">
                        Humedad Ambiental
                    </option>

                    <option value="HUMEDAD_SUELO_1">
                        Humedad Suelo 1
                    </option>

                    <option value="HUMEDAD_SUELO_2">
                        Humedad Suelo 2
                    </option>

                    <option value="LUZ">
                        Luz
                    </option>

                    <option value="GAS">
                        Gas
                    </option>
                </select>

            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">

                {/* MEDIA PONDERADA */}

                <div className="bg-white rounded-2xl border p-5">

                    <h3 className="font-bold mb-4">
                        Media Ponderada
                    </h3>

                    <div className="space-y-2">

                        <p>
                            Total valores:{" "}
                            <strong>
                                {mean?.TOTAL_VALUES ?? "-"}
                            </strong>
                        </p>

                        <p>
                            Suma:{" "}
                            <strong>
                                {formatNumber(
                                    mean?.SUM_X
                                )}
                            </strong>
                        </p>

                        <p>
                            Peso total:{" "}
                            <strong>
                                {formatNumber(
                                    mean?.WEIGHT_SUM
                                )}
                            </strong>
                        </p>

                    </div>

                    <p className="text-4xl font-bold text-indigo-600 mt-4">
                        {formatNumber(
                            mean?.WEIGHTED_MEAN
                        )}
                    </p>

                </div>

                {/* VARIANZA */}

                <div className="bg-white rounded-2xl border p-5">

                    <h3 className="font-bold mb-4">
                        Varianza
                    </h3>

                    <div className="space-y-2">

                        <p>
                            Total valores:{" "}
                            <strong>
                                {variance?.TOTAL_VALUES ?? "-"}
                            </strong>
                        </p>

                        <p>
                            Media:{" "}
                            <strong>
                                {formatNumber(
                                    variance?.MEAN
                                )}
                            </strong>
                        </p>

                        <p>
                            Varianza:{" "}
                            <strong>
                                {formatNumber(
                                    variance?.VARIANCE
                                )}
                            </strong>
                        </p>

                        <p>
                            Desviación estándar:{" "}
                            <strong>
                                {formatNumber(
                                    variance?.STD_DEV
                                )}
                            </strong>
                        </p>

                    </div>

                </div>

                {/* ANOMALIAS */}

                <div className="bg-white rounded-2xl border p-5">

                    <h3 className="font-bold mb-4">
                        Detección de Anomalías
                    </h3>

                    <div className="space-y-2">

                        <p>
                            Total valores:{" "}
                            <strong>
                                {anomaly?.TOTAL_VALUES ?? "-"}
                            </strong>
                        </p>

                        <p>
                            Media:{" "}
                            <strong>
                                {formatNumber(
                                    anomaly?.MEAN
                                )}
                            </strong>
                        </p>

                        <p>
                            Desviación estándar:{" "}
                            <strong>
                                {formatNumber(
                                    anomaly?.STD_DEV
                                )}
                            </strong>
                        </p>

                        <p>
                            Anomalías detectadas:{" "}
                            <strong>
                                {anomaly?.ANOMALIES ?? "-"}
                            </strong>
                        </p>

                    </div>

                    <p
                        className={`text-2xl font-bold mt-4 ${riskColor[
                            anomaly?.SYSTEM_RISK
                        ] || "text-slate-600"
                            }`}
                    >
                        Riesgo:{" "}
                        {anomaly?.SYSTEM_RISK || "-"}
                    </p>

                </div>

                {/* PREDICCION */}

                <div className="bg-white rounded-2xl border p-5">

                    <h3 className="font-bold mb-4">
                        Predicción
                    </h3>

                    <div className="space-y-2">

                        <p>
                            Valor inicial:{" "}
                            <strong>
                                {formatNumber(
                                    prediction?.INITIAL_VALUE
                                )}
                            </strong>
                        </p>

                        <p>
                            Valor final:{" "}
                            <strong>
                                {formatNumber(
                                    prediction?.FINAL_VALUE
                                )}
                            </strong>
                        </p>

                        <p>
                            Diferencia total:{" "}
                            <strong>
                                {formatNumber(
                                    prediction?.TOTAL_DIFF
                                )}
                            </strong>
                        </p>

                        <p>
                            Cambio promedio:{" "}
                            <strong>
                                {formatNumber(
                                    prediction?.AVG_CHANGE
                                )}
                            </strong>
                        </p>

                    </div>

                    <p className="text-4xl font-bold text-blue-600 mt-4">
                        {formatNumber(
                            prediction?.NEXT_VALUE
                        )}
                    </p>

                    <p className="text-sm text-slate-500 mt-1">
                        Próximo valor estimado
                    </p>

                </div>

                {/* TENDENCIA */}

                <div className="bg-white rounded-2xl border p-5 lg:col-span-2">

                    <h3 className="font-bold mb-4">
                        Tendencia Avanzada
                    </h3>

                    <div className="grid grid-cols-2 md:grid-cols-6 gap-4">

                        <div>

                            <p className="text-sm text-slate-500">
                                Incrementos
                            </p>

                            <p className="font-bold">
                                {trend?.INCREMENTS ?? "-"}
                            </p>

                        </div>

                        <div>

                            <p className="text-sm text-slate-500">
                                Decrementos
                            </p>

                            <p className="font-bold">
                                {trend?.DECREMENTS ?? "-"}
                            </p>

                        </div>

                        <div>

                            <p className="text-sm text-slate-500">
                                Racha ↑
                            </p>

                            <p className="font-bold">
                                {trend?.MAX_UP_STREAK ?? "-"}
                            </p>

                        </div>

                        <div>

                            <p className="text-sm text-slate-500">
                                Racha ↓
                            </p>

                            <p className="font-bold">
                                {trend?.MAX_DOWN_STREAK ?? "-"}
                            </p>

                        </div>

                        <div>

                            <p className="text-sm text-slate-500">
                                Diferencia acumulada
                            </p>

                            <p className="font-bold">
                                {formatNumber(
                                    trend?.ACCUM_DIFF
                                )}
                            </p>

                        </div>

                        <div>

                            <p className="text-sm text-slate-500">
                                Tendencia
                            </p>

                            <p className="font-bold text-xl">

                                {trend?.TREND === "UP" &&
                                    "↗ SUBIENDO"}

                                {trend?.TREND === "DOWN" &&
                                    "↘ BAJANDO"}

                                {trend?.TREND === "STABLE" &&
                                    "→ ESTABLE"}

                                {!trend?.TREND &&
                                    "-"}

                            </p>

                        </div>

                    </div>

                </div>

            </div>

        </div>
    );
}