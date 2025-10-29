-- ============================
-- FUNCIÓN AUXILIAR: GENERAR ID DE NOTIFICACIÓN
-- ============================
CREATE OR REPLACE FUNCTION generate_notification_id()
RETURNS VARCHAR AS
$$
DECLARE
    v_date_part VARCHAR;
    v_count INTEGER;
    v_notification_id VARCHAR;
BEGIN
    -- Formato: NOT_YYYYMMDD_###
    v_date_part := 'NOT_' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD');
    
    -- Contar notificaciones del día
    SELECT COUNT(*) INTO v_count
    FROM notifications
    WHERE notification_id LIKE v_date_part || '%';
    
    v_count := v_count + 1;
    v_notification_id := v_date_part || '_' || LPAD(v_count::TEXT, 3, '0');
    
    RETURN v_notification_id;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: CREAR NOTIFICACIÓN
-- ============================
CREATE OR REPLACE FUNCTION create_notification(
    p_user_id INTEGER,
    p_title VARCHAR,
    p_message TEXT,
    p_notification_type VARCHAR,
    p_related_entity_type VARCHAR DEFAULT NULL,
    p_related_entity_id VARCHAR DEFAULT NULL,
    p_expires_at TIMESTAMP DEFAULT NULL
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_user_active BOOLEAN;
    v_notification_id VARCHAR;
    v_notification_type_lower VARCHAR;
    v_related_entity_type_lower VARCHAR;
BEGIN
    -- ============================
    -- VALIDACIONES BÁSICAS
    -- ============================
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'El ID del usuario no puede estar vacío.';
    END IF;
    
    IF p_title IS NULL OR LENGTH(TRIM(p_title)) = 0 THEN
        RAISE EXCEPTION 'El título de la notificación no puede estar vacío.';
    ELSIF LENGTH(p_title) > 200 THEN
        RAISE EXCEPTION 'El título no puede exceder 200 caracteres.';
    END IF;
    
    IF p_message IS NULL OR LENGTH(TRIM(p_message)) = 0 THEN
        RAISE EXCEPTION 'El mensaje de la notificación no puede estar vacío.';
    END IF;
    
    IF p_notification_type IS NULL OR LENGTH(TRIM(p_notification_type)) = 0 THEN
        RAISE EXCEPTION 'El tipo de notificación no puede estar vacío.';
    ELSIF LENGTH(p_notification_type) > 50 THEN
        RAISE EXCEPTION 'El tipo de notificación no puede exceder 50 caracteres.';
    END IF;
    
    -- Normalizar tipos a minúsculas
    v_notification_type_lower := LOWER(TRIM(p_notification_type));
    v_related_entity_type_lower := LOWER(TRIM(p_related_entity_type));
    
    -- ============================
    -- VERIFICAR EXISTENCIA Y ESTADO DEL USUARIO
    -- ============================
    SELECT is_active INTO v_user_active
    FROM users
    WHERE id_user = p_user_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe un usuario con el ID %.', p_user_id;
    END IF;
    
    IF NOT v_user_active THEN
        RAISE EXCEPTION 'El usuario con ID % no está activo.', p_user_id;
    END IF;
    
    -- ============================
    -- VALIDAR FECHA DE EXPIRACIÓN
    -- ============================
    IF p_expires_at IS NOT NULL AND p_expires_at <= CURRENT_TIMESTAMP THEN
        RAISE EXCEPTION 'La fecha de expiración debe ser en el futuro.';
    END IF;
    
    -- ============================
    -- GENERAR ID Y CREAR NOTIFICACIÓN
    -- ============================
    v_notification_id := generate_notification_id();
    
    INSERT INTO notifications (
        notification_id, user_id, title, message, notification_type,
        related_entity_type, related_entity_id, expires_at
    ) VALUES (
        v_notification_id, p_user_id, p_title, p_message, v_notification_type_lower,
        v_related_entity_type_lower, p_related_entity_id, p_expires_at
    );
    
    RETURN format('Notificación %s creada correctamente para el usuario %s.', v_notification_id, p_user_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: MARCAR NOTIFICACIÓN COMO LEÍDA
-- ============================
CREATE OR REPLACE FUNCTION mark_notification_as_read(
    p_notification_id VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_already_read BOOLEAN;
BEGIN
    -- Verificar existencia y estado
    SELECT is_read INTO v_already_read
    FROM notifications
    WHERE notification_id = p_notification_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe una notificación con el ID %.', p_notification_id;
    END IF;
    
    IF v_already_read THEN
        RETURN format('La notificación %s ya estaba marcada como leída.', p_notification_id);
    END IF;
    
    UPDATE notifications
    SET
        is_read = TRUE,
        read_at = CURRENT_TIMESTAMP
    WHERE notification_id = p_notification_id;
    
    RETURN format('Notificación %s marcada como leída.', p_notification_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: MARCAR TODAS LAS NOTIFICACIONES COMO LEÍDAS
-- ============================
CREATE OR REPLACE FUNCTION mark_all_notifications_as_read(
    p_user_id INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE notifications
    SET
        is_read = TRUE,
        read_at = CURRENT_TIMESTAMP
    WHERE user_id = p_user_id
    AND is_read = FALSE;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    
    RETURN format('%s notificaciones marcadas como leídas para el usuario %s.', v_count, p_user_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: MARCAR NOTIFICACIÓN COMO NO LEÍDA
-- ============================
CREATE OR REPLACE FUNCTION mark_notification_as_unread(
    p_notification_id VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM notifications WHERE notification_id = p_notification_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe una notificación con el ID %.', p_notification_id;
    END IF;
    
    UPDATE notifications
    SET
        is_read = FALSE,
        read_at = NULL
    WHERE notification_id = p_notification_id;
    
    RETURN format('Notificación %s marcada como no leída.', p_notification_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR NOTIFICACIÓN
-- ============================
CREATE OR REPLACE FUNCTION delete_notification(
    p_notification_id VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM notifications WHERE notification_id = p_notification_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe una notificación con el ID %.', p_notification_id;
    END IF;
    
    DELETE FROM notifications WHERE notification_id = p_notification_id;
    
    RETURN format('Notificación %s eliminada correctamente.', p_notification_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR NOTIFICACIONES LEÍDAS DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION delete_read_notifications(
    p_user_id INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_count INTEGER;
BEGIN
    DELETE FROM notifications
    WHERE user_id = p_user_id
    AND is_read = TRUE;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    
    RETURN format('%s notificaciones leídas eliminadas para el usuario %s.', v_count, p_user_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR NOTIFICACIONES EXPIRADAS
-- ============================
CREATE OR REPLACE FUNCTION delete_expired_notifications()
RETURNS TEXT AS
$$
DECLARE
    v_count INTEGER;
BEGIN
    DELETE FROM notifications
    WHERE expires_at IS NOT NULL
    AND expires_at < CURRENT_TIMESTAMP;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    
    RETURN format('%s notificaciones expiradas eliminadas.', v_count);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER NOTIFICACIONES DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_user_notifications(
    p_user_id INTEGER,
    p_include_read BOOLEAN DEFAULT TRUE,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    notification_id VARCHAR,
    title VARCHAR,
    message TEXT,
    notification_type VARCHAR,
    related_entity_type VARCHAR,
    related_entity_id VARCHAR,
    is_read BOOLEAN,
    read_at TIMESTAMP,
    created_at TIMESTAMP,
    expires_at TIMESTAMP
)
AS
$$
BEGIN
    IF p_include_read THEN
        RETURN QUERY
        SELECT
            n.notification_id,
            n.title,
            n.message,
            n.notification_type,
            n.related_entity_type,
            n.related_entity_id,
            n.is_read,
            n.read_at,
            n.created_at,
            n.expires_at
        FROM notifications n
        WHERE n.user_id = p_user_id
        AND (n.expires_at IS NULL OR n.expires_at > CURRENT_TIMESTAMP)
        ORDER BY n.created_at DESC
        LIMIT p_limit
        OFFSET p_offset;
    ELSE
        RETURN QUERY
        SELECT
            n.notification_id,
            n.title,
            n.message,
            n.notification_type,
            n.related_entity_type,
            n.related_entity_id,
            n.is_read,
            n.read_at,
            n.created_at,
            n.expires_at
        FROM notifications n
        WHERE n.user_id = p_user_id
        AND n.is_read = FALSE
        AND (n.expires_at IS NULL OR n.expires_at > CURRENT_TIMESTAMP)
        ORDER BY n.created_at DESC
        LIMIT p_limit
        OFFSET p_offset;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER NOTIFICACIÓN POR ID
-- ============================
CREATE OR REPLACE FUNCTION get_notification_by_id(
    p_notification_id VARCHAR
)
RETURNS TABLE (
    notification_id VARCHAR,
    user_id INTEGER,
    title VARCHAR,
    message TEXT,
    notification_type VARCHAR,
    related_entity_type VARCHAR,
    related_entity_id VARCHAR,
    is_read BOOLEAN,
    read_at TIMESTAMP,
    created_at TIMESTAMP,
    expires_at TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        n.notification_id,
        n.user_id,
        n.title,
        n.message,
        n.notification_type,
        n.related_entity_type,
        n.related_entity_id,
        n.is_read,
        n.read_at,
        n.created_at,
        n.expires_at
    FROM notifications n
    WHERE n.notification_id = p_notification_id;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: CONTAR NOTIFICACIONES NO LEÍDAS
-- ============================
CREATE OR REPLACE FUNCTION count_unread_notifications(
    p_user_id INTEGER
)
RETURNS INTEGER AS
$$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM notifications
    WHERE user_id = p_user_id
    AND is_read = FALSE
    AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP);
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER NOTIFICACIONES POR TIPO
-- ============================
CREATE OR REPLACE FUNCTION get_notifications_by_type(
    p_user_id INTEGER,
    p_notification_type VARCHAR,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    notification_id VARCHAR,
    title VARCHAR,
    message TEXT,
    notification_type VARCHAR,
    related_entity_type VARCHAR,
    related_entity_id VARCHAR,
    is_read BOOLEAN,
    created_at TIMESTAMP
)
AS
$$
DECLARE
    v_type_lower VARCHAR;
BEGIN
    v_type_lower := LOWER(p_notification_type);
    
    RETURN QUERY
    SELECT
        n.notification_id,
        n.title,
        n.message,
        n.notification_type,
        n.related_entity_type,
        n.related_entity_id,
        n.is_read,
        n.created_at
    FROM notifications n
    WHERE n.user_id = p_user_id
    AND n.notification_type = v_type_lower
    AND (n.expires_at IS NULL OR n.expires_at > CURRENT_TIMESTAMP)
    ORDER BY n.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER ESTADÍSTICAS DE NOTIFICACIONES
-- ============================
CREATE OR REPLACE FUNCTION get_notification_statistics(
    p_user_id INTEGER
)
RETURNS TABLE (
    user_id INTEGER,
    total_notifications INTEGER,
    unread_notifications INTEGER,
    read_notifications INTEGER,
    notifications_last_week INTEGER,
    notifications_by_type JSONB,
    oldest_unread_date TIMESTAMP,
    latest_notification_date TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        p_user_id as user_id,
        COUNT(*)::INTEGER as total_notifications,
        COUNT(CASE WHEN n.is_read = FALSE THEN 1 END)::INTEGER as unread_notifications,
        COUNT(CASE WHEN n.is_read = TRUE THEN 1 END)::INTEGER as read_notifications,
        COUNT(CASE WHEN n.created_at >= CURRENT_TIMESTAMP - INTERVAL '7 days' THEN 1 END)::INTEGER as notifications_last_week,
        (SELECT jsonb_object_agg(notification_type, count)
         FROM (
             SELECT notification_type, COUNT(*)::INTEGER as count
             FROM notifications
             WHERE user_id = p_user_id
             GROUP BY notification_type
         ) sub) as notifications_by_type,
        (SELECT MIN(created_at) FROM notifications WHERE user_id = p_user_id AND is_read = FALSE) as oldest_unread_date,
        MAX(n.created_at) as latest_notification_date
    FROM notifications n
    WHERE n.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER NOTIFICACIONES RECIENTES (ÚLTIMOS N DÍAS)
-- ============================
CREATE OR REPLACE FUNCTION get_recent_notifications(
    p_user_id INTEGER,
    p_days INTEGER DEFAULT 7
)
RETURNS TABLE (
    notification_id VARCHAR,
    title VARCHAR,
    message TEXT,
    notification_type VARCHAR,
    is_read BOOLEAN,
    created_at TIMESTAMP,
    hours_ago INTEGER
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        n.notification_id,
        n.title,
        n.message,
        n.notification_type,
        n.is_read,
        n.created_at,
        EXTRACT(HOUR FROM (CURRENT_TIMESTAMP - n.created_at))::INTEGER as hours_ago
    FROM notifications n
    WHERE n.user_id = p_user_id
    AND n.created_at >= CURRENT_TIMESTAMP - (p_days || ' days')::INTERVAL
    AND (n.expires_at IS NULL OR n.expires_at > CURRENT_TIMESTAMP)
    ORDER BY n.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: CREAR NOTIFICACIÓN DE MATCH
-- ============================
CREATE OR REPLACE FUNCTION notify_new_match(
    p_user_id INTEGER,
    p_matched_user_id INTEGER,
    p_match_id INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_matched_user_name VARCHAR;
BEGIN
    -- Obtener nombre del usuario con quien hizo match
    SELECT first_name || ' ' || last_name INTO v_matched_user_name
    FROM users
    WHERE id_user = p_matched_user_id;
    
    RETURN create_notification(
        p_user_id,
        '¡Nuevo Match!',
        format('¡Tienes un nuevo match con %s! Comienza a chatear ahora.', v_matched_user_name),
        'match',
        'user_match',
        p_match_id::VARCHAR,
        CURRENT_TIMESTAMP + INTERVAL '30 days'
    );
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: CREAR NOTIFICACIÓN DE SESIÓN
-- ============================
CREATE OR REPLACE FUNCTION notify_session_reminder(
    p_user_id INTEGER,
    p_session_id VARCHAR,
    p_session_start TIMESTAMP
)
RETURNS TEXT AS
$$
DECLARE
    v_hours_until INTEGER;
BEGIN
    v_hours_until := EXTRACT(HOUR FROM (p_session_start - CURRENT_TIMESTAMP))::INTEGER;
    
    RETURN create_notification(
        p_user_id,
        'Recordatorio de Sesión',
        format('Tienes una sesión programada en %s horas.', v_hours_until),
        'session_reminder',
        'session',
        p_session_id,
        p_session_start + INTERVAL '1 hour'
    );
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: CREAR NOTIFICACIÓN DE CALIFICACIÓN PENDIENTE
-- ============================
CREATE OR REPLACE FUNCTION notify_pending_rating(
    p_user_id INTEGER,
    p_session_id VARCHAR
)
RETURNS TEXT AS
$$
BEGIN
    RETURN create_notification(
        p_user_id,
        'Calificación Pendiente',
        'No olvides calificar tu última sesión. ¡Tu feedback es importante!',
        'rating_pending',
        'session',
        p_session_id,
        CURRENT_TIMESTAMP + INTERVAL '7 days'
    );
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: CREAR NOTIFICACIÓN DE NUEVO MENSAJE
-- ============================
CREATE OR REPLACE FUNCTION notify_new_message(
    p_user_id INTEGER,
    p_sender_id INTEGER,
    p_match_id INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_sender_name VARCHAR;
BEGIN
    SELECT first_name || ' ' || last_name INTO v_sender_name
    FROM users
    WHERE id_user = p_sender_id;
    
    RETURN create_notification(
        p_user_id,
        'Nuevo Mensaje',
        format('%s te ha enviado un mensaje.', v_sender_name),
        'new_message',
        'match',
        p_match_id::VARCHAR,
        CURRENT_TIMESTAMP + INTERVAL '7 days'
    );
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: CREAR NOTIFICACIÓN DE TÍTULO OBTENIDO
-- ============================
CREATE OR REPLACE FUNCTION notify_title_earned(
    p_user_id INTEGER,
    p_title_name VARCHAR
)
RETURNS TEXT AS
$$
BEGIN
    RETURN create_notification(
        p_user_id,
        '¡Nuevo Logro Desbloqueado!',
        format('¡Felicidades! Has obtenido el título: %s', p_title_name),
        'achievement',
        'title',
        p_title_name,
        CURRENT_TIMESTAMP + INTERVAL '90 days'
    );
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR TODAS LAS NOTIFICACIONES DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION delete_all_user_notifications(
    p_user_id INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM notifications
    WHERE user_id = p_user_id;
    
    DELETE FROM notifications WHERE user_id = p_user_id;
    
    RETURN format('Eliminadas %s notificaciones del usuario %s.', v_count, p_user_id);
END;
$$ LANGUAGE plpgsql;