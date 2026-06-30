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

    const linea_inicial =
      req.params.linea_inicial;

    const linea_final =  
      req.params.linea_final;  


    const fn = await cargarAnalisisARM();
    const resultado = await fn(columna, linea_inicial, linea_final);

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

    // Agregamos la extracción de las líneas también en el POST
    const columna = req.params.columna_dato;
    const linea_inicial = req.params.linea_inicial;
    const linea_final = req.params.linea_final;

    const fn = await cargarAnalisisARM();
    
    const resultado = await fn(columna, linea_inicial, linea_final);

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