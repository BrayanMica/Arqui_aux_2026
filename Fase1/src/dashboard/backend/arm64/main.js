#!/usr/bin/env node
// main.js — Orquestador ARM64 (Node.js)
//
// Uso:      node main.js TEMPERATURA
//           node main.js LUZ
//           node main.js GAS
//
// Flujo:
//   1. Recibe columna por argv
//   2. Lee MongoDB sensor_readings → escribe lecturas.csv (30 filas)
//   3. Ejecuta 5 modulos ARM64 (qemu-aarch64 o nativo)
//   4. Recolecta resultados → JSON unificado
//   5. Escribe response_arm.json
//   6. Inserta en MongoDB arm64_resultados
//   7. Imprime JSON en stdout

import 'dotenv/config';
import { MongoClient } from 'mongodb';
import { execFile } from 'child_process';
import { readFileSync, writeFileSync, existsSync, accessSync, constants } from 'fs';
import { arch } from 'os';
import { dirname, resolve } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// ============================================================
// CONFIGURACION
// ============================================================

const MONGODB_URI = process.env.MONGODB_URI;
const MONGODB_DB = process.env.MONGODB_DB || 'Raspberry';
const MONGODB_COLLECTION = process.env.MONGODB_COLLECTION || 'arm64_resultados';
const COLECCION_SENSORES = process.env.MONGODB_COLLECTION_SENSORES || 'lectura_sensores';

const IS_AARCH64 = arch() === 'arm64';
const QEMU_PREFIX = IS_AARCH64 ? [] : ['qemu-aarch64'];

// ============================================================
// MAPEO DE COLUMNAS Y ALIAS
// ============================================================

const COLUMN_MAP = {
  ID: 1, TEMP: 2, HUM_AIRE: 3, HUM_SUELO_1: 4,
  HUM_SUELO_2: 5, LUZ: 6, GAS: 7, RIEGO_1: 8, RIEGO_2: 9
};

const COLUMN_ALIAS = {
  TEMPERATURA: 'TEMP',
  HUMEDAD: 'HUM_AIRE',
  HUMEDAD_AMBIENTAL: 'HUM_AIRE',
  HUM_AMBIENTE: 'HUM_AIRE',
  HUMEDAD_AMBIENTE: 'HUM_AIRE',
  HUMEDAD_SUELO: 'HUM_SUELO_1',
  HUMEDAD_SUELO_1: 'HUM_SUELO_1',
  HUMEDAD_SUELO_AREA1: 'HUM_SUELO_1',
  HUMEDAD_SUELO_2: 'HUM_SUELO_2',
  HUMEDAD_SUELO_AREA2: 'HUM_SUELO_2',
  LUZ: 'LUZ',
  GAS: 'GAS'
};

const MODULES = [
  './build/modulo_1_media',
  './build/modulo_2_varianza',
  './build/modulo_3_anomalias',
  './build/modulo_4_prediccion',
  './build/modulo_5_tendencia'
];

const OUTPUT_FILES = [
  'resultado_media.txt',
  'resultado_varianza.txt',
  'resultado_anomalias.txt',
  'resultado_prediccion.txt',
  'resultado_tendencia.txt'
];

const MAPA_CAMPOS = {
  TEMPERATURA: 'TEMP',
  HUMEDAD_AMBIENTAL: 'HUM_AIRE',
  HUMEDAD_SUELO_1: 'HUM_SUELO_1',
  HUMEDAD_SUELO_2: 'HUM_SUELO_2',
  LUZ: 'LUZ',
  GAS: 'GAS',
  RIEGO1: 'RIEGO_1',
  RIEGO2: 'RIEGO_2'
};

const COLUMNAS_CSV = [
  'ID', 'TEMP', 'HUM_AIRE', 'HUM_SUELO_1', 'HUM_SUELO_2',
  'LUZ', 'GAS', 'RIEGO_1', 'RIEGO_2'
];

const VALORES_DEFAULT = { HUM_SUELO_2: 0, RIEGO_2: 0, RIEGO_1: 0 };

const MODULE_TIMEOUT_MS = 30000;

// ============================================================
// GENERAR CSV DESDE MONGODB
// ============================================================

async function generarCSV(ruta = 'lecturas.csv', maxFilas = 30) {
  let client;
  try {
    client = new MongoClient(MONGODB_URI, { serverSelectionTimeoutMS: 5000 });
    await client.connect();
    await client.db().command({ ping: 1 });

    const db = client.db(MONGODB_DB);
    const col = db.collection(COLECCION_SENSORES);

    const total = await col.countDocuments();
    if (total < maxFilas) {
      return false;
    }

    const docs = await col.find().sort({ TIMESTAMP: -1 }).limit(maxFilas).toArray();
    if (docs.length < maxFilas) {
      return false;
    }

    docs.reverse();

    const lines = [COLUMNAS_CSV.join(',')];

    for (let i = 0; i < docs.length; i++) {
      const doc = docs[i];
      const fila = [String(i + 1)];

      for (let j = 1; j < COLUMNAS_CSV.length; j++) {
        const colCSV = COLUMNAS_CSV[j];
        let campoMongo = null;

        for (const [k, v] of Object.entries(MAPA_CAMPOS)) {
          if (v === colCSV) {
            campoMongo = k;
            break;
          }
        }

        if (campoMongo && doc[campoMongo] !== undefined && doc[campoMongo] !== null) {
          try {
            fila.push(String(parseInt(String(doc[campoMongo]), 10) || 0));
          } catch {
            fila.push(String(VALORES_DEFAULT[colCSV] ?? 0));
          }
        } else {
          fila.push(String(VALORES_DEFAULT[colCSV] ?? 0));
        }
      }

      lines.push(fila.join(','));
    }

    const csvPath = resolve(__dirname, ruta);
    writeFileSync(csvPath, lines.join('\n') + '\n');
    return true;
  } catch (e) {
    console.error(`[CSV-Mongo] Error: ${e.message}`);
    return false;
  } finally {
    if (client) {
      try { await client.close(); } catch { }
    }
  }
}

// ============================================================
// FUNCIONES AUXILIARES
// ============================================================

function resolverColumna(rawName) {
  const key = rawName.trim().toUpperCase();
  const alias = COLUMN_ALIAS[key] || key;
  return COLUMN_MAP[alias] ?? null;
}

function parsearTxt(filePath) {
  const data = {};
  const fullPath = resolve(__dirname, filePath);

  if (!existsSync(fullPath)) {
    return data;
  }

  try {
    const content = readFileSync(fullPath, 'utf-8');
    for (const line of content.split('\n')) {
      const trimmed = line.trim();
      if (!trimmed) continue;
      const eqIdx = trimmed.indexOf('=');
      if (eqIdx === -1) continue;

      const key = trimmed.substring(0, eqIdx).trim();
      const val = trimmed.substring(eqIdx + 1).trim();

      if (val.includes('.')) {
        const parsed = parseFloat(val);
        data[key] = Number.isNaN(parsed) ? val : parsed;
      } else {
        const parsed = parseInt(val, 10);
        data[key] = Number.isNaN(parsed) ? val : parsed;
      }
    }
  } catch (e) {
    console.error(`[Parser] Error en ${filePath}: ${e.message}`);
  }
  return data;
}

function ejecutarModulo(mod, colIndex) {
  return new Promise((resolve, reject) => {
    const cmd = [...QEMU_PREFIX, mod, String(colIndex)];
    const prog = cmd[0];
    const args = cmd.slice(1);

    execFile(prog, args, {
      cwd: __dirname,
      timeout: MODULE_TIMEOUT_MS,
      maxBuffer: 1024 * 1024
    }, (err, stdout, stderr) => {
      if (stdout) console.error(`[${mod}] stdout: ${stdout.trim()}`);
      if (stderr) console.error(`[${mod}] stderr: ${stderr.trim()}`);

      if (err) {
        const msg = [
          `[ARM64] ${mod} FAILED (exit ${err.code || err.signal}):`,
          stderr ? stderr.trim() : err.message
        ].filter(Boolean).join('\n       ');
        reject(new Error(msg));
        return;
      }

      resolve();
    });
  });
}

function verificarBinario(modPath) {
  const fullPath = resolve(__dirname, modPath);
  if (!existsSync(fullPath)) return false;
  try {
    accessSync(fullPath, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function verificarCSV(ruta = 'lecturas.csv', minimo = 30) {
  const fullPath = resolve(__dirname, ruta);
  if (!existsSync(fullPath)) return false;
  try {
    const content = readFileSync(fullPath, 'utf-8');
    const lines = content.trim().split('\n');
    return lines.length >= minimo + 1; // +1 por el header
  } catch {
    return false;
  }
}

// ============================================================
// ORQUESTADOR PRINCIPAL
// ============================================================

async function main(columnName) {
  const colIndex = resolverColumna(columnName);
  if (colIndex === null) {
    throw new Error(`Columna '${columnName}' no reconocida`);
  }

  // 1. Generar CSV desde MongoDB
  const okMongo = await generarCSV('lecturas.csv');
  if (!okMongo) {
    throw new Error('MongoDB sin datos suficientes (se necesitan >= 30 lecturas en sensor_readings)');
  }
  // 2. Verificar que los binarios existen
  for (const mod of MODULES) {
    if (!verificarBinario(mod)) {
      throw new Error(`Binario '${mod}' no encontrado o sin permisos de ejecucion. Ejecuta 'make' primero.`);
    }
  }

  // 3. Ejecutar modulos ARM64
  for (const mod of MODULES) {
    try {
      await ejecutarModulo(mod, colIndex);
    } catch (e) {
      throw new Error(`Fallo al ejecutar ${mod}: ${e.message}`);
    }
  }

  // 4. Recolectar resultados
  const unified = {
    timestamp: Math.floor(Date.now() / 1000),
    target_column: columnName.toUpperCase(),
    modules_data: {}
  };

  for (const f of OUTPUT_FILES) {
    const res = parsearTxt(f);
    if (res.MODULE) {
      const moduleName = res.MODULE;
      delete res.MODULE;
      unified.modules_data[moduleName] = res;
    }
  }

  // 5. Insertar en MongoDB
  let client;
  try {
    client = new MongoClient(MONGODB_URI, { serverSelectionTimeoutMS: 5000 });
    await client.connect();
    const col = client.db(MONGODB_DB).collection(MONGODB_COLLECTION);
    await col.insertOne(structuredClone(unified));
  } catch (e) {
    console.error(`[MongoDB] Error insertando: ${e.message}`);
  } finally {
    if (client) {
      try { await client.close(); } catch { }
    }
  }

  // 6. Escribir response_arm.json
  const payload = JSON.stringify(unified);
  writeFileSync(resolve(__dirname, 'response_arm.json'), payload);

  // 7. Imprimir JSON en stdout
  console.log(payload);
  return unified;
}

// ============================================================
// EXPORT PARA EL CONTROLADOR
// ============================================================

export async function ejecutarAnalisisARM(columna) {
  return await main(columna);
}

// ============================================================
// PUNTO DE ENTRADA (solo cuando se ejecuta directamente)
// ============================================================

const isMainModule = fileURLToPath(import.meta.url) === resolve(process.argv[1]);

if (isMainModule) {
  if (process.argv.length < 3) {
    console.log(JSON.stringify({ error: 'Uso: node main.js <COLUMNA>' }));
    console.log(JSON.stringify({ columnas: Object.keys(COLUMN_ALIAS) }));
    process.exit(1);
  }

  try {
    await main(process.argv[2]);
  } catch (e) {
    console.log(JSON.stringify({ error: e.message }));
    process.exit(1);
  }
}
