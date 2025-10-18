/*
VALIDACIONES:
    - El usuario debe existir y estar activo.
    - El usuario no debe tener ya un perfil de profesor.
    - El usuario debe tener asignado el rol 'teacher'.
    - El idioma de enseñanza debe ser válido.
    - La tarifa por hora y los años de experiencia no pueden ser negativos.

RETORNO:
    - 'Success: Perfil creado para usuario ID {id}' si la operación es exitosa.
    - Mensajes de error específicos si alguna validación falla o si ocurre una excepción.
*/

--FUNCIÓN PARA CREAR PERFIL DE PROFESOR ACTUALIZADA
-- Función que crea un perfil de profesor en la tabla teacher_profiles.
-- Incluye validaciones de rol, idioma de enseñanza, experiencia y tarifas.
CREATE OR REPLACE FUNCTION fun_insert_teacher_profile(
                                                    wuser_id teacher_profiles.user_id%TYPE,
                                                    wteaching_language_id teacher_profiles.teaching_language_id%TYPE,
                                                    wlang_certification teacher_profiles.lang_certification%TYPE,
                                                    wacademic_title teacher_profiles.academic_title%TYPE,
                                                    wexperience_certification teacher_profiles.experience_certification%TYPE,
                                                    whourly_rate teacher_profiles.hourly_rate%TYPE,
                                                    wspecialization teacher_profiles.specialization%TYPE,
                                                    wyears_experience teacher_profiles.years_experience%TYPE,
                                                    wavailability_notes teacher_profiles.availability_notes%TYPE
) RETURNS VARCHAR AS $$
DECLARE
    wprofile_existe teacher_profiles.user_id%TYPE;
    whas_teacher_role BOOLEAN := FALSE;
    winserted_user_id teacher_profiles.user_id%TYPE;
BEGIN
    -- Validar que el usuario existe y está activo
    IF NOT fun_valida_usuario(wuser_id) THEN
        RETURN 'Error: Usuario no válido o inactivo';
    END IF;
    
    -- Validar que no tenga ya un perfil de profesor
    SELECT tp.user_id INTO wprofile_existe 
    FROM teacher_profiles tp 
    WHERE tp.user_id = wuser_id;
    
    IF FOUND THEN
-- Mensaje de depuración para informar estado o error detectado.
        RAISE NOTICE 'ERROR: El usuario ya tiene un perfil de profesor';
        RETURN 'Error: Ya existe un perfil de profesor para este usuario';
    END IF;
    
    -- Validar que el usuario tenga rol de TEACHER
    SELECT EXISTS(
        SELECT 1 FROM user_role_assignments ura
        WHERE ura.user_id = wuser_id AND ura.role_code = 'teacher'
    ) INTO whas_teacher_role;
    
    IF NOT whas_teacher_role THEN
-- Mensaje de depuración para informar estado o error detectado.
        RAISE NOTICE 'ERROR: Usuario debe tener rol TEACHER';
        RETURN 'Error: El usuario debe tener rol de profesor';
    END IF;
    
    -- Validar idioma de enseñanza
    IF NOT fun_valida_idioma(wteaching_language_id) THEN
        RETURN 'Error: Idioma de enseñanza no válido';
    END IF;
    
    -- Validar tarifa por hora
    IF whourly_rate IS NOT NULL AND whourly_rate < 0 THEN
-- Mensaje de depuración para informar estado o error detectado.
        RAISE NOTICE 'ERROR: La tarifa por hora no puede ser negativa';
        RETURN 'Error: La tarifa por hora debe ser mayor o igual a cero';
    END IF;
    
    -- Validar años de experiencia
    IF wyears_experience IS NOT NULL AND wyears_experience < 0 THEN
-- Mensaje de depuración para informar estado o error detectado.
        RAISE NOTICE 'ERROR: Los años de experiencia no pueden ser negativos';
        RETURN 'Error: Los años de experiencia deben ser mayor o igual a cero';
    END IF;
    
    -- Insertar perfil de profesor
    BEGIN
        INSERT INTO teacher_profiles (
            user_id, teaching_language_id, lang_certification, 
            academic_title, experience_certification, hourly_rate,
            specialization, years_experience, availability_notes
        ) VALUES (
            wuser_id, wteaching_language_id, wlang_certification,
            wacademic_title, wexperience_certification, whourly_rate,
            wspecialization, wyears_experience, wavailability_notes
        ) RETURNING user_id INTO winserted_user_id;
        
-- Mensaje de depuración para informar estado o error detectado.
        RAISE NOTICE 'Perfil de profesor creado exitosamente para usuario ID: %', winserted_user_id;
        RETURN 'Success: Perfil creado para usuario ID ' || winserted_user_id;
        
-- Manejo de excepciones: captura errores de clave única, foráneas o de validación.
    EXCEPTION 
        -- Capturar error específico de violación de clave única
        WHEN unique_violation THEN
-- Mensaje de depuración para informar estado o error detectado.
            RAISE NOTICE 'ERROR: El usuario ya tiene un perfil de profesor';
            RETURN 'Error: Ya existe un perfil de profesor para este usuario';
            
        -- Capturar violación de clave foránea
        WHEN foreign_key_violation THEN
            IF POSITION('user_id' IN SQLERRM) > 0 THEN
                RETURN 'Error: Usuario no válido';
            ELSIF POSITION('teaching_language_id' IN SQLERRM) > 0 THEN
                RETURN 'Error: Idioma de enseñanza no válido';
            ELSE
                RETURN 'Error: Referencia de datos no válida';
            END IF;
            
        -- Cualquier otro error
        WHEN OTHERS THEN
-- Mensaje de depuración para informar estado o error detectado.
            RAISE NOTICE 'ERROR al insertar perfil de profesor: %', SQLERRM;
            RETURN 'Error: No se pudo crear el perfil de profesor';
    END;
END;
$$ LANGUAGE plpgsql;
