-- ============================
-- FUNCIÓN: AGREGAR TÍTULO
-- ============================
CREATE OR REPLACE FUNCTION add_title(
    p_title_code VARCHAR,
    p_title_name VARCHAR,
    p_title_description VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_title_code_normalized VARCHAR;
BEGIN
    -- ============================
    -- VALIDACIÓN Y NORMALIZACIÓN DE TITLE_CODE
    -- ============================
    IF p_title_code IS NULL OR LENGTH(TRIM(p_title_code)) = 0 THEN
        RAISE EXCEPTION 'El código del título no puede estar vacío.';
    ELSIF LENGTH(p_title_code) > 50 THEN
        RAISE EXCEPTION 'El código del título no puede tener más de 50 caracteres.';
    END IF;
    
    -- Normalizar: convertir a minúsculas y reemplazar espacios por guiones bajos
    v_title_code_normalized := LOWER(TRIM(REGEXP_REPLACE(p_title_code, '\s+', '_', 'g')));
    
    -- Validar que solo contenga letras, números y guiones bajos
    IF v_title_code_normalized !~ '^[a-z0-9_]+$' THEN
        RAISE EXCEPTION 'El código del título solo puede contener letras, números y guiones bajos.';
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE TITLE_NAME
    -- ============================
    IF p_title_name IS NULL OR LENGTH(TRIM(p_title_name)) = 0 THEN
        RAISE EXCEPTION 'El nombre del título no puede estar vacío.';
    ELSIF LENGTH(p_title_name) > 100 THEN
        RAISE EXCEPTION 'El nombre del título no puede tener más de 100 caracteres.';
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE TITLE_DESCRIPTION
    -- ============================
    IF p_title_description IS NULL OR LENGTH(TRIM(p_title_description)) = 0 THEN
        RAISE EXCEPTION 'La descripción del título no puede estar vacía.';
    ELSIF LENGTH(p_title_description) > 255 THEN
        RAISE EXCEPTION 'La descripción del título no puede tener más de 255 caracteres.';
    END IF;
    
    -- ============================
    -- VERIFICAR DUPLICADOS
    -- ============================
    SELECT EXISTS(
        SELECT 1 FROM titles 
        WHERE title_code = v_title_code_normalized 
        OR UPPER(title_name) = UPPER(p_title_name)
    ) INTO v_exists;
    
    IF v_exists THEN
        RAISE EXCEPTION 'Ya existe un título con el mismo código o nombre.';
    END IF;
    
    -- ============================
    -- INSERTAR TÍTULO
    -- ============================
    INSERT INTO titles (title_code, title_name, title_description)
    VALUES (v_title_code_normalized, p_title_name, p_title_description);
    
    RETURN format('Título "%s" (%s) agregado correctamente.', p_title_name, v_title_code_normalized);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ACTUALIZAR TÍTULO
-- ============================
CREATE OR REPLACE FUNCTION update_title(
    p_title_code VARCHAR,
    p_title_name VARCHAR,
    p_title_description VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_title_code_normalized VARCHAR;
BEGIN
    -- ============================
    -- NORMALIZACIÓN DE TITLE_CODE
    -- ============================
    IF p_title_code IS NULL OR LENGTH(TRIM(p_title_code)) = 0 THEN
        RAISE EXCEPTION 'El código del título no puede estar vacío.';
    END IF;
    
    v_title_code_normalized := LOWER(TRIM(REGEXP_REPLACE(p_title_code, '\s+', '_', 'g')));
    
    -- ============================
    -- VERIFICAR EXISTENCIA DEL TÍTULO
    -- ============================
    SELECT EXISTS(SELECT 1 FROM titles WHERE title_code = v_title_code_normalized) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un título con el código %.', v_title_code_normalized;
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE TITLE_NAME
    -- ============================
    IF p_title_name IS NULL OR LENGTH(TRIM(p_title_name)) = 0 THEN
        RAISE EXCEPTION 'El nombre del título no puede estar vacío.';
    ELSIF LENGTH(p_title_name) > 100 THEN
        RAISE EXCEPTION 'El nombre del título no puede tener más de 100 caracteres.';
    END IF;
    
    -- ============================
    -- VALIDACIÓN DE TITLE_DESCRIPTION
    -- ============================
    IF p_title_description IS NULL OR LENGTH(TRIM(p_title_description)) = 0 THEN
        RAISE EXCEPTION 'La descripción del título no puede estar vacía.';
    ELSIF LENGTH(p_title_description) > 255 THEN
        RAISE EXCEPTION 'La descripción del título no puede tener más de 255 caracteres.';
    END IF;
    
    -- ============================
    -- VALIDAR QUE EL NUEVO NOMBRE NO ESTÉ REPETIDO
    -- ============================
    SELECT EXISTS(
        SELECT 1 FROM titles
        WHERE UPPER(title_name) = UPPER(p_title_name)
        AND title_code <> v_title_code_normalized
    ) INTO v_exists;
    
    IF v_exists THEN
        RAISE EXCEPTION 'Ya existe otro título con el nombre %.', p_title_name;
    END IF;
    
    -- ============================
    -- ACTUALIZAR TÍTULO
    -- ============================
    UPDATE titles
    SET
        title_name = p_title_name,
        title_description = p_title_description
    WHERE title_code = v_title_code_normalized;
    
    RETURN format('Título "%s" (%s) actualizado correctamente.', p_title_name, v_title_code_normalized);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR TÍTULO
-- ============================
CREATE OR REPLACE FUNCTION delete_title(
    p_title_code VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_title_code_normalized VARCHAR;
    v_title_name VARCHAR;
BEGIN
    -- ============================
    -- NORMALIZACIÓN DE TITLE_CODE
    -- ============================
    IF p_title_code IS NULL OR LENGTH(TRIM(p_title_code)) = 0 THEN
        RAISE EXCEPTION 'El código del título no puede estar vacío.';
    END IF;
    
    v_title_code_normalized := LOWER(TRIM(REGEXP_REPLACE(p_title_code, '\s+', '_', 'g')));
    
    -- ============================
    -- VERIFICAR EXISTENCIA Y OBTENER NOMBRE
    -- ============================
    SELECT title_name INTO v_title_name
    FROM titles
    WHERE title_code = v_title_code_normalized;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe un título con el código %.', v_title_code_normalized;
    END IF;
    
    -- ============================
    -- ELIMINAR TÍTULO (CON MANEJO DE FK)
    -- ============================
    BEGIN
        DELETE FROM titles WHERE title_code = v_title_code_normalized;
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE EXCEPTION 'No se puede eliminar el título "%" (%) porque tiene registros asociados.', v_title_name, v_title_code_normalized;
    END;
    
    RETURN format('Título "%s" (%s) eliminado correctamente.', v_title_name, v_title_code_normalized);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER TODOS LOS TÍTULOS
-- ============================
CREATE OR REPLACE FUNCTION get_all_titles()
RETURNS TABLE (
    title_code VARCHAR,
    title_name VARCHAR,
    title_description VARCHAR
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        t.title_code,
        t.title_name,
        t.title_description
    FROM titles t
    ORDER BY t.title_name ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER TÍTULO POR CÓDIGO
-- ============================
CREATE OR REPLACE FUNCTION get_title_by_code(
    p_title_code VARCHAR
)
RETURNS TABLE (
    title_code VARCHAR,
    title_name VARCHAR,
    title_description VARCHAR
)
AS
$$
DECLARE
    v_title_code_normalized VARCHAR;
BEGIN
    v_title_code_normalized := LOWER(TRIM(REGEXP_REPLACE(p_title_code, '\s+', '_', 'g')));
    
    RETURN QUERY
    SELECT
        t.title_code,
        t.title_name,
        t.title_description
    FROM titles t
    WHERE t.title_code = v_title_code_normalized;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: BUSCAR TÍTULOS POR NOMBRE
-- ============================
CREATE OR REPLACE FUNCTION search_titles(
    p_search_term VARCHAR
)
RETURNS TABLE (
    title_code VARCHAR,
    title_name VARCHAR,
    title_description VARCHAR
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        t.title_code,
        t.title_name,
        t.title_description
    FROM titles t
    WHERE UPPER(t.title_name) LIKE '%' || UPPER(p_search_term) || '%'
    OR UPPER(t.title_description) LIKE '%' || UPPER(p_search_term) || '%'
    ORDER BY t.title_name ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: VERIFICAR SI EXISTE UN TÍTULO
-- ============================
CREATE OR REPLACE FUNCTION title_exists(
    p_title_code VARCHAR
)
RETURNS BOOLEAN AS
$$
DECLARE
    v_exists BOOLEAN;
    v_title_code_normalized VARCHAR;
BEGIN
    v_title_code_normalized := LOWER(TRIM(REGEXP_REPLACE(p_title_code, '\s+', '_', 'g')));
    
    SELECT EXISTS(
        SELECT 1 FROM titles WHERE title_code = v_title_code_normalized
    ) INTO v_exists;
    
    RETURN v_exists;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: CONTAR TOTAL DE TÍTULOS
-- ============================
CREATE OR REPLACE FUNCTION count_titles()
RETURNS INTEGER AS
$$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM titles;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER TÍTULOS CON ESTADÍSTICAS DE USO
-- ============================
CREATE OR REPLACE FUNCTION get_titles_with_usage_stats()
RETURNS TABLE (
    title_code VARCHAR,
    title_name VARCHAR,
    title_description VARCHAR,
    users_with_title INTEGER
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        t.title_code,
        t.title_name,
        t.title_description,
        COALESCE(
            (SELECT COUNT(DISTINCT user_id)::INTEGER 
             FROM user_titles ut 
             WHERE ut.title_code = t.title_code),
            0
        ) as users_with_title
    FROM titles t
    ORDER BY users_with_title DESC, t.title_name ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN AUXILIAR: NORMALIZAR CÓDIGO DE TÍTULO
-- ============================
CREATE OR REPLACE FUNCTION normalize_title_code(
    p_title_code VARCHAR
)
RETURNS VARCHAR AS
$$
BEGIN
    -- Convierte a minúsculas, elimina espacios extras y reemplaza espacios por guiones bajos
    RETURN LOWER(TRIM(REGEXP_REPLACE(p_title_code, '\s+', '_', 'g')));
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: IMPORTAR TÍTULOS EN LOTE (ADMIN)
-- ============================
CREATE OR REPLACE FUNCTION bulk_insert_titles(
    p_titles_json JSONB
)
RETURNS TEXT AS
$$
DECLARE
    v_title JSONB;
    v_inserted INTEGER := 0;
    v_skipped INTEGER := 0;
    v_title_code VARCHAR;
    v_exists BOOLEAN;
BEGIN
    -- Iterar sobre el array JSON de títulos
    FOR v_title IN SELECT * FROM jsonb_array_elements(p_titles_json)
    LOOP
        -- Normalizar código
        v_title_code := normalize_title_code(v_title->>'title_code');
        
        -- Verificar si ya existe
        SELECT EXISTS(SELECT 1 FROM titles WHERE title_code = v_title_code) INTO v_exists;
        
        IF NOT v_exists THEN
            -- Insertar título
            INSERT INTO titles (title_code, title_name, title_description)
            VALUES (
                v_title_code,
                v_title->>'title_name',
                v_title->>'title_description'
            );
            v_inserted := v_inserted + 1;
        ELSE
            v_skipped := v_skipped + 1;
        END IF;
    END LOOP;
    
    RETURN format('Importación completada: %s títulos insertados, %s omitidos (ya existían).', v_inserted, v_skipped);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: VALIDAR FORMATO DE TÍTULO
-- ============================
CREATE OR REPLACE FUNCTION validate_title_format(
    p_title_code VARCHAR,
    p_title_name VARCHAR,
    p_title_description VARCHAR
)
RETURNS TABLE (
    is_valid BOOLEAN,
    error_message TEXT
)
AS
$$
DECLARE
    v_title_code_normalized VARCHAR;
BEGIN
    -- Validar title_code
    IF p_title_code IS NULL OR LENGTH(TRIM(p_title_code)) = 0 THEN
        RETURN QUERY SELECT FALSE, 'El código del título no puede estar vacío.'::TEXT;
        RETURN;
    END IF;
    
    IF LENGTH(p_title_code) > 50 THEN
        RETURN QUERY SELECT FALSE, 'El código del título excede 50 caracteres.'::TEXT;
        RETURN;
    END IF;
    
    v_title_code_normalized := normalize_title_code(p_title_code);
    
    IF v_title_code_normalized !~ '^[a-z0-9_]+$' THEN
        RETURN QUERY SELECT FALSE, 'El código del título solo puede contener letras, números y guiones bajos.'::TEXT;
        RETURN;
    END IF;
    
    -- Validar title_name
    IF p_title_name IS NULL OR LENGTH(TRIM(p_title_name)) = 0 THEN
        RETURN QUERY SELECT FALSE, 'El nombre del título no puede estar vacío.'::TEXT;
        RETURN;
    END IF;
    
    IF LENGTH(p_title_name) > 100 THEN
        RETURN QUERY SELECT FALSE, 'El nombre del título excede 100 caracteres.'::TEXT;
        RETURN;
    END IF;
    
    -- Validar title_description
    IF p_title_description IS NULL OR LENGTH(TRIM(p_title_description)) = 0 THEN
        RETURN QUERY SELECT FALSE, 'La descripción del título no puede estar vacía.'::TEXT;
        RETURN;
    END IF;
    
    IF LENGTH(p_title_description) > 255 THEN
        RETURN QUERY SELECT FALSE, 'La descripción del título excede 255 caracteres.'::TEXT;
        RETURN;
    END IF;
    
    -- Todo válido
    RETURN QUERY SELECT TRUE, 'Formato válido.'::TEXT;
END;
$$ LANGUAGE plpgsql;