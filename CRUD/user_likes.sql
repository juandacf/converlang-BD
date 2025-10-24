-- ============================
-- FUNCIÓN: DAR LIKE A UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION add_user_like(
    p_id_user_giver INTEGER,
    p_id_user_receiver INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_giver_active BOOLEAN;
    v_receiver_active BOOLEAN;
BEGIN
    -- ============================
    -- VALIDACIONES BÁSICAS
    -- ============================
    IF p_id_user_giver IS NULL THEN
        RAISE EXCEPTION 'El ID del usuario que da el like no puede estar vacío.';
    END IF;
    
    IF p_id_user_receiver IS NULL THEN
        RAISE EXCEPTION 'El ID del usuario que recibe el like no puede estar vacío.';
    END IF;
    
    -- Validar que no sean el mismo usuario
    IF p_id_user_giver = p_id_user_receiver THEN
        RAISE EXCEPTION 'Un usuario no puede darse like a sí mismo.';
    END IF;
    
    -- ============================
    -- VERIFICAR EXISTENCIA Y ESTADO DE USUARIOS
    -- ============================
    SELECT is_active INTO v_giver_active
    FROM users
    WHERE id_user = p_id_user_giver;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El usuario que da el like (ID: %) no existe.', p_id_user_giver;
    END IF;
    
    IF NOT v_giver_active THEN
        RAISE EXCEPTION 'El usuario que da el like (ID: %) no está activo.', p_id_user_giver;
    END IF;
    
    SELECT is_active INTO v_receiver_active
    FROM users
    WHERE id_user = p_id_user_receiver;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El usuario que recibe el like (ID: %) no existe.', p_id_user_receiver;
    END IF;
    
    IF NOT v_receiver_active THEN
        RAISE EXCEPTION 'El usuario que recibe el like (ID: %) no está activo.', p_id_user_receiver;
    END IF;
    
    -- ============================
    -- VERIFICAR SI YA EXISTE EL LIKE
    -- ============================
    SELECT EXISTS(
        SELECT 1 FROM user_likes 
        WHERE id_user_giver = p_id_user_giver 
        AND id_user_receiver = p_id_user_receiver
    ) INTO v_exists;
    
    IF v_exists THEN
        RAISE EXCEPTION 'El usuario % ya dio like al usuario %.', p_id_user_giver, p_id_user_receiver;
    END IF;
    
    -- ============================
    -- CREAR LIKE
    -- ============================
    INSERT INTO user_likes (id_user_giver, id_user_receiver)
    VALUES (p_id_user_giver, p_id_user_receiver);
    
    RETURN format('Usuario %s dio like al usuario %s correctamente.', p_id_user_giver, p_id_user_receiver);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR LIKE (UNLIKE)
-- ============================
CREATE OR REPLACE FUNCTION remove_user_like(
    p_id_user_giver INTEGER,
    p_id_user_receiver INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    -- ============================
    -- VALIDACIONES BÁSICAS
    -- ============================
    IF p_id_user_giver IS NULL THEN
        RAISE EXCEPTION 'El ID del usuario que dio el like no puede estar vacío.';
    END IF;
    
    IF p_id_user_receiver IS NULL THEN
        RAISE EXCEPTION 'El ID del usuario que recibió el like no puede estar vacío.';
    END IF;
    
    -- ============================
    -- VERIFICAR EXISTENCIA DEL LIKE
    -- ============================
    SELECT EXISTS(
        SELECT 1 FROM user_likes 
        WHERE id_user_giver = p_id_user_giver 
        AND id_user_receiver = p_id_user_receiver
    ) INTO v_exists;
    
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un like del usuario % al usuario %.', p_id_user_giver, p_id_user_receiver;
    END IF;
    
    -- ============================
    -- ELIMINAR LIKE
    -- ============================
    DELETE FROM user_likes
    WHERE id_user_giver = p_id_user_giver
    AND id_user_receiver = p_id_user_receiver;
    
    RETURN format('Usuario %s quitó el like al usuario %s correctamente.', p_id_user_giver, p_id_user_receiver);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER TODOS LOS LIKES
-- ============================
CREATE OR REPLACE FUNCTION get_all_user_likes()
RETURNS TABLE (
    id_user_giver INTEGER,
    id_user_receiver INTEGER,
    like_time TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        ul.id_user_giver,
        ul.id_user_receiver,
        ul.like_time
    FROM user_likes ul
    ORDER BY ul.like_time DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER LIKES DADOS POR UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_likes_given_by_user(
    p_user_id INTEGER
)
RETURNS TABLE (
    id_user_receiver INTEGER,
    like_time TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        ul.id_user_receiver,
        ul.like_time
    FROM user_likes ul
    WHERE ul.id_user_giver = p_user_id
    ORDER BY ul.like_time DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER LIKES RECIBIDOS POR UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_likes_received_by_user(
    p_user_id INTEGER
)
RETURNS TABLE (
    id_user_giver INTEGER,
    like_time TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        ul.id_user_giver,
        ul.like_time
    FROM user_likes ul
    WHERE ul.id_user_receiver = p_user_id
    ORDER BY ul.like_time DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER MATCHES MUTUOS (AMBOS SE DIERON LIKE)
-- ============================
CREATE OR REPLACE FUNCTION get_mutual_likes(
    p_user_id INTEGER
)
RETURNS TABLE (
    matched_user_id INTEGER,
    first_like_time TIMESTAMP,
    second_like_time TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        CASE 
            WHEN ul1.id_user_giver = p_user_id THEN ul1.id_user_receiver
            ELSE ul1.id_user_giver
        END as matched_user_id,
        LEAST(ul1.like_time, ul2.like_time) as first_like_time,
        GREATEST(ul1.like_time, ul2.like_time) as second_like_time
    FROM user_likes ul1
    INNER JOIN user_likes ul2 
        ON ul1.id_user_giver = ul2.id_user_receiver 
        AND ul1.id_user_receiver = ul2.id_user_giver
    WHERE (ul1.id_user_giver = p_user_id OR ul1.id_user_receiver = p_user_id)
    AND ul1.id_user_giver < ul1.id_user_receiver  -- Evitar duplicados
    ORDER BY second_like_time DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: VERIFICAR SI EXISTE UN LIKE
-- ============================
CREATE OR REPLACE FUNCTION check_user_like_exists(
    p_id_user_giver INTEGER,
    p_id_user_receiver INTEGER
)
RETURNS BOOLEAN AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM user_likes 
        WHERE id_user_giver = p_id_user_giver 
        AND id_user_receiver = p_id_user_receiver
    ) INTO v_exists;
    
    RETURN v_exists;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: VERIFICAR SI HAY MATCH MUTUO
-- ============================
CREATE OR REPLACE FUNCTION check_mutual_like(
    p_user_id_1 INTEGER,
    p_user_id_2 INTEGER
)
RETURNS BOOLEAN AS
$$
DECLARE
    v_like_1_to_2 BOOLEAN;
    v_like_2_to_1 BOOLEAN;
BEGIN
    -- Verificar si user1 dio like a user2
    SELECT EXISTS(
        SELECT 1 FROM user_likes 
        WHERE id_user_giver = p_user_id_1 
        AND id_user_receiver = p_user_id_2
    ) INTO v_like_1_to_2;
    
    -- Verificar si user2 dio like a user1
    SELECT EXISTS(
        SELECT 1 FROM user_likes 
        WHERE id_user_giver = p_user_id_2 
        AND id_user_receiver = p_user_id_1
    ) INTO v_like_2_to_1;
    
    RETURN (v_like_1_to_2 AND v_like_2_to_1);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: CONTAR LIKES DADOS POR UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION count_likes_given(
    p_user_id INTEGER
)
RETURNS INTEGER AS
$$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM user_likes
    WHERE id_user_giver = p_user_id;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: CONTAR LIKES RECIBIDOS POR UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION count_likes_received(
    p_user_id INTEGER
)
RETURNS INTEGER AS
$$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM user_likes
    WHERE id_user_receiver = p_user_id;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: CONTAR MATCHES MUTUOS DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION count_mutual_likes(
    p_user_id INTEGER
)
RETURNS INTEGER AS
$$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM user_likes ul1
    INNER JOIN user_likes ul2 
        ON ul1.id_user_giver = ul2.id_user_receiver 
        AND ul1.id_user_receiver = ul2.id_user_giver
    WHERE ul1.id_user_giver = p_user_id;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER ESTADÍSTICAS DE LIKES DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_user_like_statistics(
    p_user_id INTEGER
)
RETURNS TABLE (
    user_id INTEGER,
    likes_given INTEGER,
    likes_received INTEGER,
    mutual_matches INTEGER,
    match_rate DECIMAL
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        p_user_id as user_id,
        (SELECT COUNT(*)::INTEGER FROM user_likes WHERE id_user_giver = p_user_id) as likes_given,
        (SELECT COUNT(*)::INTEGER FROM user_likes WHERE id_user_receiver = p_user_id) as likes_received,
        (SELECT COUNT(*)::INTEGER 
         FROM user_likes ul1
         INNER JOIN user_likes ul2 
             ON ul1.id_user_giver = ul2.id_user_receiver 
             AND ul1.id_user_receiver = ul2.id_user_giver
         WHERE ul1.id_user_giver = p_user_id) as mutual_matches,
        CASE 
            WHEN (SELECT COUNT(*) FROM user_likes WHERE id_user_giver = p_user_id) > 0 
            THEN ROUND(
                (SELECT COUNT(*)::DECIMAL 
                 FROM user_likes ul1
                 INNER JOIN user_likes ul2 
                     ON ul1.id_user_giver = ul2.id_user_receiver 
                     AND ul1.id_user_receiver = ul2.id_user_giver
                 WHERE ul1.id_user_giver = p_user_id) * 100.0 / 
                (SELECT COUNT(*) FROM user_likes WHERE id_user_giver = p_user_id),
                2
            )
            ELSE 0
        END as match_rate;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER USUARIOS QUE DIERON LIKE PERO NO RECIBIERON RESPUESTA
-- ============================
CREATE OR REPLACE FUNCTION get_unrequited_likes(
    p_user_id INTEGER
)
RETURNS TABLE (
    id_user_receiver INTEGER,
    like_time TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        ul.id_user_receiver,
        ul.like_time
    FROM user_likes ul
    WHERE ul.id_user_giver = p_user_id
    AND NOT EXISTS (
        SELECT 1 FROM user_likes ul2
        WHERE ul2.id_user_giver = ul.id_user_receiver
        AND ul2.id_user_receiver = ul.id_user_giver
    )
    ORDER BY ul.like_time DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER USUARIOS QUE TE DIERON LIKE PERO NO HAS RESPONDIDO
-- ============================
CREATE OR REPLACE FUNCTION get_pending_likes_to_respond(
    p_user_id INTEGER
)
RETURNS TABLE (
    id_user_giver INTEGER,
    like_time TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        ul.id_user_giver,
        ul.like_time
    FROM user_likes ul
    WHERE ul.id_user_receiver = p_user_id
    AND NOT EXISTS (
        SELECT 1 FROM user_likes ul2
        WHERE ul2.id_user_giver = ul.id_user_receiver
        AND ul2.id_user_receiver = ul.id_user_giver
    )
    ORDER BY ul.like_time DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER LIKES CON INFORMACIÓN COMPLETA DE USUARIOS
-- ============================
CREATE OR REPLACE FUNCTION get_likes_with_user_details(
    p_user_id INTEGER,
    p_direction VARCHAR DEFAULT 'received' -- 'given' o 'received'
)
RETURNS TABLE (
    like_id_giver INTEGER,
    like_id_receiver INTEGER,
    like_time TIMESTAMP,
    other_user_id INTEGER,
    other_user_name VARCHAR,
    other_user_email VARCHAR,
    other_user_country VARCHAR,
    other_user_native_lang VARCHAR,
    other_user_target_lang VARCHAR,
    is_mutual BOOLEAN
)
AS
$$
DECLARE
    v_direction_lower VARCHAR;
BEGIN
    v_direction_lower := LOWER(p_direction);
    
    IF v_direction_lower NOT IN ('given', 'received') THEN
        RAISE EXCEPTION 'La dirección debe ser "given" o "received". Valor proporcionado: %.', p_direction;
    END IF;
    
    IF v_direction_lower = 'received' THEN
        RETURN QUERY
        SELECT
            ul.id_user_giver,
            ul.id_user_receiver,
            ul.like_time,
            u.id_user as other_user_id,
            (u.first_name || ' ' || u.last_name)::VARCHAR as other_user_name,
            u.email,
            u.country_id as other_user_country,
            u.native_lang_id as other_user_native_lang,
            u.target_lang_id as other_user_target_lang,
            EXISTS(
                SELECT 1 FROM user_likes ul2
                WHERE ul2.id_user_giver = ul.id_user_receiver
                AND ul2.id_user_receiver = ul.id_user_giver
            ) as is_mutual
        FROM user_likes ul
        INNER JOIN users u ON u.id_user = ul.id_user_giver
        WHERE ul.id_user_receiver = p_user_id
        ORDER BY ul.like_time DESC;
    ELSE
        RETURN QUERY
        SELECT
            ul.id_user_giver,
            ul.id_user_receiver,
            ul.like_time,
            u.id_user as other_user_id,
            (u.first_name || ' ' || u.last_name)::VARCHAR as other_user_name,
            u.email,
            u.country_id as other_user_country,
            u.native_lang_id as other_user_native_lang,
            u.target_lang_id as other_user_target_lang,
            EXISTS(
                SELECT 1 FROM user_likes ul2
                WHERE ul2.id_user_giver = ul.id_user_receiver
                AND ul2.id_user_receiver = ul.id_user_giver
            ) as is_mutual
        FROM user_likes ul
        INNER JOIN users u ON u.id_user = ul.id_user_receiver
        WHERE ul.id_user_giver = p_user_id
        ORDER BY ul.like_time DESC;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: ELIMINAR TODOS LOS LIKES DE UN USUARIO (ADMIN/CLEANUP)
-- ============================
CREATE OR REPLACE FUNCTION delete_all_user_likes(
    p_user_id INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_likes_given INTEGER;
    v_likes_received INTEGER;
BEGIN
    -- Contar likes antes de eliminar
    SELECT COUNT(*) INTO v_likes_given
    FROM user_likes
    WHERE id_user_giver = p_user_id;
    
    SELECT COUNT(*) INTO v_likes_received
    FROM user_likes
    WHERE id_user_receiver = p_user_id;
    
    -- Eliminar likes dados
    DELETE FROM user_likes WHERE id_user_giver = p_user_id;
    
    -- Eliminar likes recibidos
    DELETE FROM user_likes WHERE id_user_receiver = p_user_id;
    
    RETURN format('Eliminados %s likes dados y %s likes recibidos del usuario %s.', 
                  v_likes_given, v_likes_received, p_user_id);
END;
$$ LANGUAGE plpgsql;