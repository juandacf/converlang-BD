-- ====================================================================================================
-- FUNCIÓN CORREGIDA PARA VALIDAR LIKES, HACER MACTH Y POSTERIOR A ACEPTAR EL MATCH, CREAR SESIÓN 
-- ====================================================================================================
/*
DESCRIPCIÓN:
    Esta función valida que dos usuarios se hayan dado like mutuamente antes de 
    permitir la creación de una sesión entre ellos. También verifica que ambos 
    usuarios existan, estén activos, y no tengan ya una sesión activa entre sí.

PARÁMETROS:
    - wuser1_id: ID del primer usuario
    - wuser2_id: ID del segundo usuario
    - wsession_type: Tipo de sesión ('exchange' o 'teaching')
    - wstart_time: Hora de inicio programada (opcional)
    - wend_time: Hora de fin programada (opcional)
    - wlanguage_used: Idioma a usar en la sesión (opcional)
    - wsession_notes: Notas adicionales (opcional)

RETORNA:
    - 'Success: Sesión creada con ID [session_id]' si todo es correcto
    - Mensaje de error específico si algo falla

VALIDACIONES:
    1. Ambos usuarios existen y están activos
    2. Los usuarios son diferentes
    3. Existe like mutuo entre los usuarios
    4. No hay sesión activa entre los usuarios
    5. Para 'teaching': verificar que uno sea teacher verificado
*/


-- ====================================================================================================
-- FUNCIÓN PRINCIPAL CORREGIDA
-- ====================================================================================================

CREATE OR REPLACE FUNCTION fun_validar_likes_y_crear_sesion(
    wuser1_id INTEGER,
    wuser2_id INTEGER,
    wsession_type TEXT,
    wstart_time TIMESTAMP DEFAULT NULL,
    wend_time TIMESTAMP DEFAULT NULL,
    wlanguage_used TEXT DEFAULT NULL,
    wsession_notes TEXT DEFAULT NULL
) RETURNS TEXT AS $$
DECLARE
    wlike1_existe INTEGER;
    wlike2_existe INTEGER;
    wsesion_activa TEXT;
    wteacher_verificado BOOLEAN := FALSE;
    wnew_session_id TEXT;
    wmatch_existe INTEGER;
BEGIN
    -- ================================================================
    -- 1. VALIDAR QUE AMBOS USUARIOS EXISTEN Y ESTÁN ACTIVOS
    -- ================================================================
    IF NOT fun_valida_usuario(wuser1_id) THEN
        RETURN 'Error: El primer usuario no es válido o está inactivo';
    END IF;
    
    IF NOT fun_valida_usuario(wuser2_id) THEN
        RETURN 'Error: El segundo usuario no es válido o está inactivo';
    END IF;
    
    -- ================================================================
    -- 2. VALIDAR QUE NO SEAN EL MISMO USUARIO
    -- ================================================================
    IF wuser1_id = wuser2_id THEN
        RAISE NOTICE 'ERROR: Un usuario no puede crear sesión consigo mismo';
        RETURN 'Error: No se puede crear una sesión con el mismo usuario';
    END IF;
    
    -- ================================================================
    -- 3. VALIDAR TIPO DE SESIÓN
    -- ================================================================
    IF wsession_type NOT IN ('exchange', 'teaching') THEN
        RETURN 'Error: Tipo de sesión inválido. Debe ser "exchange" o "teaching"';
    END IF;
    
    -- ================================================================
    -- 4. VALIDAR LIKES MUTUOS
    -- ================================================================
    SELECT 1 INTO wlike1_existe 
    FROM user_likes ul 
    WHERE ul.id_user_giver = wuser1_id AND ul.id_user_receiver = wuser2_id;
    
    SELECT 1 INTO wlike2_existe 
    FROM user_likes ul 
    WHERE ul.id_user_giver = wuser2_id AND ul.id_user_receiver = wuser1_id;
    
    IF wlike1_existe IS NULL OR wlike2_existe IS NULL THEN
        RAISE NOTICE 'ERROR: Los usuarios deben haberse dado like mutuamente';
        RETURN 'Error: Ambos usuarios deben haberse dado like mutuamente antes de crear una sesión';
    END IF;
    
    -- ================================================================
    -- 5. VERIFICAR QUE EXISTE MATCH ENTRE LOS USUARIOS
    -- ================================================================
    SELECT 1 INTO wmatch_existe 
    FROM user_matches um 
    WHERE (um.user_1 = LEAST(wuser1_id, wuser2_id) AND um.user_2 = GREATEST(wuser1_id, wuser2_id));
    
    IF wmatch_existe IS NULL THEN
        RAISE NOTICE 'ERROR: No existe match entre estos usuarios';
        RETURN 'Error: Debe existir un match entre los usuarios para crear una sesión';
    END IF;
    
    -- ================================================================
    -- 6. VALIDAR QUE NO TENGAN SESIÓN ACTIVA
    -- ================================================================
    SELECT s.session_id INTO wsesion_activa 
    FROM sessions s 
    WHERE ((s.id_user1 = wuser1_id AND s.id_user2 = wuser2_id) OR 
           (s.id_user1 = wuser2_id AND s.id_user2 = wuser1_id))
      AND s.session_status IN ('scheduled', 'in_progress')
    LIMIT 1;
    
    IF wsesion_activa IS NOT NULL THEN
        RAISE NOTICE 'ERROR: Ya existe sesión activa entre estos usuarios: %', wsesion_activa;
        RETURN 'Error: Ya existe una sesión activa entre estos usuarios: ' || wsesion_activa;
    END IF;
    
    -- ================================================================
    -- 7. VALIDACIONES ESPECÍFICAS PARA SESIONES DE ENSEÑANZA
    -- ================================================================
    IF wsession_type = 'teaching' THEN
        SELECT EXISTS(
            SELECT 1 FROM teacher_profiles tp
            WHERE tp.user_id IN (wuser1_id, wuser2_id) AND tp.is_verified = TRUE
        ) INTO wteacher_verificado;
        
        IF NOT wteacher_verificado THEN
            RETURN 'Error: Para sesiones de enseñanza, uno de los usuarios debe ser un teacher verificado';
        END IF;
    END IF;
    
    -- ================================================================
    -- 8. VALIDAR IDIOMA SI SE ESPECIFICA
    -- ================================================================
    IF wlanguage_used IS NOT NULL THEN
        IF NOT fun_valida_idioma(wlanguage_used) THEN
            RETURN 'Error: Idioma especificado no es válido';
        END IF;
    END IF;
    
    -- ================================================================
    -- 9. GENERAR ID DE SESIÓN
    -- ================================================================
    wnew_session_id := fun_increme_session();
    
    -- ================================================================
    -- 10. CREAR LA SESIÓN
    -- ================================================================
    BEGIN
        INSERT INTO sessions (
            session_id, id_user1, id_user2, session_type, start_time, end_time,
            session_status, session_notes, language_used, created_by
        ) VALUES (
            wnew_session_id, wuser1_id, wuser2_id, wsession_type, wstart_time, wend_time,
            'scheduled', wsession_notes, wlanguage_used, wuser1_id
        );
        
        -- ================================================================
        -- 11. CREAR REGISTRO ESPECÍFICO SEGÚN TIPO DE SESIÓN
        -- ================================================================
        IF wsession_type = 'exchange' THEN
            INSERT INTO exchange_sessions (session_id) VALUES (wnew_session_id);
            
        ELSIF wsession_type = 'teaching' THEN
            DECLARE
                wteacher_id INTEGER;
                wstudent_id INTEGER;
            BEGIN
                SELECT tp.user_id INTO wteacher_id
                FROM teacher_profiles tp
                WHERE tp.user_id IN (wuser1_id, wuser2_id) AND tp.is_verified = TRUE
                LIMIT 1;
                
                wstudent_id := CASE 
                    WHEN wteacher_id = wuser1_id THEN wuser2_id 
                    ELSE wuser1_id 
                END;
                
                INSERT INTO teaching_sessions (session_id, teacher_profile_id, student_id)
                VALUES (wnew_session_id, wteacher_id, wstudent_id);
            END;
        END IF;
        
        RAISE NOTICE 'Sesión % creada exitosamente entre usuarios % y %', 
                     wnew_session_id, wuser1_id, wuser2_id;
        RETURN 'Success: Sesión creada con ID ' || wnew_session_id;
        
    EXCEPTION 
        WHEN unique_violation THEN
            RAISE NOTICE 'ERROR: Ya existe una sesión entre estos usuarios';
            RETURN 'Error: Ya existe una sesión entre estos usuarios';
            
        WHEN foreign_key_violation THEN
            IF POSITION('language_used' IN SQLERRM) > 0 THEN
                RETURN 'Error: Idioma no válido';
            ELSE
                RETURN 'Error: Referencia de datos no válida';
            END IF;
            
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR al crear sesión: %', SQLERRM;
            RETURN 'Error: No se pudo crear la sesión - ' || SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql;

-- ====================================================================================================
-- FUNCIÓN AUXILIAR PARA VALIDAR LOS LIKES MUTUOS Y ESTABLECER EL MATCH
-- ====================================================================================================

CREATE OR REPLACE FUNCTION fun_verificar_likes_mutuos(
    wuser1_id INTEGER,
    wuser2_id INTEGER
) RETURNS BOOLEAN AS $$
DECLARE
    wlike1_existe INTEGER;
    wlike2_existe INTEGER;
BEGIN
    IF NOT fun_valida_usuario(wuser1_id) OR NOT fun_valida_usuario(wuser2_id) THEN
        RETURN FALSE;
    END IF;
    
    IF wuser1_id = wuser2_id THEN
        RETURN FALSE;
    END IF;
    
    SELECT 1 INTO wlike1_existe 
    FROM user_likes ul 
    WHERE ul.id_user_giver = wuser1_id AND ul.id_user_receiver = wuser2_id;
    
    SELECT 1 INTO wlike2_existe 
    FROM user_likes ul 
    WHERE ul.id_user_giver = wuser2_id AND ul.id_user_receiver = wuser1_id;
    
    RETURN (wlike1_existe IS NOT NULL AND wlike2_existe IS NOT NULL);
END;
$$ LANGUAGE plpgsql;


