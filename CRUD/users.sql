-- ============================
-- FUNCIÓN AUXILIAR: GENERAR SIGUIENTE ID DE USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_next_user_id()
RETURNS INTEGER AS
$$
DECLARE
    v_next_id INTEGER;
BEGIN
    SELECT COALESCE(MAX(id_user), 0) + 1 INTO v_next_id FROM users;
    RETURN v_next_id;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: AGREGAR USUARIO
-- ============================
CREATE OR REPLACE FUNCTION add_user(
    p_first_name VARCHAR,
    p_last_name VARCHAR,
    p_email VARCHAR,
    p_password_hash VARCHAR,
    p_gender_id INTEGER,
    p_birth_date DATE,
    p_country_id VARCHAR,
    p_profile_photo VARCHAR DEFAULT NULL,
    p_native_lang_id VARCHAR,
    p_target_lang_id VARCHAR,
    p_match_quantity INTEGER DEFAULT 10,
    p_bank_id VARCHAR DEFAULT NULL,
    p_role_code VARCHAR DEFAULT 'user',
    p_description TEXT DEFAULT 'NO APLICA'
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_new_user_id INTEGER;
    v_country_id_upper VARCHAR;
    v_native_lang_upper VARCHAR;
    v_target_lang_upper VARCHAR;
    v_bank_id_upper VARCHAR;
    v_role_code_lower VARCHAR;
BEGIN
    -- ============================
    -- VALIDACIONES BÁSICAS
    -- ============================
    IF p_first_name IS NULL OR LENGTH(TRIM(p_first_name)) = 0 THEN
        RAISE EXCEPTION 'El nombre no puede estar vacío.';
    ELSIF LENGTH(p_first_name) > 100 THEN
        RAISE EXCEPTION 'El nombre no puede tener más de 100 caracteres.';
    END IF;
    
    IF p_last_name IS NULL OR LENGTH(TRIM(p_last_name)) = 0 THEN
        RAISE EXCEPTION 'El apellido no puede estar vacío.';
    ELSIF LENGTH(p_last_name) > 100 THEN
        RAISE EXCEPTION 'El apellido no puede tener más de 100 caracteres.';
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE EMAIL
    -- ============================
    IF p_email IS NULL OR LENGTH(TRIM(p_email)) = 0 THEN
        RAISE EXCEPTION 'El correo electrónico no puede estar vacío.';
    ELSIF LENGTH(p_email) > 150 THEN
        RAISE EXCEPTION 'El correo electrónico no puede tener más de 150 caracteres.';
    ELSIF p_email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        RAISE EXCEPTION 'El formato del correo electrónico no es válido.';
    END IF;
    
    -- Verificar email único
    SELECT EXISTS(SELECT 1 FROM users WHERE UPPER(email) = UPPER(p_email)) INTO v_exists;
    IF v_exists THEN
        RAISE EXCEPTION 'Ya existe un usuario con el correo %.', p_email;
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE PASSWORD
    -- ============================
    IF p_password_hash IS NULL OR LENGTH(TRIM(p_password_hash)) = 0 THEN
        RAISE EXCEPTION 'El hash de la contraseña no puede estar vacío.';
    ELSIF LENGTH(p_password_hash) > 255 THEN
        RAISE EXCEPTION 'El hash de la contraseña excede el límite de 255 caracteres.';
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE FECHA DE NACIMIENTO
    -- ============================
    IF p_birth_date IS NULL THEN
        RAISE EXCEPTION 'La fecha de nacimiento no puede estar vacía.';
    ELSIF p_birth_date > CURRENT_DATE - INTERVAL '15 years' THEN
        RAISE EXCEPTION 'El usuario debe tener al menos 15 años de edad.';
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE GÉNERO
    -- ============================
    IF p_gender_id IS NOT NULL THEN
        SELECT EXISTS(SELECT 1 FROM gender_type WHERE gender_id = p_gender_id) INTO v_exists;
        IF NOT v_exists THEN
            RAISE EXCEPTION 'No existe un género con el ID %.', p_gender_id;
        END IF;
    END IF;
    
    -- ============================
    -- NORMALIZACIÓN Y VALIDACIÓN DE COUNTRY_ID
    -- ============================
    IF p_country_id IS NULL OR LENGTH(TRIM(p_country_id)) = 0 THEN
        RAISE EXCEPTION 'El código del país no puede estar vacío.';
    END IF;
    v_country_id_upper := UPPER(p_country_id);
    SELECT EXISTS(SELECT 1 FROM countries WHERE country_code = v_country_id_upper) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un país con el código %.', v_country_id_upper;
    END IF;
    
    -- ============================
    -- NORMALIZACIÓN Y VALIDACIÓN DE IDIOMA NATIVO
    -- ============================
    IF p_native_lang_id IS NULL OR LENGTH(TRIM(p_native_lang_id)) = 0 THEN
        RAISE EXCEPTION 'El idioma nativo no puede estar vacío.';
    END IF;
    v_native_lang_upper := UPPER(p_native_lang_id);
    SELECT EXISTS(SELECT 1 FROM languages WHERE language_code = v_native_lang_upper) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un idioma con el código %.', v_native_lang_upper;
    END IF;
    
    -- ============================
    -- NORMALIZACIÓN Y VALIDACIÓN DE IDIOMA OBJETIVO
    -- ============================
    IF p_target_lang_id IS NULL OR LENGTH(TRIM(p_target_lang_id)) = 0 THEN
        RAISE EXCEPTION 'El idioma objetivo no puede estar vacío.';
    END IF;
    v_target_lang_upper := UPPER(p_target_lang_id);
    SELECT EXISTS(SELECT 1 FROM languages WHERE language_code = v_target_lang_upper) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un idioma con el código %.', v_target_lang_upper;
    END IF;
    
    -- Validar que los idiomas no sean iguales
    IF v_native_lang_upper = v_target_lang_upper THEN
        RAISE EXCEPTION 'El idioma nativo y el idioma objetivo no pueden ser el mismo.';
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE MATCH_QUANTITY
    -- ============================
    IF p_match_quantity IS NULL OR p_match_quantity < 1 THEN
        RAISE EXCEPTION 'La cantidad de matches debe ser al menos 1.';
    ELSIF p_match_quantity > 100 THEN
        RAISE EXCEPTION 'La cantidad de matches no puede exceder 100.';
    END IF;
    
    -- ============================
    -- NORMALIZACIÓN Y VALIDACIÓN DE BANK_ID (OPCIONAL)
    -- ============================
    IF p_bank_id IS NOT NULL AND LENGTH(TRIM(p_bank_id)) > 0 THEN
        v_bank_id_upper := UPPER(p_bank_id);
        SELECT EXISTS(SELECT 1 FROM banks WHERE bank_code = v_bank_id_upper) INTO v_exists;
        IF NOT v_exists THEN
            RAISE EXCEPTION 'No existe un banco con el código %.', v_bank_id_upper;
        END IF;
    ELSE
        v_bank_id_upper := NULL;
    END IF;
    
    -- ============================
    -- NORMALIZACIÓN Y VALIDACIÓN DE ROLE_CODE
    -- ============================
    v_role_code_lower := LOWER(COALESCE(p_role_code, 'user'));
    IF v_role_code_lower NOT IN ('admin', 'teacher', 'user') THEN
        RAISE EXCEPTION 'El rol debe ser: admin, teacher o user. Rol proporcionado: %.', p_role_code;
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE PROFILE_PHOTO
    -- ============================
    IF p_profile_photo IS NOT NULL AND LENGTH(p_profile_photo) > 255 THEN
        RAISE EXCEPTION 'La URL de la foto de perfil no puede exceder 255 caracteres.';
    END IF;
    
    -- ============================
    -- GENERAR ID Y CREAR USUARIO
    -- ============================
    v_new_user_id := get_next_user_id();
    
    INSERT INTO users (
        id_user, first_name, last_name, email, password_hash,
        gender_id, birth_date, country_id, profile_photo,
        native_lang_id, target_lang_id, match_quantity,
        bank_id, role_code, description
    ) VALUES (
        v_new_user_id, p_first_name, p_last_name, p_email, p_password_hash,
        p_gender_id, p_birth_date, v_country_id_upper, p_profile_photo,
        v_native_lang_upper, v_target_lang_upper, p_match_quantity,
        v_bank_id_upper, v_role_code_lower, p_description
    );
    
    RETURN format('Usuario %s %s creado correctamente con ID %s.', p_first_name, p_last_name, v_new_user_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ACTUALIZAR USUARIO
-- ============================
CREATE OR REPLACE FUNCTION update_user(
    p_id_user INTEGER,
    p_first_name VARCHAR,
    p_last_name VARCHAR,
    p_email VARCHAR,
    p_gender_id INTEGER,
    p_birth_date DATE,
    p_country_id VARCHAR,
    p_profile_photo VARCHAR DEFAULT NULL,
    p_native_lang_id VARCHAR,
    p_target_lang_id VARCHAR,
    p_match_quantity INTEGER,
    p_bank_id VARCHAR DEFAULT NULL,
    p_description TEXT DEFAULT 'NO APLICA'
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_country_id_upper VARCHAR;
    v_native_lang_upper VARCHAR;
    v_target_lang_upper VARCHAR;
    v_bank_id_upper VARCHAR;
BEGIN
    -- ============================
    -- VERIFICAR EXISTENCIA DEL USUARIO
    -- ============================
    SELECT EXISTS(SELECT 1 FROM users WHERE id_user = p_id_user) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un usuario con el ID %.', p_id_user;
    END IF;
    
    -- ============================
    -- VALIDACIONES (SIMILARES A ADD_USER)
    -- ============================
    IF p_first_name IS NULL OR LENGTH(TRIM(p_first_name)) = 0 THEN
        RAISE EXCEPTION 'El nombre no puede estar vacío.';
    ELSIF LENGTH(p_first_name) > 100 THEN
        RAISE EXCEPTION 'El nombre no puede tener más de 100 caracteres.';
    END IF;
    
    IF p_last_name IS NULL OR LENGTH(TRIM(p_last_name)) = 0 THEN
        RAISE EXCEPTION 'El apellido no puede estar vacío.';
    ELSIF LENGTH(p_last_name) > 100 THEN
        RAISE EXCEPTION 'El apellido no puede tener más de 100 caracteres.';
    END IF;
    
    IF p_email IS NULL OR LENGTH(TRIM(p_email)) = 0 THEN
        RAISE EXCEPTION 'El correo electrónico no puede estar vacío.';
    ELSIF LENGTH(p_email) > 150 THEN
        RAISE EXCEPTION 'El correo electrónico no puede tener más de 150 caracteres.';
    ELSIF p_email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        RAISE EXCEPTION 'El formato del correo electrónico no es válido.';
    END IF;
    
    SELECT EXISTS(
        SELECT 1 FROM users 
        WHERE UPPER(email) = UPPER(p_email) 
        AND id_user <> p_id_user
    ) INTO v_exists;
    IF v_exists THEN
        RAISE EXCEPTION 'Ya existe otro usuario con el correo %.', p_email;
    END IF;
    
    IF p_birth_date IS NULL THEN
        RAISE EXCEPTION 'La fecha de nacimiento no puede estar vacía.';
    ELSIF p_birth_date > CURRENT_DATE - INTERVAL '15 years' THEN
        RAISE EXCEPTION 'El usuario debe tener al menos 15 años de edad.';
    END IF;
    
    IF p_gender_id IS NOT NULL THEN
        SELECT EXISTS(SELECT 1 FROM gender_type WHERE gender_id = p_gender_id) INTO v_exists;
        IF NOT v_exists THEN
            RAISE EXCEPTION 'No existe un género con el ID %.', p_gender_id;
        END IF;
    END IF;
    
    v_country_id_upper := UPPER(p_country_id);
    SELECT EXISTS(SELECT 1 FROM countries WHERE country_code = v_country_id_upper) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un país con el código %.', v_country_id_upper;
    END IF;
    
    v_native_lang_upper := UPPER(p_native_lang_id);
    SELECT EXISTS(SELECT 1 FROM languages WHERE language_code = v_native_lang_upper) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un idioma con el código %.', v_native_lang_upper;
    END IF;
    
    v_target_lang_upper := UPPER(p_target_lang_id);
    SELECT EXISTS(SELECT 1 FROM languages WHERE language_code = v_target_lang_upper) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un idioma con el código %.', v_target_lang_upper;
    END IF;
    
    IF v_native_lang_upper = v_target_lang_upper THEN
        RAISE EXCEPTION 'El idioma nativo y el idioma objetivo no pueden ser el mismo.';
    END IF;
    
    IF p_match_quantity IS NULL OR p_match_quantity < 1 THEN
        RAISE EXCEPTION 'La cantidad de matches debe ser al menos 1.';
    ELSIF p_match_quantity > 100 THEN
        RAISE EXCEPTION 'La cantidad de matches no puede exceder 100.';
    END IF;
    
    IF p_bank_id IS NOT NULL AND LENGTH(TRIM(p_bank_id)) > 0 THEN
        v_bank_id_upper := UPPER(p_bank_id);
        SELECT EXISTS(SELECT 1 FROM banks WHERE bank_code = v_bank_id_upper) INTO v_exists;
        IF NOT v_exists THEN
            RAISE EXCEPTION 'No existe un banco con el código %.', v_bank_id_upper;
        END IF;
    ELSE
        v_bank_id_upper := NULL;
    END IF;
    
    IF p_profile_photo IS NOT NULL AND LENGTH(p_profile_photo) > 255 THEN
        RAISE EXCEPTION 'La URL de la foto de perfil no puede exceder 255 caracteres.';
    END IF;
    
    -- ============================
    -- ACTUALIZAR USUARIO
    -- ============================
    UPDATE users
    SET
        first_name = p_first_name,
        last_name = p_last_name,
        email = p_email,
        gender_id = p_gender_id,
        birth_date = p_birth_date,
        country_id = v_country_id_upper,
        profile_photo = p_profile_photo,
        native_lang_id = v_native_lang_upper,
        target_lang_id = v_target_lang_upper,
        match_quantity = p_match_quantity,
        bank_id = v_bank_id_upper,
        description = p_description,
        updated_at = CURRENT_TIMESTAMP
    WHERE id_user = p_id_user;
    
    RETURN format('Usuario con ID %s actualizado correctamente.', p_id_user);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR USUARIO (SOFT DELETE)
-- ============================
CREATE OR REPLACE FUNCTION delete_user(
    p_id_user INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_user_name VARCHAR;
BEGIN
    SELECT EXISTS(SELECT 1 FROM users WHERE id_user = p_id_user) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un usuario con el ID %.', p_id_user;
    END IF;
    
    SELECT first_name || ' ' || last_name INTO v_user_name
    FROM users WHERE id_user = p_id_user;
    
    -- Soft delete: marcar como inactivo
    UPDATE users
    SET 
        is_active = FALSE,
        updated_at = CURRENT_TIMESTAMP
    WHERE id_user = p_id_user;
    
    RETURN format('Usuario %s (ID: %s) desactivado correctamente.', v_user_name, p_id_user);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR USUARIO PERMANENTEMENTE
-- ============================
CREATE OR REPLACE FUNCTION hard_delete_user(
    p_id_user INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_user_name VARCHAR;
BEGIN
    SELECT EXISTS(SELECT 1 FROM users WHERE id_user = p_id_user) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un usuario con el ID %.', p_id_user;
    END IF;
    
    SELECT first_name || ' ' || last_name INTO v_user_name
    FROM users WHERE id_user = p_id_user;
    
    BEGIN
        DELETE FROM users WHERE id_user = p_id_user;
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE EXCEPTION 'No se puede eliminar el usuario % (ID: %) porque tiene registros asociados.', v_user_name, p_id_user;
    END;
    
    RETURN format('Usuario %s (ID: %s) eliminado permanentemente.', v_user_name, p_id_user);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER TODOS LOS USUARIOS
-- ============================
CREATE OR REPLACE FUNCTION get_all_users(
    p_include_inactive BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    id_user INTEGER,
    first_name VARCHAR,
    last_name VARCHAR,
    email VARCHAR,
    gender_id INTEGER,
    birth_date DATE,
    country_id VARCHAR,
    profile_photo VARCHAR,
    native_lang_id VARCHAR,
    target_lang_id VARCHAR,
    match_quantity INTEGER,
    bank_id VARCHAR,
    role_code VARCHAR,
    description TEXT,
    is_active BOOLEAN,
    email_verified BOOLEAN,
    last_login TIMESTAMP,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
)
AS
$$
BEGIN
    IF p_include_inactive THEN
        RETURN QUERY
        SELECT
            u.id_user, u.first_name, u.last_name, u.email,
            u.gender_id, u.birth_date, u.country_id, u.profile_photo,
            u.native_lang_id, u.target_lang_id, u.match_quantity,
            u.bank_id, u.role_code, u.description, u.is_active,
            u.email_verified, u.last_login, u.created_at, u.updated_at
        FROM users u
        ORDER BY u.created_at DESC;
    ELSE
        RETURN QUERY
        SELECT
            u.id_user, u.first_name, u.last_name, u.email,
            u.gender_id, u.birth_date, u.country_id, u.profile_photo,
            u.native_lang_id, u.target_lang_id, u.match_quantity,
            u.bank_id, u.role_code, u.description, u.is_active,
            u.email_verified, u.last_login, u.created_at, u.updated_at
        FROM users u
        WHERE u.is_active = TRUE
        ORDER BY u.created_at DESC;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER USUARIO POR ID
-- ============================
CREATE OR REPLACE FUNCTION get_user_by_id(
    p_id_user INTEGER
)
RETURNS TABLE (
    id_user INTEGER,
    first_name VARCHAR,
    last_name VARCHAR,
    email VARCHAR,
    gender_id INTEGER,
    birth_date DATE,
    country_id VARCHAR,
    profile_photo VARCHAR,
    native_lang_id VARCHAR,
    target_lang_id VARCHAR,
    match_quantity INTEGER,
    bank_id VARCHAR,
    role_code VARCHAR,
    description TEXT,
    is_active BOOLEAN,
    email_verified BOOLEAN,
    last_login TIMESTAMP,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        u.id_user, u.first_name, u.last_name, u.email,
        u.gender_id, u.birth_date, u.country_id, u.profile_photo,
        u.native_lang_id, u.target_lang_id, u.match_quantity,
        u.bank_id, u.role_code, u.description, u.is_active,
        u.email_verified, u.last_login, u.created_at, u.updated_at
    FROM users u
    WHERE u.id_user = p_id_user;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER USUARIO POR EMAIL
-- ============================
CREATE OR REPLACE FUNCTION get_user_by_email(
    p_email VARCHAR
)
RETURNS TABLE (
    id_user INTEGER,
    first_name VARCHAR,
    last_name VARCHAR,
    email VARCHAR,
    password_hash VARCHAR,
    gender_id INTEGER,
    birth_date DATE,
    country_id VARCHAR,
    profile_photo VARCHAR,
    native_lang_id VARCHAR,
    target_lang_id VARCHAR,
    match_quantity INTEGER,
    bank_id VARCHAR,
    role_code VARCHAR,
    description TEXT,
    is_active BOOLEAN,
    email_verified BOOLEAN,
    last_login TIMESTAMP,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        u.id_user, u.first_name, u.last_name, u.email, u.password_hash,
        u.gender_id, u.birth_date, u.country_id, u.profile_photo,
        u.native_lang_id, u.target_lang_id, u.match_quantity,
        u.bank_id, u.role_code, u.description, u.is_active,
        u.email_verified, u.last_login, u.created_at, u.updated_at
    FROM users u
    WHERE UPPER(u.email) = UPPER(p_email);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ACTUALIZAR ÚLTIMO LOGIN
-- ============================
CREATE OR REPLACE FUNCTION update_last_login(
    p_id_user INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM users WHERE id_user = p_id_user) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un usuario con el ID %.', p_id_user;
    END IF;
    
    UPDATE users
    SET last_login = CURRENT_TIMESTAMP
    WHERE id_user = p_id_user;
    
    RETURN format('Último login actualizado para usuario ID %s.', p_id_user);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: VERIFICAR EMAIL
-- ============================
CREATE OR REPLACE FUNCTION verify_user_email(
    p_id_user INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM users WHERE id_user = p_id_user) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un usuario con el ID %.', p_id_user;
    END IF;
    
    UPDATE users
    SET email_verified = TRUE
    WHERE id_user = p_id_user;
    
    RETURN format('Email verificado para usuario ID %s.', p_id_user);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: CAMBIAR ROL DE USUARIO
-- ============================
CREATE OR REPLACE FUNCTION change_user_role(
    p_id_user INTEGER,
    p_role_code VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_role_code_lower VARCHAR;
BEGIN
    SELECT EXISTS(SELECT 1 FROM users WHERE id_user = p_id_user) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un usuario con el ID %.', p_id_user;
    END IF;
    
    v_role_code_lower := LOWER(p_role_code);
    IF v_role_code_lower NOT IN ('admin', 'teacher', 'user') THEN
        RAISE EXCEPTION 'El rol debe ser: admin, teacher o user. Rol proporcionado: %.', p_role_code;
    END IF;
    
    UPDATE users
    SET 
        role_code = v_role_code_lower,
        updated_at = CURRENT_TIMESTAMP
    WHERE id_user = p_id_user;
    
    RETURN format('Rol cambiado a "%s" para usuario ID %s.', v_role_code_lower, p_id_user);
END;
$$ LANGUAGE plpgsql;