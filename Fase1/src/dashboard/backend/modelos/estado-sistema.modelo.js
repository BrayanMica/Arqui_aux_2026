const mongoose = require('mongoose');
const EstadoSistemaEsquema = new mongoose.Schema({
  timestamp: { type: Date, default: Date.now },
  ESTADO_GLOBAL: { type: String, required: true },
  MOTIVO: { type: String, required: true }
});
module.exports = mongoose.model('EstadoSistema', EstadoSistemaEsquema, 'system_status');