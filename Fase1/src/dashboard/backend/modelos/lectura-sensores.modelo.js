const mongoose = require('mongoose');
const LecturaSensorEsquema = new mongoose.Schema({
  timestamp: { type: Date, default: Date.now },
  GAS: { type: Number, required: true },
  HUMEDAD_AMBIENTAL: { type: Number, required: true },
  HUMEDAD_SUELO: { type: Number, required: true },
  TEMPERATURA: { type: Number, required: true },
  LUZ: { type: Number, required: true },
});
module.exports = mongoose.model('LecturaSensor', LecturaSensorEsquema, 'lectura_sensores');