-- ============================
-- FUNCIÓN: CREAR MATCH ENTRE DOS USUARIOS
-- ============================
CREATE OR REPLACE FUNCTION add_user_match(
    p_user_1 INTEGER,
    p_user_2 INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_user1_active BOOLEAN;
    v_user2_active BOOLEAN;
    v_match_id INTEGER;
    v_ordered_user1 INTEGER;
    v_ordered_user2 INTEGER;
    v_mutual_like BOOLEAN;
BEGIN
    -- ============================
    -- VALIDACIONES BÁSICAS
    -- ============================
    IF p_user_1 IS NULL THEN
        RAISE EXCEPTION 'El ID del primer usuario no puede estar vacío.';
    END IF;
    
    IF p_user_2 IS NULL THEN
        RAISE EXCEPTION 'El ID del segundo usuario no puede estar vacío.';
    END IF;
    
    IF p_user_1 = p_user_2 THEN
        RAISE EXCEPTION 'Un usuario no puede hacer match consigo mismo.';
    END IF;
    
    -- Ordenar usuarios para cumplir con la restricción user_1 < user_2
    IF p_user_1 < p_user_2 THEN
        v_ordered_user1 := p_user_1;
        v_ordered_user2 := p_user_2;
    ELSE
        v_ordered_user1 := p_user_2;
        v_ordered_user2 := p_user_1;
    END IF;
    
    -- ============================
    -- VERIFICAR EXISTENCIA Y ESTADO DE USUARIOS
    -- ============================
    SELECT is_active INTO v_user1_active
    FROM users
    WHERE id_user = v_ordered_user1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El usuario con ID % no existe.', v_ordered_user1;
    END IF;
    
    IF NOT v_user1_active THEN
        RAISE EXCEPTION 'El usuario con ID % no está activo.', v_ordered_user1;
    END IF;
    
    SELECT is_active INTO v_user2_active
    FROM users
    WHERE id_user = v_ordered_user2;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El usuario con ID % no existe.', v_ordered_user2;
    END IF;
    
    IF NOT v_user2_active THEN
        RAISE EXCEPTION 'El usuario con ID % no está activo.', v_ordered_user2;
    END IF;
    
    -- ============================
    -- VERIFICAR SI YA EXISTE EL MATCH
    -- ============================
    SELECT EXISTS(
        SELECT 1 FROM user_matches 
        WHERE user_1 = v_ordered_user1 
        AND user_2 = v_ordered_user2
    ) INTO v_exists;
    
    IF v_exists THEN
        RAISE EXCEPTION 'Ya existe un match entre los usuarios % y %.', v_ordered_user1, v_ordered_user2;
    END IF;
    
    -- ============================
    -- VERIFICAR QUE EXISTA LIKE MUTUO (OPCIONAL PERO RECOMENDADO)
    -- ============================
    SELECT (
        EXISTS(SELECT 1 FROM user_likes WHERE id_user_giver = v_ordered_user1 AND id_user_receiver = v_ordered_user2)
        AND
        EXISTS(SELECT 1 FROM user_likes WHERE id_user_giver = v_ordered_user2 AND id_user_receiver = v_ordered_user1)
    ) INTO v_mutual_like;
    
    IF NOT v_mutual_like THEN
        RAISE EXCEPTION 'No se puede crear un match sin like mutuo entre los usuarios % y %.', v_ordered_user1, v_ordered_user2;
    END IF;
    
    -- ============================
    -- CREAR MATCH
    -- ============================
    INSERT INTO user_matches (user_1, user_2)
    VALUES (v_ordered_user1, v_ordered_user2)
    RETURNING match_id INTO v_match_id;
    
    RETURN format('Match creado correctamente entre usuarios %s y %s con ID %s.', v_ordered_user1, v_ordered_user2, v_match_id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_create_match_on_mutual_like()
RETURNS TRIGGER AS
$$
DECLARE
    v_user1 INTEGER;
    v_user2 INTEGER;
BEGIN
    -- Si existe like inverso...
    IF EXISTS (
        SELECT 1
        FROM user_likes
        WHERE id_user_giver = NEW.id_user_receiver
          AND id_user_receiver = NEW.id_user_giver
    ) THEN

        -- Ordenar usuarios (cumplir constraint user_1 < user_2)
        IF NEW.id_user_giver < NEW.id_user_receiver THEN
            v_user1 := NEW.id_user_giver;
            v_user2 := NEW.id_user_receiver;
        ELSE
            v_user1 := NEW.id_user_receiver;
            v_user2 := NEW.id_user_giver;
        END IF;

        -- Insertar match (si no existe)
        INSERT INTO user_matches (user_1, user_2)
        VALUES (v_user1, v_user2)
        ON CONFLICT (user_1, user_2) DO NOTHING;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auto_match
AFTER INSERT ON user_likes
FOR EACH ROW
EXECUTE FUNCTION trg_create_match_on_mutual_like();



-- ============================
-- FUNCIÓN: ELIMINAR MATCH
-- ============================
CREATE OR REPLACE FUNCTION delete_user_match(
    p_match_id INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_user1 INTEGER;
    v_user2 INTEGER;
BEGIN
    -- ============================
    -- VERIFICAR EXISTENCIA Y OBTENER USUARIOS
    -- ============================
    SELECT user_1, user_2 INTO v_user1, v_user2
    FROM user_matches
    WHERE match_id = p_match_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe un match con el ID %.', p_match_id;
    END IF;
    
    -- ============================
    -- ELIMINAR MATCH
    -- ============================
    BEGIN
        DELETE FROM user_matches WHERE match_id = p_match_id;
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE EXCEPTION 'No se puede eliminar el match (ID: %) porque tiene registros asociados.', p_match_id;
    END;
    
    RETURN format('Match eliminado correctamente entre usuarios %s y %s (ID: %s).', v_user1, v_user2, p_match_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR MATCH POR USUARIOS
-- ============================
CREATE OR REPLACE FUNCTION delete_match_by_users(
    p_user_1 INTEGER,
    p_user_2 INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_ordered_user1 INTEGER;
    v_ordered_user2 INTEGER;
    v_match_id INTEGER;
    v_deleted_chats INTEGER;
BEGIN
    -- ============================
    -- ORDENAR USUARIOS
    -- ============================
    IF p_user_1 < p_user_2 THEN
        v_ordered_user1 := p_user_1;
        v_ordered_user2 := p_user_2;
    ELSE
        v_ordered_user1 := p_user_2;
        v_ordered_user2 := p_user_1;
    END IF;

    -- ============================
    -- OBTENER MATCH
    -- ============================
    SELECT match_id
    INTO v_match_id
    FROM user_matches
    WHERE user_1 = v_ordered_user1
      AND user_2 = v_ordered_user2;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'No existe un match entre los usuarios % y %.',
            v_ordered_user1, v_ordered_user2;
    END IF;

    -- ============================
    -- ELIMINAR CHATS ASOCIADOS
    -- ============================
    DELETE FROM chat_logs
    WHERE match_id = v_match_id;

    GET DIAGNOSTICS v_deleted_chats = ROW_COUNT;

    -- ============================
    -- ELIMINAR MATCH
    -- ============================
    DELETE FROM user_matches
    WHERE match_id = v_match_id;

    -- ============================
    -- RESPUESTA
    -- ============================
    RETURN format(
        'Match eliminado correctamente entre usuarios %s y %s. Chats eliminados: %s.',
        v_ordered_user1,
        v_ordered_user2,
        v_deleted_chats
    );
END;
$$ LANGUAGE plpgsql;


-- ============================
-- FUNCIÓN: OBTENER TODOS LOS MATCHES
-- ============================
CREATE OR REPLACE FUNCTION get_all_user_matches()
RETURNS TABLE (
    match_id INTEGER,
    user_1 INTEGER,
    user_2 INTEGER,
    match_time TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        um.match_id,
        um.user_1,
        um.user_2,
        um.match_time
    FROM user_matches um
    ORDER BY um.match_time DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER MATCH POR ID
-- ============================
CREATE OR REPLACE FUNCTION get_user_match_by_id(
    p_match_id INTEGER
)
RETURNS TABLE (
    match_id INTEGER,
    user_1 INTEGER,
    user_2 INTEGER,
    match_time TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        um.match_id,
        um.user_1,
        um.user_2,
        um.match_time
    FROM user_matches um
    WHERE um.match_id = p_match_id;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER MATCHES DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_user_matches(
    p_user_id INTEGER
)
RETURNS TABLE (
    match_id INTEGER,
    matched_user_id INTEGER,
    match_time TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        um.match_id,
        CASE 
            WHEN um.user_1 = p_user_id THEN um.user_2
            ELSE um.user_1
        END as matched_user_id,
        um.match_time
    FROM user_matches um
    WHERE um.user_1 = p_user_id OR um.user_2 = p_user_id
    ORDER BY um.match_time DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: VERIFICAR SI EXISTE MATCH ENTRE DOS USUARIOS
-- ============================
CREATE OR REPLACE FUNCTION check_match_exists(
    p_user_1 INTEGER,
    p_user_2 INTEGER
)
RETURNS BOOLEAN AS
$$
DECLARE
    v_exists BOOLEAN;
    v_ordered_user1 INTEGER;
    v_ordered_user2 INTEGER;
BEGIN
    -- Ordenar usuarios
    IF p_user_1 < p_user_2 THEN
        v_ordered_user1 := p_user_1;
        v_ordered_user2 := p_user_2;
    ELSE
        v_ordered_user1 := p_user_2;
        v_ordered_user2 := p_user_1;
    END IF;
    
    SELECT EXISTS(
        SELECT 1 FROM user_matches 
        WHERE user_1 = v_ordered_user1 
        AND user_2 = v_ordered_user2
    ) INTO v_exists;
    
    RETURN v_exists;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: CONTAR MATCHES DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION count_user_matches(
    p_user_id INTEGER
)
RETURNS INTEGER AS
$$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(match_id) INTO v_count
    FROM user_matches
    WHERE user_1 = p_user_id OR user_2 = p_user_id;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER MATCHES CON INFORMACIÓN COMPLETA DE USUARIOS
-- ============================
CREATE OR REPLACE FUNCTION get_user_matches_with_details(
    p_user_id INTEGER
)
RETURNS TABLE (
    match_id INTEGER,
    match_time TIMESTAMP,
    matched_user_id INTEGER,
    matched_user_name VARCHAR,
    matched_user_email VARCHAR,
    matched_user_country VARCHAR,
    matched_user_native_lang VARCHAR,
    matched_user_target_lang VARCHAR,
    matched_user_description TEXT,
    has_sessions BOOLEAN
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        um.match_id,
        um.match_time,
        u.id_user as matched_user_id,
        (u.first_name || ' ' || u.last_name)::VARCHAR as matched_user_name,
        u.email as matched_user_email,
        u.country_id as matched_user_country,
        u.native_lang_id as matched_user_native_lang,
        u.target_lang_id as matched_user_target_lang,
        u.description as matched_user_description,
        EXISTS(
            SELECT 1 FROM sessions s
            WHERE (s.id_user1 = p_user_id AND s.id_user2 = u.id_user)
            OR (s.id_user1 = u.id_user AND s.id_user2 = p_user_id)
        ) as has_sessions
    FROM user_matches um
    INNER JOIN users u ON (
        CASE 
            WHEN um.user_1 = p_user_id THEN um.user_2
            ELSE um.user_1
        END = u.id_user
    )
    WHERE um.user_1 = p_user_id OR um.user_2 = p_user_id
    ORDER BY um.match_time DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER MATCHES RECIENTES (ÚLTIMOS N DÍAS)
-- ============================
CREATE OR REPLACE FUNCTION get_recent_matches(
    p_user_id INTEGER,
    p_days INTEGER DEFAULT 7
)
RETURNS TABLE (
    match_id INTEGER,
    matched_user_id INTEGER,
    match_time TIMESTAMP,
    days_ago INTEGER
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        um.match_id,
        CASE 
            WHEN um.user_1 = p_user_id THEN um.user_2
            ELSE um.user_1
        END as matched_user_id,
        um.match_time,
        EXTRACT(DAY FROM (CURRENT_TIMESTAMP - um.match_time))::INTEGER as days_ago
    FROM user_matches um
    WHERE (um.user_1 = p_user_id OR um.user_2 = p_user_id)
    AND um.match_time >= CURRENT_TIMESTAMP - (p_days || ' days')::INTERVAL
    ORDER BY um.match_time DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER MATCHES SIN SESIONES AGENDADAS
-- ============================
CREATE OR REPLACE FUNCTION get_matches_without_sessions(
    p_user_id INTEGER
)
RETURNS TABLE (
    match_id INTEGER,
    matched_user_id INTEGER,
    match_time TIMESTAMP,
    days_since_match INTEGER
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        um.match_id,
        CASE 
            WHEN um.user_1 = p_user_id THEN um.user_2
            ELSE um.user_1
        END as matched_user_id,
        um.match_time,
        EXTRACT(DAY FROM (CURRENT_TIMESTAMP - um.match_time))::INTEGER as days_since_match
    FROM user_matches um
    WHERE (um.user_1 = p_user_id OR um.user_2 = p_user_id)
    AND NOT EXISTS(
        SELECT 1 FROM sessions s
        WHERE (s.id_user1 = um.user_1 AND s.id_user2 = um.user_2)
        OR (s.id_user1 = um.user_2 AND s.id_user2 = um.user_1)
    )
    ORDER BY um.match_time ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER ESTADÍSTICAS DE MATCHES
-- ============================
CREATE OR REPLACE FUNCTION get_match_statistics(
    p_user_id INTEGER
)
RETURNS TABLE (
    user_id INTEGER,
    total_matches INTEGER,
    matches_last_week INTEGER,
    matches_last_month INTEGER,
    matches_with_sessions INTEGER,
    matches_without_sessions INTEGER,
    average_days_to_first_session DECIMAL
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        p_user_id as user_id,
        COUNT(match_id)::INTEGER as total_matches,
        COUNT(CASE WHEN um.match_time >= CURRENT_TIMESTAMP - INTERVAL '7 days' THEN 1 END)::INTEGER as matches_last_week,
        COUNT(CASE WHEN um.match_time >= CURRENT_TIMESTAMP - INTERVAL '30 days' THEN 1 END)::INTEGER as matches_last_month,
        COUNT(CASE 
            WHEN EXISTS(
                SELECT 1 FROM sessions s
                WHERE (s.id_user1 = um.user_1 AND s.id_user2 = um.user_2)
                OR (s.id_user1 = um.user_2 AND s.id_user2 = um.user_1)
            ) THEN 1 
        END)::INTEGER as matches_with_sessions,
        COUNT(CASE 
            WHEN NOT EXISTS(
                SELECT 1 FROM sessions s
                WHERE (s.id_user1 = um.user_1 AND s.id_user2 = um.user_2)
                OR (s.id_user1 = um.user_2 AND s.id_user2 = um.user_1)
            ) THEN 1 
        END)::INTEGER as matches_without_sessions,
        ROUND(AVG(
            CASE 
                WHEN EXISTS(
                    SELECT 1 FROM sessions s
                    WHERE (s.id_user1 = um.user_1 AND s.id_user2 = um.user_2)
                    OR (s.id_user1 = um.user_2 AND s.id_user2 = um.user_1)
                ) THEN 
                    EXTRACT(DAY FROM (
                        (SELECT MIN(s.created_at) FROM sessions s
                         WHERE (s.id_user1 = um.user_1 AND s.id_user2 = um.user_2)
                         OR (s.id_user1 = um.user_2 AND s.id_user2 = um.user_1))
                        - um.match_time
                    ))
            END
        ), 2) as average_days_to_first_session
    FROM user_matches um
    WHERE um.user_1 = p_user_id OR um.user_2 = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR TODOS LOS MATCHES DE UN USUARIO (ADMIN/CLEANUP)
-- ============================
CREATE OR REPLACE FUNCTION delete_all_user_matches(
    p_user_id INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(match_id) INTO v_count
    FROM user_matches
    WHERE user_1 = p_user_id OR user_2 = p_user_id;
    
    DELETE FROM user_matches
    WHERE user_1 = p_user_id OR user_2 = p_user_id;
    
    RETURN format('Eliminados %s matches del usuario %s.', v_count, p_user_id);
END;
$$ LANGUAGE plpgsql;