# main.py — Orquestador ARM64
#
# Uso:      python3 main.py TEMPERATURA
#           python3 main.py LUZ
#           python3 main.py GAS
#
# Flujo:
#   1. Recibe columna por argv
#   2. Lee MongoDB sensor_readings → escribe lecturas.csv (30 filas)
#   3. Ejecuta 5 modulos ARM64 (qemu-aarch64 o nativo)
#   4. Recolecta resultados → JSON unificado
#   5. Escribe response_arm.json
#   6. Inserta en MongoDB arm64_resultados
#   7. Imprime JSON en stdout

import sys
import os
import csv
import json
import time
import subprocess
from dotenv import load_dotenv
from pymongo import MongoClient

# ============================================================
# CONFIGURACION
# ============================================================

load_dotenv()

MONGODB_URI       = os.getenv("MONGODB_URI")
MONGODB_DB        = os.getenv("MONGODB_DB", "Raspberry")
MONGODB_COLLECTION = os.getenv("MONGODB_COLLECTION", "arm64_resultados")
COLECCION_SENSORES = os.getenv("MONGODB_COLLECTION_SENSORES", "lectura_sensores")

# Detectar arquitectura
ARCH_IS_AARCH64 = (os.uname().machine == "aarch64")
QEMU_PREFIX = [] if ARCH_IS_AARCH64 else ["qemu-aarch64"]

# ============================================================
# MAPEO DE COLUMNAS Y ALIAS
# ============================================================

COLUMN_MAP = {
    "ID": 1, "TEMP": 2, "HUM_AIRE": 3, "HUM_SUELO_1": 4,
    "HUM_SUELO_2": 5, "LUZ": 6, "GAS": 7, "RIEGO_1": 8, "RIEGO_2": 9
}

COLUMN_ALIAS = {
    "TEMPERATURA":         "TEMP",
    "HUMEDAD":             "HUM_AIRE",
    "HUMEDAD_AMBIENTAL":   "HUM_AIRE",
    "HUM_AMBIENTE":        "HUM_AIRE",
    "HUMEDAD_AMBIENTE":    "HUM_AIRE",
    "HUMEDAD_SUELO":       "HUM_SUELO_1",
    "HUMEDAD_SUELO_1":     "HUM_SUELO_1",
    "HUMEDAD_SUELO_AREA1": "HUM_SUELO_1",
    "HUMEDAD_SUELO_2":     "HUM_SUELO_2",
    "HUMEDAD_SUELO_AREA2": "HUM_SUELO_2",
    "LUZ":                 "LUZ",
    "GAS":                 "GAS",
}

MODULES = [
    "./build/modulo_1_media",
    "./build/modulo_2_varianza",
    "./build/modulo_3_anomalias",
    "./build/modulo_4_prediccion",
    "./build/modulo_5_tendencia"
]

OUTPUT_FILES = [
    "resultado_media.txt",
    "resultado_varianza.txt",
    "resultado_anomalias.txt",
    "resultado_prediccion.txt",
    "resultado_tendencia.txt"
]

# Mapeo de campos MongoDB → columnas CSV
MAPA_CAMPOS = {
    "TEMPERATURA":       "TEMP",
    "HUMEDAD_AMBIENTAL": "HUM_AIRE",
    "HUMEDAD_SUELO_1":   "HUM_SUELO_1",
    "HUMEDAD_SUELO_2":   "HUM_SUELO_2",
    "LUZ":               "LUZ",
    "GAS":               "GAS",
    "RIEGO1":            "RIEGO_1",
    "RIEGO2":            "RIEGO_2",
}

COLUMNAS_CSV = [
    "ID", "TEMP", "HUM_AIRE", "HUM_SUELO_1", "HUM_SUELO_2",
    "LUZ", "GAS", "RIEGO_1", "RIEGO_2"
]

VALORES_DEFAULT = {"HUM_SUELO_2": 0, "RIEGO_2": 0, "RIEGO_1": 0}

# ============================================================
# GENERAR CSV DESDE MONGODB
# ============================================================

def generar_csv_desde_mongo(ruta="lecturas.csv", max_filas=30):
    """Lee sensor_readings de MongoDB y escribe lecturas.csv."""
    try:
        mongo = MongoClient(MONGODB_URI, serverSelectionTimeoutMS=5000)
        mongo.server_info()
        col = mongo[MONGODB_DB][COLECCION_SENSORES]
        total = col.count_documents({})

        if total < max_filas:
            mongo.close()
            return False

        docs = list(col.find().sort("TIMESTAMP", -1).limit(max_filas))
        if len(docs) < max_filas:
            mongo.close()
            return False

        docs.reverse()

        with open(ruta, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(COLUMNAS_CSV)
            for i, doc in enumerate(docs, 1):
                fila = [i]
                for col_csv in COLUMNAS_CSV[1:]:
                    campo_mongo = None
                    for k, v in MAPA_CAMPOS.items():
                        if v == col_csv:
                            campo_mongo = k
                            break
                    if campo_mongo and campo_mongo in doc:
                        try:
                            fila.append(int(float(str(doc[campo_mongo]))))
                        except (ValueError, TypeError):
                            fila.append(VALORES_DEFAULT.get(col_csv, 0))
                    else:
                        fila.append(VALORES_DEFAULT.get(col_csv, 0))
                writer.writerow(fila)

        mongo.close()
        return True
    except Exception as e:
        print(f"[CSV-Mongo] Error: {e}", file=sys.stderr)
        return False

# ============================================================
# FUNCIONES AUXILIARES
# ============================================================

def resolver_columna(raw_name):
    key = raw_name.strip().upper()
    alias = COLUMN_ALIAS.get(key, key)
    return COLUMN_MAP.get(alias, None)


def parse_txt_to_dict(filepath):
    data = {}
    try:
        with open(filepath, 'r') as f:
            for line in f:
                line = line.strip()
                if '=' in line:
                    k, v = line.split('=', 1)
                    try:
                        data[k] = float(v) if '.' in v else int(v)
                    except ValueError:
                        data[k] = v
    except Exception as e:
        print(f"[Parser] Error en {filepath}: {e}", file=sys.stderr)
    return data


def run_arm64_modules(col_index):
    for mod in MODULES:
        cmd = QEMU_PREFIX + [mod, str(col_index)]
        subprocess.run(cmd, check=True)

# ============================================================
# ORQUESTADOR PRINCIPAL
# ============================================================

def main(column_name):
    col_index = resolver_columna(column_name)
    if col_index is None:
        print(json.dumps({"error": f"Columna '{column_name}' no reconocida"}))
        sys.exit(1)

    # 1. Generar CSV desde MongoDB
    ok = generar_csv_desde_mongo("lecturas.csv")
    if not ok:
        print(json.dumps({"error": "MongoDB sin datos suficientes (se necesitan >= 30 lecturas en sensor_readings)"}))
        sys.exit(1)

    # 2. Ejecutar modulos ARM64
    run_arm64_modules(col_index)

    # 3. Recolectar resultados
    unified = {
        "timestamp": int(time.time()),
        "target_column": column_name.upper(),
        "modules_data": {}
    }
    for f in OUTPUT_FILES:
        res = parse_txt_to_dict(f)
        if "MODULE" in res:
            unified["modules_data"][res.pop("MODULE")] = res

    # 4. Insertar en MongoDB
    try:
        mongo = MongoClient(MONGODB_URI, serverSelectionTimeoutMS=5000)
        col = mongo[MONGODB_DB][MONGODB_COLLECTION]
        col.insert_one(unified.copy())
        mongo.close()
    except Exception as e:
        print(f"[MongoDB] Error insertando: {e}", file=sys.stderr)

    # 5. Escribir response_arm.json
    payload = json.dumps(unified)
    with open("response_arm.json", "w") as f:
        f.write(payload)

    # 6. Imprimir JSON en stdout
    print(payload)

# ============================================================
# PUNTO DE ENTRADA
# ============================================================

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Uso: python3 main.py <COLUMNA>"}))
        print(json.dumps({"columnas": list(COLUMN_ALIAS.keys())}))
        sys.exit(1)

    main(sys.argv[1])
