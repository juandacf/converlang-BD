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
   
    -- NOTA: No se validan conflictos de horario porque las sesiones
    -- se registran como historial después de finalizadas, no se programan.

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
    SELECT jsonb_agg(
        jsonb_build_object(
            'name', to_char(day_series, 'DD/MM'),
            'sesiones', COALESCE(daily_counts.count, 0)
        )
        ORDER BY day_series ASC
    )
    INTO result
    FROM generate_series(
        CURRENT_DATE - INTERVAL '29 days',
        CURRENT_DATE,
        '1 day'::interval
    ) AS day_series
    LEFT JOIN (
        SELECT
            created_at::date AS session_date,
            SUM(1)::BIGINT AS count
        FROM sessions
        WHERE
            (id_user1 = p_user_id OR id_user2 = p_user_id)
            AND created_at >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY created_at::date
    ) AS daily_counts ON day_series::date = daily_counts.session_date;

    RETURN result;
END;
$$;

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
    SELECT COUNT(session_id) INTO v_count
    FROM sessions
    WHERE (id_user1 = p_user_id OR id_user2 = p_user_id);
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;
