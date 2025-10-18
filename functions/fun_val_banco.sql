/*
 PROPÓSITO: Valida si un banco existe en la tabla 'banks' de la base de datos.
       Es utilizada para asegurar la integridad referencial al registrar o validar
       información relacionada con bancos.
 VALOR DE RETORNO:
   - BOOLEAN:
       * TRUE  -> Si el banco existe en la tabla 'banks' o si no se especifica banco (NULL).
       * FALSE -> Si el banco no existe en la tabla 'banks'.
*/
-- FUNCIÓN PARA VALIDAR EXISTENCIA DE BANCO
CREATE OR REPLACE FUNCTION fun_valida_banco(wid_banco banks.bank_code%TYPE) 

RETURNS BOOLEAN AS $$
DECLARE 
    wnom_banco banks.bank_name%TYPE;
    wpais_banco banks.country_id%TYPE;
BEGIN
    IF wid_banco IS NULL THEN
        RETURN TRUE; -- Banco es opcional
    END IF;
    
    SELECT b.bank_name, b.country_id INTO wnom_banco, wpais_banco 
    FROM banks b 
    WHERE b.bank_code = wid_banco;
    
    IF FOUND THEN
        RAISE NOTICE 'Banco válido: % del país %', wnom_banco, wpais_banco;
        RETURN TRUE;
    ELSE
        RAISE NOTICE 'ERROR: El banco con código % no existe', wid_banco;
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;