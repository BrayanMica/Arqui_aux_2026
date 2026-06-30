const express = require('express');
const router = express.Router();
const arm64Controlador = require('../controladores/resultado-ARM64.controlador');

// Obtener los datos procesados en ensamblador ARM64
router.get('/arm64/:columna_dato/:linea_inicial/:linea_final', arm64Controlador.getCalcularModuloARM);

module.exports = router;