-- ============================
-- FUNCIÓN: CREAR/INICIALIZAR PROGRESO DE USUARIO
-- ============================
CREATE OR REPLACE FUNCTION initialize_user_progress(
    p_user_id INTEGER,
    p_language_id VARCHAR,
    p_notes TEXT DEFAULT NULL
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_user_active BOOLEAN;
    v_language_upper VARCHAR;
BEGIN
    -- ============================
    -- VALIDACIONES BÁSICAS
    -- ============================
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'El ID del usuario no puede estar vacío.';
    END IF;
    
    IF p_language_id IS NULL OR LENGTH(TRIM(p_language_id)) = 0 THEN
        RAISE EXCEPTION 'El código del idioma no puede estar vacío.';
    END IF;
    
    v_language_upper := UPPER(p_language_id);
    
    -- ============================
    -- VERIFICAR EXISTENCIA DEL USUARIO
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
    -- VERIFICAR EXISTENCIA DEL IDIOMA
    -- ============================
    SELECT EXISTS(SELECT 1 FROM languages WHERE language_code = v_language_upper) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un idioma con el código %.', v_language_upper;
    END IF;
    
    -- ============================
    -- VERIFICAR SI YA EXISTE PROGRESO
    -- ============================
    SELECT EXISTS(
        SELECT 1 FROM user_progress 
        WHERE user_id = p_user_id 
        AND language_id = v_language_upper
    ) INTO v_exists;
    
    IF v_exists THEN
        RAISE EXCEPTION 'Ya existe un registro de progreso para el usuario % en el idioma %.', p_user_id, v_language_upper;
    END IF;
    
    -- ============================
    -- CREAR REGISTRO DE PROGRESO
    -- ============================
    INSERT INTO user_progress (user_id, language_id, notes)
    VALUES (p_user_id, v_language_upper, p_notes);
    
    RETURN format('Progreso inicializado para usuario %s en idioma %s.', p_user_id, v_language_upper);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ACTUALIZAR PROGRESO MANUALMENTE
-- ============================
CREATE OR REPLACE FUNCTION update_user_progress(
    p_user_id INTEGER,
    p_language_id VARCHAR,
    p_total_sessions INTEGER DEFAULT NULL,
    p_total_hours DECIMAL DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_language_upper VARCHAR;
BEGIN
    -- ============================
    -- VALIDACIONES
    -- ============================
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'El ID del usuario no puede estar vacío.';
    END IF;
    
    v_language_upper := UPPER(p_language_id);
    
    -- Verificar existencia del registro
    SELECT EXISTS(
        SELECT 1 FROM user_progress 
        WHERE user_id = p_user_id 
        AND language_id = v_language_upper
    ) INTO v_exists;
    
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un registro de progreso para el usuario % en el idioma %.', p_user_id, v_language_upper;
    END IF;
    
    -- Validar valores no negativos
    IF p_total_sessions IS NOT NULL AND p_total_sessions < 0 THEN
        RAISE EXCEPTION 'El total de sesiones no puede ser negativo.';
    END IF;
    
    IF p_total_hours IS NOT NULL AND p_total_hours < 0 THEN
        RAISE EXCEPTION 'El total de horas no puede ser negativo.';
    END IF;
    
    IF p_total_hours IS NOT NULL AND p_total_hours > 9999.99 THEN
        RAISE EXCEPTION 'El total de horas excede el límite permitido (9999.99).';
    END IF;
    
    -- ============================
    -- ACTUALIZAR PROGRESO
    -- ============================
    UPDATE user_progress
    SET
        total_sessions = COALESCE(p_total_sessions, total_sessions),
        total_hours = COALESCE(p_total_hours, total_hours),
        notes = COALESCE(p_notes, notes),
        last_updated = CURRENT_TIMESTAMP
    WHERE user_id = p_user_id
    AND language_id = v_language_upper;
    
    RETURN format('Progreso actualizado para usuario %s en idioma %s.', p_user_id, v_language_upper);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: INCREMENTAR SESIONES Y HORAS
-- ============================
CREATE OR REPLACE FUNCTION increment_user_progress(
    p_user_id INTEGER,
    p_language_id VARCHAR,
    p_session_duration_hours DECIMAL DEFAULT 1.0
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_language_upper VARCHAR;
BEGIN
    v_language_upper := UPPER(p_language_id);
    
    -- Validar duración
    IF p_session_duration_hours <= 0 THEN
        RAISE EXCEPTION 'La duración de la sesión debe ser mayor a 0.';
    END IF;
    
    IF p_session_duration_hours > 24 THEN
        RAISE EXCEPTION 'La duración de la sesión no puede exceder 24 horas.';
    END IF;
    
    -- Verificar existencia del registro
    SELECT EXISTS(
        SELECT 1 FROM user_progress 
        WHERE user_id = p_user_id 
        AND language_id = v_language_upper
    ) INTO v_exists;
    
    IF NOT v_exists THEN
        -- Crear registro automáticamente si no existe
        INSERT INTO user_progress (user_id, language_id, total_sessions, total_hours)
        VALUES (p_user_id, v_language_upper, 1, p_session_duration_hours);
        
        RETURN format('Progreso creado e incrementado para usuario %s en idioma %s: +1 sesión, +%s horas.', 
                      p_user_id, v_language_upper, p_session_duration_hours);
    ELSE
        -- Incrementar valores existentes
        UPDATE user_progress
        SET
            total_sessions = total_sessions + 1,
            total_hours = total_hours + p_session_duration_hours,
            last_updated = CURRENT_TIMESTAMP
        WHERE user_id = p_user_id
        AND language_id = v_language_upper;
        
        RETURN format('Progreso incrementado para usuario %s en idioma %s: +1 sesión, +%s horas.', 
                      p_user_id, v_language_upper, p_session_duration_hours);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ACTUALIZAR NOTAS DE PROGRESO
-- ============================
CREATE OR REPLACE FUNCTION update_progress_notes(
    p_user_id INTEGER,
    p_language_id VARCHAR,
    p_notes TEXT
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_language_upper VARCHAR;
BEGIN
    v_language_upper := UPPER(p_language_id);
    
    SELECT EXISTS(
        SELECT 1 FROM user_progress 
        WHERE user_id = p_user_id 
        AND language_id = v_language_upper
    ) INTO v_exists;
    
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un registro de progreso para el usuario % en el idioma %.', p_user_id, v_language_upper;
    END IF;
    
    UPDATE user_progress
    SET
        notes = p_notes,
        last_updated = CURRENT_TIMESTAMP
    WHERE user_id = p_user_id
    AND language_id = v_language_upper;
    
    RETURN format('Notas actualizadas para usuario %s en idioma %s.', p_user_id, v_language_upper);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR REGISTRO DE PROGRESO
-- ============================
CREATE OR REPLACE FUNCTION delete_user_progress(
    p_user_id INTEGER,
    p_language_id VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_language_upper VARCHAR;
BEGIN
    v_language_upper := UPPER(p_language_id);
    
    SELECT EXISTS(
        SELECT 1 FROM user_progress 
        WHERE user_id = p_user_id 
        AND language_id = v_language_upper
    ) INTO v_exists;
    
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un registro de progreso para el usuario % en el idioma %.', p_user_id, v_language_upper;
    END IF;
    
    DELETE FROM user_progress
    WHERE user_id = p_user_id
    AND language_id = v_language_upper;
    
    RETURN format('Registro de progreso eliminado para usuario %s en idioma %s.', p_user_id, v_language_upper);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER PROGRESO DE UN USUARIO EN UN IDIOMA
-- ============================
CREATE OR REPLACE FUNCTION get_user_progress(
    p_user_id INTEGER,
    p_language_id VARCHAR
)
RETURNS TABLE (
    user_id INTEGER,
    language_id VARCHAR,
    last_updated TIMESTAMP,
    total_sessions INTEGER,
    total_hours DECIMAL,
    notes TEXT
)
AS
$$
DECLARE
    v_language_upper VARCHAR;
BEGIN
    v_language_upper := UPPER(p_language_id);
    
    RETURN QUERY
    SELECT
        up.user_id,
        up.language_id,
        up.last_updated,
        up.total_sessions,
        up.total_hours,
        up.notes
    FROM user_progress up
    WHERE up.user_id = p_user_id
    AND up.language_id = v_language_upper;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER TODO EL PROGRESO DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_all_user_progress(
    p_user_id INTEGER
)
RETURNS TABLE (
    user_id INTEGER,
    language_id VARCHAR,
    language_name VARCHAR,
    last_updated TIMESTAMP,
    total_sessions INTEGER,
    total_hours DECIMAL,
    average_hours_per_session DECIMAL,
    notes TEXT
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        up.user_id,
        up.language_id,
        l.language_name,
        up.last_updated,
        up.total_sessions,
        up.total_hours,
        CASE 
            WHEN up.total_sessions > 0 
            THEN ROUND(up.total_hours / up.total_sessions, 2)
            ELSE 0
        END as average_hours_per_session,
        up.notes
    FROM user_progress up
    INNER JOIN languages l ON up.language_id = l.language_code
    WHERE up.user_id = p_user_id
    ORDER BY up.total_hours DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER RANKING DE USUARIOS POR IDIOMA
-- ============================
CREATE OR REPLACE FUNCTION get_language_progress_ranking(
    p_language_id VARCHAR,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    rank INTEGER,
    user_id INTEGER,
    user_name VARCHAR,
    total_sessions INTEGER,
    total_hours DECIMAL,
    average_hours_per_session DECIMAL,
    last_updated TIMESTAMP
)
AS
$$
DECLARE
    v_language_upper VARCHAR;
BEGIN
    v_language_upper := UPPER(p_language_id);
    
    RETURN QUERY
    SELECT
        ROW_NUMBER() OVER (ORDER BY up.total_hours DESC, up.total_sessions DESC)::INTEGER as rank,
        up.user_id,
        (u.first_name || ' ' || u.last_name)::VARCHAR as user_name,
        up.total_sessions,
        up.total_hours,
        CASE 
            WHEN up.total_sessions > 0 
            THEN ROUND(up.total_hours / up.total_sessions, 2)
            ELSE 0
        END as average_hours_per_session,
        up.last_updated
    FROM user_progress up
    INNER JOIN users u ON up.user_id = u.id_user
    WHERE up.language_id = v_language_upper
    AND u.is_active = TRUE
    ORDER BY rank
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER ESTADÍSTICAS GLOBALES DE PROGRESO DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_user_progress_summary(
    p_user_id INTEGER
)
RETURNS TABLE (
    user_id INTEGER,
    total_languages INTEGER,
    total_sessions_all_languages INTEGER,
    total_hours_all_languages DECIMAL,
    average_hours_per_session DECIMAL,
    most_studied_language VARCHAR,
    most_studied_language_hours DECIMAL,
    last_activity TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        p_user_id as user_id,
        COUNT(DISTINCT up.language_id)::INTEGER as total_languages,
        SUM(up.total_sessions)::INTEGER as total_sessions_all_languages,
        ROUND(SUM(up.total_hours), 2) as total_hours_all_languages,
        CASE 
            WHEN SUM(up.total_sessions) > 0 
            THEN ROUND(SUM(up.total_hours) / SUM(up.total_sessions), 2)
            ELSE 0
        END as average_hours_per_session,
        (SELECT language_id FROM user_progress 
         WHERE user_id = p_user_id 
         ORDER BY total_hours DESC 
         LIMIT 1) as most_studied_language,
        (SELECT total_hours FROM user_progress 
         WHERE user_id = p_user_id 
         ORDER BY total_hours DESC 
         LIMIT 1) as most_studied_language_hours,
        MAX(up.last_updated) as last_activity
    FROM user_progress up
    WHERE up.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER USUARIOS MÁS ACTIVOS (GLOBAL)
-- ============================
CREATE OR REPLACE FUNCTION get_most_active_users(
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    rank INTEGER,
    user_id INTEGER,
    user_name VARCHAR,
    total_languages INTEGER,
    total_sessions INTEGER,
    total_hours DECIMAL,
    last_activity TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        ROW_NUMBER() OVER (ORDER BY SUM(up.total_hours) DESC, SUM(up.total_sessions) DESC)::INTEGER as rank,
        up.user_id,
        (u.first_name || ' ' || u.last_name)::VARCHAR as user_name,
        COUNT(DISTINCT up.language_id)::INTEGER as total_languages,
        SUM(up.total_sessions)::INTEGER as total_sessions,
        ROUND(SUM(up.total_hours), 2) as total_hours,
        MAX(up.last_updated) as last_activity
    FROM user_progress up
    INNER JOIN users u ON up.user_id = u.id_user
    WHERE u.is_active = TRUE
    GROUP BY up.user_id, u.first_name, u.last_name
    ORDER BY rank
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER IDIOMAS MÁS ESTUDIADOS
-- ============================
CREATE OR REPLACE FUNCTION get_most_studied_languages(
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    rank INTEGER,
    language_id VARCHAR,
    language_name VARCHAR,
    total_users INTEGER,
    total_sessions INTEGER,
    total_hours DECIMAL,
    average_hours_per_user DECIMAL
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        ROW_NUMBER() OVER (ORDER BY SUM(up.total_hours) DESC, COUNT(DISTINCT up.user_id) DESC)::INTEGER as rank,
        up.language_id,
        l.language_name,
        COUNT(DISTINCT up.user_id)::INTEGER as total_users,
        SUM(up.total_sessions)::INTEGER as total_sessions,
        ROUND(SUM(up.total_hours), 2) as total_hours,
        ROUND(SUM(up.total_hours) / COUNT(DISTINCT up.user_id), 2) as average_hours_per_user
    FROM user_progress up
    INNER JOIN languages l ON up.language_id = l.language_code
    GROUP BY up.language_id, l.language_name
    ORDER BY rank
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: COMPARAR PROGRESO ENTRE DOS USUARIOS
-- ============================
CREATE OR REPLACE FUNCTION compare_user_progress(
    p_user1_id INTEGER,
    p_user2_id INTEGER
)
RETURNS TABLE (
    language_id VARCHAR,
    language_name VARCHAR,
    user1_sessions INTEGER,
    user1_hours DECIMAL,
    user2_sessions INTEGER,
    user2_hours DECIMAL,
    sessions_difference INTEGER,
    hours_difference DECIMAL
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(up1.language_id, up2.language_id) as language_id,
        l.language_name,
        COALESCE(up1.total_sessions, 0)::INTEGER as user1_sessions,
        COALESCE(up1.total_hours, 0) as user1_hours,
        COALESCE(up2.total_sessions, 0)::INTEGER as user2_sessions,
        COALESCE(up2.total_hours, 0) as user2_hours,
        (COALESCE(up1.total_sessions, 0) - COALESCE(up2.total_sessions, 0))::INTEGER as sessions_difference,
        ROUND(COALESCE(up1.total_hours, 0) - COALESCE(up2.total_hours, 0), 2) as hours_difference
    FROM user_progress up1
    FULL OUTER JOIN user_progress up2 
        ON up1.language_id = up2.language_id 
        AND up2.user_id = p_user2_id
    INNER JOIN languages l ON COALESCE(up1.language_id, up2.language_id) = l.language_code
    WHERE up1.user_id = p_user1_id OR up2.user_id = p_user2_id
    ORDER BY GREATEST(COALESCE(up1.total_hours, 0), COALESCE(up2.total_hours, 0)) DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER PROGRESO RECIENTE (ÚLTIMA ACTIVIDAD)
-- ============================
CREATE OR REPLACE FUNCTION get_recent_progress_activity(
    p_days INTEGER DEFAULT 7,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    user_id INTEGER,
    user_name VARCHAR,
    language_id VARCHAR,
    language_name VARCHAR,
    total_sessions INTEGER,
    total_hours DECIMAL,
    last_updated TIMESTAMP,
    days_since_update INTEGER
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        up.user_id,
        (u.first_name || ' ' || u.last_name)::VARCHAR as user_name,
        up.language_id,
        l.language_name,
        up.total_sessions,
        up.total_hours,
        up.last_updated,
        EXTRACT(DAY FROM (CURRENT_TIMESTAMP - up.last_updated))::INTEGER as days_since_update
    FROM user_progress up
    INNER JOIN users u ON up.user_id = u.id_user
    INNER JOIN languages l ON up.language_id = l.language_code
    WHERE up.last_updated >= CURRENT_TIMESTAMP - (p_days || ' days')::INTERVAL
    AND u.is_active = TRUE
    ORDER BY up.last_updated DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: RESETEAR PROGRESO DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION reset_user_progress(
    p_user_id INTEGER,
    p_language_id VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_language_upper VARCHAR;
BEGIN
    v_language_upper := UPPER(p_language_id);
    
    SELECT EXISTS(
        SELECT 1 FROM user_progress 
        WHERE user_id = p_user_id 
        AND language_id = v_language_upper
    ) INTO v_exists;
    
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un registro de progreso para el usuario % en el idioma %.', p_user_id, v_language_upper;
    END IF;
    
    UPDATE user_progress
    SET
        total_sessions = 0,
        total_hours = 0,
        notes = NULL,
        last_updated = CURRENT_TIMESTAMP
    WHERE user_id = p_user_id
    AND language_id = v_language_upper;
    
    RETURN format('Progreso reseteado para usuario %s en idioma %s.', p_user_id, v_language_upper);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR TODO EL PROGRESO DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION delete_all_user_progress(
    p_user_id INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM user_progress
    WHERE user_id = p_user_id;
    
    DELETE FROM user_progress WHERE user_id = p_user_id;
    
    RETURN format('Eliminados %s registros de progreso del usuario %s.', v_count, p_user_id);
END;
$$ LANGUAGE plpgsql;