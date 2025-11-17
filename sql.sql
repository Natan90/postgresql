CREATE TABLE utilisateurs (
    id SERIAL PRIMARY KEY,

    email TEXT UNIQUE NOT NULL
        CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),

    password_hash TEXT NOT NULL,

    nom TEXT,
    prenom TEXT,

    actif BOOLEAN DEFAULT TRUE,

    date_creation TIMESTAMP DEFAULT NOW(),
    date_modification TIMESTAMP DEFAULT NOW()
);


CREATE INDEX idx_utilisateurs_email ON utilisateurs(email);
CREATE INDEX idx_utilisateurs_actif ON utilisateurs(actif);



CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    nom TEXT UNIQUE NOT NULL,
    description TEXT,
    date_creation TIMESTAMP DEFAULT NOW()
);



CREATE TABLE permissions (
    id SERIAL PRIMARY KEY,
    nom TEXT UNIQUE NOT NULL,
    ressource TEXT NOT NULL,
    action TEXT NOT NULL,
    description TEXT,
    date_creation TIMESTAMP DEFAULT NOW(),

    CONSTRAINT unique_ressource_action UNIQUE (ressource, action)
);


CREATE TABLE utilisateur_roles (
    utilisateur_id INTEGER REFERENCES utilisateurs(id) ON DELETE CASCADE,
    role_id INTEGER REFERENCES roles(id) ON DELETE CASCADE,
    date_assignation TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (utilisateur_id, role_id)
);

CREATE TABLE role_permissions (
    role_id INTEGER REFERENCES roles(id) ON DELETE CASCADE,
    permission_id INTEGER REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE sessions (
    id SERIAL PRIMARY KEY,
    utilisateur_id INTEGER REFERENCES utilisateurs(id) ON DELETE CASCADE,
    token TEXT UNIQUE NOT NULL,
    date_creation TIMESTAMP DEFAULT NOW(),
    date_expiration TIMESTAMP,
    actif BOOLEAN DEFAULT TRUE
);

CREATE TABLE logs_connexion (
    id SERIAL PRIMARY KEY,
    utilisateur_id INTEGER REFERENCES utilisateurs(id) ON DELETE SET NULL,
    email_tentative TEXT NOT NULL,
    date_heure TIMESTAMP DEFAULT NOW(),
    adresse_ip TEXT,
    user_agent TEXT,
    succes BOOLEAN NOT NULL,
    message TEXT
);

CREATE INDEX idx_sessions_utilisateur_id ON sessions(utilisateur_id);
CREATE INDEX idx_logs_connexion_utilisateur_id ON logs_connexion(utilisateur_id);
CREATE INDEX idx_logs_connexion_date_heure ON logs_connexion(date_heure);


INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE r.nom = 'admin';

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE r.nom = 'moderator'
  AND p.nom IN ('read_users', 'read_posts', 'write_posts', 'delete_posts');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE r.nom = 'user'
  AND p.nom IN ('read_users', 'read_posts', 'write_posts');


CREATE OR REPLACE FUNCTION utilisateur_a_permission(
    p_utilisateur_id INT,
    p_ressource VARCHAR,
    p_action VARCHAR
)
RETURNS BOOLEAN AS $$
DECLARE
    has_permission BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM utilisateurs u
        JOIN utilisateurs_roles ur ON u.id = ur.utilisateur_id
        JOIN roles_permissions rp ON ur.role_id = rp.role_id
        JOIN permissions p ON rp.permission_id = p.id
        WHERE u.id = p_utilisateur_id
          AND u.actif = TRUE
          AND p.ressource = p_ressource
          AND p.action = p_action
    ) INTO has_permission;

    RETURN has_permission;
END;
$$ LANGUAGE plpgsql;


SELECT
    u.id,
    u.email,
    array_agg(r.nom) AS roles
FROM utilisateurs u
LEFT JOIN utilisateurs_roles ur ON u.id = ur.utilisateur_id
LEFT JOIN roles r ON ur.role_id = r.id
WHERE u.id = 1
GROUP BY u.id, u.email;


SELECT DISTINCT
    u.id AS utilisateur_id,
    u.email,
    p.nom AS permission,
    p.ressource,
    p.action
FROM utilisateurs u
JOIN utilisateurs_roles ur ON u.id = ur.utilisateur_id
JOIN roles_permissions rp ON ur.role_id = rp.role_id
JOIN permissions p ON rp.permission_id = p.id
WHERE u.id = 1
ORDER BY p.ressource, p.action;


SELECT
    r.nom AS role,
    COUNT(ur.utilisateur_id) AS nombre_utilisateurs
FROM roles r
LEFT JOIN utilisateurs_roles ur ON r.id = ur.role_id
GROUP BY r.nom
ORDER BY nombre_utilisateurs DESC;


SELECT
    u.id,
    u.email,
    array_agg(r.nom) AS roles
FROM utilisateurs u
JOIN utilisateurs_roles ur ON u.id = ur.utilisateur_id
JOIN roles r ON ur.role_id = r.id
WHERE r.nom IN ('admin', 'moderator')
GROUP BY u.id, u.email
HAVING COUNT(DISTINCT r.nom) = 2;


SELECT
    DATE(date_heure) AS jour,
    COUNT(*) AS tentatives_echouees
FROM logs_connexion
WHERE succes = false
  AND date_heure >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY DATE(date_heure)
ORDER BY jour DESC;





