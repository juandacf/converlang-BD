-- ============================
-- FUNCIÓN: CREAR REGISTRO DE SESIÓN DE INTERCAMBIO
-- ============================
CREATE OR REPLACE FUNCTION add_exchange_session(
    p_session_id VARCHAR,
    p_session_rating_user1 INTEGER DEFAULT NULL,
    p_session_rating_user2 INTEGER DEFAULT NULL,
    p_feedback_user1 TEXT DEFAULT NULL,
    p_feedback_user2 TEXT DEFAULT NULL
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_session_type VARCHAR;
BEGIN
    -- ============================
    -- VALIDACIÓN DE SESSION_ID
    -- ============================
    IF p_session_id IS NULL OR LENGTH(TRIM(p_session_id)) = 0 THEN
        RAISE EXCEPTION 'El ID de la sesión no puede estar vacío.';
    END IF;
    
    -- Verificar que la sesión exista
    SELECT EXISTS(SELECT 1 FROM sessions WHERE session_id = p_session_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe una sesión con el ID %.', p_session_id;
    END IF;
    
    -- Verificar que la sesión sea de tipo 'exchange'
    SELECT session_type INTO v_session_type FROM sessions WHERE session_id = p_session_id;
    IF v_session_type <> 'exchange' THEN
        RAISE EXCEPTION 'La sesión % no es de tipo "exchange". Tipo actual: %.', p_session_id, v_session_type;
    END IF;
    
    -- Verificar que no exista ya un registro para esta sesión
    SELECT EXISTS(SELECT 1 FROM exchange_sessions WHERE session_id = p_session_id) INTO v_exists;
    IF v_exists THEN
        RAISE EXCEPTION 'Ya existe un registro de intercambio para la sesión %.', p_session_id;
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE RATINGS
    -- ============================
    IF p_session_rating_user1 IS NOT NULL THEN
        IF p_session_rating_user1 < 1 OR p_session_rating_user1 > 5 THEN
            RAISE EXCEPTION 'La calificación del usuario 1 debe estar entre 1 y 5. Valor proporcionado: %.', p_session_rating_user1;
        END IF;
    END IF;
    
    IF p_session_rating_user2 IS NOT NULL THEN
        IF p_session_rating_user2 < 1 OR p_session_rating_user2 > 5 THEN
            RAISE EXCEPTION 'La calificación del usuario 2 debe estar entre 1 y 5. Valor proporcionado: %.', p_session_rating_user2;
        END IF;
    END IF;
    
    -- ============================
    -- CREAR REGISTRO
    -- ============================
    INSERT INTO exchange_sessions (
        session_id, session_rating_user1, session_rating_user2,
        feedback_user1, feedback_user2
    ) VALUES (
        p_session_id, p_session_rating_user1, p_session_rating_user2,
        p_feedback_user1, p_feedback_user2
    );
    
    RETURN format('Registro de sesión de intercambio creado correctamente para la sesión %.', p_session_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ACTUALIZAR CALIFICACIÓN Y FEEDBACK DEL USUARIO 1
-- ============================
CREATE OR REPLACE FUNCTION update_user1_feedback(
    p_session_id VARCHAR,
    p_session_rating INTEGER DEFAULT NULL,
    p_feedback TEXT DEFAULT NULL
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_session_status VARCHAR;
BEGIN
    -- ============================
    -- VERIFICAR EXISTENCIA DEL REGISTRO
    -- ============================
    SELECT EXISTS(SELECT 1 FROM exchange_sessions WHERE session_id = p_session_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un registro de intercambio para la sesión %.', p_session_id;
    END IF;
    
    -- Verificar que la sesión esté completada
    SELECT session_status INTO v_session_status 
    FROM sessions 
    WHERE session_id = p_session_id;
    
    IF v_session_status <> 'completed' THEN
        RAISE EXCEPTION 'Solo se puede calificar sesiones completadas. Estado actual: %.', v_session_status;
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE RATING
    -- ============================
    IF p_session_rating IS NOT NULL THEN
        IF p_session_rating < 1 OR p_session_rating > 5 THEN
            RAISE EXCEPTION 'La calificación debe estar entre 1 y 5. Valor proporcionado: %.', p_session_rating;
        END IF;
    END IF;
    
    -- ============================
    -- ACTUALIZAR FEEDBACK
    -- ============================
    UPDATE exchange_sessions
    SET
        session_rating_user1 = COALESCE(p_session_rating, session_rating_user1),
        feedback_user1 = COALESCE(p_feedback, feedback_user1)
    WHERE session_id = p_session_id;
    
    RETURN format('Feedback del usuario 1 actualizado para la sesión %.', p_session_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ACTUALIZAR CALIFICACIÓN Y FEEDBACK DEL USUARIO 2
-- ============================
CREATE OR REPLACE FUNCTION update_user2_feedback(
    p_session_id VARCHAR,
    p_session_rating INTEGER DEFAULT NULL,
    p_feedback TEXT DEFAULT NULL
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_session_status VARCHAR;
BEGIN
    -- ============================
    -- VERIFICAR EXISTENCIA DEL REGISTRO
    -- ============================
    SELECT EXISTS(SELECT 1 FROM exchange_sessions WHERE session_id = p_session_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un registro de intercambio para la sesión %.', p_session_id;
    END IF;
    
    -- Verificar que la sesión esté completada
    SELECT session_status INTO v_session_status 
    FROM sessions 
    WHERE session_id = p_session_id;
    
    IF v_session_status <> 'completed' THEN
        RAISE EXCEPTION 'Solo se puede calificar sesiones completadas. Estado actual: %.', v_session_status;
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE RATING
    -- ============================
    IF p_session_rating IS NOT NULL THEN
        IF p_session_rating < 1 OR p_session_rating > 5 THEN
            RAISE EXCEPTION 'La calificación debe estar entre 1 y 5. Valor proporcionado: %.', p_session_rating;
        END IF;
    END IF;
    
    -- ============================
    -- ACTUALIZAR FEEDBACK
    -- ============================
    UPDATE exchange_sessions
    SET
        session_rating_user2 = COALESCE(p_session_rating, session_rating_user2),
        feedback_user2 = COALESCE(p_feedback, feedback_user2)
    WHERE session_id = p_session_id;
    
    RETURN format('Feedback del usuario 2 actualizado para la sesión %.', p_session_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ACTUALIZAR AMBOS FEEDBACKS (ADMIN)
-- ============================
CREATE OR REPLACE FUNCTION update_exchange_session(
    p_session_id VARCHAR,
    p_session_rating_user1 INTEGER DEFAULT NULL,
    p_session_rating_user2 INTEGER DEFAULT NULL,
    p_feedback_user1 TEXT DEFAULT NULL,
    p_feedback_user2 TEXT DEFAULT NULL
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    -- ============================
    -- VERIFICAR EXISTENCIA DEL REGISTRO
    -- ============================
    SELECT EXISTS(SELECT 1 FROM exchange_sessions WHERE session_id = p_session_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un registro de intercambio para la sesión %.', p_session_id;
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE RATINGS
    -- ============================
    IF p_session_rating_user1 IS NOT NULL THEN
        IF p_session_rating_user1 < 1 OR p_session_rating_user1 > 5 THEN
            RAISE EXCEPTION 'La calificación del usuario 1 debe estar entre 1 y 5. Valor proporcionado: %.', p_session_rating_user1;
        END IF;
    END IF;
    
    IF p_session_rating_user2 IS NOT NULL THEN
        IF p_session_rating_user2 < 1 OR p_session_rating_user2 > 5 THEN
            RAISE EXCEPTION 'La calificación del usuario 2 debe estar entre 1 y 5. Valor proporcionado: %.', p_session_rating_user2;
        END IF;
    END IF;
    
    -- ============================
    -- ACTUALIZAR REGISTRO
    -- ============================
    UPDATE exchange_sessions
    SET
        session_rating_user1 = COALESCE(p_session_rating_user1, session_rating_user1),
        session_rating_user2 = COALESCE(p_session_rating_user2, session_rating_user2),
        feedback_user1 = COALESCE(p_feedback_user1, feedback_user1),
        feedback_user2 = COALESCE(p_feedback_user2, feedback_user2)
    WHERE session_id = p_session_id;
    
    RETURN format('Registro de intercambio actualizado para la sesión %.', p_session_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR REGISTRO DE SESIÓN DE INTERCAMBIO
-- ============================
CREATE OR REPLACE FUNCTION delete_exchange_session(
    p_session_id VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    -- ============================
    -- VERIFICAR EXISTENCIA
    -- ============================
    SELECT EXISTS(SELECT 1 FROM exchange_sessions WHERE session_id = p_session_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un registro de intercambio para la sesión %.', p_session_id;
    END IF;
    
    -- ============================
    -- ELIMINAR REGISTRO
    -- ============================
    DELETE FROM exchange_sessions WHERE session_id = p_session_id;
    
    RETURN format('Registro de intercambio eliminado para la sesión %.', p_session_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER TODOS LOS REGISTROS DE INTERCAMBIO
-- ============================
CREATE OR REPLACE FUNCTION get_all_exchange_sessions()
RETURNS TABLE (
    session_id VARCHAR,
    session_rating_user1 INTEGER,
    session_rating_user2 INTEGER,
    feedback_user1 TEXT,
    feedback_user2 TEXT
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        es.session_id,
        es.session_rating_user1,
        es.session_rating_user2,
        es.feedback_user1,
        es.feedback_user2
    FROM exchange_sessions es
    ORDER BY es.session_id DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER REGISTRO POR SESSION_ID
-- ============================
CREATE OR REPLACE FUNCTION get_exchange_session_by_id(
    p_session_id VARCHAR
)
RETURNS TABLE (
    session_id VARCHAR,
    session_rating_user1 INTEGER,
    session_rating_user2 INTEGER,
    feedback_user1 TEXT,
    feedback_user2 TEXT
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        es.session_id,
        es.session_rating_user1,
        es.session_rating_user2,
        es.feedback_user1,
        es.feedback_user2
    FROM exchange_sessions es
    WHERE es.session_id = p_session_id;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER SESIONES DE INTERCAMBIO DE UN USUARIO CON DETALLES
-- ============================
CREATE OR REPLACE FUNCTION get_user_exchange_sessions_with_details(
    p_user_id INTEGER
)
RETURNS TABLE (
    session_id VARCHAR,
    id_user1 INTEGER,
    id_user2 INTEGER,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    session_status VARCHAR,
    language_used VARCHAR,
    session_rating_user1 INTEGER,
    session_rating_user2 INTEGER,
    feedback_user1 TEXT,
    feedback_user2 TEXT
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        s.session_id,
        s.id_user1,
        s.id_user2,
        s.start_time,
        s.end_time,
        s.session_status,
        s.language_used,
        es.session_rating_user1,
        es.session_rating_user2,
        es.feedback_user1,
        es.feedback_user2
    FROM sessions s
    INNER JOIN exchange_sessions es ON s.session_id = es.session_id
    WHERE (s.id_user1 = p_user_id OR s.id_user2 = p_user_id)
    AND s.session_type = 'exchange'
    ORDER BY s.start_time DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER SESIONES PENDIENTES DE CALIFICACIÓN PARA UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_pending_ratings_for_user(
    p_user_id INTEGER
)
RETURNS TABLE (
    session_id VARCHAR,
    id_user1 INTEGER,
    id_user2 INTEGER,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    language_used VARCHAR,
    user_position INTEGER, -- 1 si es user1, 2 si es user2
    already_rated BOOLEAN
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        s.session_id,
        s.id_user1,
        s.id_user2,
        s.start_time,
        s.end_time,
        s.language_used,
        CASE 
            WHEN s.id_user1 = p_user_id THEN 1
            ELSE 2
        END as user_position,
        CASE 
            WHEN s.id_user1 = p_user_id THEN (es.session_rating_user1 IS NOT NULL)
            ELSE (es.session_rating_user2 IS NOT NULL)
        END as already_rated
    FROM sessions s
    INNER JOIN exchange_sessions es ON s.session_id = es.session_id
    WHERE (s.id_user1 = p_user_id OR s.id_user2 = p_user_id)
    AND s.session_type = 'exchange'
    AND s.session_status = 'completed'
    AND (
        (s.id_user1 = p_user_id AND es.session_rating_user1 IS NULL)
        OR
        (s.id_user2 = p_user_id AND es.session_rating_user2 IS NULL)
    )
    ORDER BY s.end_time DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER PROMEDIO DE CALIFICACIONES DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_user_average_rating(
    p_user_id INTEGER
)
RETURNS TABLE (
    user_id INTEGER,
    total_sessions INTEGER,
    average_rating DECIMAL,
    total_ratings_received INTEGER
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        p_user_id as user_id,
        COUNT(*)::INTEGER as total_sessions,
        ROUND(AVG(
            CASE 
                WHEN s.id_user1 = p_user_id THEN es.session_rating_user2
                ELSE es.session_rating_user1
            END
        ), 2) as average_rating,
        COUNT(
            CASE 
                WHEN s.id_user1 = p_user_id THEN es.session_rating_user2
                ELSE es.session_rating_user1
            END
        )::INTEGER as total_ratings_received
    FROM sessions s
    INNER JOIN exchange_sessions es ON s.session_id = es.session_id
    WHERE (s.id_user1 = p_user_id OR s.id_user2 = p_user_id)
    AND s.session_type = 'exchange'
    AND s.session_status = 'completed';
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER SESIONES CON CALIFICACIONES ALTAS
-- ============================
CREATE OR REPLACE FUNCTION get_high_rated_exchange_sessions(
    p_min_rating INTEGER DEFAULT 4
)
RETURNS TABLE (
    session_id VARCHAR,
    session_rating_user1 INTEGER,
    session_rating_user2 INTEGER,
    average_rating DECIMAL,
    feedback_user1 TEXT,
    feedback_user2 TEXT
)
AS
$$
BEGIN
    IF p_min_rating < 1 OR p_min_rating > 5 THEN
        RAISE EXCEPTION 'La calificación mínima debe estar entre 1 y 5. Valor proporcionado: %.', p_min_rating;
    END IF;
    
    RETURN QUERY
    SELECT
        es.session_id,
        es.session_rating_user1,
        es.session_rating_user2,
        ROUND((COALESCE(es.session_rating_user1, 0) + COALESCE(es.session_rating_user2, 0))::DECIMAL / 
              NULLIF((CASE WHEN es.session_rating_user1 IS NOT NULL THEN 1 ELSE 0 END + 
                      CASE WHEN es.session_rating_user2 IS NOT NULL THEN 1 ELSE 0 END), 0), 2) as average_rating,
        es.feedback_user1,
        es.feedback_user2
    FROM exchange_sessions es
    WHERE (es.session_rating_user1 >= p_min_rating OR es.session_rating_user2 >= p_min_rating)
    AND (es.session_rating_user1 IS NOT NULL OR es.session_rating_user2 IS NOT NULL)
    ORDER BY average_rating DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: VERIFICAR SI AMBOS USUARIOS YA CALIFICARON
-- ============================
CREATE OR REPLACE FUNCTION is_session_fully_rated(
    p_session_id VARCHAR
)
RETURNS BOOLEAN AS
$$
DECLARE
    v_rating1 INTEGER;
    v_rating2 INTEGER;
BEGIN
    SELECT session_rating_user1, session_rating_user2 
    INTO v_rating1, v_rating2
    FROM exchange_sessions
    WHERE session_id = p_session_id;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    RETURN (v_rating1 IS NOT NULL AND v_rating2 IS NOT NULL);
END;
$$ LANGUAGE plpgsql;