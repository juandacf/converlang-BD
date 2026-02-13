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
    SELECT COUNT(id_user_giver) INTO v_count
    FROM user_likes
    WHERE id_user_giver = p_user_id;
    
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
    SELECT COUNT(ul1.id_user_giver) INTO v_count
    FROM user_likes ul1
    INNER JOIN user_likes ul2 
        ON ul1.id_user_giver = ul2.id_user_receiver 
        AND ul1.id_user_receiver = ul2.id_user_giver
    WHERE ul1.id_user_giver = p_user_id;
    
    RETURN v_count;
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
