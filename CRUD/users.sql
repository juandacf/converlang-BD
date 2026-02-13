-- ======================================
-- FUNCIÓN: Insertar nuevo usuario
-- ======================================

CREATE OR REPLACE FUNCTION fun_insert_usuarios(
    wfirst_name users.first_name%TYPE,
    wlast_name users.last_name%TYPE,
    wemail users.email%TYPE,
    wpassword_hash users.password_hash%TYPE,
    wgender_id users.gender_id%TYPE,
    wbirth_date users.birth_date%TYPE,
    wcountry_id users.country_id%TYPE,
    wprofile_photo users.profile_photo%TYPE,
    wnative_lang_id users.native_lang_id%TYPE,
    wtarget_lang_id users.target_lang_id%TYPE,
    wmatch_quantity users.match_quantity%TYPE,
    wdescription users.description%TYPE,
    wrole_code users.role_code%TYPE
)
RETURNS SETOF users AS $$
DECLARE
    wuser_existe users.email%TYPE;
    wnew_user users%ROWTYPE;
    wrol_existe BOOLEAN;
BEGIN
    -- Validar si el email ya existe
    SELECT u.email INTO wuser_existe
    FROM users u
    WHERE LOWER(u.email) = LOWER(wemail);

    IF FOUND THEN
        RAISE EXCEPTION 'Error: El correo electrónico "%" ya está registrado', wemail
            USING ERRCODE = 'unique_violation';
    END IF;

    -- VALIDACIONES DE NOMBRE
    IF wfirst_name IS NULL OR TRIM(wfirst_name) = '' THEN
        RAISE EXCEPTION 'Error: El nombre no puede estar vacío';
    ELSIF LENGTH(TRIM(wfirst_name)) < 3 THEN
        RAISE EXCEPTION 'Error: El nombre debe tener al menos 3 caracteres';
    ELSIF LENGTH(TRIM(wfirst_name)) > 50 THEN
        RAISE EXCEPTION 'Error: El nombre no puede exceder 50 caracteres';
    ELSIF NOT (wfirst_name ~ '^[a-zA-Záéíóúñüç\s]+$') THEN
        RAISE EXCEPTION 'Error: El nombre solo puede contener letras y espacios';
    END IF;

    -- VALIDACIONES DE APELLIDO
    IF wlast_name IS NULL OR TRIM(wlast_name) = '' THEN
        RAISE EXCEPTION 'Error: El apellido no puede estar vacío';
    ELSIF LENGTH(TRIM(wlast_name)) < 3 THEN
        RAISE EXCEPTION 'Error: El apellido debe tener al menos 3 caracteres';
    ELSIF LENGTH(TRIM(wlast_name)) > 50 THEN
        RAISE EXCEPTION 'Error: El apellido no puede exceder 50 caracteres';
    ELSIF NOT (wlast_name ~ '^[a-zA-Záéíóúñüç\s]+$') THEN
        RAISE EXCEPTION 'Error: El apellido solo puede contener letras y espacios';
    END IF;

    -- Validar país, idiomas y edad
    IF NOT fun_valida_pais(wcountry_id) THEN
        RAISE EXCEPTION 'Error: País no válido';
    END IF;

    IF NOT fun_valida_idioma(wnative_lang_id) THEN
        RAISE EXCEPTION 'Error: Idioma nativo no válido';
    END IF;

    IF NOT fun_valida_idioma(wtarget_lang_id) THEN
        RAISE EXCEPTION 'Error: Idioma objetivo no válido';
    END IF;

    IF wnative_lang_id = wtarget_lang_id THEN
        RAISE EXCEPTION 'Error: Los idiomas nativo y objetivo deben ser diferentes';
    END IF;

    IF wbirth_date > CURRENT_DATE - INTERVAL '15 years' THEN
        RAISE EXCEPTION 'Error: Debe tener al menos 15 años para registrarse';
    END IF;

    -- Validar rol
    SELECT TRUE INTO wrol_existe
    FROM user_roles
    WHERE role_code = wrole_code;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Error: El rol "%" no es válido', wrole_code;
    END IF;

    -- Inserción del usuario CON is_active = TRUE 
    INSERT INTO users (
        first_name, last_name, email, password_hash, gender_id,
        birth_date, country_id, profile_photo, native_lang_id,
        target_lang_id, match_quantity, description, role_code, is_active
    )
    VALUES (
        wfirst_name, wlast_name, wemail, wpassword_hash, wgender_id,
        wbirth_date, wcountry_id, wprofile_photo, wnative_lang_id,
        wtarget_lang_id, wmatch_quantity, wdescription, wrole_code, TRUE
    )
    RETURNING * INTO wnew_user;

    RETURN NEXT wnew_user;
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- FUNCIÓN PARA VALIDAR EXISTENCIA DE PAÍS
-- Función que valida si un código de país existe en la tabla countries.
CREATE OR REPLACE FUNCTION fun_valida_pais(wid_pais countries.country_code%TYPE) 
RETURNS BOOLEAN AS $$
DECLARE 
    wnom_pais countries.country_name%TYPE;
BEGIN
    SELECT c.country_name INTO wnom_pais 
    FROM countries c 
    WHERE c.country_code = wid_pais;

    IF FOUND THEN
        RAISE NOTICE 'País válido: %', wnom_pais;
        RETURN TRUE;
    ELSE
        RAISE NOTICE 'ERROR: El país con código % no existe', wid_pais;
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;


/*
 PROPÓSITO:
   Esta función es útil en validaciones previas a inserciones o actualizaciones
   de registros que dependan de la existencia de un idioma válido.
*/

-- FUNCIÓN PARA VALIDAR EXISTENCIA DE IDIOMA
-- Función que valida si un código de idioma existe en la tabla languages.
CREATE OR REPLACE FUNCTION fun_valida_idioma(wid_idioma languages.language_code%TYPE) 
RETURNS BOOLEAN AS $$
DECLARE 
    wnom_idioma languages.language_name%TYPE;
BEGIN
    SELECT l.language_name INTO wnom_idioma 
    FROM languages l 
    WHERE l.language_code = wid_idioma;
    
        IF FOUND THEN
        RAISE NOTICE 'Idioma válido: %', wnom_idioma;
        RETURN TRUE;
    ELSE
        RAISE NOTICE 'ERROR: El idioma con código % no existe', wid_idioma;
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

/*
    . Función 'fun_increme_user':
        - Retorna el siguiente valor disponible de la secuencia.
        - Permite obtener un nuevo ID de usuario de forma controlada y segura 
        desde la aplicación o procedimientos almacenados.
*/

CREATE OR REPLACE FUNCTION fun_increm_user()
RETURNS INTEGER AS $$
DECLARE
    v_next_id INTEGER;
BEGIN
    SELECT COALESCE(MAX(id_user), 0) + 1
    INTO v_next_id
    FROM users;

    RETURN v_next_id;
END;
$$ LANGUAGE plpgsql;

-- se agigna la función como default en id_user
ALTER TABLE users
ALTER COLUMN id_user SET DEFAULT fun_increm_user();



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
    p_profile_photo VARCHAR,
    p_native_lang_id VARCHAR,
    p_target_lang_id VARCHAR,
    p_match_quantity INTEGER,
    p_description TEXT
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_country_id_upper VARCHAR;
    v_native_lang_upper VARCHAR;
    v_target_lang_upper VARCHAR;
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
        profile_photo = COALESCE(NULLIF(p_profile_photo, ''), profile_photo),
        native_lang_id = v_native_lang_upper,
        target_lang_id = v_target_lang_upper,
        match_quantity = p_match_quantity,
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
            u.role_code, u.description, u.is_active,
            u.email_verified, u.last_login, u.created_at, u.updated_at
        FROM users u
        ORDER BY u.created_at DESC;
    ELSE
        RETURN QUERY
        SELECT
            u.id_user, u.first_name, u.last_name, u.email,
            u.gender_id, u.birth_date, u.country_id, u.profile_photo,
            u.native_lang_id, u.target_lang_id, u.match_quantity,
            u.role_code, u.description, u.is_active,
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
        u.role_code, u.description, u.is_active,
        u.email_verified, u.last_login, u.created_at, u.updated_at
    FROM users u
    WHERE u.id_user = p_id_user;
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

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fun_find_user_by_email(p_email VARCHAR)
RETURNS TABLE (
    id_user INTEGER,
    first_name VARCHAR,
    last_name VARCHAR,
    email VARCHAR,
    password_hash VARCHAR,
    role_code VARCHAR,
    role_name VARCHAR,
    is_active BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id_user,
        u.first_name,
        u.last_name,
        u.email,
        u.password_hash,
        u.role_code,
        r.role_name,
        u.is_active
    FROM users u
    LEFT JOIN user_roles r ON r.role_code = u.role_code
    WHERE u.email = p_email;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


CREATE OR REPLACE FUNCTION fun_get_user_matches(p_user_id INTEGER)
RETURNS TABLE (
    match_id INTEGER,
    matched_user_id INTEGER,
    match_time TIMESTAMP,
    first_name VARCHAR,
    last_name VARCHAR,
    email VARCHAR,
    profile_photo VARCHAR
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.match_id,
        CASE 
            WHEN m.user_1 = p_user_id THEN m.user_2
            ELSE m.user_1
        END AS matched_user_id,
        m.match_time,
        u.first_name,
        u.last_name,
        u.email,
        u.profile_photo
    FROM user_matches m
    JOIN users u 
        ON u.id_user = CASE 
                           WHEN m.user_1 = p_user_id THEN m.user_2
                           ELSE m.user_1
                       END
    WHERE m.user_1 = p_user_id OR m.user_2 = p_user_id
    ORDER BY m.match_time DESC;
END;
$$;


CREATE OR REPLACE FUNCTION get_user_age(p_id_user INTEGER)
RETURNS INTEGER AS
$$
DECLARE
    v_birth_date DATE;
    v_age INTEGER;
BEGIN
    -- Obtener fecha de nacimiento del usuario
    SELECT birth_date INTO v_birth_date
    FROM users
    WHERE id_user = p_id_user;

    -- Si no existe el usuario
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El usuario con ID % no existe.', p_id_user;
    END IF;

    -- Calcular edad exacta
    SELECT EXTRACT(YEAR FROM age(CURRENT_DATE, v_birth_date))::INTEGER
    INTO v_age;

    RETURN v_age;
END;
$$ LANGUAGE plpgsql STABLE;


CREATE OR REPLACE FUNCTION update_user_photo(
    p_id_user INTEGER,
    p_photo_path VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    -- Verificar si el usuario existe
    SELECT EXISTS(SELECT 1 FROM users WHERE id_user = p_id_user)
    INTO v_exists;

    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un usuario con el ID %.', p_id_user;
    END IF;

    -- Validación opcional del tamaño de la URL
    IF p_photo_path IS NOT NULL AND LENGTH(p_photo_path) > 255 THEN
        RAISE EXCEPTION 'La ruta de la foto no puede exceder 255 caracteres.';
    END IF;

    -- Actualizar la foto del usuario
    UPDATE users
    SET 
        profile_photo = p_photo_path,
        updated_at = CURRENT_TIMESTAMP
    WHERE id_user = p_id_user;

    RETURN format('Foto de usuario %s actualizada correctamente.', p_id_user);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ACTUALIZAR CONTRASEA
-- ============================
CREATE OR REPLACE FUNCTION update_user_password(
    p_id_user INTEGER,
    p_password_hash VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    -- Verificar si el usuario existe
    SELECT EXISTS(SELECT 1 FROM users WHERE id_user = p_id_user) INTO v_exists;
    
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un usuario con el ID %.', p_id_user;
    END IF;
    
    -- Actualizar contraseña
    UPDATE users
    SET 
        password_hash = p_password_hash,
        updated_at = CURRENT_TIMESTAMP
    WHERE id_user = p_id_user;
    
    RETURN format('Contraseña actualizada correctamente para el usuario ID %s.', p_id_user);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fun_get_potential_users(p_id_user INTEGER)
RETURNS TABLE (
    id_user INTEGER,
    first_name VARCHAR,
    last_name VARCHAR,
    email VARCHAR,
    native_lang_id_out VARCHAR,
    target_lang_id_out VARCHAR,
    description TEXT,
    profile_photo VARCHAR,
    country_id VARCHAR,   
    age INTEGER
)
AS $$
DECLARE
    v_user_native VARCHAR(2);
    v_user_target VARCHAR(2);
BEGIN
    -- Obtener los idiomas del usuario base
    SELECT u.native_lang_id, u.target_lang_id
    INTO v_user_native, v_user_target
    FROM users u
    WHERE u.id_user = p_id_user;   

    RETURN QUERY
    SELECT 
        u2.id_user,
        u2.first_name,
        u2.last_name,
        u2.email,
        u2.native_lang_id AS native_lang_id_out,
        u2.target_lang_id AS target_lang_id_out,
        u2.description,
        u2.profile_photo,
        u2.country_id,  
        EXTRACT(YEAR FROM age(CURRENT_DATE, u2.birth_date))::INTEGER AS age
    FROM users u2
    WHERE 
        u2.native_lang_id = v_user_target
        AND u2.target_lang_id = v_user_native
        AND u2.id_user <> p_id_user
        AND u2.is_active = TRUE
        AND u2.role_code = 'user'
        AND NOT EXISTS (
            SELECT 1
            FROM user_likes ul
            WHERE ul.id_user_giver = p_id_user
              AND ul.id_user_receiver = u2.id_user
        )
        AND NOT EXISTS (
            SELECT 1
            FROM user_matches m
            WHERE (m.user_1 = p_id_user AND m.user_2 = u2.id_user)
               OR (m.user_2 = p_id_user AND m.user_1 = u2.id_user)
        )
    ORDER BY u2.last_login DESC;
END;
$$ LANGUAGE plpgsql;

-- generar reporte de usuario que infringe con las reglas de la comunidad, si este tiene mas de 3 reportes su cuenta será incativada
CREATE OR REPLACE FUNCTION fun_generate_report(p_id_user INTEGER)
RETURNS TABLE (
    o_id_user INTEGER,
    o_first_name VARCHAR,
    o_last_name VARCHAR,
    o_email VARCHAR,
    o_report_quantity INTEGER,
    o_is_active BOOLEAN
) AS $$
BEGIN
    --Incrementa el contador
    UPDATE users
    SET report_quantity = report_quantity + 1
    WHERE id_user = p_id_user;

    -- Retornamos los datos actualizados
    RETURN QUERY
    SELECT u.id_user, u.first_name, u.last_name, u.email, u.report_quantity, u.is_active
    FROM users u
    WHERE u.id_user = p_id_user;
END;
$$ LANGUAGE plpgsql;


