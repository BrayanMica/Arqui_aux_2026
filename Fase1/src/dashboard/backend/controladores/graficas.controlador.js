const LecturaSensor = require('../modelos/lectura-sensores.modelo');

exports.getDatosGraficas = async (req, res) => {
    try {

        const { rango = '24h' } = req.query;

        let fechaLimite = null;

        switch (rango) {

            case '1h':
                fechaLimite = new Date();
                fechaLimite.setHours(fechaLimite.getHours() - 1);
                break;

            case '6h':
                fechaLimite = new Date();
                fechaLimite.setHours(fechaLimite.getHours() - 6);
                break;

            case '12h':
                fechaLimite = new Date();
                fechaLimite.setHours(fechaLimite.getHours() - 12);
                break;

            case '24h':
                fechaLimite = new Date();
                fechaLimite.setHours(fechaLimite.getHours() - 24);
                break;

            case '7d':
                fechaLimite = new Date();
                fechaLimite.setDate(fechaLimite.getDate() - 7);
                break;

            case '30d':
                fechaLimite = new Date();
                fechaLimite.setDate(fechaLimite.getDate() - 30);
                break;

            case 'historico':
            default:
                fechaLimite = null;
                break;
        }

        const filtro = {};

        if (fechaLimite) {
            filtro.TIMESTAMP = {
                $gte: fechaLimite
            };
        }

        const datos = await LecturaSensor
            .find(filtro)
            .sort({ TIMESTAMP: 1 })
            .lean();

        const datosFormateados = datos.map(item => ({
            fecha: item.TIMESTAMP,

            TEMPERATURA: item.TEMPERATURA ?? 0,
            HUMEDAD_AMBIENTAL: item.HUMEDAD_AMBIENTAL ?? 0,
            GAS: item.GAS ?? 0,
            LUZ: item.LUZ ?? 0,
            HUMEDAD_SUELO: item.HUMEDAD_SUELO ?? 0,
        }));

        res.status(200).json({
            rango,
            total_puntos: datosFormateados.length,
            datos: datosFormateados
        });

    } catch (error) {

        console.error(error);

        res.status(500).json({
            error: error.message
        });

    }
};