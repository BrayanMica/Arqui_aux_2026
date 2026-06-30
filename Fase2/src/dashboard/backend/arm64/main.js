#!/usr/bin/env node
// main.js — Orquestador ARM64 (Node.js)
//
// Uso:      node main.js TEMPERATURA [linea_inicial] [linea_final]
//           node main.js LUZ 1 15
//           node main.js GAS 10 30
//
// Flujo:
//   1. Recibe columna, linea_inicial y linea_final por argv o controlador
//   2. Lee MongoDB sensor_readings → escribe lecturas.csv (filas limitadas)
//   3. Ejecuta primer bloque de módulos ARM64 (incluyendo regresión)
//   4. Extrae SLOPE_X100 del archivo resultado_regresion.txt
//   5. Ejecuta modulo_3_prediccion pasándole SLOPE_X100 como 5to parámetro
//   6. Ejecuta los módulos restantes
//   7. Recolecta resultados → JSON unificado
//   8. Escribe response_arm.json e inserta en MongoDB
//   9. Imprime JSON en stdout

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

// Módulos divididos en bloques estratégicos para manejar la dependencia
const PRIMER_BLOQUE_MODULES = [
  './build/modulo_1_media',
  './build/modulo_2_varianza',
  './build/modulo_3_anomalias',
  './build/modulo_4_prediccion',
  './build/modulo_5_tendencia',
];

const SEGUNDO_BLOQUE_MODULES = [
  './build/modulo_1_rmse',
  './build/modulo_2_regresion',
  './build/modulo_4_integral_error',
  './build/modulo_5_derivada_local'
];

// Array unificado solo para verificar la existencia de los binarios al inicio
const ALL_MODULES = [
  ...PRIMER_BLOQUE_MODULES,
  './build/modulo_3_prediccion',
  ...SEGUNDO_BLOQUE_MODULES
];

const OUTPUT_FILES = [
  'resultado_media.txt',
  'resultado_varianza.txt',
  'resultado_anomalias.txt',
  'resultado_prediccion.txt',
  'resultado_tendencia.txt',

  'resultado_rmse.txt',
  'resultado_regresion.txt',
  'resultado_prediccion_m3.txt',
  'resultado_integral.txt',
  'resultado_derivada.txt'
];

const MAPA_CAMPOS = {
  TEMPERATURA: 'TEMP',
  HUMEDAD_AMBIENTAL: 'HUM_AIRE',
  HUMEDAD_SUELO: 'HUM_SUELO_1',
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

function ejecutarModulo(mod, colIndex, lineaInicial, lineaFinal) {
  return new Promise((resolve, reject) => {
    const cmd = [...QEMU_PREFIX, mod, String(colIndex), String(lineaInicial), String(lineaFinal)];
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

// ============================================================
// ORQUESTADOR PRINCIPAL
// ============================================================

async function main(columnName, iniStr = '1', finStr = '30') {
  const colIndex = resolverColumna(columnName);
  if (colIndex === null) {
    throw new Error(`Columna '${columnName}' no reconocida`);
  }

  // Sanitizar rangos
  const lineaInicial = parseInt(iniStr, 10) || 1;
  const lineaFinal = parseInt(finStr, 10) || 30;

  if (lineaInicial <= 0 || lineaFinal < lineaInicial) {
    throw new Error(`Rango de líneas inválido: ${lineaInicial} a ${lineaFinal}`);
  }

  const maxFilasNecesarias = Math.max(30, lineaFinal);

  // 1. Generar CSV desde MongoDB
  const okMongo = await generarCSV('lecturas.csv', maxFilasNecesarias);
  if (!okMongo) {
    throw new Error(`MongoDB sin datos suficientes (se necesitan >= ${maxFilasNecesarias} lecturas en lectura_sensores)`);
  }

  // 2. Verificar que todos los binarios existen
  for (const mod of ALL_MODULES) {
    if (!verificarBinario(mod)) {
      throw new Error(`Binario '${mod}' no encontrado o sin permisos de ejecucion. Ejecuta 'make' primero.`);
    }
  }

  // 3. Ejecutar PRIMER BLOQUE de módulos ARM64 (Calcula la regresión)
  for (const mod of PRIMER_BLOQUE_MODULES) {
    try {
      await ejecutarModulo(mod, colIndex, lineaInicial, lineaFinal);
    } catch (e) {
      throw new Error(`Fallo al ejecutar ${mod}: ${e.message}`);
    }
  }

  // 4. Interceptación: Extraer SLOPE_X100 de la regresión
  const datosRegresion = parsearTxt('resultado_regresion.txt');
  const slopeX100 = datosRegresion.SLOPE_X100 ?? 0;
  console.error(`[ORQUESTADOR] Pendiente detectada para módulo 3 (SLOPE_X100): ${slopeX100}`);

  // 5. Ejecutar de forma dedicada './build/modulo_3_prediccion' con el parámetro extra
  try {
    const mod3 = './build/modulo_3_prediccion';
    await new Promise((resolve, reject) => {
      const cmd = [...QEMU_PREFIX, mod3, String(colIndex), String(lineaInicial), String(lineaFinal), String(slopeX100)];
      const prog = cmd[0];
      const args = cmd.slice(1);

      execFile(prog, args, {
        cwd: __dirname,
        timeout: MODULE_TIMEOUT_MS,
        maxBuffer: 1024 * 1024
      }, (err, stdout, stderr) => {
        if (stdout) console.error(`[${mod3}] stdout: ${stdout.trim()}`);
        if (stderr) console.error(`[${mod3}] stderr: ${stderr.trim()}`);
        if (err) return reject(err);
        resolve();
      });
    });
  } catch (e) {
    throw new Error(`Fallo al ejecutar ./build/modulo/modulo_3_prediccion con parámetro dependiente: ${e.message}`);
  }

  // 6. Ejecutar SEGUNDO BLOQUE de módulos restantes
  for (const mod of SEGUNDO_BLOQUE_MODULES) {
    try {
      await ejecutarModulo(mod, colIndex, lineaInicial, lineaFinal);
    } catch (e) {
      throw new Error(`Fallo al ejecutar ${mod}: ${e.message}`);
    }
  }

  // 7. Recolectar resultados
  const unified = {
    timestamp: Math.floor(Date.now() / 1000),
    target_column: columnName.toUpperCase(),
    linea_inicial: lineaInicial,
    linea_final: lineaFinal,
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

  // 8. Insertar en MongoDB
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

  // 9. Escribir response_arm.json
  const payload = JSON.stringify(unified);
  writeFileSync(resolve(__dirname, 'response_arm.json'), payload);

  // 10. Imprimir JSON en stdout
  console.log(payload);
  return unified;
}

// ============================================================
// EXPORT PARA EL CONTROLADOR EXPRESS
// ============================================================

export async function ejecutarAnalisisARM(columna, linea_inicial, linea_final) {
  return await main(columna, linea_inicial, linea_final);
}

// ============================================================
// PUNTO DE ENTRADA DESDE TERMINAL (CLI)
// ============================================================

const isMainModule = fileURLToPath(import.meta.url) === resolve(process.argv[1]);

if (isMainModule) {
  if (process.argv.length < 3) {
    console.log(JSON.stringify({ error: 'Uso: node main.js <COLUMNA> [linea_inicial] [linea_final]' }));
    console.log(JSON.stringify({ ejemplos: ['node main.js TEMPERATURA', 'node main.js LUZ 1 15'] }));
    process.exit(1);
  }

  try {
    await main(process.argv[2], process.argv[3], process.argv[4]);
  } catch (e) {
    console.log(JSON.stringify({ error: e.message }));
    process.exit(1);
  }
}