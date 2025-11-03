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
    wbank_id users.bank_id%TYPE,
    wdescription users.description%TYPE,
    wrole_code users.role_code%TYPE       -- 🔹 nuevo parámetro agregado
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

    -- Inserción del usuario
    INSERT INTO users (
        first_name, last_name, email, password_hash, gender_id,
        birth_date, country_id, profile_photo, native_lang_id,
        target_lang_id, match_quantity, bank_id, description, role_code
    )
    VALUES (
        wfirst_name, wlast_name, wemail, wpassword_hash, wgender_id,
        wbirth_date, wcountry_id, wprofile_photo, wnative_lang_id,
        wtarget_lang_id, wmatch_quantity, wbank_id, wdescription, wrole_code
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