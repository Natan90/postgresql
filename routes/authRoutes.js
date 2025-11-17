const express = require('express');
const router = express.Router();
const pool = require('../database/db');
const bcrypt = require('bcrypt');

router.post('/register', async (req, res) => {
  const { email, password, nom, prenom } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'Email et mot de passe requis' });
  }

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const checkUser = await client.query(
      'SELECT id FROM utilisateurs WHERE email = $1',
      [email]
    );

    if (checkUser.rows.length > 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Email déjà utilisé' });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const result = await client.query(
      `INSERT INTO utilisateurs (email, password_hash, nom, prenom)
       VALUES ($1, $2, $3, $4)
       RETURNING id, email, nom, prenom, date_creation`,
      [email, passwordHash, nom || null, prenom || null]
    );

    const newUser = result.rows[0];

    await client.query(
      `INSERT INTO utilisateurs_roles (utilisateur_id, role_id, date_assignation)
       VALUES ($1, (SELECT id FROM roles WHERE nom = 'user'), NOW())`,
      [newUser.id]
    );

    await client.query('COMMIT');

    res.status(201).json({
      message: 'Utilisateur créé avec succès',
      user: newUser
    });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Erreur création utilisateur:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  } finally {
    client.release();
  }
});

module.exports = router;


const { v4: uuidv4 } = require('uuid');

router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const userResult = await client.query(
      'SELECT id, email, password_hash, nom, prenom, actif FROM utilisateurs WHERE email = $1',
      [email]
    );

    if (userResult.rows.length === 0) {
      await client.query(
        `INSERT INTO logs_connexion (utilisateur_id, email_tentative, date_heure, succes, message)
         VALUES (NULL, $1, NOW(), false, 'Email inexistant')`,
        [email]
      );
      await client.query('COMMIT');
      return res.status(401).json({ error: 'Email ou mot de passe incorrect' });
    }

    const user = userResult.rows[0];

    if (!user.actif) {
      await client.query(
        `INSERT INTO logs_connexion (utilisateur_id, email_tentative, date_heure, succes, message)
         VALUES ($1, $2, NOW(), false, 'Utilisateur inactif')`,
        [user.id, email]
      );
      await client.query('COMMIT');
      return res.status(403).json({ error: 'Utilisateur inactif' });
    }

    const passwordMatch = await bcrypt.compare(password, user.password_hash);
    if (!passwordMatch) {
      await client.query(
        `INSERT INTO logs_connexion (utilisateur_id, email_tentative, date_heure, succes, message)
         VALUES ($1, $2, NOW(), false, 'Mot de passe incorrect')`,
        [user.id, email]
      );
      await client.query('COMMIT');
      return res.status(401).json({ error: 'Email ou mot de passe incorrect' });
    }

   const token = uuidv4();
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + 24);

    await client.query(
      `INSERT INTO sessions (utilisateur_id, token, date_creation, date_expiration, actif)
       VALUES ($1, $2, NOW(), $3, TRUE)`,
      [user.id, token, expiresAt]
    );

    await client.query(
      `INSERT INTO logs_connexion (utilisateur_id, email_tentative, date_heure, succes, message)
       VALUES ($1, $2, NOW(), true, 'Connexion réussie')`,
      [user.id, email]
    );

    await client.query('COMMIT');

    res.json({
      message: 'Connexion réussie',
      token: token,
      user: {
        id: user.id,
        email: user.email,
        nom: user.nom,
        prenom: user.prenom
      },
      expiresAt: expiresAt
    });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Erreur login:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  } finally {
    client.release();
  }
});
