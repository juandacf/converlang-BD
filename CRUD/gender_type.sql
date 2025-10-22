-- ============================
-- FUNCIÓN: AGREGAR TIPO DE GÉNERO
-- ============================
CREATE OR REPLACE FUNCTION add_gender_type(
    p_gender_name VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_gender_id INTEGER;
BEGIN
    -- ============================
    -- VALIDACIÓN DEL NOMBRE DEL GÉNERO
    -- ============================
    IF p_gender_name IS NULL OR LENGTH(TRIM(p_gender_name)) = 0 THEN
        RAISE EXCEPTION 'El nombre del género no puede estar vacío.';
    ELSIF LENGTH(p_gender_name) > 30 THEN
        RAISE EXCEPTION 'El nombre del género no puede tener más de 30 caracteres.';
    END IF;
    
    -- ============================
    -- VERIFICAR SI EL GÉNERO YA EXISTE
    -- ============================
    SELECT EXISTS (
        SELECT 1 FROM gender_type 
        WHERE UPPER(gender_name) = UPPER(p_gender_name)
    ) INTO v_exists;
    
    IF v_exists THEN
        RAISE EXCEPTION 'Ya existe un género con el nombre %.', p_gender_name;
    END IF;
    
    -- ============================
    -- INSERTAR REGISTRO
    -- ============================
    INSERT INTO gender_type (gender_name)
    VALUES (p_gender_name)
    RETURNING gender_id INTO v_gender_id;
    
    RETURN format('Género "%s" agregado correctamente con ID %s.', p_gender_name, v_gender_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ACTUALIZAR TIPO DE GÉNERO
-- ============================
CREATE OR REPLACE FUNCTION update_gender_type(
    p_gender_id INTEGER,
    p_gender_name VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_old_name VARCHAR;
BEGIN
    -- ============================
    -- VALIDACIÓN DEL ID
    -- ============================
    IF p_gender_id IS NULL THEN
        RAISE EXCEPTION 'El ID del género no puede estar vacío.';
    END IF;
    
    -- ============================
    -- VERIFICAR EXISTENCIA DEL GÉNERO
    -- ============================
    SELECT gender_name INTO v_old_name
    FROM gender_type
    WHERE gender_id = p_gender_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe ningún género con el ID %.', p_gender_id;
    END IF;
    
    -- ============================
    -- VALIDACIÓN DEL NOMBRE DEL GÉNERO
    -- ============================
    IF p_gender_name IS NULL OR LENGTH(TRIM(p_gender_name)) = 0 THEN
        RAISE EXCEPTION 'El nombre del género no puede estar vacío.';
    ELSIF LENGTH(p_gender_name) > 30 THEN
        RAISE EXCEPTION 'El nombre del género no puede tener más de 30 caracteres.';
    END IF;
    
    -- ============================
    -- VALIDAR QUE EL NUEVO NOMBRE NO ESTÉ REPETIDO EN OTRO GÉNERO
    -- ============================
    SELECT EXISTS(
        SELECT 1 FROM gender_type
        WHERE UPPER(gender_name) = UPPER(p_gender_name)
        AND gender_id <> p_gender_id
    ) INTO v_exists;
    
    IF v_exists THEN
        RAISE EXCEPTION 'Ya existe otro género con el nombre %.', p_gender_name;
    END IF;
    
    -- ============================
    -- ACTUALIZAR GÉNERO
    -- ============================
    UPDATE gender_type
    SET gender_name = p_gender_name
    WHERE gender_id = p_gender_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No se pudo actualizar el género con ID %.', p_gender_id;
    END IF;
    
    RETURN format('Género actualizado de "%s" a "%s" (ID: %s).', v_old_name, p_gender_name, p_gender_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR TIPO DE GÉNERO
-- ============================
CREATE OR REPLACE FUNCTION delete_gender_type(
    p_gender_id INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_gender_name VARCHAR;
BEGIN
    -- ============================
    -- VALIDACIÓN DEL ID
    -- ============================
    IF p_gender_id IS NULL THEN
        RAISE EXCEPTION 'El ID del género no puede estar vacío.';
    END IF;
    
    -- ============================
    -- VERIFICAR EXISTENCIA Y OBTENER NOMBRE DEL GÉNERO
    -- ============================
    SELECT gender_name INTO v_gender_name
    FROM gender_type
    WHERE gender_id = p_gender_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe ningún género con el ID %.', p_gender_id;
    END IF;
    
    -- ============================
    -- ELIMINAR EL GÉNERO (MANEJO SEGURO)
    -- ============================
    BEGIN
        DELETE FROM gender_type
        WHERE gender_id = p_gender_id;
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE EXCEPTION 'No se puede eliminar el género "%" (ID: %) porque tiene registros asociados.', v_gender_name, p_gender_id;
    END;
    
    RETURN format('Género "%s" (ID: %s) eliminado correctamente.', v_gender_name, p_gender_id);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER TODOS LOS TIPOS DE GÉNERO
-- ============================
CREATE OR REPLACE FUNCTION get_all_gender_types()
RETURNS TABLE (
    gender_id INTEGER,
    gender_name VARCHAR
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        g.gender_id,
        g.gender_name
    FROM gender_type g
    ORDER BY g.gender_name ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER UN TIPO DE GÉNERO POR ID
-- ============================
CREATE OR REPLACE FUNCTION get_gender_type_by_id(
    p_gender_id INTEGER
)
RETURNS TABLE (
    gender_id INTEGER,
    gender_name VARCHAR
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        g.gender_id,
        g.gender_name
    FROM gender_type g
    WHERE g.gender_id = p_gender_id;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: BUSCAR TIPOS DE GÉNERO POR NOMBRE (BÚSQUEDA PARCIAL)
-- ============================
CREATE OR REPLACE FUNCTION search_gender_types(
    p_search_term VARCHAR
)
RETURNS TABLE (
    gender_id INTEGER,
    gender_name VARCHAR
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        g.gender_id,
        g.gender_name
    FROM gender_type g
    WHERE UPPER(g.gender_name) LIKE '%' || UPPER(p_search_term) || '%'
    ORDER BY g.gender_name ASC;
END;
$$ LANGUAGE plpgsql;