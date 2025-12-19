CREATE OR REPLACE FUNCTION add_exchange_session(
    p_session_id VARCHAR,
    p_session_rating_user1 INTEGER DEFAULT NULL,
    p_session_rating_user2 INTEGER DEFAULT NULL,
    p_feedback_user1 TEXT DEFAULT NULL,
    p_feedback_user2 TEXT DEFAULT NULL
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    IF p_session_id IS NULL OR LENGTH(TRIM(p_session_id)) = 0 THEN
        RAISE EXCEPTION 'El ID de la sesión no puede estar vacío.';
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM sessions WHERE session_id = p_session_id
    ) INTO v_exists;

    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe una sesión con el ID %.', p_session_id;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM exchange_sessions WHERE session_id = p_session_id
    ) INTO v_exists;

    IF v_exists THEN
        RAISE EXCEPTION 'Ya existe un registro de intercambio para la sesión %.', p_session_id;
    END IF;

    INSERT INTO exchange_sessions (
        session_id,
        session_rating_user1,
        session_rating_user2,
        feedback_user1,
        feedback_user2
    )
    VALUES (
        p_session_id,
        p_session_rating_user1,
        p_session_rating_user2,
        p_feedback_user1,
        p_feedback_user2
    );

    RETURN format('Registro de intercambio creado para la sesión %.', p_session_id);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_user_exchange_sessions_with_details(
    p_user_id INTEGER
)
RETURNS TABLE (
    session_id VARCHAR,
    id_user1 INTEGER,
    id_user2 INTEGER,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    session_status VARCHAR,
    session_rating_user1 INTEGER,
    session_rating_user2 INTEGER,
    feedback_user1 TEXT,
    feedback_user2 TEXT
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        s.session_id,
        s.id_user1,
        s.id_user2,
        s.start_time,
        s.end_time,
        s.session_status,
        es.session_rating_user1,
        es.session_rating_user2,
        es.feedback_user1,
        es.feedback_user2
    FROM sessions s
    INNER JOIN exchange_sessions es ON s.session_id = es.session_id
    WHERE s.id_user1 = p_user_id OR s.id_user2 = p_user_id
    ORDER BY s.start_time DESC;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_pending_ratings_for_user(
    p_user_id INTEGER
)
RETURNS TABLE (
    session_id VARCHAR,
    id_user1 INTEGER,
    id_user2 INTEGER,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    user_position INTEGER,
    already_rated BOOLEAN
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        s.session_id,
        s.id_user1,
        s.id_user2,
        s.start_time,
        s.end_time,
        CASE 
            WHEN s.id_user1 = p_user_id THEN 1
            ELSE 2
        END AS user_position,
        CASE 
            WHEN s.id_user1 = p_user_id THEN es.session_rating_user1 IS NOT NULL
            ELSE es.session_rating_user2 IS NOT NULL
        END AS already_rated
    FROM sessions s
    INNER JOIN exchange_sessions es ON s.session_id = es.session_id
    WHERE (s.id_user1 = p_user_id OR s.id_user2 = p_user_id)
      AND s.session_status = 'completed'
      AND (
          (s.id_user1 = p_user_id AND es.session_rating_user1 IS NULL)
          OR
          (s.id_user2 = p_user_id AND es.session_rating_user2 IS NULL)
      )
    ORDER BY s.end_time DESC;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_user_average_rating(
    p_user_id INTEGER
)
RETURNS TABLE (
    user_id INTEGER,
    total_sessions INTEGER,
    average_rating DECIMAL,
    total_ratings_received INTEGER
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        p_user_id AS user_id,
        COUNT(*)::INTEGER AS total_sessions,
        ROUND(
            AVG(
                CASE 
                    WHEN s.id_user1 = p_user_id THEN es.session_rating_user2
                    ELSE es.session_rating_user1
                END
            ), 2
        ) AS average_rating,
        COUNT(
            CASE 
                WHEN s.id_user1 = p_user_id THEN es.session_rating_user2
                ELSE es.session_rating_user1
            END
        )::INTEGER AS total_ratings_received
    FROM sessions s
    INNER JOIN exchange_sessions es ON s.session_id = es.session_id
    WHERE s.id_user1 = p_user_id OR s.id_user2 = p_user_id
      AND s.session_status = 'completed';
END;
$$ LANGUAGE plpgsql;