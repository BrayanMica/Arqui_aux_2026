const mongoose = require('mongoose');
const ComandoEsquema = new mongoose.Schema({
  timestamp: { type: Date, default: Date.now },
  COMANDO: { type: String, required: true },
  ORIGEN: { type: String, required: true }
});
module.exports = mongoose.model('Comando', ComandoEsquema, 'comandos');