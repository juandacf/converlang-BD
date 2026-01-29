CREATE OR REPLACE FUNCTION generate_session_id()
RETURNS VARCHAR AS
$$
DECLARE
    v_date_part VARCHAR;
    v_count INTEGER;
    v_session_id VARCHAR;
BEGIN
    -- Formato: SES_YYYYMMDD_###
    v_date_part := 'SES_' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD');
    
    -- Contar sesiones del día
    SELECT COUNT(*) INTO v_count
    FROM sessions
    WHERE session_id LIKE v_date_part || '%';
    
    v_count := v_count + 1;
    v_session_id := v_date_part || '_' || LPAD(v_count::TEXT, 3, '0');
    
    RETURN v_session_id;
END;
$$ LANGUAGE plpgsql;

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
    v_session_id VARCHAR;
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

    IF p_end_time - p_start_time > INTERVAL '8 hours' THEN
        RAISE EXCEPTION 'La duración de la sesión no puede exceder 8 horas.';
    END IF;

    -- ============================
    -- CREAR SESIÓN
    -- ============================
    v_session_id := generate_session_id();

    INSERT INTO sessions (
        session_id,
        id_user1,
        id_user2,
        start_time,
        end_time,
        session_notes
    )
    VALUES (
        v_session_id,
        p_id_user1,
        p_id_user2,
        p_start_time,
        p_end_time,
        p_session_notes
    );

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
    p_session_id VARCHAR,
    p_start_time TIMESTAMP,
    p_end_time TIMESTAMP DEFAULT NULL,
    p_session_status VARCHAR DEFAULT 'scheduled',
    p_session_notes TEXT DEFAULT NULL,
    p_language_used VARCHAR DEFAULT NULL
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_language_upper VARCHAR;
    v_status_lower VARCHAR;
    v_current_status VARCHAR;
    v_id_user1 INTEGER;
    v_id_user2 INTEGER;
BEGIN
    -- ============================
    -- VERIFICAR EXISTENCIA DE LA SESIÓN
    -- ============================
    SELECT EXISTS(SELECT 1 FROM sessions WHERE session_id = p_session_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe una sesión con el ID %.', p_session_id;
    END IF;
    
    -- Obtener estado actual y usuarios
    SELECT session_status, id_user1, id_user2 
    INTO v_current_status, v_id_user1, v_id_user2
    FROM sessions 
    WHERE session_id = p_session_id;
    
    -- No permitir actualizar sesiones completadas o canceladas
    IF v_current_status IN ('completed', 'canceled') THEN
        RAISE EXCEPTION 'No se pueden modificar sesiones con estado "%" . Solo se pueden actualizar sesiones con estado "scheduled".', v_current_status;
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE FECHAS
    -- ============================
    IF p_start_time IS NULL THEN
        RAISE EXCEPTION 'La fecha y hora de inicio son obligatorias.';
    END IF;
    
    IF p_end_time IS NOT NULL THEN
        IF p_end_time <= p_start_time THEN
            RAISE EXCEPTION 'La fecha de finalización debe ser posterior a la fecha de inicio.';
        END IF;
        
        IF p_end_time - p_start_time > INTERVAL '8 hours' THEN
            RAISE EXCEPTION 'La duración de la sesión no puede exceder 8 horas.';
        END IF;
    END IF;
    
    -- ============================
    -- VALIDACIÓN Y NORMALIZACIÓN DE SESSION_STATUS
    -- ============================
    v_status_lower := LOWER(COALESCE(p_session_status, 'scheduled'));
    
    IF v_status_lower NOT IN ('scheduled', 'completed', 'canceled', 'no_show') THEN
        RAISE EXCEPTION 'El estado de sesión debe ser: scheduled, completed, canceled o no_show. Estado proporcionado: %.', p_session_status;
    END IF;
    
    -- ============================
    -- VALIDACIÓN Y NORMALIZACIÓN DE LANGUAGE_USED
    -- ============================
    IF p_language_used IS NOT NULL AND LENGTH(TRIM(p_language_used)) > 0 THEN
        v_language_upper := UPPER(p_language_used);
        SELECT EXISTS(SELECT 1 FROM languages WHERE language_code = v_language_upper) INTO v_exists;
        IF NOT v_exists THEN
            RAISE EXCEPTION 'No existe un idioma con el código %.', v_language_upper;
        END IF;
    ELSE
        v_language_upper := NULL;
    END IF;
    
    -- ============================
    -- VALIDAR CONFLICTOS DE HORARIO (solo si se cambia el horario)
    -- ============================
    SELECT EXISTS(
        SELECT 1 FROM sessions
        WHERE session_id <> p_session_id
        AND (id_user1 = v_id_user1 OR id_user2 = v_id_user1 OR id_user1 = v_id_user2 OR id_user2 = v_id_user2)
        AND session_status = 'scheduled'
        AND (
            (p_start_time BETWEEN start_time AND COALESCE(end_time, start_time + INTERVAL '1 hour'))
            OR
            (COALESCE(p_end_time, p_start_time + INTERVAL '1 hour') BETWEEN start_time AND COALESCE(end_time, start_time + INTERVAL '1 hour'))
            OR
            (start_time BETWEEN p_start_time AND COALESCE(p_end_time, p_start_time + INTERVAL '1 hour'))
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
        session_status = v_status_lower,
        session_notes = p_session_notes,
        language_used = v_language_upper,
        updated_at = CURRENT_TIMESTAMP
    WHERE session_id = p_session_id;
    
    RETURN format('Sesión %s actualizada correctamente.', p_session_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: CAMBIAR ESTADO DE SESIÓN
-- ============================
CREATE OR REPLACE FUNCTION update_session_status(
    p_session_id VARCHAR,
    p_session_status VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_status_lower VARCHAR;
BEGIN
    SELECT EXISTS(SELECT 1 FROM sessions WHERE session_id = p_session_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe una sesión con el ID %.', p_session_id;
    END IF;
    
    v_status_lower := LOWER(p_session_status);
    
    IF v_status_lower NOT IN ('scheduled', 'completed', 'canceled', 'no_show') THEN
        RAISE EXCEPTION 'El estado de sesión debe ser: scheduled, completed, canceled o no_show. Estado proporcionado: %.', p_session_status;
    END IF;
    
    UPDATE sessions
    SET
        session_status = v_status_lower,
        updated_at = CURRENT_TIMESTAMP
    WHERE session_id = p_session_id;
    
    RETURN format('Estado de sesión %s actualizado a "%s".', p_session_id, v_status_lower);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: CANCELAR SESIÓN
-- ============================
CREATE OR REPLACE FUNCTION cancel_session(
    p_session_id VARCHAR,
    p_cancel_notes TEXT DEFAULT NULL
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_current_status VARCHAR;
BEGIN
    SELECT session_status INTO v_current_status
    FROM sessions 
    WHERE session_id = p_session_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe una sesión con el ID %.', p_session_id;
    END IF;
    
    IF v_current_status = 'completed' THEN
        RAISE EXCEPTION 'No se puede cancelar una sesión que ya fue completada.';
    END IF;
    
    IF v_current_status = 'canceled' THEN
        RAISE EXCEPTION 'La sesión ya está cancelada.';
    END IF;
    
    UPDATE sessions
    SET
        session_status = 'canceled',
        session_notes = COALESCE(p_cancel_notes, session_notes),
        updated_at = CURRENT_TIMESTAMP
    WHERE session_id = p_session_id;
    
    RETURN format('Sesión %s cancelada correctamente.', p_session_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: COMPLETAR SESIÓN
-- ============================
CREATE OR REPLACE FUNCTION complete_session(
    p_session_id VARCHAR,
    p_completion_notes TEXT DEFAULT NULL
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_current_status VARCHAR;
BEGIN
    SELECT session_status INTO v_current_status
    FROM sessions 
    WHERE session_id = p_session_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe una sesión con el ID %.', p_session_id;
    END IF;
    
    IF v_current_status = 'canceled' THEN
        RAISE EXCEPTION 'No se puede completar una sesión cancelada.';
    END IF;
    
    IF v_current_status = 'completed' THEN
        RAISE EXCEPTION 'La sesión ya está completada.';
    END IF;
    
    UPDATE sessions
    SET
        session_status = 'completed',
        session_notes = COALESCE(p_completion_notes, session_notes),
        updated_at = CURRENT_TIMESTAMP
    WHERE session_id = p_session_id;
    
    RETURN format('Sesión %s completada correctamente.', p_session_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR SESIÓN
-- ============================
CREATE OR REPLACE FUNCTION delete_session(
    p_session_id VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_current_status VARCHAR;
BEGIN
    SELECT session_status INTO v_current_status
    FROM sessions 
    WHERE session_id = p_session_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe una sesión con el ID %.', p_session_id;
    END IF;
    
    -- Solo permitir eliminar sesiones canceladas o que no se realizaron
    IF v_current_status NOT IN ('canceled', 'no_show') THEN
        RAISE EXCEPTION 'Solo se pueden eliminar sesiones con estado "canceled" o "no_show". Estado actual: %.', v_current_status;
    END IF;
    
    BEGIN
        DELETE FROM sessions WHERE session_id = p_session_id;
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE EXCEPTION 'No se puede eliminar la sesión % porque tiene registros asociados.', p_session_id;
    END;
    
    RETURN format('Sesión %s eliminada correctamente.', p_session_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER TODAS LAS SESIONES
-- ============================
CREATE OR REPLACE FUNCTION get_all_sessions(
    p_status_filter VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    session_id VARCHAR,
    id_user1 INTEGER,
    id_user2 INTEGER,
    session_type VARCHAR,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    session_status VARCHAR,
    session_notes TEXT,
    language_used VARCHAR,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    created_by INTEGER
)
AS
$$
DECLARE
    v_status_lower VARCHAR;
BEGIN
    IF p_status_filter IS NOT NULL THEN
        v_status_lower := LOWER(p_status_filter);
        RETURN QUERY
        SELECT
            s.session_id, s.id_user1, s.id_user2,
            s.start_time, s.end_time, s.session_status, s.session_notes,
            s.language_used, s.created_at, s.updated_at, s.created_by
        FROM sessions s
        WHERE s.session_status = v_status_lower
        ORDER BY s.start_time DESC;
    ELSE
        RETURN QUERY
        SELECT
            s.session_id, s.id_user1, s.id_user2,
            s.start_time, s.end_time, s.session_status, s.session_notes,
            s.language_used, s.created_at, s.updated_at, s.created_by
        FROM sessions s
        ORDER BY s.start_time DESC;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER SESIÓN POR ID
-- ============================
CREATE OR REPLACE FUNCTION get_session_by_id(
    p_session_id VARCHAR
)
RETURNS TABLE (
    session_id VARCHAR,
    id_user1 INTEGER,
    id_user2 INTEGER,
    session_type VARCHAR,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    session_status VARCHAR,
    session_notes TEXT,
    language_used VARCHAR,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    created_by INTEGER
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        s.session_id, s.id_user1, s.id_user2,
        s.start_time, s.end_time, s.session_status, s.session_notes,
        s.language_used, s.created_at, s.updated_at, s.created_by
    FROM sessions s
    WHERE s.session_id = p_session_id;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER SESIONES DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_user_sessions(
    p_user_id INTEGER,
    p_status_filter VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    session_id VARCHAR,
    id_user1 INTEGER,
    id_user2 INTEGER,
    session_type VARCHAR,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    session_status VARCHAR,
    session_notes TEXT,
    language_used VARCHAR,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    created_by INTEGER
)
AS
$$
DECLARE
    v_status_lower VARCHAR;
BEGIN
    IF p_status_filter IS NOT NULL THEN
        v_status_lower := LOWER(p_status_filter);
        RETURN QUERY
        SELECT
            s.session_id, s.id_user1, s.id_user2,
            s.start_time, s.end_time, s.session_status, s.session_notes,
            s.language_used, s.created_at, s.updated_at, s.created_by
        FROM sessions s
        WHERE (s.id_user1 = p_user_id OR s.id_user2 = p_user_id)
        AND s.session_status = v_status_lower
        ORDER BY s.start_time DESC;
    ELSE
        RETURN QUERY
        SELECT
            s.session_id, s.id_user1, s.id_user2,
            s.start_time, s.end_time, s.session_status, s.session_notes,
            s.language_used, s.created_at, s.updated_at, s.created_by
        FROM sessions s
        WHERE (s.id_user1 = p_user_id OR s.id_user2 = p_user_id)
        ORDER BY s.start_time DESC;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER PRÓXIMAS SESIONES DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_upcoming_user_sessions(
    p_user_id INTEGER
)
RETURNS TABLE (
    session_id VARCHAR,
    id_user1 INTEGER,
    id_user2 INTEGER,
    session_type VARCHAR,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    session_status VARCHAR,
    session_notes TEXT,
    language_used VARCHAR,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    created_by INTEGER
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        s.session_id, s.id_user1, s.id_user2,
        s.start_time, s.end_time, s.session_status, s.session_notes,
        s.language_used, s.created_at, s.updated_at, s.created_by
    FROM sessions s
    WHERE (s.id_user1 = p_user_id OR s.id_user2 = p_user_id)
    AND s.session_status = 'scheduled'
    AND s.start_time > CURRENT_TIMESTAMP
    ORDER BY s.start_time ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER SESIONES POR TIPO
-- ============================
CREATE OR REPLACE FUNCTION get_sessions_by_type(
    p_session_type VARCHAR,
    p_status_filter VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    session_id VARCHAR,
    id_user1 INTEGER,
    id_user2 INTEGER,
    session_type VARCHAR,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    session_status VARCHAR,
    session_notes TEXT,
    language_used VARCHAR,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    created_by INTEGER
)
AS
$$
DECLARE
    v_type_lower VARCHAR;
    v_status_lower VARCHAR;
BEGIN
    v_type_lower := LOWER(p_session_type);
    
    IF p_status_filter IS NOT NULL THEN
        v_status_lower := LOWER(p_status_filter);
        RETURN QUERY
        SELECT
            s.session_id, s.id_user1, s.id_user2,
            s.start_time, s.end_time, s.session_status, s.session_notes,
            s.language_used, s.created_at, s.updated_at, s.created_by
        FROM sessions s
        WHERE s.session_type = v_type_lower
        AND s.session_status = v_status_lower
        ORDER BY s.start_time DESC;
    ELSE
        RETURN QUERY
        SELECT
            s.session_id, s.id_user1, s.id_user2,
            s.start_time, s.end_time, s.session_status, s.session_notes,
            s.language_used, s.created_at, s.updated_at, s.created_by
        FROM sessions s
        WHERE s.session_type = v_type_lower
        ORDER BY s.start_time DESC;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_user_sessions_last_month(p_user_id INTEGER)
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
        SELECT 'Day 0'  AS name, COUNT(*) FILTER (WHERE days_ago = 0)               AS sesiones FROM sessions_filtered
        UNION ALL
        SELECT 'Day 10' AS name, COUNT(*) FILTER (WHERE days_ago BETWEEN 1 AND 10)  AS sesiones FROM sessions_filtered
        UNION ALL
        SELECT 'Day 20' AS name, COUNT(*) FILTER (WHERE days_ago BETWEEN 11 AND 20) AS sesiones FROM sessions_filtered
        UNION ALL
        SELECT 'Day 30' AS name, COUNT(*) FILTER (WHERE days_ago BETWEEN 21 AND 30) AS sesiones FROM sessions_filtered
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'name', name,
            'sesiones', sesiones
        )
        ORDER BY
            CASE name
                WHEN 'Day 0' THEN 0
                WHEN 'Day 10' THEN 1
                WHEN 'Day 20' THEN 2
                WHEN 'Day 30' THEN 3
            END
    )
    INTO result
    FROM buckets;

    RETURN result;
END;
$$;
