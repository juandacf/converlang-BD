-- ================================================================
-- FUNCIÓN: add_bank
-- Descripción: Agrega un nuevo banco al sistema
-- ================================================================
CREATE OR REPLACE FUNCTION add_bank(
    p_bank_code VARCHAR,
    p_bank_name VARCHAR,
    p_country_id VARCHAR
)
RETURNS TABLE(bank_code VARCHAR, bank_name VARCHAR) AS
$$
DECLARE
    v_exists BOOLEAN;
    v_country_exists BOOLEAN;
    v_bank_code_upper VARCHAR;
    v_country_id_upper VARCHAR;
BEGIN
    -- ============================
    -- VALIDACIÓN Y NORMALIZACIÓN DE BANK_CODE
    -- ============================
    IF p_bank_code IS NULL OR LENGTH(TRIM(p_bank_code)) = 0 THEN
        RAISE EXCEPTION 'El código del banco no puede estar vacío.';
    ELSIF LENGTH(p_bank_code) > 20 THEN
        RAISE EXCEPTION 'El código del banco no puede tener más de 20 caracteres.';
    END IF;
    
    v_bank_code_upper := UPPER(p_bank_code);
    
    IF v_bank_code_upper !~ '^[A-Z0-9]+$' THEN
        RAISE EXCEPTION 'El código del banco solo puede contener letras y números.';
    END IF;

    -- ============================
    -- VALIDACIÓN DE BANK_NAME
    -- ============================
    IF p_bank_name IS NULL OR LENGTH(TRIM(p_bank_name)) = 0 THEN
        RAISE EXCEPTION 'El nombre del banco no puede estar vacío.';
    ELSIF LENGTH(p_bank_name) > 100 THEN
        RAISE EXCEPTION 'El nombre del banco no puede tener más de 100 caracteres.';
    END IF;

    -- ============================
    -- VALIDACIÓN Y NORMALIZACIÓN DE COUNTRY_ID
    -- ============================
    IF p_country_id IS NULL OR LENGTH(TRIM(p_country_id)) = 0 THEN
        RAISE EXCEPTION 'El código de país no puede estar vacío.';
    ELSIF LENGTH(p_country_id) < 2 OR LENGTH(p_country_id) > 5 THEN
        RAISE EXCEPTION 'El código de país debe tener entre 2 y 5 caracteres.';
    END IF;
    
    v_country_id_upper := UPPER(p_country_id);
    
    IF v_country_id_upper !~ '^[A-Z]+$' THEN
        RAISE EXCEPTION 'El código de país debe contener solo letras.';
    END IF;

    -- Verificar si el país existe
    SELECT EXISTS (
        SELECT 1 FROM countries WHERE country_code = v_country_id_upper
    ) INTO v_country_exists;

    IF NOT v_country_exists THEN
        RAISE EXCEPTION 'No existe ningún país con el código %.', v_country_id_upper;
    END IF;

    -- ============================
    -- VALIDAR DUPLICADOS
    -- ============================
    SELECT EXISTS (
        SELECT 1 FROM banks 
        WHERE banks.bank_code = v_bank_code_upper OR UPPER(banks.bank_name) = UPPER(p_bank_name)
    ) INTO v_exists;

    IF v_exists THEN
        RAISE EXCEPTION 'Ya existe un banco con ese código o nombre.';
    END IF;

    -- ============================
    -- INSERCIÓN Y RETORNO
    -- ============================
    INSERT INTO banks (bank_code, bank_name, country_id)
    VALUES (v_bank_code_upper, p_bank_name, v_country_id_upper);

    RETURN QUERY
    SELECT b.bank_code, b.bank_name
    FROM banks b
    WHERE b.bank_code = v_bank_code_upper;
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- FUNCIÓN: update_bank
-- Descripción: Actualiza un banco existente en el sistema
-- ================================================================
CREATE OR REPLACE FUNCTION update_bank(
    p_bank_name VARCHAR,
    p_country_id VARCHAR,
    p_bank_code VARCHAR
)
RETURNS TABLE(bank_code VARCHAR, bank_name VARCHAR) AS
$$
DECLARE
    v_bank_code_upper VARCHAR;
    v_country_id_upper VARCHAR;
    v_country_exists BOOLEAN;
    v_bank_exists BOOLEAN;
    v_name_exists BOOLEAN;
BEGIN
    -- ============================
    -- VALIDACIÓN DEL BANK_CODE (obligatorio)
    -- ============================
    IF p_bank_code IS NULL OR LENGTH(TRIM(p_bank_code)) = 0 THEN
        RAISE EXCEPTION 'El código del banco no puede estar vacío.';
    END IF;
    
    v_bank_code_upper := UPPER(p_bank_code);
    
    -- Verificar si el banco existe
    SELECT EXISTS (
        SELECT 1 FROM banks WHERE banks.bank_code = v_bank_code_upper
    ) INTO v_bank_exists;
    
    IF NOT v_bank_exists THEN
        RAISE EXCEPTION 'No existe ningún banco con el código %.', v_bank_code_upper;
    END IF;

    -- ============================
    -- VALIDACIÓN DE BANK_NAME (opcional)
    -- ============================
    IF p_bank_name IS NOT NULL THEN
        IF LENGTH(TRIM(p_bank_name)) = 0 THEN
            RAISE EXCEPTION 'El nombre del banco no puede estar vacío.';
        ELSIF LENGTH(p_bank_name) > 100 THEN
            RAISE EXCEPTION 'El nombre del banco no puede tener más de 100 caracteres.';
        END IF;
        
        -- Verificar que no exista otro banco con ese nombre
        SELECT EXISTS (
            SELECT 1 FROM banks 
            WHERE UPPER(banks.bank_name) = UPPER(p_bank_name) 
            AND banks.bank_code != v_bank_code_upper
        ) INTO v_name_exists;
        
        IF v_name_exists THEN
            RAISE EXCEPTION 'Ya existe otro banco con ese nombre.';
        END IF;
    END IF;

    -- ============================
    -- VALIDACIÓN DE COUNTRY_ID (opcional)
    -- ============================
    IF p_country_id IS NOT NULL THEN
        IF LENGTH(TRIM(p_country_id)) = 0 THEN
            RAISE EXCEPTION 'El código de país no puede estar vacío.';
        ELSIF LENGTH(p_country_id) < 2 OR LENGTH(p_country_id) > 5 THEN
            RAISE EXCEPTION 'El código de país debe tener entre 2 y 5 caracteres.';
        END IF;
        
        v_country_id_upper := UPPER(p_country_id);
        
        IF v_country_id_upper !~ '^[A-Z]+$' THEN
            RAISE EXCEPTION 'El código de país debe contener solo letras.';
        END IF;
        
        -- Verificar si el país existe
        SELECT EXISTS (
            SELECT 1 FROM countries WHERE country_code = v_country_id_upper
        ) INTO v_country_exists;
        
        IF NOT v_country_exists THEN
            RAISE EXCEPTION 'No existe ningún país con el código %.', v_country_id_upper;
        END IF;
    END IF;

    -- ============================
    -- ACTUALIZACIÓN
    -- ============================
    UPDATE banks
    SET 
        bank_name = COALESCE(p_bank_name, banks.bank_name),
        country_id = COALESCE(v_country_id_upper, banks.country_id),
        updated_at = CURRENT_TIMESTAMP
    WHERE banks.bank_code = v_bank_code_upper;

    -- ============================
    -- RETORNAR EL REGISTRO ACTUALIZADO
    -- ============================
    RETURN QUERY
    SELECT b.bank_code, b.bank_name
    FROM banks b
    WHERE b.bank_code = v_bank_code_upper;
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- FUNCIÓN: delete_bank_by_code
-- Descripción: Elimina un banco del sistema por su código
-- ================================================================
CREATE OR REPLACE FUNCTION delete_bank_by_code(
    p_bank_code VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_bank_code_upper VARCHAR;
    v_bank_exists BOOLEAN;
BEGIN
    -- ============================
    -- VALIDACIÓN DEL BANK_CODE
    -- ============================
    IF p_bank_code IS NULL OR LENGTH(TRIM(p_bank_code)) = 0 THEN
        RAISE EXCEPTION 'El código del banco no puede estar vacío.';
    END IF;
    
    v_bank_code_upper := UPPER(p_bank_code);
    
    -- ============================
    -- VERIFICAR SI EL BANCO EXISTE
    -- ============================
    SELECT EXISTS (
        SELECT 1 FROM banks WHERE banks.bank_code = v_bank_code_upper
    ) INTO v_bank_exists;
    
    IF NOT v_bank_exists THEN
        RAISE EXCEPTION 'No existe ningún banco con el código %.', v_bank_code_upper;
    END IF;
    
    -- ============================
    -- ELIMINACIÓN
    -- ============================
    DELETE FROM banks WHERE banks.bank_code = v_bank_code_upper;
    
    -- ============================
    -- RETORNO
    -- ============================
    RETURN format('Banco con código %s eliminado correctamente.', v_bank_code_upper);
END;
$$ LANGUAGE plpgsql;