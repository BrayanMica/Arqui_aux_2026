export const mockSensorData = {
  current: {
    temperature: 24.5,
    humidity: 60,
    soilMoisture: 45,
    lightLevel: 800,
    gasLevel: 15, // Normal < 50
    status: 'NORMAL' // NORMAL, ALERTA, EMERGENCIA
  },
  actuators: {
    waterPump: { active: false, mode: 'auto' }, // mode: auto | manual
    fan: { active: true },
    lights: { active: true },
    buzzer: { active: false }
  },
  armAnalysis: {
    weightedMeanTemp: 24.6,
    historicalTemp: [
      { time: '08:00', temp: 22.1 },
      { time: '09:00', temp: 23.0 },
      { time: '10:00', temp: 24.2 },
      { time: '11:00', temp: 24.5 },
      { time: '12:00', temp: 25.1 },
      { time: '13:00', temp: 24.8 }
    ],
    variance: 1.24,
    stdDeviation: 1.11,
    anomalies: [
      { id: 1, time: '10:15', sensor: 'Gas', value: 55, zScore: 3.2 },
      { id: 2, time: '12:45', sensor: 'Temp', value: 29.5, zScore: 2.8 }
    ],
    prediction: {
      nextHours: 3,
      estimatedTemp: 26.2
    },
    trend: 'UP' // UP, STABLE, DOWN
  },
  logs: [
    { id: 101, timestamp: '01/06/2026 14:32', type: 'EMERGENCIA', message: 'Nivel de gas excedido, extractor activado.' },
    { id: 102, timestamp: '01/06/2026 12:45', type: 'ALERTA', message: 'Pico de temperatura detectado.' },
    { id: 103, timestamp: '01/06/2026 08:00', type: 'NORMAL', message: 'Sistema iniciado correctamente.' }
  ]
};