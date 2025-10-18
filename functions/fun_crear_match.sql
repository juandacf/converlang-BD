/*
Descripción:
    Esta función PL/pgSQL permite crear un "match" (emparejamiento) entre dos 
    usuarios en la tabla 'user_matches'. Un match se crea únicamente si ambos 
    usuarios existen, no son el mismo usuario, y se han dado "like" mutuamente 
    en la tabla 'user_likes'. Además, la función previene la creación de 
    duplicados y valida la integridad de los datos.

Retorna:
    - Mensaje de éxito si el match se crea correctamente.
    - Mensaje de error si ocurre alguna de las siguientes situaciones:
        * Alguno de los usuarios no existe.
        * Los usuarios son el mismo.
        * Ya existe un match entre los usuarios.
        * No hay likes mutuos.
        * Error de integridad referencial o de otro tipo.
*/
-- FUNCIÓN PARA CREAR MATCHES
CREATE OR REPLACE FUNCTION fun_insert_match(
    wuser_1 user_matches.user_1%TYPE,
    wuser_2 user_matches.user_2%TYPE
) RETURNS VARCHAR AS $$
DECLARE
    wmatch_existe INTEGER;
    wlike1_existe INTEGER;
    wlike2_existe INTEGER;
    wuser1_final user_matches.user_1%TYPE;
    wuser2_final user_matches.user_2%TYPE;
BEGIN
    -- Validar que ambos usuarios existen
    IF NOT fun_valida_usuario(wuser_1) THEN
        RETURN 'Error: El primer usuario no es válido';
    END IF;
    
    IF NOT fun_valida_usuario(wuser_2) THEN
        RETURN 'Error: El segundo usuario no es válido';
    END IF;
    
    -- Validar que no sean el mismo usuario
    IF wuser_1 = wuser_2 THEN
-- Mensaje de depuración para informar estado o error detectado.
        RAISE NOTICE 'ERROR: Un usuario no puede hacer match consigo mismo';
        RETURN 'Error: No se puede crear un emparejamiento con el mismo usuario';
    END IF;
    
    -- Ordenar usuarios para evitar duplicados (menor primero)
    wuser1_final := LEAST(wuser_1, wuser_2);
    wuser2_final := GREATEST(wuser_1, wuser_2);
    
    -- Validar que no exista ya el match
    SELECT 1 INTO wmatch_existe 
    FROM user_matches um 
    WHERE um.user_1 = wuser1_final AND um.user_2 = wuser2_final;
    
    IF FOUND THEN
-- Mensaje de depuración para informar estado o error detectado.
        RAISE NOTICE 'ERROR: Ya existe match entre estos usuarios';
        RETURN 'Error: Ya existe un emparejamiento entre estos usuarios';
    END IF;
    
    -- Validar que ambos usuarios se hayan dado like mutuamente
    SELECT 1 INTO wlike1_existe 
    FROM user_likes ul 
    WHERE ul.id_user_giver = wuser_1 AND ul.id_user_receiver = wuser_2;
    
    SELECT 1 INTO wlike2_existe 
    FROM user_likes ul 
    WHERE ul.id_user_giver = wuser_2 AND ul.id_user_receiver = wuser_1;
    
    IF wlike1_existe IS NULL OR wlike2_existe IS NULL THEN
-- Mensaje de depuración para informar estado o error detectado.
        RAISE NOTICE 'ERROR: Los usuarios deben haberse dado like mutuamente';
        RETURN 'Error: Los usuarios deben haberse dado like mutuamente para crear un emparejamiento';
    END IF;
    
    -- Crear match
    BEGIN
        INSERT INTO user_matches (user_1, user_2) 
        VALUES (wuser1_final, wuser2_final);
        
-- Mensaje de depuración para informar estado o error detectado.
        RAISE NOTICE 'Match creado exitosamente entre usuarios % y %', wuser1_final, wuser2_final;
        RETURN 'Success: Match creado entre usuarios ' || wuser1_final || ' y ' || wuser2_final;
        
-- Manejo de excepciones: captura errores de clave única, foráneas o de validación.
    EXCEPTION 
        -- Capturar error específico de violación de clave única
        WHEN unique_violation THEN
-- Mensaje de depuración para informar estado o error detectado.
            RAISE NOTICE 'ERROR: Ya existe match entre estos usuarios';
            RETURN 'Error: Ya existe un emparejamiento entre estos usuarios';
            
        -- Capturar violación de clave foránea
        WHEN foreign_key_violation THEN
            IF POSITION('user_1' IN SQLERRM) > 0 OR POSITION('user_2' IN SQLERRM) > 0 THEN
                RETURN 'Error: Usuario no válido';
            ELSE
                RETURN 'Error: Referencia de datos no válida';
            END IF;
            
        -- Cualquier otro error
        WHEN OTHERS THEN
-- Mensaje de depuración para informar estado o error detectado.
            RAISE NOTICE 'ERROR al crear match: %', SQLERRM;
            RETURN 'Error: No se pudo crear el emparejamiento';
    END;
END;
$$ LANGUAGE plpgsql;