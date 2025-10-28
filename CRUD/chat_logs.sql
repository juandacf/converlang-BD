-- ============================
-- FUNCIÓN AUXILIAR: GENERAR ID DE MENSAJE
-- ============================
CREATE OR REPLACE FUNCTION generate_message_id()
RETURNS VARCHAR AS
$$
DECLARE
    v_timestamp VARCHAR;
    v_random VARCHAR;
    v_message_id VARCHAR;
BEGIN
    -- Formato: MSG_YYYYMMDDHHMMSS_RAND
    v_timestamp := TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISS');
    v_random := LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
    v_message_id := 'MSG_' || v_timestamp || '_' || v_random;
    
    RETURN v_message_id;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ENVIAR MENSAJE
-- ============================
CREATE OR REPLACE FUNCTION send_message(
    p_match_id INTEGER,
    p_sender_id INTEGER,
    p_message TEXT,
    p_reply_to VARCHAR DEFAULT NULL
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_message_id VARCHAR;
    v_match_user1 INTEGER;
    v_match_user2 INTEGER;
    v_sender_active BOOLEAN;
BEGIN
    -- ============================
    -- VALIDACIONES BÁSICAS
    -- ============================
    IF p_match_id IS NULL THEN
        RAISE EXCEPTION 'El ID del match no puede estar vacío.';
    END IF;
    
    IF p_sender_id IS NULL THEN
        RAISE EXCEPTION 'El ID del remitente no puede estar vacío.';
    END IF;
    
    IF p_message IS NULL OR LENGTH(TRIM(p_message)) = 0 THEN
        RAISE EXCEPTION 'El mensaje no puede estar vacío.';
    END IF;
    
    IF LENGTH(p_message) > 5000 THEN
        RAISE EXCEPTION 'El mensaje excede el límite de 5000 caracteres.';
    END IF;
    
    -- ============================
    -- VERIFICAR EXISTENCIA DEL MATCH
    -- ============================
    SELECT user_1, user_2 INTO v_match_user1, v_match_user2
    FROM user_matches
    WHERE match_id = p_match_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe un match con el ID %.', p_match_id;
    END IF;
    
    -- ============================
    -- VERIFICAR QUE EL SENDER SEA PARTE DEL MATCH
    -- ============================
    IF p_sender_id <> v_match_user1 AND p_sender_id <> v_match_user2 THEN
        RAISE EXCEPTION 'El usuario % no es parte del match %.', p_sender_id, p_match_id;
    END IF;
    
    -- Verificar que el sender esté activo
    SELECT is_active INTO v_sender_active
    FROM users
    WHERE id_user = p_sender_id;
    
    IF NOT v_sender_active THEN
        RAISE EXCEPTION 'El usuario % no está activo.', p_sender_id;
    END IF;
    
    -- ============================
    -- VALIDAR REPLY_TO (SI EXISTE)
    -- ============================
    IF p_reply_to IS NOT NULL AND LENGTH(TRIM(p_reply_to)) > 0 THEN
        -- Verificar que el mensaje al que responde existe
        SELECT EXISTS(SELECT 1 FROM chat_logs WHERE message_id = p_reply_to) INTO v_exists;
        IF NOT v_exists THEN
            RAISE EXCEPTION 'El mensaje al que intenta responder (%) no existe.', p_reply_to;
        END IF;
        
        -- Verificar que el mensaje al que responde pertenece al mismo match
        SELECT EXISTS(
            SELECT 1 FROM chat_logs 
            WHERE message_id = p_reply_to 
            AND match_id = p_match_id
        ) INTO v_exists;
        
        IF NOT v_exists THEN
            RAISE EXCEPTION 'El mensaje al que intenta responder no pertenece a este match.';
        END IF;
    END IF;
    
    -- ============================
    -- GENERAR ID Y CREAR MENSAJE
    -- ============================
    v_message_id := generate_message_id();
    
    INSERT INTO chat_logs (
        message_id, match_id, sender_id, message, reply_to
    ) VALUES (
        v_message_id, p_match_id, p_sender_id, p_message, p_reply_to
    );
    
    RETURN format('Mensaje enviado correctamente con ID %s.', v_message_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: MARCAR MENSAJE COMO LEÍDO
-- ============================
CREATE OR REPLACE FUNCTION mark_message_as_read(
    p_message_id VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM chat_logs WHERE message_id = p_message_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un mensaje con el ID %.', p_message_id;
    END IF;
    
    UPDATE chat_logs
    SET is_read = TRUE
    WHERE message_id = p_message_id;
    
    RETURN format('Mensaje %s marcado como leído.', p_message_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: MARCAR MÚLTIPLES MENSAJES COMO LEÍDOS
-- ============================
CREATE OR REPLACE FUNCTION mark_messages_as_read_batch(
    p_match_id INTEGER,
    p_reader_id INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_count INTEGER;
    v_match_user1 INTEGER;
    v_match_user2 INTEGER;
BEGIN
    -- Verificar que el match existe
    SELECT user_1, user_2 INTO v_match_user1, v_match_user2
    FROM user_matches
    WHERE match_id = p_match_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe un match con el ID %.', p_match_id;
    END IF;
    
    -- Verificar que el reader es parte del match
    IF p_reader_id <> v_match_user1 AND p_reader_id <> v_match_user2 THEN
        RAISE EXCEPTION 'El usuario % no es parte del match %.', p_reader_id, p_match_id;
    END IF;
    
    -- Marcar como leídos todos los mensajes que NO fueron enviados por el reader
    UPDATE chat_logs
    SET is_read = TRUE
    WHERE match_id = p_match_id
    AND sender_id <> p_reader_id
    AND is_read = FALSE;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    
    RETURN format('%s mensajes marcados como leídos en el match %s.', v_count, p_match_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: MARCAR MENSAJE COMO CORREGIDO
-- ============================
CREATE OR REPLACE FUNCTION mark_message_as_corrected(
    p_message_id VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM chat_logs WHERE message_id = p_message_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un mensaje con el ID %.', p_message_id;
    END IF;
    
    UPDATE chat_logs
    SET is_corrected = TRUE
    WHERE message_id = p_message_id;
    
    RETURN format('Mensaje %s marcado como corregido.', p_message_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: EDITAR MENSAJE
-- ============================
CREATE OR REPLACE FUNCTION edit_message(
    p_message_id VARCHAR,
    p_new_message TEXT
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_sender_id INTEGER;
BEGIN
    IF p_new_message IS NULL OR LENGTH(TRIM(p_new_message)) = 0 THEN
        RAISE EXCEPTION 'El nuevo mensaje no puede estar vacío.';
    END IF;
    
    IF LENGTH(p_new_message) > 5000 THEN
        RAISE EXCEPTION 'El mensaje excede el límite de 5000 caracteres.';
    END IF;
    
    SELECT sender_id INTO v_sender_id
    FROM chat_logs
    WHERE message_id = p_message_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe un mensaje con el ID %.', p_message_id;
    END IF;
    
    UPDATE chat_logs
    SET message = p_new_message
    WHERE message_id = p_message_id;
    
    RETURN format('Mensaje %s editado correctamente.', p_message_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR MENSAJE
-- ============================
CREATE OR REPLACE FUNCTION delete_message(
    p_message_id VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM chat_logs WHERE message_id = p_message_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un mensaje con el ID %.', p_message_id;
    END IF;
    
    BEGIN
        DELETE FROM chat_logs WHERE message_id = p_message_id;
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE EXCEPTION 'No se puede eliminar el mensaje % porque tiene respuestas asociadas.', p_message_id;
    END;
    
    RETURN format('Mensaje %s eliminado correctamente.', p_message_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER MENSAJES DE UN MATCH
-- ============================
CREATE OR REPLACE FUNCTION get_match_messages(
    p_match_id INTEGER,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    message_id VARCHAR,
    sender_id INTEGER,
    message TEXT,
    timestamp TIMESTAMP,
    is_corrected BOOLEAN,
    reply_to VARCHAR,
    is_read BOOLEAN
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        cl.message_id,
        cl.sender_id,
        cl.message,
        cl.timestamp,
        cl.is_corrected,
        cl.reply_to,
        cl.is_read
    FROM chat_logs cl
    WHERE cl.match_id = p_match_id
    ORDER BY cl.timestamp DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER MENSAJE POR ID
-- ============================
CREATE OR REPLACE FUNCTION get_message_by_id(
    p_message_id VARCHAR
)
RETURNS TABLE (
    message_id VARCHAR,
    match_id INTEGER,
    sender_id INTEGER,
    message TEXT,
    timestamp TIMESTAMP,
    is_corrected BOOLEAN,
    reply_to VARCHAR,
    is_read BOOLEAN
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        cl.message_id,
        cl.match_id,
        cl.sender_id,
        cl.message,
        cl.timestamp,
        cl.is_corrected,
        cl.reply_to,
        cl.is_read
    FROM chat_logs cl
    WHERE cl.message_id = p_message_id;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER MENSAJES NO LEÍDOS DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_unread_messages(
    p_user_id INTEGER
)
RETURNS TABLE (
    message_id VARCHAR,
    match_id INTEGER,
    sender_id INTEGER,
    message TEXT,
    timestamp TIMESTAMP,
    is_corrected BOOLEAN,
    reply_to VARCHAR
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        cl.message_id,
        cl.match_id,
        cl.sender_id,
        cl.message,
        cl.timestamp,
        cl.is_corrected,
        cl.reply_to
    FROM chat_logs cl
    INNER JOIN user_matches um ON cl.match_id = um.match_id
    WHERE (um.user_1 = p_user_id OR um.user_2 = p_user_id)
    AND cl.sender_id <> p_user_id
    AND cl.is_read = FALSE
    ORDER BY cl.timestamp ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: CONTAR MENSAJES NO LEÍDOS POR MATCH
-- ============================
CREATE OR REPLACE FUNCTION count_unread_messages_by_match(
    p_match_id INTEGER,
    p_user_id INTEGER
)
RETURNS INTEGER AS
$$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM chat_logs
    WHERE match_id = p_match_id
    AND sender_id <> p_user_id
    AND is_read = FALSE;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: CONTAR TOTAL DE MENSAJES NO LEÍDOS DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION count_total_unread_messages(
    p_user_id INTEGER
)
RETURNS INTEGER AS
$$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM chat_logs cl
    INNER JOIN user_matches um ON cl.match_id = um.match_id
    WHERE (um.user_1 = p_user_id OR um.user_2 = p_user_id)
    AND cl.sender_id <> p_user_id
    AND cl.is_read = FALSE;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER ÚLTIMO MENSAJE DE CADA MATCH
-- ============================
CREATE OR REPLACE FUNCTION get_last_messages_per_match(
    p_user_id INTEGER
)
RETURNS TABLE (
    match_id INTEGER,
    message_id VARCHAR,
    sender_id INTEGER,
    message TEXT,
    timestamp TIMESTAMP,
    is_read BOOLEAN,
    unread_count INTEGER
)
AS
$$
BEGIN
    RETURN QUERY
    WITH last_messages AS (
        SELECT DISTINCT ON (cl.match_id)
            cl.match_id,
            cl.message_id,
            cl.sender_id,
            cl.message,
            cl.timestamp,
            cl.is_read
        FROM chat_logs cl
        INNER JOIN user_matches um ON cl.match_id = um.match_id
        WHERE um.user_1 = p_user_id OR um.user_2 = p_user_id
        ORDER BY cl.match_id, cl.timestamp DESC
    )
    SELECT
        lm.match_id,
        lm.message_id,
        lm.sender_id,
        lm.message,
        lm.timestamp,
        lm.is_read,
        (SELECT COUNT(*)::INTEGER 
         FROM chat_logs cl2 
         WHERE cl2.match_id = lm.match_id 
         AND cl2.sender_id <> p_user_id 
         AND cl2.is_read = FALSE) as unread_count
    FROM last_messages lm
    ORDER BY lm.timestamp DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: BUSCAR MENSAJES POR TEXTO
-- ============================
CREATE OR REPLACE FUNCTION search_messages(
    p_match_id INTEGER,
    p_search_text VARCHAR
)
RETURNS TABLE (
    message_id VARCHAR,
    sender_id INTEGER,
    message TEXT,
    timestamp TIMESTAMP,
    is_corrected BOOLEAN,
    reply_to VARCHAR,
    is_read BOOLEAN
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        cl.message_id,
        cl.sender_id,
        cl.message,
        cl.timestamp,
        cl.is_corrected,
        cl.reply_to,
        cl.is_read
    FROM chat_logs cl
    WHERE cl.match_id = p_match_id
    AND UPPER(cl.message) LIKE '%' || UPPER(p_search_text) || '%'
    ORDER BY cl.timestamp DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER CONVERSACIÓN CON DETALLES DE USUARIOS
-- ============================
CREATE OR REPLACE FUNCTION get_conversation_with_details(
    p_match_id INTEGER,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    message_id VARCHAR,
    sender_id INTEGER,
    sender_name VARCHAR,
    sender_photo VARCHAR,
    message TEXT,
    timestamp TIMESTAMP,
    is_corrected BOOLEAN,
    reply_to VARCHAR,
    reply_to_message TEXT,
    is_read BOOLEAN
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        cl.message_id,
        cl.sender_id,
        (u.first_name || ' ' || u.last_name)::VARCHAR as sender_name,
        u.profile_photo as sender_photo,
        cl.message,
        cl.timestamp,
        cl.is_corrected,
        cl.reply_to,
        cl_reply.message as reply_to_message,
        cl.is_read
    FROM chat_logs cl
    INNER JOIN users u ON cl.sender_id = u.id_user
    LEFT JOIN chat_logs cl_reply ON cl.reply_to = cl_reply.message_id
    WHERE cl.match_id = p_match_id
    ORDER BY cl.timestamp DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER ESTADÍSTICAS DE CHAT
-- ============================
CREATE OR REPLACE FUNCTION get_chat_statistics(
    p_match_id INTEGER
)
RETURNS TABLE (
    match_id INTEGER,
    total_messages INTEGER,
    user1_id INTEGER,
    user1_message_count INTEGER,
    user2_id INTEGER,
    user2_message_count INTEGER,
    corrected_messages INTEGER,
    unread_messages INTEGER,
    first_message_date TIMESTAMP,
    last_message_date TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        p_match_id as match_id,
        COUNT(*)::INTEGER as total_messages,
        um.user_1 as user1_id,
        COUNT(CASE WHEN cl.sender_id = um.user_1 THEN 1 END)::INTEGER as user1_message_count,
        um.user_2 as user2_id,
        COUNT(CASE WHEN cl.sender_id = um.user_2 THEN 1 END)::INTEGER as user2_message_count,
        COUNT(CASE WHEN cl.is_corrected = TRUE THEN 1 END)::INTEGER as corrected_messages,
        COUNT(CASE WHEN cl.is_read = FALSE THEN 1 END)::INTEGER as unread_messages,
        MIN(cl.timestamp) as first_message_date,
        MAX(cl.timestamp) as last_message_date
    FROM chat_logs cl
    INNER JOIN user_matches um ON cl.match_id = um.match_id
    WHERE cl.match_id = p_match_id
    GROUP BY um.user_1, um.user_2;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR MENSAJES ANTIGUOS (ADMIN/CLEANUP)
-- ============================
CREATE OR REPLACE FUNCTION delete_old_messages(
    p_days_old INTEGER DEFAULT 365
)
RETURNS TEXT AS
$$
DECLARE
    v_count INTEGER;
BEGIN
    DELETE FROM chat_logs
    WHERE timestamp < CURRENT_TIMESTAMP - (p_days_old || ' days')::INTERVAL;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    
    RETURN format('Eliminados %s mensajes con más de %s días de antigüedad.', v_count, p_days_old);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR TODOS LOS MENSAJES DE UN MATCH
-- ============================
CREATE OR REPLACE FUNCTION delete_match_messages(
    p_match_id INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM chat_logs
    WHERE match_id = p_match_id;
    
    DELETE FROM chat_logs WHERE match_id = p_match_id;
    
    RETURN format('Eliminados %s mensajes del match %s.', v_count, p_match_id);
END;
$$ LANGUAGE plpgsql;