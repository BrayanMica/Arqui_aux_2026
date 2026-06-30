const mongoose = require('mongoose');
const EventoEsquema = new mongoose.Schema({
  timestamp: { type: Date, default: Date.now },
  TIPO_EVENTO: { type: String, required: true },
  DESCRIPCION: { type: String, required: true },
  VALOR: { type: Number, required: true }
});
module.exports = mongoose.model('Evento', EventoEsquema, 'eventos');