-- ================================================================
-- FUNCIONES Y TRIGGERS PARA NOTIFICACIONES
-- Converlang - Sistema de Notificaciones Automáticas
-- ================================================================

-- ============================
-- FUNCIÓN: TRIGGER PARA CREAR NOTIFICACIÓN DE LIKE
-- Se ejecuta automáticamente después de cada INSERT en user_likes
-- ============================
CREATE OR REPLACE FUNCTION trigger_notify_like()
RETURNS TRIGGER AS $$
DECLARE
    v_sender_name VARCHAR;
    v_mutual_like BOOLEAN;
BEGIN
    -- Obtener nombre del usuario que envía el like
    SELECT first_name || ' ' || last_name INTO v_sender_name
    FROM users 
    WHERE id_user = NEW.id_user_giver;

    -- Verificar si existe un like mutuo (Match)
    SELECT EXISTS (
        SELECT 1 
        FROM user_likes 
        WHERE id_user_giver = NEW.id_user_receiver 
        AND id_user_receiver = NEW.id_user_giver
    ) INTO v_mutual_like;
    
    -- Insertar notificación para el usuario que recibe el like
    IF v_mutual_like THEN
        -- Si es Match, notificamos el Match
        INSERT INTO notifications (
            user_id,
            title,
            message,
            notification_type
        ) VALUES (
            NEW.id_user_receiver,
            '¡Nuevo Match!',
            v_sender_name,
            'match'
        );
    ELSE
        -- Si solo es Like, notificamos el Like
        INSERT INTO notifications (
            user_id,
            title,
            message,
            notification_type
        ) VALUES (
            NEW.id_user_receiver,
            'Nueva solicitud de Match',
            v_sender_name,
            'like_request'
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- TRIGGER: AFTER INSERT EN USER_LIKES
-- ============================
DROP TRIGGER IF EXISTS trg_notify_on_like ON user_likes;

CREATE TRIGGER trg_notify_on_like
    AFTER INSERT ON user_likes
    FOR EACH ROW
    EXECUTE FUNCTION trigger_notify_like();

-- ============================
-- FUNCIÓN: OBTENER NOTIFICACIONES DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_user_notifications(
    p_user_id INTEGER,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    notification_id INTEGER,
    user_id INTEGER,
    title VARCHAR,
    message TEXT,
    notification_type VARCHAR,
    read_at TIMESTAMP,
    created_at TIMESTAMP,
    is_read BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        n.notification_id,
        n.user_id,
        n.title,
        n.message,
        n.notification_type,
        n.read_at,
        n.created_at,
        (n.read_at IS NOT NULL) AS is_read
    FROM notifications n
    WHERE n.user_id = p_user_id
    ORDER BY n.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: CONTAR NOTIFICACIONES NO LEÍDAS
-- ============================
CREATE OR REPLACE FUNCTION count_unread_notifications(
    p_user_id INTEGER
) RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(notification_id) INTO v_count
    FROM notifications
    WHERE user_id = p_user_id
    AND read_at IS NULL;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: MARCAR NOTIFICACIÓN COMO LEÍDA
-- ============================
CREATE OR REPLACE FUNCTION mark_notification_as_read(
    p_notification_id INTEGER
) RETURNS BOOLEAN AS $$
BEGIN
    UPDATE notifications
    SET read_at = CURRENT_TIMESTAMP
    WHERE notification_id = p_notification_id
    AND read_at IS NULL;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: MARCAR TODAS LAS NOTIFICACIONES COMO LEÍDAS
-- ============================
CREATE OR REPLACE FUNCTION mark_all_notifications_as_read(
    p_user_id INTEGER
) RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE notifications
    SET read_at = CURRENT_TIMESTAMP
    WHERE user_id = p_user_id
    AND read_at IS NULL;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR NOTIFICACIÓN
-- ============================
CREATE OR REPLACE FUNCTION delete_notification(
    p_notification_id INTEGER,
    p_user_id INTEGER
) RETURNS BOOLEAN AS $$
BEGIN
    DELETE FROM notifications
    WHERE notification_id = p_notification_id
    AND user_id = p_user_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;
