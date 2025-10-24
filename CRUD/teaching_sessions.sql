-- ============================
-- FUNCIÓN: CREAR SESIÓN DE ENSEÑANZA
-- ============================
CREATE OR REPLACE FUNCTION add_teaching_session(
    p_session_id VARCHAR,
    p_teacher_profile_id INTEGER,
    p_student_id INTEGER,
    p_session_cost DECIMAL DEFAULT NULL,
    p_teacher_notes TEXT DEFAULT NULL,
    p_student_rating INTEGER DEFAULT NULL,
    p_teacher_rating INTEGER DEFAULT NULL,
    p_homework_assigned TEXT DEFAULT NULL,
    p_homework_completed BOOLEAN DEFAULT FALSE
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_session_type VARCHAR;
    v_session_user1 INTEGER;
    v_session_user2 INTEGER;
    v_teacher_verified BOOLEAN;
    v_teacher_hourly_rate DECIMAL;
BEGIN
    -- ============================
    -- VALIDACIÓN DE SESSION_ID
    -- ============================
    IF p_session_id IS NULL OR LENGTH(TRIM(p_session_id)) = 0 THEN
        RAISE EXCEPTION 'El ID de la sesión no puede estar vacío.';
    END IF;
    
    -- Verificar que la sesión exista
    SELECT session_type, id_user1, id_user2 
    INTO v_session_type, v_session_user1, v_session_user2
    FROM sessions 
    WHERE session_id = p_session_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe una sesión con el ID %.', p_session_id;
    END IF;
    
    -- Verificar que la sesión sea de tipo 'teaching'
    IF v_session_type <> 'teaching' THEN
        RAISE EXCEPTION 'La sesión % no es de tipo "teaching". Tipo actual: %.', p_session_id, v_session_type;
    END IF;
    
    -- Verificar que no exista ya un registro para esta sesión
    SELECT EXISTS(SELECT 1 FROM teaching_sessions WHERE session_id = p_session_id) INTO v_exists;
    IF v_exists THEN
        RAISE EXCEPTION 'Ya existe un registro de enseñanza para la sesión %.', p_session_id;
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE TEACHER_PROFILE_ID
    -- ============================
    IF p_teacher_profile_id IS NULL THEN
        RAISE EXCEPTION 'El ID del perfil del profesor no puede estar vacío.';
    END IF;
    
    -- Verificar que el perfil de profesor exista
    SELECT is_verified, hourly_rate 
    INTO v_teacher_verified, v_teacher_hourly_rate
    FROM teacher_profiles 
    WHERE user_id = p_teacher_profile_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe un perfil de profesor con el ID %.', p_teacher_profile_id;
    END IF;
    
    -- Verificar que el profesor esté verificado
    IF NOT v_teacher_verified THEN
        RAISE EXCEPTION 'El perfil del profesor (ID: %) no está verificado.', p_teacher_profile_id;
    END IF;
    
    -- Verificar que el profesor sea uno de los participantes de la sesión
    IF p_teacher_profile_id <> v_session_user1 AND p_teacher_profile_id <> v_session_user2 THEN
        RAISE EXCEPTION 'El profesor (ID: %) no es participante de la sesión %.', p_teacher_profile_id, p_session_id;
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE STUDENT_ID
    -- ============================
    IF p_student_id IS NULL THEN
        RAISE EXCEPTION 'El ID del estudiante no puede estar vacío.';
    END IF;
    
    -- Verificar que el estudiante exista y esté activo
    SELECT EXISTS(SELECT 1 FROM users WHERE id_user = p_student_id AND is_active = TRUE) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'El estudiante con ID % no existe o no está activo.', p_student_id;
    END IF;
    
    -- Verificar que el estudiante sea el otro participante de la sesión
    IF p_student_id <> v_session_user1 AND p_student_id <> v_session_user2 THEN
        RAISE EXCEPTION 'El estudiante (ID: %) no es participante de la sesión %.', p_student_id, p_session_id;
    END IF;
    
    -- Verificar que profesor y estudiante sean diferentes
    IF p_teacher_profile_id = p_student_id THEN
        RAISE EXCEPTION 'El profesor y el estudiante no pueden ser la misma persona.';
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE COSTO
    -- ============================
    IF p_session_cost IS NOT NULL THEN
        IF p_session_cost < 0 THEN
            RAISE EXCEPTION 'El costo de la sesión no puede ser negativo.';
        ELSIF p_session_cost > 999999.99 THEN
            RAISE EXCEPTION 'El costo de la sesión excede el límite permitido (999999.99).';
        END IF;
    ELSE
        -- Si no se proporciona costo, usar la tarifa por hora del profesor
        p_session_cost := v_teacher_hourly_rate;
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE RATINGS
    -- ============================
    IF p_student_rating IS NOT NULL THEN
        IF p_student_rating < 1 OR p_student_rating > 5 THEN
            RAISE EXCEPTION 'La calificación del estudiante debe estar entre 1 y 5. Valor proporcionado: %.', p_student_rating;
        END IF;
    END IF;
    
    IF p_teacher_rating IS NOT NULL THEN
        IF p_teacher_rating < 1 OR p_teacher_rating > 5 THEN
            RAISE EXCEPTION 'La calificación del profesor debe estar entre 1 y 5. Valor proporcionado: %.', p_teacher_rating;
        END IF;
    END IF;
    
    -- ============================
    -- CREAR REGISTRO
    -- ============================
    INSERT INTO teaching_sessions (
        session_id, teacher_profile_id, student_id, session_cost,
        teacher_notes, student_rating, teacher_rating, homework_assigned,
        homework_completed
    ) VALUES (
        p_session_id, p_teacher_profile_id, p_student_id, p_session_cost,
        p_teacher_notes, p_student_rating, p_teacher_rating, p_homework_assigned,
        p_homework_completed
    );
    
    RETURN format('Registro de sesión de enseñanza creado correctamente para la sesión %.', p_session_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ACTUALIZAR NOTAS Y TAREA DEL PROFESOR
-- ============================
CREATE OR REPLACE FUNCTION update_teacher_session_notes(
    p_session_id VARCHAR,
    p_teacher_notes TEXT DEFAULT NULL,
    p_homework_assigned TEXT DEFAULT NULL
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM teaching_sessions WHERE session_id = p_session_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un registro de enseñanza para la sesión %.', p_session_id;
    END IF;
    
    UPDATE teaching_sessions
    SET
        teacher_notes = COALESCE(p_teacher_notes, teacher_notes),
        homework_assigned = COALESCE(p_homework_assigned, homework_assigned)
    WHERE session_id = p_session_id;
    
    RETURN format('Notas del profesor actualizadas para la sesión %.', p_session_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: MARCAR TAREA COMO COMPLETADA
-- ============================
CREATE OR REPLACE FUNCTION mark_homework_completed(
    p_session_id VARCHAR,
    p_completed BOOLEAN DEFAULT TRUE
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM teaching_sessions WHERE session_id = p_session_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un registro de enseñanza para la sesión %.', p_session_id;
    END IF;
    
    UPDATE teaching_sessions
    SET homework_completed = p_completed
    WHERE session_id = p_session_id;
    
    IF p_completed THEN
        RETURN format('Tarea marcada como completada para la sesión %.', p_session_id);
    ELSE
        RETURN format('Tarea marcada como no completada para la sesión %.', p_session_id);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ACTUALIZAR CALIFICACIÓN DEL ESTUDIANTE AL PROFESOR
-- ============================
CREATE OR REPLACE FUNCTION update_student_rating(
    p_session_id VARCHAR,
    p_student_rating INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_session_status VARCHAR;
BEGIN
    SELECT EXISTS(SELECT 1 FROM teaching_sessions WHERE session_id = p_session_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un registro de enseñanza para la sesión %.', p_session_id;
    END IF;
    
    -- Verificar que la sesión esté completada
    SELECT session_status INTO v_session_status 
    FROM sessions 
    WHERE session_id = p_session_id;
    
    IF v_session_status <> 'completed' THEN
        RAISE EXCEPTION 'Solo se puede calificar sesiones completadas. Estado actual: %.', v_session_status;
    END IF;
    
    IF p_student_rating < 1 OR p_student_rating > 5 THEN
        RAISE EXCEPTION 'La calificación debe estar entre 1 y 5. Valor proporcionado: %.', p_student_rating;
    END IF;
    
    UPDATE teaching_sessions
    SET student_rating = p_student_rating
    WHERE session_id = p_session_id;
    
    RETURN format('Calificación del estudiante actualizada para la sesión %.', p_session_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ACTUALIZAR CALIFICACIÓN DEL PROFESOR AL ESTUDIANTE
-- ============================
CREATE OR REPLACE FUNCTION update_teacher_rating(
    p_session_id VARCHAR,
    p_teacher_rating INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_session_status VARCHAR;
BEGIN
    SELECT EXISTS(SELECT 1 FROM teaching_sessions WHERE session_id = p_session_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un registro de enseñanza para la sesión %.', p_session_id;
    END IF;
    
    -- Verificar que la sesión esté completada
    SELECT session_status INTO v_session_status 
    FROM sessions 
    WHERE session_id = p_session_id;
    
    IF v_session_status <> 'completed' THEN
        RAISE EXCEPTION 'Solo se puede calificar sesiones completadas. Estado actual: %.', v_session_status;
    END IF;
    
    IF p_teacher_rating < 1 OR p_teacher_rating > 5 THEN
        RAISE EXCEPTION 'La calificación debe estar entre 1 y 5. Valor proporcionado: %.', p_teacher_rating;
    END IF;
    
    UPDATE teaching_sessions
    SET teacher_rating = p_teacher_rating
    WHERE session_id = p_session_id;
    
    RETURN format('Calificación del profesor actualizada para la sesión %.', p_session_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ACTUALIZAR SESIÓN DE ENSEÑANZA COMPLETA
-- ============================
CREATE OR REPLACE FUNCTION update_teaching_session(
    p_session_id VARCHAR,
    p_session_cost DECIMAL DEFAULT NULL,
    p_teacher_notes TEXT DEFAULT NULL,
    p_student_rating INTEGER DEFAULT NULL,
    p_teacher_rating INTEGER DEFAULT NULL,
    p_homework_assigned TEXT DEFAULT NULL,
    p_homework_completed BOOLEAN DEFAULT NULL
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM teaching_sessions WHERE session_id = p_session_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un registro de enseñanza para la sesión %.', p_session_id;
    END IF;
    
    -- Validaciones
    IF p_session_cost IS NOT NULL THEN
        IF p_session_cost < 0 THEN
            RAISE EXCEPTION 'El costo de la sesión no puede ser negativo.';
        ELSIF p_session_cost > 999999.99 THEN
            RAISE EXCEPTION 'El costo de la sesión excede el límite permitido (999999.99).';
        END IF;
    END IF;
    
    IF p_student_rating IS NOT NULL THEN
        IF p_student_rating < 1 OR p_student_rating > 5 THEN
            RAISE EXCEPTION 'La calificación del estudiante debe estar entre 1 y 5. Valor proporcionado: %.', p_student_rating;
        END IF;
    END IF;
    
    IF p_teacher_rating IS NOT NULL THEN
        IF p_teacher_rating < 1 OR p_teacher_rating > 5 THEN
            RAISE EXCEPTION 'La calificación del profesor debe estar entre 1 y 5. Valor proporcionado: %.', p_teacher_rating;
        END IF;
    END IF;
    
    UPDATE teaching_sessions
    SET
        session_cost = COALESCE(p_session_cost, session_cost),
        teacher_notes = COALESCE(p_teacher_notes, teacher_notes),
        student_rating = COALESCE(p_student_rating, student_rating),
        teacher_rating = COALESCE(p_teacher_rating, teacher_rating),
        homework_assigned = COALESCE(p_homework_assigned, homework_assigned),
        homework_completed = COALESCE(p_homework_completed, homework_completed)
    WHERE session_id = p_session_id;
    
    RETURN format('Registro de enseñanza actualizado para la sesión %.', p_session_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR SESIÓN DE ENSEÑANZA
-- ============================
CREATE OR REPLACE FUNCTION delete_teaching_session(
    p_session_id VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM teaching_sessions WHERE session_id = p_session_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un registro de enseñanza para la sesión %.', p_session_id;
    END IF;
    
    DELETE FROM teaching_sessions WHERE session_id = p_session_id;
    
    RETURN format('Registro de enseñanza eliminado para la sesión %.', p_session_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER TODAS LAS SESIONES DE ENSEÑANZA
-- ============================
CREATE OR REPLACE FUNCTION get_all_teaching_sessions()
RETURNS TABLE (
    session_id VARCHAR,
    teacher_profile_id INTEGER,
    student_id INTEGER,
    session_cost DECIMAL,
    teacher_notes TEXT,
    student_rating INTEGER,
    teacher_rating INTEGER,
    homework_assigned TEXT,
    homework_completed BOOLEAN
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        ts.session_id,
        ts.teacher_profile_id,
        ts.student_id,
        ts.session_cost,
        ts.teacher_notes,
        ts.student_rating,
        ts.teacher_rating,
        ts.homework_assigned,
        ts.homework_completed
    FROM teaching_sessions ts
    ORDER BY ts.session_id DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER SESIÓN DE ENSEÑANZA POR ID
-- ============================
CREATE OR REPLACE FUNCTION get_teaching_session_by_id(
    p_session_id VARCHAR
)
RETURNS TABLE (
    session_id VARCHAR,
    teacher_profile_id INTEGER,
    student_id INTEGER,
    session_cost DECIMAL,
    teacher_notes TEXT,
    student_rating INTEGER,
    teacher_rating INTEGER,
    homework_assigned TEXT,
    homework_completed BOOLEAN
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        ts.session_id,
        ts.teacher_profile_id,
        ts.student_id,
        ts.session_cost,
        ts.teacher_notes,
        ts.student_rating,
        ts.teacher_rating,
        ts.homework_assigned,
        ts.homework_completed
    FROM teaching_sessions ts
    WHERE ts.session_id = p_session_id;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER SESIONES DE ENSEÑANZA DE UN PROFESOR
-- ============================
CREATE OR REPLACE FUNCTION get_teacher_sessions(
    p_teacher_id INTEGER,
    p_completed_only BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    session_id VARCHAR,
    student_id INTEGER,
    session_cost DECIMAL,
    teacher_notes TEXT,
    student_rating INTEGER,
    teacher_rating INTEGER,
    homework_assigned TEXT,
    homework_completed BOOLEAN,
    start_time TIMESTAMP,
    session_status VARCHAR
)
AS
$$
BEGIN
    IF p_completed_only THEN
        RETURN QUERY
        SELECT
            ts.session_id,
            ts.student_id,
            ts.session_cost,
            ts.teacher_notes,
            ts.student_rating,
            ts.teacher_rating,
            ts.homework_assigned,
            ts.homework_completed,
            s.start_time,
            s.session_status
        FROM teaching_sessions ts
        INNER JOIN sessions s ON ts.session_id = s.session_id
        WHERE ts.teacher_profile_id = p_teacher_id
        AND s.session_status = 'completed'
        ORDER BY s.start_time DESC;
    ELSE
        RETURN QUERY
        SELECT
            ts.session_id,
            ts.student_id,
            ts.session_cost,
            ts.teacher_notes,
            ts.student_rating,
            ts.teacher_rating,
            ts.homework_assigned,
            ts.homework_completed,
            s.start_time,
            s.session_status
        FROM teaching_sessions ts
        INNER JOIN sessions s ON ts.session_id = s.session_id
        WHERE ts.teacher_profile_id = p_teacher_id
        ORDER BY s.start_time DESC;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER SESIONES DE ENSEÑANZA DE UN ESTUDIANTE
-- ============================
CREATE OR REPLACE FUNCTION get_student_sessions(
    p_student_id INTEGER,
    p_completed_only BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    session_id VARCHAR,
    teacher_profile_id INTEGER,
    session_cost DECIMAL,
    teacher_notes TEXT,
    student_rating INTEGER,
    teacher_rating INTEGER,
    homework_assigned TEXT,
    homework_completed BOOLEAN,
    start_time TIMESTAMP,
    session_status VARCHAR
)
AS
$$
BEGIN
    IF p_completed_only THEN
        RETURN QUERY
        SELECT
            ts.session_id,
            ts.teacher_profile_id,
            ts.session_cost,
            ts.teacher_notes,
            ts.student_rating,
            ts.teacher_rating,
            ts.homework_assigned,
            ts.homework_completed,
            s.start_time,
            s.session_status
        FROM teaching_sessions ts
        INNER JOIN sessions s ON ts.session_id = s.session_id
        WHERE ts.student_id = p_student_id
        AND s.session_status = 'completed'
        ORDER BY s.start_time DESC;
    ELSE
        RETURN QUERY
        SELECT
            ts.session_id,
            ts.teacher_profile_id,
            ts.session_cost,
            ts.teacher_notes,
            ts.student_rating,
            ts.teacher_rating,
            ts.homework_assigned,
            ts.homework_completed,
            s.start_time,
            s.session_status
        FROM teaching_sessions ts
        INNER JOIN sessions s ON ts.session_id = s.session_id
        WHERE ts.student_id = p_student_id
        ORDER BY s.start_time DESC;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER SESIONES PENDIENTES DE CALIFICACIÓN
-- ============================
CREATE OR REPLACE FUNCTION get_pending_rating_teaching_sessions(
    p_user_id INTEGER,
    p_user_type VARCHAR -- 'teacher' o 'student'
)
RETURNS TABLE (
    session_id VARCHAR,
    other_user_id INTEGER,
    start_time TIMESTAMP,
    already_rated BOOLEAN
)
AS
$$
DECLARE
    v_user_type_lower VARCHAR;
BEGIN
    v_user_type_lower := LOWER(p_user_type);
    
    IF v_user_type_lower NOT IN ('teacher', 'student') THEN
        RAISE EXCEPTION 'El tipo de usuario debe ser "teacher" o "student". Valor proporcionado: %.', p_user_type;
    END IF;
    
    IF v_user_type_lower = 'teacher' THEN
        RETURN QUERY
        SELECT
            ts.session_id,
            ts.student_id as other_user_id,
            s.start_time,
            (ts.teacher_rating IS NOT NULL) as already_rated
        FROM teaching_sessions ts
        INNER JOIN sessions s ON ts.session_id = s.session_id
        WHERE ts.teacher_profile_id = p_user_id
        AND s.session_status = 'completed'
        AND ts.teacher_rating IS NULL
        ORDER BY s.end_time DESC;
    ELSE
        RETURN QUERY
        SELECT
            ts.session_id,
            ts.teacher_profile_id as other_user_id,
            s.start_time,
            (ts.student_rating IS NOT NULL) as already_rated
        FROM teaching_sessions ts
        INNER JOIN sessions s ON ts.session_id = s.session_id
        WHERE ts.student_id = p_user_id
        AND s.session_status = 'completed'
        AND ts.student_rating IS NULL
        ORDER BY s.end_time DESC;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER TAREAS PENDIENTES DEL ESTUDIANTE
-- ============================
CREATE OR REPLACE FUNCTION get_pending_homework(
    p_student_id INTEGER
)
RETURNS TABLE (
    session_id VARCHAR,
    teacher_profile_id INTEGER,
    homework_assigned TEXT,
    start_time TIMESTAMP,
    days_since_session INTEGER
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        ts.session_id,
        ts.teacher_profile_id,
        ts.homework_assigned,
        s.start_time,
        EXTRACT(DAY FROM (CURRENT_TIMESTAMP - s.end_time))::INTEGER as days_since_session
    FROM teaching_sessions ts
    INNER JOIN sessions s ON ts.session_id = s.session_id
    WHERE ts.student_id = p_student_id
    AND ts.homework_assigned IS NOT NULL
    AND ts.homework_completed = FALSE
    AND s.session_status = 'completed'
    ORDER BY s.end_time ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER ESTADÍSTICAS DEL PROFESOR
-- ============================
CREATE OR REPLACE FUNCTION get_teacher_statistics(
    p_teacher_id INTEGER
)
RETURNS TABLE (
    teacher_id INTEGER,
    total_sessions INTEGER,
    completed_sessions INTEGER,
    average_student_rating DECIMAL,
    total_earnings DECIMAL,
    sessions_rated INTEGER,
    homework_assigned_count INTEGER,
    homework_completed_count INTEGER
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        p_teacher_id as teacher_id,
        COUNT(*)::INTEGER as total_sessions,
        COUNT(CASE WHEN s.session_status = 'completed' THEN 1 END)::INTEGER as completed_sessions,
        ROUND(AVG(ts.student_rating), 2) as average_student_rating,
        ROUND(SUM(CASE WHEN s.session_status = 'completed' THEN ts.session_cost ELSE 0 END), 2) as total_earnings,
        COUNT(ts.student_rating)::INTEGER as sessions_rated,
        COUNT(CASE WHEN ts.homework_assigned IS NOT NULL THEN 1 END)::INTEGER as homework_assigned_count,
        COUNT(CASE WHEN ts.homework_completed = TRUE THEN 1 END)::INTEGER as homework_completed_count
    FROM teaching_sessions ts
    INNER JOIN sessions s ON ts.session_id = s.session_id
    WHERE ts.teacher_profile_id = p_teacher_id;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER ESTADÍSTICAS DEL ESTUDIANTE
-- ============================
CREATE OR REPLACE FUNCTION get_student_statistics(
    p_student_id INTEGER
)
RETURNS TABLE (
    student_id INTEGER,
    total_sessions INTEGER,
    completed_sessions INTEGER,
    average_teacher_rating DECIMAL,
    total_spent DECIMAL,
    sessions_rated INTEGER,
    homework_assigned INTEGER,
    homework_completed INTEGER,
    homework_completion_rate DECIMAL
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        p_student_id as student_id,
        COUNT(*)::INTEGER as total_sessions,
        COUNT(CASE WHEN s.session_status = 'completed' THEN 1 END)::INTEGER as completed_sessions,
        ROUND(AVG(ts.teacher_rating), 2) as average_teacher_rating,
        ROUND(SUM(CASE WHEN s.session_status = 'completed' THEN ts.session_cost ELSE 0 END), 2) as total_spent,
        COUNT(ts.teacher_rating)::INTEGER as sessions_rated,
        COUNT(CASE WHEN ts.homework_assigned IS NOT NULL THEN 1 END)::INTEGER as homework_assigned,
        COUNT(CASE WHEN ts.homework_completed = TRUE THEN 1 END)::INTEGER as homework_completed,
        CASE 
            WHEN COUNT(CASE WHEN ts.homework_assigned IS NOT NULL THEN 1 END) > 0 
            THEN ROUND(
                COUNT(CASE WHEN ts.homework_completed = TRUE THEN 1 END)::DECIMAL * 100.0 / 
                COUNT(CASE WHEN ts.homework_assigned IS NOT NULL THEN 1 END),
                2
            )
            ELSE 0
        END as homework_completion_rate
    FROM teaching_sessions ts
    INNER JOIN sessions s ON ts.session_id = s.session_id
    WHERE ts.student_id = p_student_id;
END;
$$ LANGUAGE plpgsql;