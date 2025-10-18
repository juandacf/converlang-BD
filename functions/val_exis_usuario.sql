-- FUNCIÓN PARA VALIDAR USUARIO EXISTENTE
-- Función que valida si un usuario existe y está activo en la tabla users.
CREATE OR REPLACE FUNCTION fun_valida_usuario(wid_usuario users.id_user%TYPE) 
RETURNS BOOLEAN AS $$
DECLARE 
    wnom_usuario users.first_name%TYPE;
    wactivo users.is_active%TYPE;
BEGIN
    SELECT u.first_name, u.is_active INTO wnom_usuario, wactivo 
    FROM users u 
    WHERE u.id_user = wid_usuario;
    
    IF FOUND THEN
        IF wactivo THEN
-- Mensaje de depuración para informar estado o error detectado.
            RAISE NOTICE 'Usuario válido: %', wnom_usuario;
            RETURN TRUE;
        ELSE
-- Mensaje de depuración para informar estado o error detectado.
            RAISE NOTICE 'ERROR: Usuario % está inactivo', wnom_usuario;
            RETURN FALSE;
        END IF;
    ELSE
-- Mensaje de depuración para informar estado o error detectado.
        RAISE NOTICE 'ERROR: Usuario con ID % no existe', wid_usuario;
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;