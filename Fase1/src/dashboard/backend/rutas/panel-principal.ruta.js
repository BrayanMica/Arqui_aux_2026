const express = require('express');
const router = express.Router();
const panelPrincipalControlador = require('../controladores/panel-principal.controlador');

// Obtener logs de alertas y automatizaciones
router.get('/estado', panelPrincipalControlador.getDatosPanelPrincipal);

module.exports = router;