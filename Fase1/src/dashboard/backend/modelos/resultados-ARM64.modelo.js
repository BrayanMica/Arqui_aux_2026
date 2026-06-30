const mongoose = require('mongoose');
const ResultadosARM64Esquema = new mongoose.Schema({
  timestamp: { type: Date, default: Date.now },
  tipo_dato: { type: String, required: true }, // 'MEDIA_PONDERADA', 'VARIANZA', 'ANOMALIAS', etc.
  resultados: { type: mongoose.Schema.Types.Mixed, required: true } // Almacena el JSON dinámico mapeado desde el .txt
});
module.exports = mongoose.model('ResultadoArm64', ResultadosARM64Esquema, 'arm64_resultados');