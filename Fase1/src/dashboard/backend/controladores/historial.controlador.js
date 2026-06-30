const express = require('express');
const router = express.Router();

// Importar tus modelos exactos
const Comando = require('../modelos/comandos.modelo'); // Ajusta las rutas de tus archivos
const Evento = require('../modelos/eventos.modelo');
const EstadoSistema = require('../modelos/estado-sistema.modelo');
const RegistroActuador = require('../modelos/actuadores-registros.modelo');


exports.getHistorial = async (req, res) => {
    try {
        let { limite } = req.query;
        limite = parseInt(limite, 10) || 10;

        const [comandos, eventos, estados, actuadores] = await Promise.all([
            Comando.find().sort({ timestamp: -1 }).limit(limite),
            Evento.find().sort({ timestamp: -1 }).limit(limite),
            EstadoSistema.find().sort({ timestamp: -1 }).limit(limite),
            RegistroActuador.find().sort({ timestamp: -1 }).limit(limite)
        ]);

        const respuesta = {
            ultimos_comandos: comandos.map(c => ({
                id: c._id,
                timestamp: c.timestamp,
                COMANDO: c.COMANDO,
                ORIGEN: c.ORIGEN
            })),

            ultimas_alertas_eventos: eventos.map(e => ({
                id: e._id,
                timestamp: e.timestamp,
                TIPO: e.TIPO_EVENTO,
                DESCRIPCION: e.DESCRIPCION,
                VALOR: e.VALOR
            })),

            ultimos_estados_sistema: estados.map(est => ({
                id: est._id,
                timestamp: est.timestamp,
                ESTADO_GLOBAL: est.ESTADO_GLOBAL,
                MOTIVO: est.MOTIVO
            })),

            ultimas_activaciones_actuadores: actuadores.map(a => ({
                id: a._id,
                timestamp: a.timestamp,
                ACTUADOR: a.ACTUADOR,
                MODO: a.MODO,
                ACCION: a.ACCION
            }))
        };

        res.status(200).json(respuesta);

    } catch (error) {
        res.status(500).json({
            error_mensaje: error.message
        });
    }
};