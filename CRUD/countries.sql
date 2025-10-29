-- Crear países

CREATE OR REPLACE FUNCTION add_country(
    p_country_code VARCHAR,
    p_country_name VARCHAR,
    p_timezone VARCHAR DEFAULT NULL
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_country_code_upper VARCHAR;
BEGIN
    -- ============================
    -- VALIDACIÓN Y NORMALIZACIÓN DEL CÓDIGO DEL PAÍS
    -- ============================
    IF p_country_code IS NULL OR LENGTH(TRIM(p_country_code)) = 0 THEN
        RAISE EXCEPTION 'El código del país no puede estar vacío.';
    ELSIF LENGTH(p_country_code) < 2 OR LENGTH(p_country_code) > 5 THEN
        RAISE EXCEPTION 'El código del país debe tener entre 2 y 5 caracteres.';
    END IF;
    
    -- Convertir country_code a mayúsculas
    v_country_code_upper := UPPER(p_country_code);
    
    IF v_country_code_upper !~ '^[A-Z]+$' THEN
        RAISE EXCEPTION 'El código de país debe contener solo letras.';
    END IF;
    
    -- ============================
    -- VALIDACIÓN DEL NOMBRE DEL PAÍS
    -- ============================
    IF p_country_name IS NULL OR LENGTH(TRIM(p_country_name)) = 0 THEN
        RAISE EXCEPTION 'El nombre del país no puede estar vacío.';
    ELSIF LENGTH(p_country_name) > 50 THEN
        RAISE EXCEPTION 'El nombre del país no puede tener más de 50 caracteres.';
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE ZONA HORARIA (si se proporciona)
    -- ============================
    IF p_timezone IS NOT NULL AND LENGTH(p_timezone) > 50 THEN
        RAISE EXCEPTION 'La zona horaria no puede tener más de 50 caracteres.';
    END IF;
    
    -- ============================
    -- VERIFICAR SI EL PAÍS YA EXISTE
    -- ============================
    SELECT EXISTS (
        SELECT 1 FROM countries 
        WHERE country_code = v_country_code_upper OR UPPER(country_name) = UPPER(p_country_name)
    ) INTO v_exists;
    
    IF v_exists THEN
        RAISE EXCEPTION 'Ya existe un país con el mismo código o nombre.';
    END IF;
    
    -- ============================
    -- INSERTAR REGISTRO
    -- ============================
    INSERT INTO countries (country_code, country_name, timezone)
    VALUES (v_country_code_upper, p_country_name, p_timezone);
    
    RETURN format('País %s (%s) agregado correctamente.', p_country_name, v_country_code_upper);
END;
$$ LANGUAGE plpgsql;


--Editar países
CREATE OR REPLACE FUNCTION update_country(
    p_country_code VARCHAR,
    p_country_name VARCHAR,
    p_timezone VARCHAR DEFAULT NULL
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_country_code_upper VARCHAR;
BEGIN
    -- ============================
    -- VALIDACIÓN Y NORMALIZACIÓN DEL CÓDIGO DEL PAÍS
    -- ============================
    IF p_country_code IS NULL OR LENGTH(TRIM(p_country_code)) = 0 THEN
        RAISE EXCEPTION 'El código del país no puede estar vacío.';
    ELSIF LENGTH(p_country_code) < 2 OR LENGTH(p_country_code) > 5 THEN
        RAISE EXCEPTION 'El código del país debe tener entre 2 y 5 caracteres.';
    END IF;
    
    -- Convertir country_code a mayúsculas
    v_country_code_upper := UPPER(p_country_code);
    
    -- ============================
    -- VERIFICAR EXISTENCIA DEL PAÍS
    -- ============================
    SELECT EXISTS(SELECT 1 FROM countries WHERE country_code = v_country_code_upper)
    INTO v_exists;
    
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe ningún país con el código %.', v_country_code_upper;
    END IF;
    
    -- ============================
    -- VALIDACIÓN DEL NOMBRE DEL PAÍS
    -- ============================
    IF p_country_name IS NULL OR LENGTH(TRIM(p_country_name)) = 0 THEN
        RAISE EXCEPTION 'El nombre del país no puede estar vacío.';
    ELSIF LENGTH(p_country_name) > 50 THEN
        RAISE EXCEPTION 'El nombre del país no puede tener más de 50 caracteres.';
    END IF;
    
    -- ============================
    -- VALIDAR QUE EL NUEVO NOMBRE NO ESTÉ REPETIDO EN OTRO PAÍS
    -- ============================
    SELECT EXISTS(
        SELECT 1 FROM countries
        WHERE UPPER(country_name) = UPPER(p_country_name)
        AND country_code <> v_country_code_upper
    ) INTO v_exists;
    
    IF v_exists THEN
        RAISE EXCEPTION 'Ya existe otro país con el nombre %.', p_country_name;
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE ZONA HORARIA
    -- ============================
    IF p_timezone IS NOT NULL AND LENGTH(p_timezone) > 50 THEN
        RAISE EXCEPTION 'La zona horaria no puede tener más de 50 caracteres.';
    END IF;
    
    -- ============================
    -- ACTUALIZAR PAÍS
    -- ============================
    UPDATE countries
    SET
        country_name = p_country_name,
        timezone = p_timezone,
        updated_at = CURRENT_TIMESTAMP
    WHERE country_code = v_country_code_upper;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No se pudo actualizar el país con código %.', v_country_code_upper;
    END IF;
    
    RETURN format('País %s (%s) actualizado correctamente.', p_country_name, v_country_code_upper);
END;
$$ LANGUAGE plpgsql;


--Función para obtener todos los países

CREATE OR REPLACE FUNCTION get_all_countries()
RETURNS TABLE (
    country_code VARCHAR,
    country_name VARCHAR,
    timezone VARCHAR,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT 
        c.country_code,
        c.country_name,
        c.timezone,
        c.created_at,
        c.updated_at
    FROM countries c
    ORDER BY c.country_name ASC;
END;
$$ LANGUAGE plpgsql;


--Se debe usar así:
-- SELECT * FROM get_all_countries();


CREATE OR REPLACE FUNCTION get_country_by_code(
    p_country_code VARCHAR
)
RETURNS TABLE (
    country_code VARCHAR,
    country_name VARCHAR,
    timezone VARCHAR,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
)
AS
$$
BEGIN
    -- Validar código del país
    IF p_country_code IS NULL OR LENGTH(TRIM(p_country_code)) = 0 THEN
        RAISE EXCEPTION 'El código del país no puede estar vacío.';
    ELSIF LENGTH(p_country_code) < 2 OR LENGTH(p_country_code) > 5 THEN
        RAISE EXCEPTION 'El código del país debe tener entre 2 y 5 caracteres.';
    END IF;

    -- Retornar el país correspondiente
    RETURN QUERY
    SELECT 
        country_code,
        country_name,
        timezone,
        created_at,
        updated_at
    FROM countries
    WHERE country_code = p_country_code;

    -- Si no se encontró ningún registro
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No se encontró ningún país con el código %.', p_country_code;
    END IF;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION delete_country_by_code(
    p_country_code VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    -- Validar código del país
    IF p_country_code IS NULL OR LENGTH(TRIM(p_country_code)) = 0 THEN
        RAISE EXCEPTION 'El código del país no puede estar vacío.';
    ELSIF LENGTH(p_country_code) < 2 OR LENGTH(p_country_code) > 5 THEN
        RAISE EXCEPTION 'El código del país debe tener entre 2 y 5 caracteres.';
    END IF;

    -- Verificar si el país existe
    SELECT EXISTS (
        SELECT 1 FROM countries WHERE country_code = p_country_code
    ) INTO v_exists;

    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe ningún país con el código %.', p_country_code;
    END IF;

    -- Eliminar país
    DELETE FROM countries WHERE country_code = p_country_code;

    RETURN format('El país con código %s fue eliminado correctamente.', p_country_code);
END;
$$ LANGUAGE plpgsql;




