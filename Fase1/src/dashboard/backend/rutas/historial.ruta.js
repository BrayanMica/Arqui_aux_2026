const express = require('express');
const router = express.Router();
const historialControlador = require('../controladores/historial.controlador');

// Obtener logs de alertas y automatizaciones
router.get('/historial', historialControlador.getHistorial);

module.exports = router;