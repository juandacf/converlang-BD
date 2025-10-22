-- ============================
-- FUNCIÓN: CREAR PERFIL DE PROFESOR
-- ============================
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
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_teaching_lang_upper VARCHAR;
    v_user_role VARCHAR;
BEGIN
    -- ============================
    -- VALIDACIÓN DE USER_ID
    -- ============================
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'El ID del usuario no puede estar vacío.';
    END IF;
    
    -- Verificar que el usuario exista
    SELECT EXISTS(SELECT 1 FROM users WHERE id_user = p_user_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un usuario con el ID %.', p_user_id;
    END IF;
    
    -- Verificar que el usuario tenga rol de teacher
    SELECT role_code INTO v_user_role FROM users WHERE id_user = p_user_id;
    IF v_user_role <> 'teacher' THEN
        RAISE EXCEPTION 'El usuario con ID % no tiene rol de profesor. Rol actual: %.', p_user_id, v_user_role;
    END IF;
    
    -- Verificar que no exista ya un perfil de profesor para este usuario
    SELECT EXISTS(SELECT 1 FROM teacher_profiles WHERE user_id = p_user_id) INTO v_exists;
    IF v_exists THEN
        RAISE EXCEPTION 'Ya existe un perfil de profesor para el usuario con ID %.', p_user_id;
    END IF;
    
    -- ============================
    -- VALIDACIÓN Y NORMALIZACIÓN DE TEACHING_LANGUAGE_ID
    -- ============================
    IF p_teaching_language_id IS NULL OR LENGTH(TRIM(p_teaching_language_id)) = 0 THEN
        RAISE EXCEPTION 'El idioma que enseña no puede estar vacío.';
    END IF;
    
    v_teaching_lang_upper := UPPER(p_teaching_language_id);
    
    SELECT EXISTS(SELECT 1 FROM languages WHERE language_code = v_teaching_lang_upper) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un idioma con el código %.', v_teaching_lang_upper;
    END IF;
    
    -- ============================
    -- VALIDACIONES DE CAMPOS OPCIONALES
    -- ============================
    IF p_lang_certification IS NOT NULL AND LENGTH(p_lang_certification) > 255 THEN
        RAISE EXCEPTION 'La certificación de idioma no puede exceder 255 caracteres.';
    END IF;
    
    IF p_academic_title IS NOT NULL AND LENGTH(p_academic_title) > 255 THEN
        RAISE EXCEPTION 'El título académico no puede exceder 255 caracteres.';
    END IF;
    
    IF p_experience_certification IS NOT NULL AND LENGTH(p_experience_certification) > 255 THEN
        RAISE EXCEPTION 'La certificación de experiencia no puede exceder 255 caracteres.';
    END IF;
    
    IF p_hourly_rate IS NOT NULL THEN
        IF p_hourly_rate < 0 THEN
            RAISE EXCEPTION 'La tarifa por hora no puede ser negativa.';
        ELSIF p_hourly_rate > 999999.99 THEN
            RAISE EXCEPTION 'La tarifa por hora excede el límite permitido (999999.99).';
        END IF;
    END IF;
    
    IF p_years_experience IS NOT NULL THEN
        IF p_years_experience < 0 THEN
            RAISE EXCEPTION 'Los años de experiencia no pueden ser negativos.';
        ELSIF p_years_experience > 100 THEN
            RAISE EXCEPTION 'Los años de experiencia no pueden exceder 100 años.';
        END IF;
    END IF;
    
    -- ============================
    -- CREAR PERFIL DE PROFESOR
    -- ============================
    INSERT INTO teacher_profiles (
        user_id, teaching_language_id, lang_certification,
        academic_title, experience_certification, hourly_rate,
        specialization, years_experience, availability_notes
    ) VALUES (
        p_user_id, v_teaching_lang_upper, p_lang_certification,
        p_academic_title, p_experience_certification, p_hourly_rate,
        p_specialization, p_years_experience, p_availability_notes
    );
    
    RETURN format('Perfil de profesor creado correctamente para el usuario con ID %s.', p_user_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ACTUALIZAR PERFIL DE PROFESOR
-- ============================
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
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_teaching_lang_upper VARCHAR;
BEGIN
    -- ============================
    -- VERIFICAR EXISTENCIA DEL PERFIL
    -- ============================
    SELECT EXISTS(SELECT 1 FROM teacher_profiles WHERE user_id = p_user_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un perfil de profesor para el usuario con ID %.', p_user_id;
    END IF;
    
    -- ============================
    -- VALIDACIÓN Y NORMALIZACIÓN DE TEACHING_LANGUAGE_ID
    -- ============================
    IF p_teaching_language_id IS NULL OR LENGTH(TRIM(p_teaching_language_id)) = 0 THEN
        RAISE EXCEPTION 'El idioma que enseña no puede estar vacío.';
    END IF;
    
    v_teaching_lang_upper := UPPER(p_teaching_language_id);
    
    SELECT EXISTS(SELECT 1 FROM languages WHERE language_code = v_teaching_lang_upper) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un idioma con el código %.', v_teaching_lang_upper;
    END IF;
    
    -- ============================
    -- VALIDACIONES DE CAMPOS
    -- ============================
    IF p_lang_certification IS NOT NULL AND LENGTH(p_lang_certification) > 255 THEN
        RAISE EXCEPTION 'La certificación de idioma no puede exceder 255 caracteres.';
    END IF;
    
    IF p_academic_title IS NOT NULL AND LENGTH(p_academic_title) > 255 THEN
        RAISE EXCEPTION 'El título académico no puede exceder 255 caracteres.';
    END IF;
    
    IF p_experience_certification IS NOT NULL AND LENGTH(p_experience_certification) > 255 THEN
        RAISE EXCEPTION 'La certificación de experiencia no puede exceder 255 caracteres.';
    END IF;
    
    IF p_hourly_rate IS NOT NULL THEN
        IF p_hourly_rate < 0 THEN
            RAISE EXCEPTION 'La tarifa por hora no puede ser negativa.';
        ELSIF p_hourly_rate > 999999.99 THEN
            RAISE EXCEPTION 'La tarifa por hora excede el límite permitido (999999.99).';
        END IF;
    END IF;
    
    IF p_years_experience IS NOT NULL THEN
        IF p_years_experience < 0 THEN
            RAISE EXCEPTION 'Los años de experiencia no pueden ser negativos.';
        ELSIF p_years_experience > 100 THEN
            RAISE EXCEPTION 'Los años de experiencia no pueden exceder 100 años.';
        END IF;
    END IF;
    
    -- ============================
    -- ACTUALIZAR PERFIL
    -- ============================
    UPDATE teacher_profiles
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
    WHERE user_id = p_user_id;
    
    RETURN format('Perfil de profesor actualizado correctamente para el usuario con ID %s.', p_user_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR PERFIL DE PROFESOR
-- ============================
CREATE OR REPLACE FUNCTION delete_teacher_profile(
    p_user_id INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    -- ============================
    -- VERIFICAR EXISTENCIA DEL PERFIL
    -- ============================
    SELECT EXISTS(SELECT 1 FROM teacher_profiles WHERE user_id = p_user_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un perfil de profesor para el usuario con ID %.', p_user_id;
    END IF;
    
    -- ============================
    -- ELIMINAR PERFIL (CON MANEJO DE FK)
    -- ============================
    BEGIN
        DELETE FROM teacher_profiles WHERE user_id = p_user_id;
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE EXCEPTION 'No se puede eliminar el perfil del profesor (ID: %) porque tiene registros asociados.', p_user_id;
    END;
    
    RETURN format('Perfil de profesor eliminado correctamente para el usuario con ID %s.', p_user_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: VERIFICAR PERFIL DE PROFESOR
-- ============================
CREATE OR REPLACE FUNCTION verify_teacher_profile(
    p_user_id INTEGER,
    p_verified_by INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_verifier_role VARCHAR;
BEGIN
    -- ============================
    -- VERIFICAR EXISTENCIA DEL PERFIL
    -- ============================
    SELECT EXISTS(SELECT 1 FROM teacher_profiles WHERE user_id = p_user_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un perfil de profesor para el usuario con ID %.', p_user_id;
    END IF;
    
    -- ============================
    -- VERIFICAR QUE EL VERIFICADOR EXISTA Y SEA ADMIN
    -- ============================
    SELECT EXISTS(SELECT 1 FROM users WHERE id_user = p_verified_by) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un usuario con el ID %.', p_verified_by;
    END IF;
    
    SELECT role_code INTO v_verifier_role FROM users WHERE id_user = p_verified_by;
    IF v_verifier_role <> 'admin' THEN
        RAISE EXCEPTION 'Solo los administradores pueden verificar perfiles de profesores. Usuario con ID % tiene rol: %.', p_verified_by, v_verifier_role;
    END IF;
    
    -- ============================
    -- VERIFICAR PERFIL
    -- ============================
    UPDATE teacher_profiles
    SET
        is_verified = TRUE,
        verified_at = CURRENT_TIMESTAMP,
        verified_by = p_verified_by,
        updated_at = CURRENT_TIMESTAMP
    WHERE user_id = p_user_id;
    
    RETURN format('Perfil de profesor verificado correctamente para el usuario con ID %s por el administrador con ID %s.', p_user_id, p_verified_by);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: REVOCAR VERIFICACIÓN DE PERFIL
-- ============================
CREATE OR REPLACE FUNCTION unverify_teacher_profile(
    p_user_id INTEGER,
    p_unverified_by INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_unverifier_role VARCHAR;
BEGIN
    -- ============================
    -- VERIFICAR EXISTENCIA DEL PERFIL
    -- ============================
    SELECT EXISTS(SELECT 1 FROM teacher_profiles WHERE user_id = p_user_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un perfil de profesor para el usuario con ID %.', p_user_id;
    END IF;
    
    -- ============================
    -- VERIFICAR QUE QUIEN REVOCA SEA ADMIN
    -- ============================
    SELECT EXISTS(SELECT 1 FROM users WHERE id_user = p_unverified_by) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un usuario con el ID %.', p_unverified_by;
    END IF;
    
    SELECT role_code INTO v_unverifier_role FROM users WHERE id_user = p_unverified_by;
    IF v_unverifier_role <> 'admin' THEN
        RAISE EXCEPTION 'Solo los administradores pueden revocar verificación de perfiles. Usuario con ID % tiene rol: %.', p_unverified_by, v_unverifier_role;
    END IF;
    
    -- ============================
    -- REVOCAR VERIFICACIÓN
    -- ============================
    UPDATE teacher_profiles
    SET
        is_verified = FALSE,
        verified_at = NULL,
        verified_by = NULL,
        updated_at = CURRENT_TIMESTAMP
    WHERE user_id = p_user_id;
    
    RETURN format('Verificación revocada para el perfil del profesor con ID %s por el administrador con ID %s.', p_user_id, p_unverified_by);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER TODOS LOS PERFILES DE PROFESORES
-- ============================
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

-- ============================
-- FUNCIÓN: OBTENER PERFIL DE PROFESOR POR USER_ID
-- ============================
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

-- ============================
-- FUNCIÓN: BUSCAR PROFESORES POR IDIOMA QUE ENSEÑAN
-- ============================
CREATE OR REPLACE FUNCTION get_teachers_by_language(
    p_teaching_language_id VARCHAR,
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
DECLARE
    v_teaching_lang_upper VARCHAR;
BEGIN
    v_teaching_lang_upper := UPPER(p_teaching_language_id);
    
    IF p_verified_only THEN
        RETURN QUERY
        SELECT
            tp.user_id, tp.teaching_language_id, tp.lang_certification,
            tp.academic_title, tp.experience_certification, tp.hourly_rate,
            tp.specialization, tp.years_experience, tp.availability_notes,
            tp.is_verified, tp.verified_at, tp.verified_by,
            tp.created_at, tp.updated_at
        FROM teacher_profiles tp
        WHERE tp.teaching_language_id = v_teaching_lang_upper
        AND tp.is_verified = TRUE
        ORDER BY tp.hourly_rate ASC NULLS LAST;
    ELSE
        RETURN QUERY
        SELECT
            tp.user_id, tp.teaching_language_id, tp.lang_certification,
            tp.academic_title, tp.experience_certification, tp.hourly_rate,
            tp.specialization, tp.years_experience, tp.availability_notes,
            tp.is_verified, tp.verified_at, tp.verified_by,
            tp.created_at, tp.updated_at
        FROM teacher_profiles tp
        WHERE tp.teaching_language_id = v_teaching_lang_upper
        ORDER BY tp.hourly_rate ASC NULLS LAST;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: BUSCAR PROFESORES POR RANGO DE TARIFA
-- ============================
CREATE OR REPLACE FUNCTION get_teachers_by_price_range(
    p_min_rate DECIMAL,
    p_max_rate DECIMAL,
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
        WHERE tp.hourly_rate BETWEEN p_min_rate AND p_max_rate
        AND tp.is_verified = TRUE
        ORDER BY tp.hourly_rate ASC;
    ELSE
        RETURN QUERY
        SELECT
            tp.user_id, tp.teaching_language_id, tp.lang_certification,
            tp.academic_title, tp.experience_certification, tp.hourly_rate,
            tp.specialization, tp.years_experience, tp.availability_notes,
            tp.is_verified, tp.verified_at, tp.verified_by,
            tp.created_at, tp.updated_at
        FROM teacher_profiles tp
        WHERE tp.hourly_rate BETWEEN p_min_rate AND p_max_rate
        ORDER BY tp.hourly_rate ASC;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER PERFILES PENDIENTES DE VERIFICACIÓN
-- ============================
CREATE OR REPLACE FUNCTION get_unverified_teacher_profiles()
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
        tp.is_verified, tp.created_at, tp.updated_at
    FROM teacher_profiles tp
    WHERE tp.is_verified = FALSE
    ORDER BY tp.created_at ASC;
END;
$$ LANGUAGE plpgsql;