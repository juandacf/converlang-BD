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