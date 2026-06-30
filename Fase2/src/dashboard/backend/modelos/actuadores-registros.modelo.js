const mongoose = require('mongoose');
const RegistroActuadoresEsquema = new mongoose.Schema({
  timestamp: { type: Date, default: Date.now },
  ACTUADOR: { type: String, required: true }, // 'bomba_agua', 'ventilador', 'luces', 'buzzer' 
  MODO: { type: String, required: true },
  ACCION:  { type: String, required: true },
});
module.exports = mongoose.model('RegistroActuador', RegistroActuadoresEsquema, 'registro_actuadores');