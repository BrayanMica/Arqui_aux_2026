const { execFile } = require("child_process");
const fs = require("fs").promises;
const path = require("path");

let ejecutarAnalisisARM;

async function cargarAnalisisARM() {
  if (!ejecutarAnalisisARM) {
    const modulo = await import("../arm64/main.js");
    console.error('[DEBUG] modulo keys:', Object.keys(modulo));
    console.error('[DEBUG] modulo.ejecutarAnalisisARM:', typeof modulo.ejecutarAnalisisARM);
    ejecutarAnalisisARM = modulo.ejecutarAnalisisARM;
  }
  console.error('[DEBUG] fn type:', typeof ejecutarAnalisisARM);
  return ejecutarAnalisisARM;
}


exports.getCalcularModuloARM = async (
  req,
  res
) => {

  try {

    const columna =
      req.params.columna_dato;

    const fn = await cargarAnalisisARM();
    const resultado =
      await fn(
        columna
      );

    return res.status(200).json(
      resultado
    );

  } catch (error) {

    console.error(error);

    return res.status(500).json({
      ok: false,
      error: error.message
    });

  }

};

exports.postCalcularModuloARM = async (
  req,
  res
) => {

  try {

    const columna =
      req.params.columna_dato;

    const fn = await cargarAnalisisARM();
    const resultado =
      await fn(
        columna
      );

    console.error('[DEBUG] resultado:', typeof resultado, resultado ? Object.keys(resultado) : null);

    return res.status(200).json(
      resultado
    );

  } catch (error) {

    console.error(error);

    return res.status(500).json({
      ok: false,
      error: error.message
    });

  }

};