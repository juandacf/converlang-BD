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
