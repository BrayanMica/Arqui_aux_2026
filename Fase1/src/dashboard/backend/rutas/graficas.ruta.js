const express = require('express');
const router = express.Router();
const graficasControlador = require('../controladores/graficas.controlador');

// Obtener logs de alertas y automatizaciones
router.get('/graficas', graficasControlador.getDatosGraficas);

module.exports = router;