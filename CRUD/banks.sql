CREATE OR REPLACE FUNCTION add_bank(
    p_bank_code VARCHAR,
    p_bank_name VARCHAR,
    p_country_id VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_country_exists BOOLEAN;
BEGIN
    -- ============================
    -- VALIDACIÓN DE BANK_CODE
    -- ============================
    IF p_bank_code IS NULL OR LENGTH(TRIM(p_bank_code)) = 0 THEN
        RETURN 'El código del banco no puede estar vacío.';
    ELSIF LENGTH(p_bank_code) > 20 THEN
        RETURN 'El código del banco no puede tener más de 20 caracteres.';
    ELSIF p_bank_code !~ '^[A-Z0-9]+$' THEN
        RETURN 'El código del banco solo puede contener letras mayúsculas (A-Z) y números.';
    END IF;

    -- ============================
    -- VALIDACIÓN DE BANK_NAME
    -- ============================
    IF p_bank_name IS NULL OR LENGTH(TRIM(p_bank_name)) = 0 THEN
        RETURN 'El nombre del banco no puede estar vacío.';
    ELSIF LENGTH(p_bank_name) > 100 THEN
        RETURN 'El nombre del banco no puede tener más de 100 caracteres.';
    END IF;

    -- ============================
    -- VALIDACIÓN DE COUNTRY_ID
    -- ============================
    IF p_country_id IS NULL OR LENGTH(TRIM(p_country_id)) = 0 THEN
        RETURN 'El código de país no puede estar vacío.';
    ELSIF LENGTH(p_country_id) < 2 OR LENGTH(p_country_id) > 5 THEN
        RETURN 'El código de país debe tener entre 2 y 5 caracteres.';
    ELSIF p_country_id !~ '^[A-Z]+$' THEN
        RETURN 'El código de país debe contener solo letras mayúsculas (A-Z).';
    END IF;

    -- Verificar si el país existe
    SELECT EXISTS (
        SELECT 1 FROM countries WHERE country_code = p_country_id
    ) INTO v_country_exists;

    IF NOT v_country_exists THEN
        RETURN 'No existe ningún país con el código %.', p_country_id;
    END IF;

    -- ============================
    -- VALIDAR DUPLICADOS
    -- ============================
    SELECT EXISTS (
        SELECT 1 FROM banks 
        WHERE bank_code = p_bank_code OR UPPER(bank_name) = UPPER(p_bank_name)
    ) INTO v_exists;

    IF v_exists THEN
        RETURN 'Ya existe un banco con ese código o nombre.';
    END IF;

    -- ============================
    -- INSERCIÓN
    -- ============================
    INSERT INTO banks (bank_code, bank_name, country_id)
    VALUES (p_bank_code, p_bank_name, p_country_id);

    RETURN format('Banco %s (%s) agregado correctamente para el país %s.', p_bank_name, p_bank_code, p_country_id);
END;
$$ LANGUAGE plpgsql;





CREATE OR REPLACE FUNCTION get_all_banks()
RETURNS TABLE (
    bank_code VARCHAR,
    bank_name VARCHAR,
    country_id VARCHAR,
    country_name VARCHAR,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT 
        b.bank_code,
        b.bank_name,
        b.country_id,
        c.country_name,
        b.created_at,
        b.updated_at
    FROM banks b
    INNER JOIN countries c ON b.country_id = c.country_code
    ORDER BY b.bank_name ASC;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_bank_by_code(
    p_bank_code VARCHAR
)
RETURNS TABLE (
    bank_code VARCHAR,
    bank_name VARCHAR,
    country_id VARCHAR,
    country_name VARCHAR,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
)
AS
$$
BEGIN
    -- ============================
    -- VALIDAR BANK_CODE
    -- ============================
    IF p_bank_code IS NULL OR LENGTH(TRIM(p_bank_code)) = 0 THEN
        RAISE EXCEPTION 'El código del banco no puede estar vacío.';
    ELSIF LENGTH(p_bank_code) > 20 THEN
        RAISE EXCEPTION 'El código del banco no puede tener más de 20 caracteres.';
    ELSIF p_bank_code !~ '^[A-Z0-9]+$' THEN
        RAISE EXCEPTION 'El código del banco solo puede contener letras mayúsculas (A-Z) y números.';
    END IF;

    -- ============================
    -- RETORNAR DATOS DEL BANCO
    -- ============================
    RETURN QUERY
    SELECT 
        b.bank_code,
        b.bank_name,
        b.country_id,
        c.country_name,
        b.created_at,
        b.updated_at
    FROM banks b
    INNER JOIN countries c ON b.country_id = c.country_code
    WHERE b.bank_code = p_bank_code;

    -- Si no se encontró ningún banco
    IF NOT FOUND THEN
        RAISE NOTICE 'No se encontró ningún banco con el código %.', p_bank_code;
    END IF;
END;
$$ LANGUAGE plpgsql;
-- Se usa así: --  SELECT * FROM get_bank_by_code('BOFAUS');


CREATE OR REPLACE FUNCTION update_bank(
    p_bank_code VARCHAR,      -- Llave primaria (identificador del banco)
    p_bank_name VARCHAR,      -- Nuevo nombre del banco
    p_country_id VARCHAR      -- Nuevo país asociado
)
RETURNS TEXT
AS
$$
DECLARE
    v_exists INTEGER;
    v_country_exists INTEGER;
BEGIN
    -- ============================
    -- VALIDACIONES BÁSICAS
    -- ============================

    IF p_bank_code IS NULL OR LENGTH(TRIM(p_bank_code)) = 0 THEN
        RETURN 'El código del banco no puede estar vacío.';
    END IF;

    IF LENGTH(p_bank_code) > 20 THEN
        RETURN 'El código del banco excede los 20 caracteres permitidos.';
    END IF;

    IF p_bank_name IS NULL OR LENGTH(TRIM(p_bank_name)) = 0 THEN
        RETURN 'El nombre del banco no puede estar vacío.';
    END IF;

    IF LENGTH(p_bank_name) > 100 THEN
        RETURN 'El nombre del banco excede los 100 caracteres permitidos.';
    END IF;

    IF p_country_id IS NULL OR LENGTH(TRIM(p_country_id)) = 0 THEN
        RETURN 'El código del país no puede estar vacío.';
    END IF;

    -- ============================
    -- VERIFICAR EXISTENCIA DEL BANCO
    -- ============================
    SELECT COUNT(*) INTO v_exists
    FROM banks
    WHERE bank_code = p_bank_code;

    IF v_exists = 0 THEN
        RETURN format('No se encontró ningún banco con el código %s.', p_bank_code);
    END IF;

    -- ============================
    -- VERIFICAR EXISTENCIA DEL PAÍS
    -- ============================
    SELECT COUNT(*) INTO v_country_exists
    FROM countries
    WHERE country_code = p_country_id;

    IF v_country_exists = 0 THEN
        RETURN format('No existe ningún país con el código %s.', p_country_id);
    END IF;

    -- ============================
    -- ACTUALIZAR EL BANCO
    -- ============================
    UPDATE banks
    SET 
        bank_name = p_bank_name,
        country_id = p_country_id,
        updated_at = CURRENT_TIMESTAMP
    WHERE bank_code = p_bank_code;

    RETURN format('Banco "%s" (%s) actualizado correctamente.', p_bank_name, p_bank_code);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION delete_bank(
    p_bank_code VARCHAR -- Código del banco a eliminar
)
RETURNS TEXT
AS
$$
DECLARE
    v_exists INTEGER;
BEGIN
    -- ============================
    -- VALIDACIONES BÁSICAS
    -- ============================
    IF p_bank_code IS NULL OR LENGTH(TRIM(p_bank_code)) = 0 THEN
        RETURN 'El código del banco no puede estar vacío.';
    END IF;

    IF LENGTH(p_bank_code) > 20 THEN
        RETURN 'El código del banco excede los 20 caracteres permitidos.';
    END IF;

    -- ============================
    -- VERIFICAR EXISTENCIA DEL BANCO
    -- ============================
    SELECT COUNT(*) INTO v_exists
    FROM banks
    WHERE bank_code = p_bank_code;

    IF v_exists = 0 THEN
        RETURN format('No se encontró ningún banco con el código %s.', p_bank_code);
    END IF;

    -- ============================
    -- ELIMINAR EL BANCO (MANEJO SEGURO)
    -- ============================
    BEGIN
        DELETE FROM banks
        WHERE bank_code = p_bank_code;
    EXCEPTION
        WHEN foreign_key_violation THEN
            RETURN format('No se puede eliminar el banco con código %s porque tiene registros asociados.', p_bank_code);
    END;

    RETURN format('Banco con código %s eliminado correctamente.', p_bank_code);
END;
$$ LANGUAGE plpgsql;
