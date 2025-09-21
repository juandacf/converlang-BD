-- Eliminación previa de objetos para evitar conflictos
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS user_preferences;
DROP TABLE IF EXISTS user_settings;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS user_progress;
DROP TABLE IF EXISTS user_titles;
DROP TABLE IF EXISTS titles;
DROP TABLE IF EXISTS chat_logs;
DROP TABLE IF EXISTS teaching_sessions;
DROP TABLE IF EXISTS user_matches;
DROP TABLE IF EXISTS user_likes;
DROP TABLE IF EXISTS exchange_sessions;
DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS teacher_profiles;
DROP TABLE IF EXISTS user_role_assignments;
DROP FUNCTION IF EXISTS fun_insert_usuarios;
DROP TABLE IF EXISTS users;
DROP TYPE IF EXISTS  gender_type;
DROP TABLE IF EXISTS user_roles;
DROP TABLE IF EXISTS languages;
DROP TABLE IF EXISTS banks;
DROP TABLE IF EXISTS countries;

-- ================================================================
-- TABLA: countries
-- Almacena los países disponibles en la plataforma.
-- ================================================================
CREATE TABLE countries (
    country_code        VARCHAR(5) PRIMARY KEY,   -- Código ISO o personalizado del país (ej: "CO").
    country_name        VARCHAR(50) UNIQUE NOT NULL, -- Nombre único del país.
    timezone            VARCHAR(50),             -- Zona horaria del país.
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Fecha de creación.
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- Fecha de actualización.
);

-- ================================================================
-- TABLA: banks
-- Bancos registrados en el sistema, vinculados a países.
-- ================================================================
CREATE TABLE banks (
    bank_code           VARCHAR(20) PRIMARY KEY,  -- Código único del banco.
    bank_name           VARCHAR(100) UNIQUE NOT NULL, -- Nombre único del banco.
    country_id          VARCHAR(5) NOT NULL,      -- Relación al país (FK con countries).
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_country FOREIGN KEY (country_id) REFERENCES countries(country_code)
);

-- ================================================================
-- TABLA: languages
-- Idiomas soportados por la plataforma.
-- ================================================================
CREATE TABLE languages (
    language_code       VARCHAR(2) PRIMARY KEY,  -- Código ISO de idioma (ej: "EN", "ES").
    language_name       VARCHAR(100) UNIQUE NOT NULL, -- Nombre único del idioma.
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================================================
-- TABLA: user_roles
-- Define los roles disponibles en el sistema.
-- ================================================================
CREATE TABLE user_roles (
    role_code           VARCHAR(20) PRIMARY KEY,  -- Identificador único del rol.
    role_name           VARCHAR(50) UNIQUE NOT NULL, -- Nombre único del rol.
    description         TEXT,                     -- Descripción del rol.
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================================================
-- ENUM: gender_type
-- Define valores válidos para género en usuarios.
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
-- Información de los usuarios registrados.
-- ================================================================
CREATE TABLE users (
    id_user             SERIAL PRIMARY KEY, -- ID autoincremental.
    first_name          VARCHAR(100) NOT NULL, -- Nombre del usuario.
    last_name           VARCHAR(100) NOT NULL, -- Apellido del usuario.
    email               VARCHAR(150) UNIQUE NOT NULL 
                        CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'), 
                        -- Validación de formato de correo con regex.
    password_hash       VARCHAR(255) NOT NULL, -- Hash de la contraseña.
    gender              gender_type NOT NULL,  -- Género (ENUM).
    birth_date          DATE NOT NULL CHECK (birth_date <= CURRENT_DATE - INTERVAL '15 years'),
                        -- Validación: usuario debe tener mínimo 15 años.
    country_id          VARCHAR(5) NOT NULL,   -- País de residencia (FK con countries).
    profile_photo       VARCHAR(255),          -- URL de foto de perfil.
    native_lang_id      VARCHAR(2) NOT NULL,   -- Idioma nativo (FK con languages).
    target_lang_id      VARCHAR(2) NOT NULL,   -- Idioma objetivo (FK con languages).
    match_quantity      INTEGER NOT NULL,      -- Cantidad de matches.
    bank_id             VARCHAR(20),           -- Banco vinculado (FK con banks).
    description         TEXT NOT NULL DEFAULT 'NO APLICA',                       -- Descripción del usuario.
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,  -- Estado activo/inactivo.
    email_verified      BOOLEAN NOT NULL DEFAULT FALSE, -- Verificación de correo.
    last_login          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,             -- Última conexión.
    created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Claves foráneas
    CONSTRAINT fk_country FOREIGN KEY (country_id) REFERENCES countries(country_code),
    CONSTRAINT fk_native_lang FOREIGN KEY (native_lang_id) REFERENCES languages(language_code),
    CONSTRAINT fk_target_lang FOREIGN KEY (target_lang_id) REFERENCES languages(language_code),
    CONSTRAINT fk_bank FOREIGN KEY (bank_id) REFERENCES banks(bank_code)
);

-- ================================================================
-- TABLA: user_role_assignments
-- Relación N:M entre usuarios y roles.
-- ================================================================
CREATE TABLE user_role_assignments (
    user_id              INTEGER,               -- Usuario asignado.
    role_code            VARCHAR(20),           -- Rol asignado.
    assigned_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Fecha de asignación.
    assigned_by          INTEGER,               -- Usuario que asigna.

    PRIMARY KEY (user_id, role_code),
    CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES users(id_user) ON DELETE CASCADE,
    CONSTRAINT fk_role FOREIGN KEY (role_code) REFERENCES user_roles(role_code),
    CONSTRAINT fk_assigned_by FOREIGN KEY (assigned_by) REFERENCES users(id_user) ON DELETE SET NULL
);

-- ================================================================
-- TABLA: teacher_profiles
-- Perfil docente asociado a un usuario con rol "teacher".
-- ================================================================
CREATE TABLE teacher_profiles (
    user_id              INTEGER PRIMARY KEY,   -- Usuario que es profesor.
    teaching_language_id VARCHAR(2) NOT NULL,   -- Idioma que enseña (FK).
    lang_certification   VARCHAR(255),          -- Certificación de idioma.
    academic_title       VARCHAR(255),          -- Título académico.
    experience_certification VARCHAR(255),      -- Certificación de experiencia.
    hourly_rate          DECIMAL(8,2),          -- Tarifa por hora.
    specialization       TEXT,                  -- Área de especialización.
    years_experience     INTEGER,               -- Años de experiencia.
    availability_notes   TEXT,                  -- Notas sobre disponibilidad.
    is_verified          BOOLEAN DEFAULT FALSE, -- Estado de verificación.
    verified_at          TIMESTAMP,             -- Fecha verificación.
    verified_by          INTEGER,               -- Usuario verificador.
    created_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Relaciones
    CONSTRAINT fk_user_teacher FOREIGN KEY (user_id) REFERENCES users(id_user),
    CONSTRAINT fk_teaching_lang FOREIGN KEY (teaching_language_id) REFERENCES languages(language_code),
    CONSTRAINT fk_verified_by FOREIGN KEY (verified_by) REFERENCES users(id_user)
);

-- ================================================================
-- TABLA: sessions
-- Sesiones entre usuarios (intercambio o enseñanza).
-- ================================================================
CREATE TABLE sessions (
    session_id           VARCHAR(50) PRIMARY KEY, -- ID de sesión (UUID personalizado).
    id_user1             INTEGER NOT NULL,        -- Usuario 1.
    id_user2             INTEGER NOT NULL,        -- Usuario 2.
    session_type         VARCHAR(20) NOT NULL,    -- Tipo (exchange, teaching).
    start_time           TIMESTAMP,   
    end_time             TIMESTAMP,
    session_status       VARCHAR(20) DEFAULT 'scheduled', -- Estado inicial.
    session_notes        TEXT,                    -- Notas de la sesión.
    language_used        VARCHAR(2),              -- Idioma usado en sesión.
    created_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by           INTEGER,                 -- Usuario creador.

    -- Relaciones
    CONSTRAINT fk_language_used FOREIGN KEY (language_used) REFERENCES languages(language_code),
    CONSTRAINT fk_user1 FOREIGN KEY (id_user1) REFERENCES users(id_user),
    CONSTRAINT fk_user2 FOREIGN KEY (id_user2) REFERENCES users(id_user)
);

-- ================================================================
-- TABLA: exchange_sessions
-- Evaluaciones de sesiones de intercambio entre usuarios.
-- ================================================================
CREATE TABLE exchange_sessions (
    session_id           VARCHAR(50) PRIMARY KEY, -- ID sesión (FK).
    session_rating_user1 INTEGER,                 -- Calificación del usuario 1.
    session_rating_user2 INTEGER,                 -- Calificación del usuario 2.
    feedback_user1       TEXT,                    -- Comentarios usuario 1.
    feedback_user2       TEXT,                    -- Comentarios usuario 2.

    CONSTRAINT fk_session FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- ================================================================
-- TABLA: user_likes
-- Likes entre usuarios (sistema de compatibilidad).
-- ================================================================
CREATE TABLE user_likes (
    id_user_giver       INTEGER, -- Usuario que da like.
    id_user_receiver    INTEGER, -- Usuario que recibe like.
    like_time           TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Fecha.

    PRIMARY KEY (id_user_giver, id_user_receiver),
    CONSTRAINT fk_user_giver FOREIGN KEY (id_user_giver) REFERENCES users(id_user),
    CONSTRAINT fk_user_receiver FOREIGN KEY (id_user_receiver) REFERENCES users(id_user)
);

-- ================================================================
-- TABLA: user_matches
-- Matches entre usuarios cuando hay likes recíprocos.
-- ================================================================
CREATE TABLE user_matches (
    user_1              INTEGER, -- Usuario 1.
    user_2              INTEGER, -- Usuario 2.
    match_time          TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Fecha match.

    PRIMARY KEY (user_1, user_2),
    CONSTRAINT fk_user_1 FOREIGN KEY (user_1) REFERENCES users(id_user),
    CONSTRAINT fk_user_2 FOREIGN KEY (user_2) REFERENCES users(id_user),
    CONSTRAINT chk_different_users CHECK (user_1 < user_2) -- Evita duplicados (1,2) y (2,1).
);

-- ================================================================
-- TABLA: teaching_sessions
-- Sesiones de enseñanza formal con un profesor verificado.
-- ================================================================
CREATE TABLE teaching_sessions (
    session_id          VARCHAR(50) PRIMARY KEY, -- Sesión (FK con sessions).
    teacher_profile_id  INTEGER NOT NULL,        -- Profesor (FK con teacher_profiles).
    student_id          INTEGER NOT NULL,        -- Alumno (FK con users).
    session_cost        DECIMAL(8,2),            -- Costo de la sesión.
    teacher_notes       TEXT,                    -- Notas del profesor.
    student_rating      INTEGER,                 -- Calificación del alumno.
    teacher_rating      INTEGER,                 -- Calificación del profesor.
    homework_assigned   TEXT,                    -- Tarea asignada.
    homework_completed  BOOLEAN DEFAULT FALSE,   -- Estado tarea.

    CONSTRAINT fk_teacher_profile FOREIGN KEY (teacher_profile_id) REFERENCES teacher_profiles(user_id),
    CONSTRAINT fk_student FOREIGN KEY (student_id) REFERENCES users(id_user),
    CONSTRAINT fk_session_teacher FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- ================================================================
-- TABLA: chat_logs
-- Historial de chat de sesiones.
-- ================================================================
CREATE TABLE chat_logs (
    message_id          VARCHAR(50) PRIMARY KEY, -- ID mensaje.
    session_id          VARCHAR(50) NOT NULL,    -- Sesión (FK).
    sender_id           INTEGER NOT NULL,        -- Usuario emisor.
    message             TEXT NOT NULL,           -- Texto del mensaje.
    timestamp           TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Fecha envío.
    is_corrected        BOOLEAN DEFAULT FALSE,   -- Indica si fue corregido.
    reply_to            VARCHAR(50),             -- Mensaje al que responde (FK).
    is_read             BOOLEAN DEFAULT FALSE,   -- Estado leído.

    CONSTRAINT fk_session_chat FOREIGN KEY (session_id) REFERENCES sessions(session_id),
    CONSTRAINT fk_sender FOREIGN KEY (sender_id) REFERENCES users(id_user),
    CONSTRAINT fk_reply_to FOREIGN KEY (reply_to) REFERENCES chat_logs(message_id)
);

-- ================================================================
-- TABLA: titles
-- Títulos que los usuarios pueden obtener (gamificación).
-- ================================================================
CREATE TABLE titles (
    title_code          VARCHAR(50) PRIMARY KEY, -- Código único título.
    title_name          VARCHAR(100) NOT NULL,   -- Nombre del título.
    title_description   VARCHAR(255) NOT NULL    -- Descripción del título.
);

-- ================================================================
-- TABLA: user_titles
-- Relación N:M entre usuarios y títulos obtenidos.
-- ================================================================
CREATE TABLE user_titles (
    id_user             INTEGER,                 -- Usuario.
    title_code          VARCHAR(50),             -- Código de título.
    earned_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Fecha obtención.

    PRIMARY KEY (id_user, title_code),
    CONSTRAINT fk_id_user_title FOREIGN KEY (id_user) REFERENCES users(id_user),
    CONSTRAINT fk_title_code FOREIGN KEY (title_code) REFERENCES titles(title_code)
);

-- ================================================================
-- TABLA: user_progress
-- Seguimiento de progreso del usuario en idiomas.
-- ================================================================
CREATE TABLE user_progress (
    user_id              INTEGER,                -- Usuario.
    language_id          VARCHAR(2),             -- Idioma en progreso.
    last_updated         TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Última actualización.
    total_sessions       INTEGER DEFAULT 0,      -- Total de sesiones realizadas.
    total_hours          DECIMAL(6,2) DEFAULT 0, -- Total de horas.
    notes                TEXT,                   -- Notas de progreso.
    
    PRIMARY KEY (user_id, language_id),
    CONSTRAINT fk_user_progress FOREIGN KEY (user_id) REFERENCES users(id_user),
    CONSTRAINT fk_language_progress FOREIGN KEY (language_id) REFERENCES languages(language_code)
);

-- ================================================================
-- TABLA: notifications
-- Notificaciones enviadas a usuarios.
-- ================================================================
CREATE TABLE notifications (
    notification_id       VARCHAR(50) PRIMARY KEY, -- ID notificación (UUID personalizado).
    user_id               INTEGER NOT NULL,        -- Usuario receptor.
    title                 VARCHAR(200) NOT NULL,   -- Título notificación.
    message               TEXT NOT NULL,           -- Contenido.
    notification_type     VARCHAR(50) NOT NULL,    -- Tipo (match, sesión, etc.).
    related_entity_type   VARCHAR(50),             -- Entidad relacionada.
    related_entity_id     VARCHAR(50),             -- ID entidad relacionada.
    is_read               BOOLEAN DEFAULT FALSE,   -- Estado de lectura.
    read_at               TIMESTAMP,               -- Fecha de lectura.
    created_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at            TIMESTAMP,               -- Expiración.

    CONSTRAINT fk_notification_user FOREIGN KEY (user_id) REFERENCES users(id_user)
);

-- ================================================================
-- TABLA: user_preferences
-- Preferencias personales del usuario en la app.
-- ================================================================
CREATE TABLE user_preferences (
    user_id                 INTEGER PRIMARY KEY,  -- Usuario.
    theme                   VARCHAR(20) DEFAULT 'light', -- Tema visual.
    notifications_email     BOOLEAN DEFAULT true, -- Preferencia correo.
    notifications_push      BOOLEAN DEFAULT false,-- Preferencia push.
    notifications_matches   BOOLEAN DEFAULT true, -- Avisos matches.
    notifications_sessions  BOOLEAN DEFAULT true, -- Avisos sesiones.
    language_interface      VARCHAR(2) DEFAULT 'ES', -- Idioma interfaz.
    session_duration_pref   INTEGER DEFAULT 60,   -- Duración preferida sesión.
    profile_visibility      VARCHAR(20) DEFAULT 'public', -- Visibilidad.
    auto_accept_matches     BOOLEAN DEFAULT false, -- Auto aceptar matches.
    show_online_status      BOOLEAN DEFAULT true, -- Mostrar estado online.
    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_preference_user FOREIGN KEY (user_id) REFERENCES users(id_user)
);

-- ================================================================
-- TABLA: audit_logs
-- Registro de auditoría de cambios en tablas sensibles.
-- ================================================================
CREATE TABLE audit_logs (
    audit_id                VARCHAR(50) PRIMARY KEY, -- ID auditoría.
    table_name              VARCHAR(100) NOT NULL,   -- Tabla afectada.
    record_id               VARCHAR(50) NOT NULL,    -- ID del registro afectado.
    action                  VARCHAR(20) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_values              JSON,                    -- Valores previos.
    new_values              JSON,                    -- Valores nuevos.
    changed_by              INTEGER,                 -- Usuario que hizo cambio.
    changed_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Fecha cambio.
    ip_address              VARCHAR(45),             -- IP de origen.
    user_agent              TEXT,                    -- Navegador/cliente.

    CONSTRAINT fk_audit_user FOREIGN KEY (changed_by) REFERENCES users(id_user)
);


-- INDICES DE PERFORMANCE PARA CONVERLANG AUMENTANDO LA VELOCIDAD DE RESPUESTAS PARA PETICIONES ESPECIFICAS DE ALTA DEMANDA. 

-- 1. AUTENTICACIÓN Y USUARIOS

-- Índice crítico para login diario de usuarios
CREATE UNIQUE INDEX idx_users_email ON users(email);

-- Índice para búsquedas de perfil y usuarios activos por país
CREATE INDEX idx_users_active_country ON users(is_active, country_id) WHERE is_active = true;

-- 2. SISTEMA DE MATCHING

-- índice compuesto para encontrar usuarios compatibles en el algoritmo de matching
-- Optimiza consultas que filtran por país, idioma nativo, idioma objetivo y estado activo
CREATE INDEX idx_users_matching ON users(country_id, native_lang_id, target_lang_id, is_active);

-- índice para verificar likes existentes y evitar duplicados en el sistema de "me gusta"
CREATE INDEX idx_user_likes_giver_receiver ON user_likes(id_user_giver, id_user_receiver);

-- índice para mostrar matches del usuario de forma eficiente
CREATE INDEX idx_user_matches_users ON user_matches(user_1, user_2);

-- 3. SESIONES Y CHAT

-- índice para mostrar sesiones del usuario por estado
CREATE INDEX idx_sessions_users_status ON sessions(id_user1, id_user2, session_status);

-- índice crítico para cargar mensajes de chat ordenados cronológicamente
-- Optimiza la carga de historial de chat y mensajes en tiempo real
CREATE INDEX idx_chat_logs_session_time ON chat_logs(session_id, timestamp);

-- índice parcial para mensajes no leídos (optimiza notificaciones de chat)
CREATE INDEX idx_chat_logs_unread ON chat_logs(session_id, is_read) WHERE is_read = false;

-- 4. NOTIFICACIONES

-- índice para notificaciones del usuario por estado de lectura y fecha
CREATE INDEX idx_notifications ON notifications(user_id, is_read, created_at);

-- 5. TEACHERS Y BÚSQUEDAS

-- índice para buscar profesores por idioma que enseñan y estado de verificación
CREATE INDEX idx_teacher_profiles_lang_verified ON teacher_profiles(teaching_language_id, is_verified) WHERE is_verified = true;

-- índice para búsquedas y filtros por rango de precio de profesores verificados
CREATE INDEX idx_teacher_profiles_rate ON teacher_profiles(hourly_rate, is_verified) WHERE is_verified = true;

-- índice para mostrar profesores por experiencia y especialización
CREATE INDEX idx_teacher_profiles_experience ON teacher_profiles(years_experience, is_verified) WHERE is_verified = true;

