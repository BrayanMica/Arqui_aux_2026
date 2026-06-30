require('dotenv').config();
const express = require('express');
const connectDB = require('./configuracion/db');
const cors = require('cors');


// Inicializar Express
const app = express();

// Conectar a Base de Datos en MongoDB Atlas
connectDB();

// Middlewares globales
app.use(express.json());
app.use(cors());


// API REST
app.use('/api/invernadero', require('./rutas/resultados-ARM64.ruta'));
app.use('/api/invernadero', require('./rutas/graficas.ruta'));
app.use('/api/invernadero', require('./rutas/historial.ruta'));

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Servidor Express ejecutándose en el puerto ${PORT}`);
});