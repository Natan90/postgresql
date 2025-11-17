const pool = require('../database/db');

async function requireAuth(req, res, next) {
  const token = req.headers['authorization'];
  if (!token) {
    return res.status(401).json({ error: 'Token manquant' });
  }

  try {
    const result = await pool.query(
      `SELECT u.id, u.email, u.nom, u.prenom
       FROM sessions s
       JOIN utilisateurs u ON s.utilisateur_id = u.id
       WHERE s.token = $1
         AND s.actif = TRUE
         AND s.date_expiration > NOW()
         AND u.actif = TRUE`,
      [token]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Token invalide ou expiré' });
    }

    req.user = {
      id: result.rows[0].id,
      email: result.rows[0].email,
      nom: result.rows[0].nom,
      prenom: result.rows[0].prenom
    };

    next();
  } catch (error) {
    console.error('Erreur middleware auth:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

module.exports = { requireAuth };
