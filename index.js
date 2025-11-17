const express = require('express');
require('dotenv').config();
const pool = require('./database/db');
const authRoutes = require('./routes/authRoutes');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.use('/api/auth', authRoutes);

app.get('/api/health', async (req, res) => {
  try {
    const result = await pool.query('SELECT NOW()');
    res.status(200).json({
      status: 'OK',
      server_time: result.rows[0].now
    });
  } catch (err) {
    console.error('❌ Erreur de health check:', err);
    res.status(500).json({ status: 'ERROR', message: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`✅ Serveur démarré sur http://localhost:${PORT}`);
});
