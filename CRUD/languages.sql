-- Función para obtener todos los idiomas
CREATE OR REPLACE FUNCTION get_all_languages()
RETURNS TABLE (
    language_code VARCHAR(2),
    language_name VARCHAR(100),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.language_code,
        l.language_name,
        l.created_at,
        l.updated_at
    FROM languages l
    ORDER BY l.language_name;
END;
$$;

-- Función para obtener un idioma por su código (language_code)
CREATE OR REPLACE FUNCTION get_language_by_id(p_language_code VARCHAR(2))
RETURNS TABLE (
    language_code VARCHAR(2),
    language_name VARCHAR(100),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) 
LANGUAGE plpgsql
AS $
BEGIN
    RETURN QUERY
    SELECT 
        l.language_code,
        l.language_name,
        l.created_at,
        l.updated_at
    FROM languages l
    WHERE l.language_code = p_language_code;
END;
$;


-- Función para crear un nuevo idioma
CREATE OR REPLACE FUNCTION create_language(
    p_language_code VARCHAR(2),
    p_language_name VARCHAR(100)
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT,
    language_code VARCHAR(2),
    language_name VARCHAR(100),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
)
LANGUAGE plpgsql
AS $
DECLARE
    v_exists_code BOOLEAN;
    v_exists_name BOOLEAN;
    v_created_at TIMESTAMP;
    v_updated_at TIMESTAMP;
BEGIN
    -- Validación: el código no puede ser nulo o vacío
    IF p_language_code IS NULL OR TRIM(p_language_code) = '' THEN
        RETURN QUERY SELECT FALSE, 'El código del idioma es requerido'::TEXT, NULL::VARCHAR(2), NULL::VARCHAR(100), NULL::TIMESTAMP, NULL::TIMESTAMP;
        RETURN;
    END IF;

    -- Validación: el código debe tener exactamente 2 caracteres
    IF LENGTH(TRIM(p_language_code)) != 2 THEN
        RETURN QUERY SELECT FALSE, 'El código del idioma debe tener exactamente 2 caracteres'::TEXT, NULL::VARCHAR(2), NULL::VARCHAR(100), NULL::TIMESTAMP, NULL::TIMESTAMP;
        RETURN;
    END IF;

    -- Validación: el nombre no puede ser nulo o vacío
    IF p_language_name IS NULL OR TRIM(p_language_name) = '' THEN
        RETURN QUERY SELECT FALSE, 'El nombre del idioma es requerido'::TEXT, NULL::VARCHAR(2), NULL::VARCHAR(100), NULL::TIMESTAMP, NULL::TIMESTAMP;
        RETURN;
    END IF;

    -- Convertir el código a mayúsculas para estandarizar
    p_language_code := UPPER(TRIM(p_language_code));
    p_language_name := TRIM(p_language_name);

    -- Verificar si ya existe un idioma con ese código
    SELECT EXISTS(SELECT 1 FROM languages WHERE languages.language_code = p_language_code) INTO v_exists_code;
    
    IF v_exists_code THEN
        RETURN QUERY SELECT FALSE, 'Ya existe un idioma con el código: ' || p_language_code, NULL::VARCHAR(2), NULL::VARCHAR(100), NULL::TIMESTAMP, NULL::TIMESTAMP;
        RETURN;
    END IF;

    -- Verificar si ya existe un idioma con ese nombre
    SELECT EXISTS(SELECT 1 FROM languages WHERE LOWER(languages.language_name) = LOWER(p_language_name)) INTO v_exists_name;
    
    IF v_exists_name THEN
        RETURN QUERY SELECT FALSE, 'Ya existe un idioma con el nombre: ' || p_language_name, NULL::VARCHAR(2), NULL::VARCHAR(100), NULL::TIMESTAMP, NULL::TIMESTAMP;
        RETURN;
    END IF;

    -- Obtener timestamp actual
    v_created_at := CURRENT_TIMESTAMP;
    v_updated_at := CURRENT_TIMESTAMP;

    -- Insertar el nuevo idioma
    INSERT INTO languages (language_code, language_name, created_at, updated_at)
    VALUES (p_language_code, p_language_name, v_created_at, v_updated_at);

    -- Retornar el resultado exitoso con los datos creados
    RETURN QUERY SELECT TRUE, 'Idioma creado exitosamente'::TEXT, p_language_code, p_language_name, v_created_at, v_updated_at;
END;
$;