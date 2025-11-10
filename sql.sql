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


CREATE TABLE utilisateurs_roles (
    utilisateur_id INTEGER REFERENCES utilisateurs(id) ON DELETE CASCADE,
    role_id INTEGER REFERENCES roles(id) ON DELETE CASCADE,
    PRIMARY KEY (utilisateur_id, role_id)
);


CREATE TABLE roles_permissions (
    role_id INTEGER REFERENCES roles(id) ON DELETE CASCADE,
    permission_id INTEGER REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);




