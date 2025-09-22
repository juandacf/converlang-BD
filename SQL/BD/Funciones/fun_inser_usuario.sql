/*
Nombre de la función: fun_insert_usuarios
Propósito:
  Permite insertar un nuevo usuario en la tabla 'users' realizando múltiples validaciones
  para asegurar la integridad y calidad de los datos ingresados.*/

--FUNCIÓN PRINCIPAL PARA INSERTAR USUARIOS CON VALIDACIONES ACTUALIZADA
-- Función principal para insertar usuarios en la tabla users.
-- Incluye validaciones de email, nombre, apellido, país, idiomas, edad, y manejo de excepciones.
CREATE OR REPLACE FUNCTION fun_insert_usuarios(
                                                wfirst_name users.first_name%TYPE,
                                                wlast_name users.last_name%TYPE,
                                                wemail users.email%TYPE,
                                                wpassword users.password_hash%TYPE,
                                                wgender users.gender%TYPE,
                                                wbirth_date users.birth_date%TYPE,
                                                wcountry_id users.country_id%TYPE,
                                                wprofile_photo users.profile_photo%TYPE,
                                                wnative_lang_id users.native_lang_id%TYPE,
                                                wtarget_lang_id users.target_lang_id%TYPE,
                                                wmatch_quantity users.match_quantity%TYPE,
                                                wbank_id users.bank_id%TYPE,
                                                wdescription users.description%TYPE
) RETURNS VARCHAR AS $$
DECLARE
    wuser_existe users.email%TYPE;
    wnew_user_id users.id_user%TYPE;
BEGIN
    SELECT u.email INTO wuser_existe 
    FROM users u 
    WHERE LOWER(u.email) = LOWER(wemail);
    
    IF FOUND THEN
        RAISE NOTICE 'ERROR: El email % ya está registrado', wemail;
        RETURN 'Error: El correo electrónico ya está registrado';
    END IF;
	
    -- VALIDACIÓN FIRST_NAME EVITANDO GOLES DE INSERCIÓN DE USUARIO
    IF wfirst_name IS NULL THEN
            RETURN 'Error: El nombre no puede ser nulo';
    END IF;
        IF LENGTH(TRIM(wfirst_name)) < 3 THEN
        RETURN 'Error: El nombre debe contener al menos 3 caracteres';
    END IF;

    IF LENGTH(TRIM(wfirst_name)) > 50 THEN
        RETURN 'Error: El nombre no puede exceder 50 caracteres';
    END IF;
    
    IF TRIM(wfirst_name) = '' THEN
        RETURN 'Error: El nombre no puede estar vacío';
    END IF;
    
    IF wfirst_name ~ '^\s+$' THEN
        RETURN 'Error: El nombre no puede contener solo espacios en blanco';
    END IF;
    
    IF NOT (wfirst_name ~ '^[a-zA-Záéíóúñüç\s]+$') THEN
        RETURN 'Error: El nombre solo puede contener letras y espacios';
    END IF;
    
    -- VALIDACIÓN LAST_NAME
    IF wlast_name IS NULL THEN
        RETURN 'Error: El apellido no puede ser nulo';
    END IF;
    
    IF LENGTH(TRIM(wlast_name)) < 3 THEN
        RETURN 'Error: El apellido debe contener al menos 3 caracteres';
    END IF;
    
    IF LENGTH(TRIM(wlast_name)) > 50 THEN
        RETURN 'Error: El apellido no puede exceder 50 caracteres';
    END IF;
    
    IF TRIM(wlast_name) = '' THEN
        RETURN 'Error: El apellido no puede estar vacío';
    END IF;
    
    IF wlast_name ~ '^\s+$' THEN
        RETURN 'Error: El apellido no puede contener solo espacios en blanco';
    END IF;
    
    IF NOT (wlast_name ~ '^[a-zA-Záéíóúñüç\s]+$') THEN
        RETURN 'Error: El apellido solo puede contener letras y espacios';
    END IF;
    
    -- Validar país
    IF NOT fun_valida_pais(wcountry_id) THEN
        RETURN 'Error: País no válido';
    END IF;
    
    -- Validar idioma nativo
    IF NOT fun_valida_idioma(wnative_lang_id) THEN
        RETURN 'Error: Idioma nativo no válido';
    END IF;
    
    -- Validar idioma objetivo
    IF NOT fun_valida_idioma(wtarget_lang_id) THEN
        RETURN 'Error: Idioma objetivo no válido';
    END IF;
    
    -- Validar que idioma nativo y objetivo sean diferentes
    IF wnative_lang_id = wtarget_lang_id THEN
-- Mensaje de depuración para informar estado o error detectado.
        RAISE NOTICE 'ERROR: El idioma nativo no puede ser igual al idioma objetivo';
        RETURN 'Error: Los idiomas nativo y objetivo deben ser diferentes';
    END IF;
    
    -- Validar edad mínima (15 años según constraint en la base)
    IF wbirth_date > CURRENT_DATE - INTERVAL '15 years' THEN
-- Mensaje de depuración para informar estado o error detectado.
        RAISE NOTICE 'ERROR: El usuario debe tener al menos 15 años';
        RETURN 'Error: Debe tener al menos 15 años para registrarse';
    END IF;
    -- Si todas las validaciones pasan, insertar usuario
    BEGIN
        INSERT INTO users (
            first_name, last_name, email, password_hash, gender, 
            birth_date, country_id, profile_photo, native_lang_id, 
            target_lang_id, match_quantity, bank_id, description
        ) VALUES (
            wfirst_name, wlast_name, wemail, wpassword, wgender,
            wbirth_date, wcountry_id, wprofile_photo, wnative_lang_id,
            wtarget_lang_id, wmatch_quantity, wbank_id, wdescription
        ) RETURNING id_user INTO wnew_user_id;
        
        INSERT INTO user_role_assignments (user_id, role_code) 
        VALUES (wnew_user_id, 'user');
        
-- Mensaje de depuración para informar estado o error detectado.
        RAISE NOTICE 'Usuario creado exitosamente con ID: %', wnew_user_id;
        RETURN 'Success: Usuario creado con ID ' || wnew_user_id;
        
-- Manejo de excepciones: captura errores de clave única, foráneas o de validación.
    EXCEPTION 
        -- Capturar error específico de violación de clave única
        WHEN unique_violation THEN
            -- Determinar qué campo causó la violación
            IF POSITION('email' IN SQLERRM) > 0 THEN
-- Mensaje de depuración para informar estado o error detectado.
                RAISE NOTICE 'ERROR: El correo electrónico % ya está registrado', wemail;
                RETURN 'Error: El correo electrónico ya está registrado';
            ELSE
-- Mensaje de depuración para informar estado o error detectado.
                RAISE NOTICE 'ERROR: Ya existe un usuario con esos datos';
                RETURN 'Error: Ya existe un usuario con esos datos';
            END IF;
            
        -- Capturar violación de clave foránea
        WHEN foreign_key_violation THEN
            IF POSITION('country_id' IN SQLERRM) > 0 THEN
                RETURN 'Error: País no válido';
            ELSIF POSITION('native_lang_id' IN SQLERRM) > 0 THEN
                RETURN 'Error: Idioma nativo no válido';
            ELSIF POSITION('target_lang_id' IN SQLERRM) > 0 THEN
                RETURN 'Error: Idioma objetivo no válido';
            ELSIF POSITION('bank_id' IN SQLERRM) > 0 THEN
                RETURN 'Error: Banco no válido';
            ELSE
                RETURN 'Error: Referencia de datos no válida';
            END IF;
            
        -- Capturar violación de check constraint
        WHEN check_violation THEN
-- Mensaje de depuración para informar estado o error detectado.
            RAISE NOTICE 'ERROR: Datos no válidos - %', SQLERRM;
            RETURN 'Error: Los datos no cumplen con los requisitos del sistema';
            
        -- Cualquier otro error
        WHEN OTHERS THEN
-- Mensaje de depuración para informar estado o error detectado.
            RAISE NOTICE 'ERROR inesperado al crear usuario: %', SQLERRM;
            RETURN 'Error: No se pudo crear el usuario';
    END;
END;
$$ LANGUAGE plpgsql;