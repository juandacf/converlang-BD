-- ================================================================
-- FUNCIÓN: OBTENER TODOS LOS PERFILES (Get All)
-- Recibe un booleano: TRUE (solo verificados) o FALSE (todos)
-- ================================================================
CREATE OR REPLACE FUNCTION get_all_teacher_profiles(
    p_verified_only BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    user_id INTEGER,
    teaching_language_id VARCHAR,
    lang_certification VARCHAR,
    academic_title VARCHAR,
    experience_certification VARCHAR,
    hourly_rate DECIMAL,
    specialization TEXT,
    years_experience INTEGER,
    availability_notes TEXT,
    is_verified BOOLEAN,
    verified_at TIMESTAMP,
    verified_by INTEGER,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
)
AS
$$
BEGIN
    IF p_verified_only THEN
        RETURN QUERY
        SELECT
            tp.user_id, tp.teaching_language_id, tp.lang_certification,
            tp.academic_title, tp.experience_certification, tp.hourly_rate,
            tp.specialization, tp.years_experience, tp.availability_notes,
            tp.is_verified, tp.verified_at, tp.verified_by,
            tp.created_at, tp.updated_at
        FROM teacher_profiles tp
        WHERE tp.is_verified = TRUE
        ORDER BY tp.created_at DESC;
    ELSE
        RETURN QUERY
        SELECT
            tp.user_id, tp.teaching_language_id, tp.lang_certification,
            tp.academic_title, tp.experience_certification, tp.hourly_rate,
            tp.specialization, tp.years_experience, tp.availability_notes,
            tp.is_verified, tp.verified_at, tp.verified_by,
            tp.created_at, tp.updated_at
        FROM teacher_profiles tp
        ORDER BY tp.created_at DESC;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- 5. FUNCIÓN: OBTENER PERFIL POR ID (Get One)
-- ================================================================
CREATE OR REPLACE FUNCTION get_teacher_profile_by_id(
    p_user_id INTEGER
)
RETURNS TABLE (
    user_id INTEGER,
    teaching_language_id VARCHAR,
    lang_certification VARCHAR,
    academic_title VARCHAR,
    experience_certification VARCHAR,
    hourly_rate DECIMAL,
    specialization TEXT,
    years_experience INTEGER,
    availability_notes TEXT,
    is_verified BOOLEAN,
    verified_at TIMESTAMP,
    verified_by INTEGER,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        tp.user_id, tp.teaching_language_id, tp.lang_certification,
        tp.academic_title, tp.experience_certification, tp.hourly_rate,
        tp.specialization, tp.years_experience, tp.availability_notes,
        tp.is_verified, tp.verified_at, tp.verified_by,
        tp.created_at, tp.updated_at
    FROM teacher_profiles tp
    WHERE tp.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- 1. MEJORA "POST": ADD_TEACHER_PROFILE
-- ================================================================
CREATE OR REPLACE FUNCTION add_teacher_profile(
    p_user_id INTEGER,
    p_teaching_language_id VARCHAR,
    p_lang_certification VARCHAR DEFAULT NULL,
    p_academic_title VARCHAR DEFAULT NULL,
    p_experience_certification VARCHAR DEFAULT NULL,
    p_hourly_rate DECIMAL DEFAULT NULL,
    p_specialization TEXT DEFAULT NULL,
    p_years_experience INTEGER DEFAULT NULL,
    p_availability_notes TEXT DEFAULT NULL
)
RETURNS TABLE (
    user_id INTEGER,
    teaching_language_id VARCHAR,
    lang_certification VARCHAR,
    academic_title VARCHAR,
    experience_certification VARCHAR,
    hourly_rate DECIMAL,
    specialization TEXT,
    years_experience INTEGER,
    availability_notes TEXT,
    is_verified BOOLEAN,
    verified_at TIMESTAMP,
    verified_by INTEGER,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) AS
$$
DECLARE
    v_exists BOOLEAN;
    v_teaching_lang_upper VARCHAR;
    v_user_role VARCHAR;
BEGIN
    -- 1. Validaciones previas (Idénticas a tu lógica original)
    IF p_user_id IS NULL THEN RAISE EXCEPTION 'El ID del usuario no puede estar vacío.'; END IF;
    
    SELECT EXISTS(SELECT 1 FROM users WHERE id_user = p_user_id) INTO v_exists;
    IF NOT v_exists THEN RAISE EXCEPTION 'No existe un usuario con el ID %.', p_user_id; END IF;
    
    SELECT role_code INTO v_user_role FROM users WHERE id_user = p_user_id;
    IF v_user_role <> 'teacher' THEN RAISE EXCEPTION 'El usuario % no tiene rol de profesor.', p_user_id; END IF;

    SELECT EXISTS(SELECT 1 FROM teacher_profiles tp WHERE tp.user_id = p_user_id) INTO v_exists;
    IF v_exists THEN RAISE EXCEPTION 'Ya existe un perfil para el usuario %.', p_user_id; END IF;

    -- 2. Normalización
    v_teaching_lang_upper := UPPER(p_teaching_language_id);
    
    SELECT EXISTS(SELECT 1 FROM languages WHERE language_code = v_teaching_lang_upper) INTO v_exists;
    IF NOT v_exists THEN RAISE EXCEPTION 'No existe el idioma %.', v_teaching_lang_upper; END IF;

    -- 3. Inserción
    INSERT INTO teacher_profiles (
        user_id, teaching_language_id, lang_certification,
        academic_title, experience_certification, hourly_rate,
        specialization, years_experience, availability_notes
    ) VALUES (
        p_user_id, v_teaching_lang_upper, p_lang_certification,
        p_academic_title, p_experience_certification, p_hourly_rate,
        p_specialization, p_years_experience, p_availability_notes
    );
    
    -- 4. RETORNO DEL OBJETO (La mejora clave)
    RETURN QUERY 
    SELECT tp.user_id, tp.teaching_language_id, tp.lang_certification,
           tp.academic_title, tp.experience_certification, tp.hourly_rate,
           tp.specialization, tp.years_experience, tp.availability_notes,
           tp.is_verified, tp.verified_at, tp.verified_by,
           tp.created_at, tp.updated_at
    FROM teacher_profiles tp 
    WHERE tp.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;


-- ================================================================
-- 2. MEJORA "PATCH/UPDATE": UPDATE_TEACHER_PROFILE
-- Cambio: Retorna la fila actualizada y actualiza el campo updated_at.
-- ================================================================
CREATE OR REPLACE FUNCTION update_teacher_profile(
    p_user_id INTEGER,
    p_teaching_language_id VARCHAR,
    p_lang_certification VARCHAR DEFAULT NULL,
    p_academic_title VARCHAR DEFAULT NULL,
    p_experience_certification VARCHAR DEFAULT NULL,
    p_hourly_rate DECIMAL DEFAULT NULL,
    p_specialization TEXT DEFAULT NULL,
    p_years_experience INTEGER DEFAULT NULL,
    p_availability_notes TEXT DEFAULT NULL
)
RETURNS TABLE (
    user_id INTEGER,
    teaching_language_id VARCHAR,
    lang_certification VARCHAR,
    academic_title VARCHAR,
    experience_certification VARCHAR,
    hourly_rate DECIMAL,
    specialization TEXT,
    years_experience INTEGER,
    availability_notes TEXT,
    is_verified BOOLEAN,
    verified_at TIMESTAMP,
    verified_by INTEGER,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) AS
$$
DECLARE
    v_exists BOOLEAN;
    v_teaching_lang_upper VARCHAR;
BEGIN
    -- 1. Validar existencia
    SELECT EXISTS(SELECT 1 FROM teacher_profiles tp WHERE tp.user_id = p_user_id) INTO v_exists;
    IF NOT v_exists THEN RAISE EXCEPTION 'No existe perfil para el usuario %.', p_user_id; END IF;

    -- 2. Normalización idioma (si viene null, se manejará en el UPDATE, pero aquí validamos si viene)
    IF p_teaching_language_id IS NOT NULL THEN
        v_teaching_lang_upper := UPPER(p_teaching_language_id);
         SELECT EXISTS(SELECT 1 FROM languages WHERE language_code = v_teaching_lang_upper) INTO v_exists;
        IF NOT v_exists THEN RAISE EXCEPTION 'No existe el idioma %.', v_teaching_lang_upper; END IF;
    ELSE
        -- Si no envían idioma nuevo, recuperamos el actual para no romper la lógica
        SELECT teaching_language_id INTO v_teaching_lang_upper FROM teacher_profiles tp WHERE tp.user_id = p_user_id;
    END IF;

    -- 3. Actualización (Sobrescribe valores)
    UPDATE teacher_profiles tp
    SET
        teaching_language_id = v_teaching_lang_upper,
        lang_certification = p_lang_certification,
        academic_title = p_academic_title,
        experience_certification = p_experience_certification,
        hourly_rate = p_hourly_rate,
        specialization = p_specialization,
        years_experience = p_years_experience,
        availability_notes = p_availability_notes,
        updated_at = CURRENT_TIMESTAMP
    WHERE tp.user_id = p_user_id;
    
    -- 4. RETORNO DEL OBJETO ACTUALIZADO
    RETURN QUERY 
    SELECT tp.user_id, tp.teaching_language_id, tp.lang_certification,
           tp.academic_title, tp.experience_certification, tp.hourly_rate,
           tp.specialization, tp.years_experience, tp.availability_notes,
           tp.is_verified, tp.verified_at, tp.verified_by,
           tp.created_at, tp.updated_at
    FROM teacher_profiles tp 
    WHERE tp.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;


-- ================================================================
-- 3. MEJORA "DELETE": DELETE_TEACHER_PROFILE
-- Cambio: Retorna un JSON o mensaje claro, manejando errores de FK.
-- ================================================================
CREATE OR REPLACE FUNCTION delete_teacher_profile(
    p_user_id INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    -- 1. Verificar existencia
    SELECT EXISTS(SELECT 1 FROM teacher_profiles tp WHERE tp.user_id = p_user_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un perfil de profesor para el usuario con ID %.', p_user_id;
    END IF;
    
    -- 2. Intentar Eliminar
    BEGIN
        DELETE FROM teacher_profiles tp WHERE tp.user_id = p_user_id;
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE EXCEPTION 'No se puede eliminar el perfil (ID: %) porque tiene clases o registros asociados.', p_user_id;
    END;
    
    -- 3. Retornar mensaje de éxito (esto lo captura el service y lo devuelve)
    RETURN 'Perfil de profesor eliminado correctamente';
END;
$$ LANGUAGE plpgsql;