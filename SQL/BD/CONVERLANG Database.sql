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
DROP TYPE IF EXISTS gender_type CASCADE;       --tipo enumerado para el género de los usuarios.
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
CREATE TYPE gender_type AS ENUM ( 
    'masculino',                               
    'femenino',
    'no_binario',
    'otro',
    'prefiero_no_decir'
);

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
    gender              gender_type NOT NULL CHECK (gender IN ('masculino', 'femenino', 'no_binario', 'otro', 'prefiero_no_decir')),                     -- Género del usuario (usando el tipo enumerado).
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
    CONSTRAINT fk_role_code     FOREIGN KEY (role_code)     REFERENCES user_roles(role_code)
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
    session_type         VARCHAR(20) NOT NULL,     -- Tipo de sesión ('exchange' para intercambio, 'teaching' para enseñanza).
    start_time           TIMESTAMP,                -- Fecha y hora de inicio de la sesión.
    end_time             TIMESTAMP,                -- Fecha y hora de finalización de la sesión.
    session_status       VARCHAR(20) DEFAULT 'scheduled',  -- Estado de la sesión ('scheduled', 'completed', 'canceled', 'no_show').
    session_notes        TEXT,                     -- Notas adicionales sobre la sesión.
    language_used        VARCHAR(2),               -- Código del idioma utilizado en la sesión (clave foránea a languages).
    created_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Fecha y hora de creación del registro.
    updated_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Fecha y hora de la última actualización del registro.
    created_by           INTEGER,                             -- Identificador del usuario que creó la sesión (clave foránea a users).
    CONSTRAINT fk_language_used FOREIGN KEY (language_used) REFERENCES languages(language_code),
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
    message_id          VARCHAR(50) PRIMARY KEY,
    match_id            INTEGER NOT NULL,
    sender_id           INTEGER NOT NULL,
    message             TEXT NOT NULL,
    timestamp           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_corrected        BOOLEAN DEFAULT FALSE,
    reply_to            VARCHAR(50),
    is_read             BOOLEAN DEFAULT FALSE,
    CONSTRAINT fk_match_id  FOREIGN KEY (match_id)  REFERENCES user_matches(match_id),
    CONSTRAINT fk_sender    FOREIGN KEY (sender_id) REFERENCES users(id_user),
    CONSTRAINT fk_reply_to  FOREIGN KEY (reply_to)  REFERENCES chat_logs(message_id)
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
    theme                   VARCHAR(20) DEFAULT 'light',    -- Tema de la interfaz ('light' o 'dark').
    notifications_email     BOOLEAN DEFAULT true,           -- Prefiere recibir notificaciones por email.
    notifications_push      BOOLEAN DEFAULT false,          -- Prefiere recibir notificaciones push en la app móvil.
    notifications_matches   BOOLEAN DEFAULT true,           -- Prefiere recibir notificaciones de nuevos matches.
    notifications_sessions  BOOLEAN DEFAULT true,           -- Prefiere recibir notificaciones de nuevas sesiones.
    language_interface      VARCHAR(2) DEFAULT 'ES',        -- Idioma de la interfaz de usuario (clave foránea a languages).
    session_duration_pref   INTEGER DEFAULT 60,             -- Duración preferida de las sesiones en minutos (30, 60, 90).
    profile_visibility      VARCHAR(20) DEFAULT 'public',   -- Visibilidad del perfil ('public', 'private', 'friends_only').
    auto_accept_matches     BOOLEAN DEFAULT false,          -- Prefiere auto-aceptar nuevos matches.
    show_online_status      BOOLEAN DEFAULT true,           -- Prefiere mostrar su estado en línea a otros usuarios.
    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,    -- Fecha y hora de creación del registro.
    updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,   -- Fecha y hora de la última actualización del registro.
    CONSTRAINT fk_preference_user FOREIGN KEY (user_id) REFERENCES users(id_user)  
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



INSERT INTO countries (country_code, country_name, timezone, created_at, updated_at) VALUES
('US','United States','America/New_York',NOW(),NOW()),
('CA','Canada','America/Toronto',NOW(),NOW()),
('MX','Mexico','America/Mexico_City',NOW(),NOW()),
('GT','Guatemala','America/Guatemala',NOW(),NOW()),
('SV','El Salvador','America/El_Salvador',NOW(),NOW()),
('HN','Honduras','America/Tegucigalpa',NOW(),NOW()),
('NI','Nicaragua','America/Managua',NOW(),NOW()),
('CR','Costa Rica','America/Costa_Rica',NOW(),NOW()),
('PA','Panama','America/Panama',NOW(),NOW()),
('BZ','Belize','America/Belize',NOW(),NOW()),
('CO','Colombia','America/Bogota',NOW(),NOW()),
('VE','Venezuela','America/Caracas',NOW(),NOW()),
('EC','Ecuador','America/Guayaquil',NOW(),NOW()),
('PE','Peru','America/Lima',NOW(),NOW()),
('BO','Bolivia','America/La_Paz',NOW(),NOW()),
('CL','Chile','America/Santiago',NOW(),NOW()),
('AR','Argentina','America/Argentina/Buenos_Aires',NOW(),NOW()),
('UY','Uruguay','America/Montevideo',NOW(),NOW()),
('PY','Paraguay','America/Asuncion',NOW(),NOW()),
('BR','Brazil','America/Sao_Paulo',NOW(),NOW()),
('DO','Dominican Republic','America/Santo_Domingo',NOW(),NOW()),
('CU','Cuba','America/Havana',NOW(),NOW()),
('PR','Puerto Rico','America/Puerto_Rico',NOW(),NOW())
ON CONFLICT (country_code) DO NOTHING;

-- 2) BANKS --------------------------------------------------------
INSERT INTO banks (bank_code, bank_name, country_id, created_at, updated_at) VALUES
('CHASEUS','JPMorgan Chase','US',NOW(),NOW()),
('BOFAUS','Bank of America','US',NOW(),NOW()),
('SCOTIACA','Scotiabank Canada','CA',NOW(),NOW()),
('BBVAMX','BBVA Mexico','MX',NOW(),NOW()),
('BANAMXMX','Citibanamex','MX',NOW(),NOW()),
('BACCR','BAC Credomatic Costa Rica','CR',NOW(),NOW()),
('BCRCR','Banco de Costa Rica','CR',NOW(),NOW()),
('BPDOD','Banco Popular Dominicano','DO',NOW(),NOW()),
('BANRESERV','BanReservas','DO',NOW(),NOW()),
('DAVIVACO','Davivienda','CO',NOW(),NOW()),
('BANCOLCO','Bancolombia','CO',NOW(),NOW()),
('BCPPE','Banco de Crédito del Perú','PE',NOW(),NOW()),
('ITAUAR','Itaú Argentina','AR',NOW(),NOW()),
('SANTCL','Santander Chile','CL',NOW(),NOW()),
('IT AUBR','Itaú Brazil','BR',NOW(),NOW()),
('BRADBR','Bradesco','BR',NOW(),NOW()),
('BROUUY','Banco República','UY',NOW(),NOW()),
('BISA BO','Banco BISA','BO',NOW(),NOW()),
('PICHINEC','Banco Pichincha','EC',NOW(),NOW())
ON CONFLICT (bank_code) DO NOTHING;

-- 3) LANGUAGES (solo 4) ------------------------------------------
INSERT INTO languages (language_code, language_name, created_at, updated_at) VALUES
('ES','Español',NOW(),NOW()),
('EN','Inglés',NOW(),NOW()),
('PT','Português',NOW(),NOW()),
('FR','Français',NOW(),NOW())
ON CONFLICT (language_code) DO NOTHING;

-- 4) ROLES --------------------------------------------------------
INSERT INTO user_roles (role_code, role_name, description, created_at) VALUES
('admin','Administrador','Acceso total',NOW()),
('teacher','Teacher','Profesor certificado',NOW()),
('user','Usuario','Usuario base',NOW()),
('student','Estudiante','Aprendiz de idiomas',NOW())
ON CONFLICT (role_code) DO NOTHING;

-- 5) TITLES -------------------------------------------------------
INSERT INTO titles (title_code, title_name, title_description) VALUES
('lang_master','Maestro del Idioma','Alcanzó dominio avanzado'),
('top_teacher','Profesor Destacado','Altas calificaciones'),
('active_learner','Aprendiz Activo','Completó 10+ sesiones'),
('helper','Compañero Solidario','Ayudó a otros en sesiones')
ON CONFLICT (title_code) DO NOTHING;

-- 6) USERS (muchos) -----------------------------------------------
-- 40 usuarios distribuidos por América, con idiomas ES/EN/PT/FR
-- NOTA: Se fija id_user explícito para referenciar en tablas hijas.
INSERT INTO users
(id_user, first_name, last_name, email, password_hash, gender, birth_date, country_id, profile_photo, native_lang_id, target_lang_id, match_quantity, bank_id, role_code, description, is_active, email_verified, last_login, created_at, updated_at)
VALUES
(1,'Sofía','Ramírez','sofia.mx@example.com','h1','femenino','1994-05-12','MX',NULL,'ES','EN',10,'BBVAMX','admin','Amante de los idiomas',TRUE,TRUE,NOW(),NOW(),NOW()),
(2,'Lucas','Pereira','lucas.br@example.com','h2','masculino','1990-02-20','BR',NULL,'PT','EN',8,'BRADBR','teacher','De São Paulo',TRUE,TRUE,NOW(),NOW(),NOW()),
(3,'Camila','Gómez','camila.co@example.com','h3','femenino','1998-11-08','CO',NULL,'ES','FR',6,'BANCOLCO','user','Colombiana aprendiendo francés',TRUE,FALSE,NOW(),NOW(),NOW()),
(4,'John','Smith','john.us@example.com','h4','masculino','1987-07-03','US',NULL,'EN','ES',12,'CHASEUS','teacher','Viajero frecuente',TRUE,TRUE,NOW(),NOW(),NOW()),
(5,'Marie','Dupont','marie.fr@example.com','h5','femenino','1992-03-30','CA',NULL,'FR','EN',7,'SCOTIACA','user','Francófona en Canadá',TRUE,TRUE,NOW(),NOW(),NOW()),
(6,'Ana','Fernández','ana.ar@example.com','h6','femenino','1995-09-15','AR',NULL,'ES','EN',9,'ITAUAR','teacher','Docente argentina',TRUE,TRUE,NOW(),NOW(),NOW()),
(7,'Pedro','Silva','pedro.br@example.com','h7','masculino','1985-12-01','BR',NULL,'PT','ES',5,'IT AUBR','user','Amante del fútbol',TRUE,FALSE,NOW(),NOW(),NOW()),
(8,'Valentina','Ríos','valentina.cl@example.com','h8','femenino','1999-06-21','CL',NULL,'ES','EN',6,'SANTCL','user','Chilena curiosa',TRUE,TRUE,NOW(),NOW(),NOW()),
(9,'Andrés','Quispe','andres.pe@example.com','h9','masculino','1993-01-10','PE',NULL,'ES','EN',10,'BCPPE','user','Cusqueño',TRUE,TRUE,NOW(),NOW(),NOW()),
(10,'Daniela','Torres','daniela.co@example.com','h10','femenino','2000-04-25','CO',NULL,'ES','FR',7,'DAVIVACO','user','Bogotá, música y arte',TRUE,FALSE,NOW(),NOW(),NOW()),
(11,'José','García','jose.mx@example.com','h11','masculino','1991-08-18','MX',NULL,'ES','EN',6,'BANAMXMX','user','CDMX',TRUE,TRUE,NOW(),NOW(),NOW()),
(12,'Laura','Mendoza','laura.uy@example.com','h12','femenino','1996-02-14','UY',NULL,'ES','PT',8,'BROUUY','teacher','Uruguaya',TRUE,TRUE,NOW(),NOW(),NOW()),
(13,'Thiago','Costa','thiago.br@example.com','h13','masculino','1997-07-07','BR',NULL,'PT','ES',5,NULL,'user','Belo Horizonte',TRUE,FALSE,NOW(),NOW(),NOW()),
(14,'Carla','Morales','carla.cl@example.com','h14','femenino','1989-10-02','CL',NULL,'ES','EN',9,'SANTCL','teacher','Valparaíso',TRUE,TRUE,NOW(),NOW(),NOW()),
(15,'Gabriel','Rodríguez','gabriel.co@example.com','h15','masculino','1994-12-12','CO',NULL,'ES','EN',7,'BANCOLCO','user','Medellín',TRUE,TRUE,NOW(),NOW(),NOW()),
(16,'Emily','Johnson','emily.us@example.com','h16','femenino','1993-03-03','US',NULL,'EN','ES',8,'BOFAUS','user','NYC',TRUE,TRUE,NOW(),NOW(),NOW()),
(17,'Carlos','López','carlos.gt@example.com','h17','masculino','1992-09-09','GT',NULL,'ES','EN',6,NULL,'user','Guatemala City',TRUE,FALSE,NOW(),NOW(),NOW()),
(18,'Rosa','Mejía','rosa.sv@example.com','h18','femenino','1990-11-11','SV',NULL,'ES','EN',5,NULL,'teacher','San Salvador',TRUE,TRUE,NOW(),NOW(),NOW()),
(19,'Miguel','Hernández','miguel.hn@example.com','h19','masculino','1998-05-05','HN',NULL,'ES','EN',7,NULL,'user','Tegucigalpa',TRUE,TRUE,NOW(),NOW(),NOW()),
(20,'Lucía','Castro','lucia.ni@example.com','h20','femenino','1997-06-06','NI',NULL,'ES','EN',6,NULL,'teacher','Managua',TRUE,FALSE,NOW(),NOW(),NOW()),
(21,'Adrián','Solís','adrian.cr@example.com','h21','masculino','1991-01-21','CR',NULL,'ES','EN',8,'BCRCR','user','San José',TRUE,TRUE,NOW(),NOW(),NOW()),
(22,'Paula','Rojas','paula.pa@example.com','h22','femenino','1995-02-22','PA',NULL,'ES','EN',7,'BACCR','user','Ciudad de Panamá',TRUE,TRUE,NOW(),NOW(),NOW()),
(23,'Belén','Martínez','belen.bz@example.com','h23','femenino','1996-03-23','BZ',NULL,'ES','EN',6,NULL,'user','Belize City',TRUE,FALSE,NOW(),NOW(),NOW()),
(24,'Diego','Vera','diego.ve@example.com','h24','masculino','1988-04-24','VE',NULL,'ES','FR',9,NULL,'user','Caracas',TRUE,TRUE,NOW(),NOW(),NOW()),
(25,'Elena','Suárez','elena.ec@example.com','h25','femenino','1999-05-25','EC',NULL,'ES','EN',7,'PICHINEC','user','Quito',TRUE,TRUE,NOW(),NOW(),NOW()),
(26,'Hugo','Flores','hugo.pr@example.com','h26','masculino','1987-06-26','PR',NULL,'ES','EN',6,NULL,'user','San Juan',TRUE,TRUE,NOW(),NOW(),NOW()),
(27,'Renata','Almeida','renata.br@example.com','h27','femenino','1995-07-27','BR',NULL,'PT','ES',8,'BRADBR','teacher','Recife',TRUE,FALSE,NOW(),NOW(),NOW()),
(28,'Nicolás','Paz','nicolas.ar@example.com','h28','masculino','1996-08-28','AR',NULL,'ES','EN',10,'ITAUAR','user','Rosario',TRUE,TRUE,NOW(),NOW(),NOW()),
(29,'Patricia','Guzmán','patricia.cl@example.com','h29','femenino','1994-09-29','CL',NULL,'ES','FR',6,'SANTCL','teacher','Santiago',TRUE,TRUE,NOW(),NOW(),NOW()),
(30,'Eric','Brown','eric.us@example.com','h30','masculino','1993-10-30','US',NULL,'EN','ES',7,'CHASEUS','user','Miami',TRUE,TRUE,NOW(),NOW(),NOW()),
(31,'Santiago','Fuentes','santiago.co@example.com','h31','masculino','1997-01-15','CO',NULL,'ES','EN',6,'DAVIVACO','user','Cali',TRUE,TRUE,NOW(),NOW(),NOW()),
(32,'Marta','Álvarez','marta.mx@example.com','h32','femenino','1998-02-16','MX',NULL,'ES','EN',5,'BBVAMX','user','Guadalajara',TRUE,FALSE,NOW(),NOW(),NOW()),
(33,'Bruno','Cardoso','bruno.br@example.com','h33','masculino','1992-03-17','BR',NULL,'PT','EN',6,NULL,'user','Porto Alegre',TRUE,TRUE,NOW(),NOW(),NOW()),
(34,'Paige','Miller','paige.ca@example.com','h34','femenino','1991-04-18','CA',NULL,'EN','FR',8,'SCOTIACA','teacher','Toronto',TRUE,TRUE,NOW(),NOW(),NOW()),
(35,'Clara','Núñez','clara.uy@example.com','h35','femenino','1990-05-19','UY',NULL,'ES','PT',7,'BROUUY','user','Montevideo',TRUE,TRUE,NOW(),NOW(),NOW()),
(36,'Juan','Guevara','juan.pe@example.com','h36','masculino','1999-06-20','PE',NULL,'ES','EN',6,'BCPPE','user','Lima',TRUE,FALSE,NOW(),NOW(),NOW()),
(37,'Teresa','Vega','teresa.ec@example.com','h37','femenino','1986-07-21','EC',NULL,'ES','FR',7,'PICHINEC','user','Guayaquil',TRUE,TRUE,NOW(),NOW(),NOW()),
(38,'Marco','Díaz','marco.do@example.com','h38','masculino','1995-08-22','DO',NULL,'ES','EN',5,'BPDOD','user','Santo Domingo',TRUE,TRUE,NOW(),NOW(),NOW()),
(39,'Alicia','Reyes','alicia.cr@example.com','h39','femenino','1994-09-23','CR',NULL,'ES','EN',6,'BACCR','user','Heredia',TRUE,TRUE,NOW(),NOW(),NOW()),
(40,'Hélène','Moreau','helene.ca@example.com','h40','femenino','1992-10-24','CA',NULL,'FR','EN',8,'SCOTIACA','teacher','Montreal',TRUE,TRUE,NOW(),NOW(),NOW());



-- 8) TEACHER PROFILES --------------------------------------------
INSERT INTO teacher_profiles
(user_id, teaching_language_id, lang_certification, academic_title, experience_certification, hourly_rate, specialization, years_experience, availability_notes, is_verified, verified_at, verified_by, created_at, updated_at)
VALUES
(2,'PT','CELPE-Bras C1','Lic. Letras','5 años enseñando',22.00,'Portugués conversacional',5,'Lun-Vie 9-17',TRUE,NOW(),1,NOW(),NOW()),
(4,'EN','TESOL','BA English','3 años enseñando',30.00,'Business English',3,'Fines de semana',TRUE,NOW(),1,NOW(),NOW()),
(6,'ES','DELE C2','Prof. Lengua','6 años enseñando',18.00,'Español general',6,'Lun-Sáb',TRUE,NOW(),1,NOW(),NOW()),
(12,'ES','DELE C1','Lic. Educación','4 años enseñando',16.50,'Español para turismo',4,'Tardes',TRUE,NOW(),1,NOW(),NOW()),
(14,'ES','DELE B2','Lic. Lingüística','3 años enseñando',15.00,'Español para negocios',3,'Horario flexible',TRUE,NOW(),1,NOW(),NOW()),
(18,'ES','Cert. Docencia','Lic. Idiomas','5 años enseñando',14.00,'Conversación básica',5,'Noches',TRUE,NOW(),1,NOW(),NOW()),
(20,'ES','Cert. Idiomas','Lic. Lenguas','2 años enseñando',12.00,'Español para viajeros',2,'Fines de semana',TRUE,NOW(),1,NOW(),NOW()),
(27,'PT','CELPE-Bras B2','Lic. Educación','3 años enseñando',17.00,'Portugués para trabajo',3,'Mañanas',TRUE,NOW(),1,NOW(),NOW()),
(29,'ES','DELE C1','Lic. Educación','4 años enseñando',19.00,'Preparación DELE',4,'Tardes',TRUE,NOW(),1,NOW(),NOW()),
(34,'EN','CELTA','MA Applied Linguistics','6 años enseñando',32.00,'IELTS/TOEFL',6,'Horario flexible',TRUE,NOW(),1,NOW(),NOW()),
(40,'FR','DALF C1','BA French','5 años enseñando',28.00,'Francés profesional',5,'Mañanas y tardes',TRUE,NOW(),1,NOW(),NOW());

-- 9) SESSIONS (exchange y teaching) -------------------------------
INSERT INTO sessions (session_id, id_user1, id_user2, session_type, start_time, end_time, session_status, session_notes, language_used, created_at, updated_at, created_by)
VALUES
('SES_20250801_001', 3, 4, 'exchange', '2025-08-01 15:00:00','2025-08-01 16:00:00','completed','FR<->EN práctica','FR',NOW(),NOW(),3),
('SES_20250805_001', 5, 4, 'teaching', '2025-08-05 18:00:00','2025-08-05 19:00:00','completed','Clase de pronunciación','EN',NOW(),NOW(),5),
('SES_20250810_001', 1, 2, 'exchange', '2025-08-10 10:00:00','2025-08-10 11:00:00','completed','ES<->PT','ES',NOW(),NOW(),1),
('SES_20250815_001', 28, 34, 'exchange', '2025-08-15 14:00:00','2025-08-15 15:00:00','completed','EN<->ES','EN',NOW(),NOW(),28),
('SES_20250820_001', 36, 6, 'teaching', '2025-08-20 09:00:00','2025-08-20 10:00:00','scheduled','Preparar entrevista','ES',NOW(),NOW(),36),
('SES_20250822_001', 27, 8, 'exchange', '2025-08-22 09:00:00','2025-08-22 10:00:00','completed','PT<->ES','PT',NOW(),NOW(),27),
('SES_20250823_001', 40, 5, 'exchange', '2025-08-23 13:00:00','2025-08-23 14:00:00','completed','FR<->FR corrección','FR',NOW(),NOW(),40),
('SES_20250825_001', 21, 16, 'exchange', '2025-08-25 20:00:00','2025-08-25 21:00:00','scheduled','ES<->EN','EN',NOW(),NOW(),21);

-- 10) EXCHANGE_SESSIONS ------------------------------------------
INSERT INTO exchange_sessions (session_id, session_rating_user1, session_rating_user2, feedback_user1, feedback_user2) VALUES
('SES_20250801_001', 5, 4, 'Muy buena práctica', 'Camila fue genial'),
('SES_20250810_001', 4, 5, 'Aprendí expresiones nuevas', 'Sofía explica muy bien'),
('SES_20250822_001', 5, 5, 'Fluida y divertida', 'Renata es muy paciente'),
('SES_20250823_001', 4, 4, 'Correcciones útiles', 'Buen ritmo');

-- 11) USER_LIKES --------------------------------------------------
INSERT INTO user_likes (id_user_giver, id_user_receiver, like_time) VALUES
(1,2,'2025-08-09 12:00:00'),
(2,1,'2025-08-09 12:30:00'),
(3,4,'2025-07-31 10:00:00'),
(4,3,'2025-07-31 11:00:00'),
(28,34,'2025-08-14 18:00:00'),
(34,28,'2025-08-14 18:30:00'),
(27,8,'2025-08-21 08:00:00'),
(8,27,'2025-08-21 08:30:00'),
(21,16,'2025-08-24 19:00:00');

-- 12) USER_MATCHES ------------------------------------------------
-- Respetando (user_1 < user_2)
INSERT INTO user_matches (user_1, user_2, match_time) VALUES
(1,2,'2025-08-09 12:45:00'),
(3,4,'2025-07-31 11:30:00'),
(8,27,'2025-08-21 08:45:00'),
(28,34,'2025-08-14 18:45:00');

-- 13) TEACHING_SESSIONS ------------------------------------------
INSERT INTO teaching_sessions (session_id, teacher_profile_id, student_id, session_cost, teacher_notes, student_rating, teacher_rating, homework_assigned, homework_completed) VALUES
('SES_20250805_001', 4, 5, 30.00, 'Pronunciación de /th/ y entonación', 5, 5, 'Grabar 3 lecturas cortas', TRUE),
('SES_20250820_001', 6, 36, 18.00, 'Preparación de entrevista laboral', NULL, NULL, 'Practicar preguntas frecuentes', FALSE);

-- 15) USER_TITLES -------------------------------------------------
INSERT INTO user_titles (id_user, title_code, earned_at) VALUES
(2,'top_teacher','2025-08-05 19:05:00'),
(3,'active_learner','2025-08-01 16:05:00'),
(4,'helper','2025-08-05 19:10:00'),
(28,'active_learner','2025-08-15 15:10:00');

-- 16) USER_PROGRESS -----------------------------------------------
INSERT INTO user_progress (user_id, language_id, last_updated, total_sessions, total_hours, notes) VALUES
(3,'FR','2025-08-01 16:10:00',12,9.5,'Pronunciación nasal'),
(4,'ES','2025-08-01 16:12:00',4,3.0,'Perífrasis verbales'),
(1,'EN','2025-08-10 11:10:00',6,6.0,'Phrasal verbs'),
(28,'EN','2025-08-15 15:12:00',8,7.5,'Presentaciones'),
(27,'ES','2025-08-22 10:10:00',10,8.0,'Pasado simple');

-- 17) NOTIFICATIONS -----------------------------------------------
INSERT INTO notifications (notification_id, user_id, title, message, notification_type, related_entity_type, related_entity_id, is_read, read_at, created_at, expires_at) VALUES
('NOT_20250809_001', 2, 'Nuevo match', '¡Hiciste match con Sofía!', 'match', 'user_match', '1_2', TRUE, '2025-08-09 12:50:00', NOW(), '2025-09-09 12:50:00'),
('NOT_20250801_001', 3, 'Sesión completada', 'Tu sesión con John se completó.', 'session', 'session', 'SES_20250801_001', TRUE, '2025-08-01 16:00:00', NOW(), '2025-09-01 16:00:00'),
('NOT_20250805_001', 5, 'Clase evaluada', 'Has calificado a tu profesor.', 'rating', 'session', 'SES_20250805_001', TRUE, '2025-08-05 19:05:00', NOW(), '2025-09-05 19:05:00');

-- 18) USER_PREFERENCES --------------------------------------------
INSERT INTO user_preferences (user_id, theme, notifications_email, notifications_push, notifications_matches, notifications_sessions, language_interface, session_duration_pref, profile_visibility, auto_accept_matches, show_online_status, created_at, updated_at) VALUES
(1,'dark',TRUE,TRUE,TRUE,TRUE,'ES',60,'public',FALSE,TRUE,NOW(),NOW()),
(3,'dark',TRUE,FALSE,TRUE,TRUE,'ES',60,'public',FALSE,TRUE,NOW(),NOW()),
(4,'light',TRUE,FALSE,TRUE,TRUE,'EN',45,'public',FALSE,TRUE,NOW(),NOW()),
(5,'light',TRUE,TRUE,TRUE,TRUE,'FR',60,'friends_only',FALSE,TRUE,NOW(),NOW()),
(28,'dark',TRUE,FALSE,TRUE,TRUE,'ES',90,'public',FALSE,TRUE,NOW(),NOW());

-- 19) AUDIT_LOGS (ejemplo) ----------------------------------------
INSERT INTO audit_logs (audit_id, table_name, record_id, action, old_values, new_values, changed_by, changed_at, ip_address, user_agent) VALUES
('AUD_20250801_001','sessions','SES_20250801_001','INSERT',NULL,'{"id_user1":3,"id_user2":4}',1,'2025-08-01 14:50:00','10.0.0.1','psql'),
('AUD_20250805_001','teaching_sessions','SES_20250805_001','INSERT',NULL,'{"teacher_profile_id":4,"student_id":5}',1,'2025-08-05 17:50:00','10.0.0.1','psql');

-- FIN DEL SEED ----------------------------------------------------

