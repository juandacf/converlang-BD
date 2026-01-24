-- ====================================================================================================================================================================
--------------------------------------------------------------------------------------CONVERLANG DATABASE--
-- ====================================================================================================================================================================

-- drops para el reinicio de la base de datos para pruebas
-- Se eliminan en orden inverso a las dependencias para evitar errores de clave foránea
-- Algunas FK se eliminan automáticamente con ON DELETE CASCADE por termas de integridad referencial.
DROP TABLE IF EXISTS audit_logs;        --tabla de logs de auditoría.
DROP TABLE IF EXISTS user_preferences;  --tabla de preferencias de usuario.
DROP TABLE IF EXISTS notifications;     --tabla de notificaciones .
DROP TABLE IF EXISTS user_progress;     --tabla de progreso de usuario
DROP TABLE IF EXISTS user_titles;       --tabla de títulos de usuario por logros.
DROP TABLE IF EXISTS titles;            --tabla de tipos de títulos disponibles.
DROP TABLE IF EXISTS chat_logs;         --tabla de logs de chat.
DROP TABLE IF EXISTS teaching_sessions; --tabla de sesiones de enseñanza pagadas y dadas por teachers.
DROP TABLE IF EXISTS user_matches;      --tabla de matches entre usuarios para empezar un conversación.
DROP TABLE IF EXISTS user_likes;        --tabla de likes entre usuarios para posibles matches e inicio de sesion.
DROP TABLE IF EXISTS exchange_sessions; --tabla de sesiones de intercambio de idiomas entre usuarios.     
DROP TABLE IF EXISTS sessions;          --tabla de sesiones (tanto de intercambio como de enseñanza).
DROP TABLE IF EXISTS teacher_profiles;  --tabla de perfiles de teachers (deben ser certificados para ingresar).
DROP TABLE IF EXISTS user_role_assignments; --tabla de asignaciones de roles a usuarios, tres roles.
DROP TABLE IF EXISTS users;             --tabla principal de usuarios.
DROP TABLE IF EXISTS gender_type;       --tipo enumerado para el género de los usuarios.
DROP TABLE IF EXISTS user_roles;        --tabla de roles disponibles en el sistema.
DROP TABLE IF EXISTS languages;         --tabla de idiomas soportados por la plataforma(serán ingles y español por el momento).
DROP TABLE IF EXISTS banks;             --tabla de bancos vinculados a países.
DROP TABLE IF EXISTS countries;         --tabla de países disponibles en la plataforma.



-- ================================================================
-- TABLA: countries
-- Almacena los países disponibles en la plataforma.
-- ================================================================
CREATE TABLE countries (
    country_code        VARCHAR(5) PRIMARY KEY,         -- ISO Alpha-2 codido de dos letras internacional ejemplo: ES: para España US: para Estados Unidos CO: para Colombia.
    country_name        VARCHAR(50) UNIQUE NOT NULL,    -- Nombre del país.
    timezone            VARCHAR(50),                    -- Zona horaria del país (ejemplo: 'America/New_York').
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Fecha y hora de creación del registro.
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- Fecha y hora de la última actualización del registro.
);

-- ================================================================
-- TABLA: banks
-- Bancos registrados en el sistema, vinculados a países para posibles integraciones futuras.
-- ================================================================
CREATE TABLE banks (
    bank_code           VARCHAR(20) PRIMARY KEY,            -- Código único del banco (ejemplo: 'BOFAUS' para Bank of America).
    bank_name           VARCHAR(100) UNIQUE NOT NULL,       -- Nombre del banco.
    country_id          VARCHAR(5) NOT NULL,                -- Código del país donde opera el banco (clave foránea a countries).
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Fecha y hora de creación del registro.
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,    -- Fecha y hora de la última actualización del registro.
    CONSTRAINT fk_country FOREIGN KEY (country_id) REFERENCES countries(country_code)
);

-- ================================================================
-- TABLA: languages
-- Idiomas soportados por la plataforma.
-- ================================================================
CREATE TABLE languages (
    language_code       VARCHAR(2) PRIMARY KEY,                 -- Código ISO 639-1 de dos letras (ejemplo: 'EN' para inglés, 'ES' para español).
    language_name       VARCHAR(100) UNIQUE NOT NULL,             -- Nombre del idioma.
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,    -- Fecha y hora de creación del registro.
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP    -- Fecha y hora de la última actualización del registro.
);

-- ================================================================
-- TABLA: user_roles
-- Define los roles disponibles en el sistema.
-- ================================================================
CREATE TABLE user_roles (
    role_code           VARCHAR(20) PRIMARY KEY,         -- Código único del rol (ejemplo: 'admin', 'teacher', 'user').
    role_name           VARCHAR(50) UNIQUE NOT NULL,     -- Nombre descriptivo del rol.
    description         TEXT,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP       -- Fecha y hora de creación del registro para auditorias de creación de usuarios.
);

-- ================================================================
-- ENUM: gender_type
-- Tipo enumerado para el género de los usuarios. Se crea una asignación de forma génerica acorde al orden de los datos suministrados, ejm. 1- masculino, 2 femenino. 
-- ================================================================
CREATE TABLE gender_type ( 
 gender_id  SERIAL PRIMARY KEY,
 gender_name  VARCHAR(30)
);

--4.1 GENDER
INSERT INTO gender_type(gender_name) VALUES('Masculino'), ('Femenino'), ('No binario'), ('Prefiero no decirlo');
-- ================================================================
-- TABLA: users
-- ================================================================
CREATE TABLE users (
    id_user             INTEGER PRIMARY KEY, -- Identificador único del usuario. Función secuencial personalizada para evitar huecos en la secuencia.
    first_name          VARCHAR(100) NOT NULL,                     -- Nombre del usuario.
    last_name           VARCHAR(100) NOT NULL,                     -- Apellido del usuario.
    email               VARCHAR(150) UNIQUE NOT NULL             
                        CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),     -- Correo electrónico del usuario con validación de formato.
    password_hash       VARCHAR(255) NOT NULL,                    -- Hash de la contraseña para autenticación segura se aplicara en el backend.
    gender_id           INTEGER,                 -- Género del usuario (usando el tipo enumerado).
    birth_date          DATE NOT NULL CHECK (birth_date <= CURRENT_DATE - INTERVAL '15 years'),
    country_id          VARCHAR(5) NOT NULL,                 -- Código del país del usuario (clave foránea a countries). 
    profile_photo       VARCHAR(255),                        -- URL o ruta de la foto de perfil del usuario.
    native_lang_id      VARCHAR(2) NOT NULL,                 -- Código del idioma nativo del usuario (clave foránea a languages).
    target_lang_id      VARCHAR(2) NOT NULL,                 -- Código del idioma que el usuario desea aprender (clave foránea a languages).
    match_quantity      INTEGER NOT NULL DEFAULT 10,         -- Cantidad máxima de matches que el usuario desea recibir por día.
    bank_id             VARCHAR(20),                         -- Código del banco vinculado al usuario (clave foránea a banks).
    role_code           VARCHAR(20),
    description         TEXT NOT NULL DEFAULT 'NO APLICA', -- Descripción o biografía del usuario.
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,     -- Indica si el usuario está activo en la plataforma.
    email_verified      BOOLEAN NOT NULL DEFAULT FALSE,    -- Indica si el correo electrónico del usuario ha sido verificado.
    last_login          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,   -- Fecha y hora del último inicio de sesión del usuario.
    created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,   -- Fecha y hora de creación del registro.
    updated_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,   -- Fecha y hora de la última actualización del registro.
    CONSTRAINT fk_country      FOREIGN KEY (country_id)     REFERENCES countries(country_code), 
    CONSTRAINT fk_native_lang  FOREIGN KEY (native_lang_id) REFERENCES languages(language_code), 
    CONSTRAINT fk_target_lang  FOREIGN KEY (target_lang_id) REFERENCES languages(language_code),
    CONSTRAINT fk_bank         FOREIGN KEY (bank_id)        REFERENCES banks(bank_code),
    CONSTRAINT fk_role_code     FOREIGN KEY (role_code)     REFERENCES user_roles(role_code), 
    CONSTRAINT fk_gender_id    FOREIGN KEY(gender_id)       REFERENCES  gender_type(gender_id)
);



-- ================================================================
-- TABLA: teacher_profiles
-- Perfiles adicionales para usuarios con rol de "teacher".
-- ================================================================
CREATE TABLE teacher_profiles (
    user_id              INTEGER PRIMARY KEY,   -- Identificador del usuario (clave foránea a users).
    teaching_language_id VARCHAR(2) NOT NULL,   -- Código del idioma que el teacher está certificado para enseñar (clave foránea a languages).
    lang_certification   VARCHAR(255),          -- Certificación de idioma del teacher (ejemplo: 'CELPE-Bras', 'DELE', 'TOEFL').
    academic_title       VARCHAR(255),          -- Título académico del teacher (ejemplo: 'Licenciatura en Educación', 'Maestría en Lingüística').
    experience_certification VARCHAR(255),      -- Certificación de experiencia del teacher (ejemplo: '5 años enseñando', 'Certificado TESOL').
    hourly_rate          DECIMAL(8,2),          -- Tarifa por hora del teacher en USD.
    specialization       TEXT,                  -- Áreas de especialización del teacher (ejemplo: 'Inglés de negocios', 'Preparación para exámenes').
    years_experience     INTEGER,               -- Años de experiencia enseñando.
    availability_notes   TEXT,                  -- Notas sobre la disponibilidad del teacher (ejemplo: 'Disponible fines de semana', 'Solo tardes').
    is_verified          BOOLEAN DEFAULT FALSE, -- Indica si el perfil del teacher ha sido verificado por un administrador.
    verified_at          TIMESTAMP,             -- Fecha y hora en que el perfil fue verificado.
    verified_by          INTEGER,               -- Identificador del usuario que verificó el perfil (clave foránea a users).
    created_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Fecha y hora de creación del registro.
    updated_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Fecha y hora de la última actualización del registro.
    CONSTRAINT fk_user_teacher  FOREIGN KEY (user_id)              REFERENCES users(id_user),
    CONSTRAINT fk_teaching_lang FOREIGN KEY (teaching_language_id) REFERENCES languages(language_code),
    CONSTRAINT fk_verified_by   FOREIGN KEY (verified_by)          REFERENCES users(id_user)
);

-- ================================================================
-- TABLA: sessions
-- Almacena las sesiones de intercambio y enseñanza entre usuarios.
-- ================================================================
CREATE TABLE sessions (
    session_id           VARCHAR(50) PRIMARY KEY,  -- Identificador único de la sesión (ejemplo: 'SES_20250728_001').
    id_user1             INTEGER NOT NULL,         -- Identificador del primer usuario participante (clave foránea a users).
    id_user2             INTEGER NOT NULL,         -- Identificador del segundo usuario participante (clave foránea a users).
    start_time           TIMESTAMP,                -- Fecha y hora de inicio de la sesión.
    end_time             TIMESTAMP,                -- Fecha y hora de finalización de la sesión.
    session_notes        TEXT,                     -- Notas adicionales sobre la sesión.
    created_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Fecha y hora de creación del registro.
    updated_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Fecha y hora de la última actualización del registro.
    CONSTRAINT fk_user1        FOREIGN KEY (id_user1)      REFERENCES users(id_user),
    CONSTRAINT fk_user2        FOREIGN KEY (id_user2)      REFERENCES users(id_user)
);

-- ================================================================
-- TABLA: exchange_sessions
-- Detalles específicos para sesiones de intercambio de idiomas entre usuarios.
-- ================================================================
CREATE TABLE exchange_sessions (                    
    session_id           VARCHAR(50) PRIMARY KEY, -- Identificador único de la sesión (clave foránea a sessions).
    session_rating_user1 INTEGER,                 -- Calificación dada por el primer usuario (1-5).
    session_rating_user2 INTEGER,                 -- Calificación dada por el segundo usuario (1-5).
    feedback_user1       TEXT,                    -- Comentarios o feedback del primer usuario.
    feedback_user2       TEXT,                    -- Comentarios o feedback del segundo usuario.
    CONSTRAINT fk_session FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- ================================================================
-- TABLA: user_likes
-- Registra los "likes" que los usuarios se dan entre sí para posibles matches e inicio de conversación.
-- ================================================================
CREATE TABLE user_likes (
    id_user_giver       INTEGER,        -- Identificador del usuario que da el like (clave foránea a users).
    id_user_receiver    INTEGER,        -- Identificador del usuario que recibe el like (clave foránea a users).
    like_time           TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Fecha y hora en que se dio el like.
    PRIMARY KEY (id_user_giver, id_user_receiver),           -- Clave primaria compuesta para evitar duplicados de likes entre los mismos usuarios.
    CONSTRAINT fk_user_giver   FOREIGN KEY (id_user_giver)    REFERENCES users(id_user), 
    CONSTRAINT fk_user_receiver FOREIGN KEY (id_user_receiver) REFERENCES users(id_user)
);

-- ================================================================
-- TABLA: user_matches
-- Registra los matches entre usuarios cuando ambos se han dado "like".
-- ================================================================
CREATE TABLE user_matches (
    match_id            SERIAL PRIMARY KEY,        -- Identificador único del match.
    user_1              INTEGER NOT NULL,          -- Primer usuario.
    user_2              INTEGER NOT NULL,          -- Segundo usuario.
    match_time          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_user_1 FOREIGN KEY (user_1) REFERENCES users(id_user),
    CONSTRAINT fk_user_2 FOREIGN KEY (user_2) REFERENCES users(id_user),
    CONSTRAINT chk_different_users CHECK (user_1 < user_2),
    CONSTRAINT uq_user_pair UNIQUE (user_1, user_2)  -- Evita duplicados entre los mismos usuarios.
);
-- ================================================================
-- TABLA: teaching_sessions
-- Detalles específicos para sesiones de enseñanza pagadas entre teachers y estudiantes.
-- ================================================================
CREATE TABLE teaching_sessions (
    session_id          VARCHAR(50) PRIMARY KEY,    -- Identificador único de la sesión (clave foránea a sessions).
    teacher_profile_id  INTEGER NOT NULL,           -- Identificador del perfil del teacher (clave foránea a teacher_profiles).
    student_id          INTEGER NOT NULL,           -- Identificador del estudiante (clave foránea a users).
    session_cost        DECIMAL(8,2),               -- Costo total de la sesión.
    teacher_notes       TEXT,                       -- Notas o comentarios del teacher sobre la sesión.
    student_rating      INTEGER,                    -- Calificación dada por el estudiante al teacher (1-5).   
    teacher_rating      INTEGER,                    -- Calificación dada por el teacher al estudiante (1-5).
    homework_assigned   TEXT,                       -- Tareas o ejercicios asignados por el teacher al estudiante.
    homework_completed  BOOLEAN DEFAULT FALSE,      -- Indica si el estudiante completó la tarea asignada.
    CONSTRAINT fk_teacher_profile   FOREIGN KEY (teacher_profile_id) REFERENCES teacher_profiles(user_id),
    CONSTRAINT fk_student           FOREIGN KEY (student_id)          REFERENCES users(id_user),
    CONSTRAINT fk_session_teacher   FOREIGN KEY (session_id)         REFERENCES sessions(session_id)
);

-- ================================================================
-- TABLA: chat_logs
-- Almacena los mensajes intercambiados durante las sesiones entre usuarios.
-- ================================================================
CREATE TABLE chat_logs (
    message_id          SERIAL PRIMARY KEY,
    match_id            INTEGER NOT NULL,
    sender_id           INTEGER NOT NULL,
    message             TEXT NOT NULL,
    timestamp           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,                                                    
    is_corrected        BOOLEAN DEFAULT FALSE,
    is_read             BOOLEAN DEFAULT FALSE,
    CONSTRAINT fk_match_id  FOREIGN KEY (match_id)  REFERENCES user_matches(match_id),
    CONSTRAINT fk_sender    FOREIGN KEY (sender_id) REFERENCES users(id_user)
);


-- ================================================================
-- TABLA: titles
-- Almacena los tipos de títulos o logros que los usuarios pueden obtener en la plataforma.
-- ================================================================
CREATE TABLE titles (
    title_code          VARCHAR(50) PRIMARY KEY,   -- Código único del título (ejemplo: 'lang_master', 'top_teacher').
    title_name          VARCHAR(100) NOT NULL,     -- Nombre del título.
    title_description   VARCHAR(255) NOT NULL      -- Descripción del título.
);

-- ================================================================
-- TABLA: user_titles
-- ================================================================
CREATE TABLE user_titles (
    id_user             INTEGER,              -- Identificador del usuario (clave foránea a users).
    title_code          VARCHAR(50),         -- Código del título obtenido (clave foránea a titles).
    earned_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Fecha y hora en que el usuario obtuvo el título.
    PRIMARY KEY (id_user, title_code),                        -- Clave primaria compuesta para evitar duplicados de títulos para el mismo usuario.
    CONSTRAINT fk_id_user_title FOREIGN KEY (id_user)    REFERENCES users(id_user),
    CONSTRAINT fk_title_code    FOREIGN KEY (title_code) REFERENCES titles(title_code)
);

-- ================================================================
-- TABLA: user_progress
-- Almacena el progreso de los usuarios en sus sesiones de aprendizaje.
-- ================================================================
CREATE TABLE user_progress (
    user_id              INTEGER,             -- Identificador del usuario (clave foránea a users).
    language_id          VARCHAR(2),        -- Código del idioma en el que el usuario está progresando (clave foránea a languages).
    last_updated         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  -- Fecha y hora de la última actualización del progreso.
    total_sessions       INTEGER DEFAULT 0,        -- Total de sesiones completadas por el usuario en el idioma.
    total_hours          DECIMAL(6,2) DEFAULT 0,   -- Total de horas acumuladas por el usuario en el idioma.
    notes                TEXT,                     -- Notas adicionales sobre el progreso del usuario.
    PRIMARY KEY (user_id, language_id),
    CONSTRAINT fk_user_progress     FOREIGN KEY (user_id)     REFERENCES users(id_user),
    CONSTRAINT fk_language_progress FOREIGN KEY (language_id) REFERENCES languages(language_code)
);

-- ================================================================
-- TABLA: notifications
-- Almacena las notificaciones enviadas a los usuarios.
-- ================================================================
CREATE TABLE notifications (
    notification_id       VARCHAR(50) PRIMARY KEY,      -- Identificador único de la notificación (ejemplo: 'NOT_20250728_001').
    user_id               INTEGER NOT NULL,             -- Identificador del usuario que recibe la notificación (clave foránea a users).
    title                 VARCHAR(200) NOT NULL,        -- Título o asunto de la notificación.
    message               TEXT NOT NULL,                -- Contenido o cuerpo de la notificación.
    notification_type     VARCHAR(50) NOT NULL,         -- Tipo de notificación (ejemplo: 'match', 'session', 'rating').
    related_entity_type   VARCHAR(50),                  -- Tipo de entidad relacionada (ejemplo: 'user_match', 'session', 'exchange_session').
    related_entity_id     VARCHAR(50),                  -- Identificador de la entidad relacionada (ejemplo: '2_3' para un match entre usuarios 2 y 3).
    is_read               BOOLEAN DEFAULT FALSE,        -- Indica si el usuario ha leído la notificación.
    read_at               TIMESTAMP,                    -- Fecha y hora en que el usuario leyó la notificación.
    created_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Fecha y hora de creación de la notificación.
    expires_at            TIMESTAMP,                        -- Fecha y hora en que la notificación expira y ya no es relevante.
    CONSTRAINT fk_notification_user FOREIGN KEY (user_id) REFERENCES users(id_user)
);

-- ================================================================
-- TABLA: user_preferences
-- Almacena las preferencias personalizadas de los usuarios en su landing.
-- ================================================================
CREATE TABLE user_preferences (
    user_id                 INTEGER PRIMARY KEY,            -- Identificador del usuario (clave foránea a users).
    theme                   BOOLEAN DEFAULT true,            -- True: light // False: Dark 
    language_code      VARCHAR(2) DEFAULT 'ES',        -- Idioma de la interfaz de usuario (clave foránea a languages).
    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,    -- Fecha y hora de creación del registro.
    updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,   -- Fecha y hora de la última actualización del registro.
    CONSTRAINT fk_preference_user FOREIGN KEY (user_id) REFERENCES users(id_user),
    CONSTRAINT fk_preference_language FOREIGN KEY (language_code) REFERENCES languages(language_code)  
);

-- ================================================================
-- TABLA: audit_logs
-- Almacena logs de auditoría para cambios críticos en la base de datos o modificaciones de usuarios.
-- ================================================================
CREATE TABLE audit_logs (
    audit_id                VARCHAR(50) PRIMARY KEY,        -- Identificador único del log de auditoría (ejemplo: 'AUD_20250728_001').
    table_name              VARCHAR(100) NOT NULL,          -- Nombre de la tabla donde ocurrió el cambio.
    record_id               VARCHAR(50) NOT NULL,           -- Identificador del registro afectado (puede ser un ID numérico o alfanumérico).
    action                  VARCHAR(20) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')), -- Tipo de acción realizada.
    old_values              JSON,                           -- Valores anteriores del registro (en formato JSON).
    new_values              JSON,                           -- Nuevos valores del registro (en formato JSON).
    changed_by              INTEGER,                        -- Identificador del usuario que realizó el cambio (clave foránea a users).
    changed_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,    -- Fecha y hora en que se realizó el cambio.    
    ip_address              VARCHAR(45),                    -- Dirección IP del usuario que realizó el cambio.
    user_agent              TEXT,                           -- Información del agente de usuario (navegador, dispositivo).
    CONSTRAINT fk_audit_user FOREIGN KEY (changed_by) REFERENCES users(id_user)
);

-- ================================================================
-- ÍNDICES (performance)
-- ================================================================

-- 1. Autenticación y usuarios
CREATE UNIQUE INDEX idx_users_email ON users(email);    --- Búsqueda rápida por email (autenticación).
CREATE INDEX idx_users_active_country ON users(is_active, country_id) WHERE is_active = true;  -- Filtrado rápido de usuarios activos por país.

-- 2. Matching
CREATE INDEX idx_users_matching ON users(country_id, native_lang_id, target_lang_id, is_active);  -- Búsqueda rápida para matching de usuarios activos por país e idiomas.

-- 3. Likes y matches
CREATE INDEX idx_user_likes_giver_receiver ON user_likes(id_user_giver, id_user_receiver);  -- Búsqueda rápida de likes entre usuarios.
CREATE INDEX idx_user_matches_users ON user_matches(user_1, user_2); -- Búsqueda rápida de matches entre usuarios.


-- 5. Notificaciones
CREATE INDEX idx_notifications ON notifications(user_id, is_read, created_at); -- Búsqueda rápida de notificaciones por usuario y estado de lectura.

-- 6. Teachers
CREATE INDEX idx_teacher_profiles_lang_verified ON teacher_profiles(teaching_language_id, is_verified) WHERE is_verified = true; -- Búsqueda rápida de teachers verificados por idioma que enseñan.
CREATE INDEX idx_teacher_profiles_rate ON teacher_profiles(hourly_rate, is_verified) WHERE is_verified = true;         -- Búsqueda rápida de teachers verificados por tarifa por hora.
CREATE INDEX idx_teacher_profiles_experience ON teacher_profiles(years_experience, is_verified) WHERE is_verified = true;  -- Búsqueda rápida de teachers verificados por años de experiencia.

-- ================================================================
-- 1. COUNTRIES
-- ================================================================
INSERT INTO countries (country_code, country_name, timezone) VALUES
('CO', 'Colombia', 'America/Bogota'),
('US', 'United States', 'America/New_York'),
('ES', 'Spain', 'Europe/Madrid'),
('BR', 'Brazil', 'America/Sao_Paulo'),
('FR', 'France', 'Europe/Paris');

-- ================================================================
-- 2. BANKS
-- ================================================================
INSERT INTO banks (bank_code, bank_name, country_id) VALUES
('BANCOLOMBIA', 'Bancolombia S.A.', 'CO'),
('BBVAES', 'BBVA España', 'ES'),
('BOFAUS', 'Bank of America', 'US'),
('ITAU', 'Banco Itaú', 'BR'),
('BNPFR', 'BNP Paribas', 'FR');

-- ================================================================
-- 3. LANGUAGES
-- ================================================================
INSERT INTO languages (language_code, language_name) VALUES
('ES', 'Español'),
('EN', 'Inglés'),
('FR', 'Francés'),
('PT', 'Portugués'),
('DE', 'Alemán');

-- ================================================================
-- 4. USER ROLES
-- ================================================================
INSERT INTO user_roles (role_code, role_name, description) VALUES
('admin', 'Administrador', 'Gestiona usuarios, contenido y sesiones'),
('user', 'Usuario', 'Participa en intercambios y sesiones gratuitas');


-- ================================================================
-- 6. USERS
-- ================================================================
INSERT INTO users (
    id_user, first_name, last_name, email, password_hash,
    gender_id, birth_date, country_id, profile_photo,
    native_lang_id, target_lang_id, match_quantity,
    bank_id, role_code, description, is_active, email_verified
) VALUES
(2001, 'John', 'Miller', 'john.miller@example.com', 'hash123', 1, '1995-03-12', 'US', NULL, 'EN', 'ES', 10, 'BOFAUS', 'user', 'Learner', TRUE, TRUE),
(2002, 'Emily', 'Johnson', 'emily.j@example.com', 'hash123', 2, '1998-07-25', 'US', NULL, 'EN', 'ES', 10, 'BOFAUS', 'user', 'Excited to learn', TRUE, TRUE),
(2003, 'Michael', 'Brown', 'michael.b@example.com', 'hash123', 1, '1992-10-02', 'US', NULL, 'EN', 'ES', 10, 'BOFAUS', 'user', 'Ready to practice', TRUE, TRUE),
(2004, 'Sarah', 'Davis', 'sarah.d@example.com', 'hash123', 2, '1999-01-17', 'US', NULL, 'EN', 'ES', 10, 'BOFAUS', 'user', 'Let’s practice Spanish!', TRUE, TRUE),
(2005, 'David', 'Smith', 'david.s@example.com', 'hash123', 1, '1990-09-11', 'US', NULL, 'EN', 'ES', 10, 'BOFAUS', 'user', 'Spanish learner', TRUE, TRUE),
(2006, 'Jessica', 'White', 'jessica.w@example.com', 'hash123', 2, '1996-04-06', 'US', NULL, 'EN', 'ES', 10, 'BOFAUS', 'user', 'Here to learn', TRUE, TRUE),
(2007, 'Kevin', 'Taylor', 'kevin.t@example.com', 'hash123', 1, '1989-08-19', 'US', NULL, 'EN', 'ES', 10, 'BOFAUS', 'user', 'Love languages', TRUE, TRUE),
(2008, 'Laura', 'Anderson', 'laura.a@example.com', 'hash123', 2, '1997-05-09', 'US', NULL, 'EN', 'ES', 10, 'BOFAUS', 'user', 'Here for exchange', TRUE, TRUE),
(2009, 'Brian', 'Clark', 'brian.c@example.com', 'hash123', 1, '1993-02-21', 'US', NULL, 'EN', 'ES', 10, 'BOFAUS', 'user', 'Happy to connect', TRUE, TRUE),
(2010, 'Rachel', 'Walker', 'rachel.w@example.com', 'hash123', 2, '1995-11-14', 'US', NULL, 'EN', 'ES', 10, 'BOFAUS', 'user', 'Practicing daily', TRUE, TRUE),

(2011, 'Anthony', 'Hall', 'anthony.h@example.com', 'hash123', 1, '1994-07-30', 'US', NULL, 'EN', 'ES', 10, 'BOFAUS', 'user', 'Portafolio', TRUE, TRUE),
(2012, 'Olivia', 'Moore', 'olivia.m@example.com', 'hash123', 2, '1999-03-22', 'US', NULL, 'EN', 'ES', 10, 'BOFAUS', 'user', 'Improving my Spanish', TRUE, TRUE),
(2013, 'Ethan', 'Lopez', 'ethan.l@example.com', 'hash123', 1, '1991-12-01', 'US', NULL, 'EN', 'ES', 10, 'BOFAUS', 'user', 'Traveler learning', TRUE, TRUE),
(2014, 'Sophia', 'Hill', 'sophia.h@example.com', 'hash123', 2, '1997-09-04', 'US', NULL, 'EN', 'ES', 10, 'BOFAUS', 'user', 'Looking for partners', TRUE, TRUE),
(2015, 'Daniel', 'Green', 'daniel.g@example.com', 'hash123', 1, '1990-06-18', 'US', NULL, 'EN', 'ES', 10, 'BOFAUS', 'user', 'Exchange session?', TRUE, TRUE),
(2016, 'Chloe', 'Adams', 'chloe.a@example.com', 'hash123', 2, '1996-10-26', 'US', NULL, 'EN', 'ES', 10, 'BOFAUS', 'user', 'Learning Latin Spanish', TRUE, TRUE),
(2017, 'Jason', 'Baker', 'jason.b@example.com', 'hash123', 1, '1993-08-07', 'US', NULL, 'EN', 'ES', 10, 'BOFAUS', 'user', 'Practice with me', TRUE, TRUE),
(2018, 'Grace', 'Carter', 'grace.c@example.com', 'hash123', 2, '1998-04-15', 'US', NULL, 'EN', 'ES', 10, 'BOFAUS', 'user', 'Hola amigos!', TRUE, TRUE),
(2019, 'Aaron', 'Turner', 'aaron.t@example.com', 'hash123', 1, '1992-02-10', 'US', NULL, 'EN', 'ES', 10, 'BOFAUS', 'user', 'Beginner in Spanish', TRUE, TRUE),
(2020, 'Megan', 'Perry', 'megan.p@example.com', 'hash123', 2, '1997-01-28', 'US', NULL, 'EN', 'ES', 10, 'BOFAUS', 'user', 'Let’s talk!', TRUE, TRUE);