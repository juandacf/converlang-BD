-- ============================
-- FUNCIÓN: AGREGAR SESIÓN
-- ============================
CREATE OR REPLACE FUNCTION add_session(
    p_id_user1 INTEGER,
    p_id_user2 INTEGER,
    p_start_time TIMESTAMP,
    p_end_time TIMESTAMP,
    p_session_notes TEXT DEFAULT NULL
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_session_id INTEGER;
BEGIN
    -- ============================
    -- VALIDACIÓN DE USUARIOS
    -- ============================
    IF p_id_user1 IS NULL OR p_id_user2 IS NULL THEN
        RAISE EXCEPTION 'Ambos usuarios participantes son obligatorios.';
    END IF;

    IF p_id_user1 = p_id_user2 THEN
        RAISE EXCEPTION 'Los dos usuarios participantes deben ser diferentes.';
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM users WHERE id_user = p_id_user1 AND is_active = TRUE
    ) INTO v_exists;

    IF NOT v_exists THEN
        RAISE EXCEPTION 'El usuario con ID % no existe o no está activo.', p_id_user1;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM users WHERE id_user = p_id_user2 AND is_active = TRUE
    ) INTO v_exists;

    IF NOT v_exists THEN
        RAISE EXCEPTION 'El usuario con ID % no existe o no está activo.', p_id_user2;
    END IF;

    -- ============================
    -- VALIDACIÓN DE FECHAS
    -- ============================
    IF p_start_time IS NULL OR p_end_time IS NULL THEN
        RAISE EXCEPTION 'La fecha de inicio y fin son obligatorias.';
    END IF;

    IF p_end_time <= p_start_time THEN
        RAISE EXCEPTION 'La fecha de finalización debe ser posterior a la fecha de inicio.';
    END IF;

    IF p_end_time - p_start_time > INTERVAL '8 hours' THEN
        RAISE EXCEPTION 'La duración de la sesión no puede exceder 8 horas.';
    END IF;
   
    -- ============================
    -- VALIDAR CONFLICTOS DE HORARIO
    -- ============================
    SELECT EXISTS(
        SELECT 1 FROM sessions
        WHERE (id_user1 = p_id_user1 OR id_user2 = p_id_user1 OR id_user1 = p_id_user2 OR id_user2 = p_id_user2)
        AND (
            (p_start_time BETWEEN start_time AND end_time)
            OR
            (p_end_time BETWEEN start_time AND end_time)
            OR
            (start_time BETWEEN p_start_time AND p_end_time)
        )
    ) INTO v_exists;
    
    IF v_exists THEN
        RAISE EXCEPTION 'Uno de los usuarios ya tiene otra sesión programada en ese horario.';
    END IF;

    -- ============================
    -- INSERTAR SESIÓN
    -- ============================
    INSERT INTO sessions (
        id_user1,
        id_user2,
        start_time,
        end_time,
        session_notes
    )
    VALUES (
        p_id_user1,
        p_id_user2,
        p_start_time,
        p_end_time,
        p_session_notes
    )
    RETURNING session_id INTO v_session_id;

    RETURN format(
        'Sesión %s creada correctamente para usuarios %s y %s.',
        v_session_id, p_id_user1, p_id_user2
    );
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ACTUALIZAR SESIÓN
-- ============================
CREATE OR REPLACE FUNCTION update_session(
    p_session_id INTEGER,
    p_start_time TIMESTAMP,
    p_end_time TIMESTAMP,
    p_session_notes TEXT DEFAULT NULL
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_id_user1 INTEGER;
    v_id_user2 INTEGER;
BEGIN
    -- ============================
    -- VERIFICAR EXISTENCIA DE LA SESIÓN
    -- ============================
    SELECT id_user1, id_user2 
    INTO v_id_user1, v_id_user2
    FROM sessions 
    WHERE session_id = p_session_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe una sesión con el ID %.', p_session_id;
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE FECHAS
    -- ============================
    IF p_start_time IS NULL OR p_end_time IS NULL THEN
        RAISE EXCEPTION 'La fecha de inicio y fin son obligatorias.';
    END IF;
    
    IF p_end_time <= p_start_time THEN
        RAISE EXCEPTION 'La fecha de finalización debe ser posterior a la fecha de inicio.';
    END IF;
    
    IF p_end_time - p_start_time > INTERVAL '8 hours' THEN
        RAISE EXCEPTION 'La duración de la sesión no puede exceder 8 horas.';
    END IF;
    
    -- ============================
    -- VALIDAR CONFLICTOS DE HORARIO (excluyendo la sesión actual)
    -- ============================
    SELECT EXISTS(
        SELECT 1 FROM sessions
        WHERE session_id <> p_session_id
        AND (id_user1 = v_id_user1 OR id_user2 = v_id_user1 OR id_user1 = v_id_user2 OR id_user2 = v_id_user2)
        AND (
            (p_start_time BETWEEN start_time AND end_time)
            OR
            (p_end_time BETWEEN start_time AND end_time)
            OR
            (start_time BETWEEN p_start_time AND p_end_time)
        )
    ) INTO v_exists;
    
    IF v_exists THEN
        RAISE EXCEPTION 'Los usuarios ya tienen otra sesión programada en ese horario.';
    END IF;
    
    -- ============================
    -- ACTUALIZAR SESIÓN
    -- ============================
    UPDATE sessions
    SET
        start_time = p_start_time,
        end_time = p_end_time,
        session_notes = COALESCE(p_session_notes, session_notes),
        updated_at = CURRENT_TIMESTAMP
    WHERE session_id = p_session_id;
    
    RETURN format('Sesión %s actualizada correctamente.', p_session_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR SESIÓN
-- ============================
CREATE OR REPLACE FUNCTION delete_session(
    p_session_id INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM sessions WHERE session_id = p_session_id) INTO v_exists;
    
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe una sesión con el ID %.', p_session_id;
    END IF;
    
    DELETE FROM sessions WHERE session_id = p_session_id;
    
    RETURN format('Sesión %s eliminada correctamente.', p_session_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER TODAS LAS SESIONES
-- ============================
CREATE OR REPLACE FUNCTION get_all_sessions()
RETURNS TABLE (
    session_id INTEGER,
    id_user1 INTEGER,
    id_user2 INTEGER,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    session_notes TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
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
        s.session_notes,
        s.created_at, 
        s.updated_at
    FROM sessions s
    ORDER BY s.start_time DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER SESIÓN POR ID
-- ============================
CREATE OR REPLACE FUNCTION get_session_by_id(
    p_session_id INTEGER
)
RETURNS TABLE (
    session_id INTEGER,
    id_user1 INTEGER,
    id_user2 INTEGER,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    session_notes TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
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
        s.session_notes,
        s.created_at, 
        s.updated_at
    FROM sessions s
    WHERE s.session_id = p_session_id;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER SESIONES DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_user_sessions(
    p_user_id INTEGER
)
RETURNS TABLE (
    session_id INTEGER,
    id_user1 INTEGER,
    id_user2 INTEGER,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    session_notes TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
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
        s.session_notes,
        s.created_at, 
        s.updated_at
    FROM sessions s
    WHERE (s.id_user1 = p_user_id OR s.id_user2 = p_user_id)
    ORDER BY s.start_time DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER PRÓXIMAS SESIONES DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_upcoming_user_sessions(
    p_user_id INTEGER
)
RETURNS TABLE (
    session_id INTEGER,
    id_user1 INTEGER,
    id_user2 INTEGER,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    session_notes TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
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
        s.session_notes,
        s.created_at, 
        s.updated_at
    FROM sessions s
    WHERE (s.id_user1 = p_user_id OR s.id_user2 = p_user_id)
    AND s.start_time > CURRENT_TIMESTAMP
    ORDER BY s.start_time ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER SESIONES PASADAS DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_past_user_sessions(
    p_user_id INTEGER
)
RETURNS TABLE (
    session_id INTEGER,
    id_user1 INTEGER,
    id_user2 INTEGER,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    session_notes TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
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
        s.session_notes,
        s.created_at, 
        s.updated_at
    FROM sessions s
    WHERE (s.id_user1 = p_user_id OR s.id_user2 = p_user_id)
    AND s.end_time < CURRENT_TIMESTAMP
    ORDER BY s.start_time DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER SESIONES DEL ÚLTIMO MES DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_user_sessions_last_month(
    p_user_id INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    result JSONB;
BEGIN
    WITH sessions_filtered AS (
        SELECT
            (CURRENT_DATE - created_at::date) AS days_ago
        FROM sessions
        WHERE
            (id_user1 = p_user_id OR id_user2 = p_user_id)
            AND created_at >= CURRENT_DATE - INTERVAL '30 days'
    ),
    buckets AS (
        SELECT 'Week 4'  AS name, COUNT(*) FILTER (WHERE days_ago = 0)               AS sesiones FROM sessions_filtered
        UNION ALL
        SELECT 'Week 3' AS name, COUNT(*) FILTER (WHERE days_ago BETWEEN 1 AND 10)  AS sesiones FROM sessions_filtered
        UNION ALL
        SELECT 'Week 2' AS name, COUNT(*) FILTER (WHERE days_ago BETWEEN 11 AND 20) AS sesiones FROM sessions_filtered
        UNION ALL
        SELECT 'Week 1' AS name, COUNT(*) FILTER (WHERE days_ago BETWEEN 21 AND 30) AS sesiones FROM sessions_filtered
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'name', name,
            'sesiones', sesiones
        )
        ORDER BY
            CASE name
                WHEN 'Week 1' THEN 0
                WHEN 'Week 2' THEN 1
                WHEN 'Week 3' THEN 2
                WHEN 'Week 4' THEN 3
            END
    )
    INTO result
    FROM buckets;

    RETURN result;
END;
$$;

-- ============================
-- FUNCIÓN: OBTENER SESIONES ENTRE DOS USUARIOS
-- ============================
CREATE OR REPLACE FUNCTION get_sessions_between_users(
    p_user1_id INTEGER,
    p_user2_id INTEGER
)
RETURNS TABLE (
    session_id INTEGER,
    id_user1 INTEGER,
    id_user2 INTEGER,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    session_notes TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
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
        s.session_notes,
        s.created_at, 
        s.updated_at
    FROM sessions s
    WHERE (
        (s.id_user1 = p_user1_id AND s.id_user2 = p_user2_id)
        OR
        (s.id_user1 = p_user2_id AND s.id_user2 = p_user1_id)
    )
    ORDER BY s.start_time DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: CONTAR SESIONES DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION count_user_sessions(
    p_user_id INTEGER
)
RETURNS INTEGER
AS
$$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM sessions
    WHERE (id_user1 = p_user_id OR id_user2 = p_user_id);
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER SESIONES EN UN RANGO DE FECHAS
-- ============================
CREATE OR REPLACE FUNCTION get_sessions_by_date_range(
    p_start_date TIMESTAMP,
    p_end_date TIMESTAMP
)
RETURNS TABLE (
    session_id INTEGER,
    id_user1 INTEGER,
    id_user2 INTEGER,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    session_notes TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
)
AS
$$
BEGIN
    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION 'La fecha de inicio debe ser anterior a la fecha de fin.';
    END IF;

    RETURN QUERY
    SELECT
        s.session_id, 
        s.id_user1, 
        s.id_user2,
        s.start_time, 
        s.end_time, 
        s.session_notes,
        s.created_at, 
        s.updated_at
    FROM sessions s
    WHERE s.start_time BETWEEN p_start_date AND p_end_date
    ORDER BY s.start_time ASC;
END;
$$ LANGUAGE plpgsql;
