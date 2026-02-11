-- ============================
-- FUNCIÓN: OTORGAR TÍTULO A USUARIO
-- ============================
CREATE OR REPLACE FUNCTION grant_title_to_user(
    p_id_user INTEGER,
    p_title_code VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_user_active BOOLEAN;
    v_title_code_normalized VARCHAR;
    v_title_name VARCHAR;
BEGIN
    -- ============================
    -- VALIDACIONES BÁSICAS
    -- ============================
    IF p_id_user IS NULL THEN
        RAISE EXCEPTION 'El ID del usuario no puede estar vacío.';
    END IF;
    
    IF p_title_code IS NULL OR LENGTH(TRIM(p_title_code)) = 0 THEN
        RAISE EXCEPTION 'El código del título no puede estar vacío.';
    END IF;
    
    -- Normalizar código del título
    v_title_code_normalized := normalize_title_code(p_title_code);
    
    -- ============================
    -- VERIFICAR EXISTENCIA DEL USUARIO
    -- ============================
    SELECT is_active INTO v_user_active
    FROM users
    WHERE id_user = p_id_user;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe un usuario con el ID %.', p_id_user;
    END IF;
    
    IF NOT v_user_active THEN
        RAISE EXCEPTION 'El usuario con ID % no está activo.', p_id_user;
    END IF;
    
    -- ============================
    -- VERIFICAR EXISTENCIA DEL TÍTULO
    -- ============================
    SELECT title_name INTO v_title_name
    FROM titles
    WHERE title_code = v_title_code_normalized;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe un título con el código %.', v_title_code_normalized;
    END IF;
    
    -- ============================
    -- VERIFICAR SI EL USUARIO YA TIENE EL TÍTULO
    -- ============================
    SELECT EXISTS(
        SELECT 1 FROM user_titles 
        WHERE id_user = p_id_user 
        AND title_code = v_title_code_normalized
    ) INTO v_exists;
    
    IF v_exists THEN
        RAISE EXCEPTION 'El usuario % ya tiene el título "%s" (%s).', p_id_user, v_title_name, v_title_code_normalized;
    END IF;
    
    -- ============================
    -- OTORGAR TÍTULO
    -- ============================
    INSERT INTO user_titles (id_user, title_code)
    VALUES (p_id_user, v_title_code_normalized);
    
    RETURN format('Título "%s" (%s) otorgado al usuario %s correctamente.', v_title_name, v_title_code_normalized, p_id_user);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: REVOCAR TÍTULO DE USUARIO
-- ============================
CREATE OR REPLACE FUNCTION revoke_title_from_user(
    p_id_user INTEGER,
    p_title_code VARCHAR
)
RETURNS TEXT AS
$$
DECLARE
    v_exists BOOLEAN;
    v_title_code_normalized VARCHAR;
    v_title_name VARCHAR;
BEGIN
    -- ============================
    -- VALIDACIONES BÁSICAS
    -- ============================
    IF p_id_user IS NULL THEN
        RAISE EXCEPTION 'El ID del usuario no puede estar vacío.';
    END IF;
    
    IF p_title_code IS NULL OR LENGTH(TRIM(p_title_code)) = 0 THEN
        RAISE EXCEPTION 'El código del título no puede estar vacío.';
    END IF;
    
    v_title_code_normalized := normalize_title_code(p_title_code);
    
    -- Obtener nombre del título para el mensaje
    SELECT title_name INTO v_title_name
    FROM titles
    WHERE title_code = v_title_code_normalized;
    
    -- ============================
    -- VERIFICAR SI EL USUARIO TIENE EL TÍTULO
    -- ============================
    SELECT EXISTS(
        SELECT 1 FROM user_titles 
        WHERE id_user = p_id_user 
        AND title_code = v_title_code_normalized
    ) INTO v_exists;
    
    IF NOT v_exists THEN
        RAISE EXCEPTION 'El usuario % no tiene el título "%s" (%s).', p_id_user, COALESCE(v_title_name, 'Desconocido'), v_title_code_normalized;
    END IF;
    
    -- ============================
    -- REVOCAR TÍTULO
    -- ============================
    DELETE FROM user_titles
    WHERE id_user = p_id_user
    AND title_code = v_title_code_normalized;
    
    RETURN format('Título "%s" (%s) revocado del usuario %s correctamente.', COALESCE(v_title_name, 'Desconocido'), v_title_code_normalized, p_id_user);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER TÍTULOS DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_user_titles(
    p_id_user INTEGER
)
RETURNS TABLE (
    title_code VARCHAR,
    title_name VARCHAR,
    title_description VARCHAR,
    earned_at TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        t.title_code,
        t.title_name,
        t.title_description,
        ut.earned_at
    FROM user_titles ut
    INNER JOIN titles t ON ut.title_code = t.title_code
    WHERE ut.id_user = p_id_user
    ORDER BY ut.earned_at DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER USUARIOS QUE TIENEN UN TÍTULO ESPECÍFICO
-- ============================
CREATE OR REPLACE FUNCTION get_users_with_title(
    p_title_code VARCHAR
)
RETURNS TABLE (
    id_user INTEGER,
    first_name VARCHAR,
    last_name VARCHAR,
    email VARCHAR,
    earned_at TIMESTAMP
)
AS
$$
DECLARE
    v_title_code_normalized VARCHAR;
BEGIN
    v_title_code_normalized := normalize_title_code(p_title_code);
    
    RETURN QUERY
    SELECT
        u.id_user,
        u.first_name,
        u.last_name,
        u.email,
        ut.earned_at
    FROM user_titles ut
    INNER JOIN users u ON ut.id_user = u.id_user
    WHERE ut.title_code = v_title_code_normalized
    ORDER BY ut.earned_at DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: VERIFICAR SI UN USUARIO TIENE UN TÍTULO
-- ============================
CREATE OR REPLACE FUNCTION user_has_title(
    p_id_user INTEGER,
    p_title_code VARCHAR
)
RETURNS BOOLEAN AS
$$
DECLARE
    v_exists BOOLEAN;
    v_title_code_normalized VARCHAR;
BEGIN
    v_title_code_normalized := normalize_title_code(p_title_code);
    
    SELECT EXISTS(
        SELECT 1 FROM user_titles 
        WHERE id_user = p_id_user 
        AND title_code = v_title_code_normalized
    ) INTO v_exists;
    
    RETURN v_exists;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: CONTAR TÍTULOS DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION count_user_titles(
    p_id_user INTEGER
)
RETURNS INTEGER AS
$$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(title_code) INTO v_count
    FROM user_titles
    WHERE id_user = p_id_user;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER TÍTULOS MÁS RECIENTES DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_recent_user_titles(
    p_id_user INTEGER,
    p_limit INTEGER DEFAULT 5
)
RETURNS TABLE (
    title_code VARCHAR,
    title_name VARCHAR,
    title_description VARCHAR,
    earned_at TIMESTAMP,
    days_since_earned INTEGER
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        t.title_code,
        t.title_name,
        t.title_description,
        ut.earned_at,
        EXTRACT(DAY FROM (CURRENT_TIMESTAMP - ut.earned_at))::INTEGER as days_since_earned
    FROM user_titles ut
    INNER JOIN titles t ON ut.title_code = t.title_code
    WHERE ut.id_user = p_id_user
    ORDER BY ut.earned_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OTORGAR MÚLTIPLES TÍTULOS A UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION grant_multiple_titles(
    p_id_user INTEGER,
    p_title_codes VARCHAR[]
)
RETURNS TEXT AS
$$
DECLARE
    v_title_code VARCHAR;
    v_granted INTEGER := 0;
    v_skipped INTEGER := 0;
    v_title_code_normalized VARCHAR;
    v_exists BOOLEAN;
BEGIN
    -- Verificar que el usuario existe
    SELECT EXISTS(SELECT 1 FROM users WHERE id_user = p_id_user) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'No existe un usuario con el ID %.', p_id_user;
    END IF;
    
    -- Iterar sobre los códigos de títulos
    FOREACH v_title_code IN ARRAY p_title_codes
    LOOP
        v_title_code_normalized := normalize_title_code(v_title_code);
        
        -- Verificar que el título existe
        SELECT EXISTS(SELECT 1 FROM titles WHERE title_code = v_title_code_normalized) INTO v_exists;
        IF NOT v_exists THEN
            v_skipped := v_skipped + 1;
            CONTINUE;
        END IF;
        
        -- Verificar si ya tiene el título
        SELECT EXISTS(
            SELECT 1 FROM user_titles 
            WHERE id_user = p_id_user 
            AND title_code = v_title_code_normalized
        ) INTO v_exists;
        
        IF NOT v_exists THEN
            INSERT INTO user_titles (id_user, title_code)
            VALUES (p_id_user, v_title_code_normalized);
            v_granted := v_granted + 1;
        ELSE
            v_skipped := v_skipped + 1;
        END IF;
    END LOOP;
    
    RETURN format('Títulos otorgados al usuario %s: %s concedidos, %s omitidos.', p_id_user, v_granted, v_skipped);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: REVOCAR TODOS LOS TÍTULOS DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION revoke_all_user_titles(
    p_id_user INTEGER
)
RETURNS TEXT AS
$$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(title_code) INTO v_count
    FROM user_titles
    WHERE id_user = p_id_user;
    
    DELETE FROM user_titles WHERE id_user = p_id_user;
    
    RETURN format('Revocados %s títulos del usuario %s.', v_count, p_id_user);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER RANKING DE USUARIOS POR CANTIDAD DE TÍTULOS
-- ============================
CREATE OR REPLACE FUNCTION get_users_title_ranking(
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    rank INTEGER,
    id_user INTEGER,
    user_name VARCHAR,
    email VARCHAR,
    total_titles INTEGER,
    latest_title VARCHAR,
    latest_title_date TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    WITH user_title_counts AS (
        SELECT 
            ut.id_user,
            COUNT(ut.title_code)::INTEGER as title_count,
            MAX(ut.earned_at) as last_earned
        FROM user_titles ut
        GROUP BY ut.id_user
    ),
    latest_titles AS (
        SELECT DISTINCT ON (ut.id_user)
            ut.id_user,
            t.title_name,
            ut.earned_at
        FROM user_titles ut
        INNER JOIN titles t ON ut.title_code = t.title_code
        ORDER BY ut.id_user, ut.earned_at DESC
    )
    SELECT
        ROW_NUMBER() OVER (ORDER BY utc.title_count DESC, utc.last_earned DESC)::INTEGER as rank,
        u.id_user,
        (u.first_name || ' ' || u.last_name)::VARCHAR as user_name,
        u.email,
        utc.title_count as total_titles,
        lt.title_name as latest_title,
        lt.earned_at as latest_title_date
    FROM user_title_counts utc
    INNER JOIN users u ON utc.id_user = u.id_user
    LEFT JOIN latest_titles lt ON utc.id_user = lt.id_user
    WHERE u.is_active = TRUE
    ORDER BY rank
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER TÍTULOS POPULARES
-- ============================
CREATE OR REPLACE FUNCTION get_popular_titles(
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    title_code VARCHAR,
    title_name VARCHAR,
    title_description VARCHAR,
    users_count INTEGER,
    last_granted TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        t.title_code,
        t.title_name,
        t.title_description,
        COUNT(ut.id_user)::INTEGER as users_count,
        MAX(ut.earned_at) as last_granted
    FROM titles t
    LEFT JOIN user_titles ut ON t.title_code = ut.title_code
    GROUP BY t.title_code, t.title_name, t.title_description
    ORDER BY users_count DESC, last_granted DESC NULLS LAST
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER TÍTULOS RAROS (MENOS OTORGADOS)
-- ============================
CREATE OR REPLACE FUNCTION get_rare_titles(
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    title_code VARCHAR,
    title_name VARCHAR,
    title_description VARCHAR,
    users_count INTEGER
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        t.title_code,
        t.title_name,
        t.title_description,
        COUNT(ut.id_user)::INTEGER as users_count
    FROM titles t
    LEFT JOIN user_titles ut ON t.title_code = ut.title_code
    GROUP BY t.title_code, t.title_name, t.title_description
    ORDER BY users_count ASC, t.title_name ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER TÍTULOS NO OBTENIDOS POR UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_titles_not_earned_by_user(
    p_id_user INTEGER
)
RETURNS TABLE (
    title_code VARCHAR,
    title_name VARCHAR,
    title_description VARCHAR,
    total_users_with_title INTEGER
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        t.title_code,
        t.title_name,
        t.title_description,
        (SELECT COUNT(ut2.id_user)::INTEGER FROM user_titles ut2 WHERE ut2.title_code = t.title_code) as total_users_with_title
    FROM titles t
    WHERE NOT EXISTS (
        SELECT 1 FROM user_titles ut
        WHERE ut.id_user = p_id_user
        AND ut.title_code = t.title_code
    )
    ORDER BY total_users_with_title DESC, t.title_name ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER ESTADÍSTICAS DE TÍTULOS DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_user_title_statistics(
    p_id_user INTEGER
)
RETURNS TABLE (
    user_id INTEGER,
    total_titles INTEGER,
    titles_last_week INTEGER,
    titles_last_month INTEGER,
    first_title_date TIMESTAMP,
    last_title_date TIMESTAMP,
    most_recent_title VARCHAR,
    titles_available INTEGER
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        p_id_user as user_id,
        COUNT(ut.title_code)::INTEGER as total_titles,
        COUNT(CASE WHEN ut.earned_at >= CURRENT_TIMESTAMP - INTERVAL '7 days' THEN 1 END)::INTEGER as titles_last_week,
        COUNT(CASE WHEN ut.earned_at >= CURRENT_TIMESTAMP - INTERVAL '30 days' THEN 1 END)::INTEGER as titles_last_month,
        MIN(ut.earned_at) as first_title_date,
        MAX(ut.earned_at) as last_title_date,
        (SELECT t.title_name FROM user_titles ut2 
         INNER JOIN titles t ON ut2.title_code = t.title_code 
         WHERE ut2.id_user = p_id_user 
         ORDER BY ut2.earned_at DESC 
         LIMIT 1) as most_recent_title,
        (SELECT COUNT(title_code)::INTEGER FROM titles) as titles_available
    FROM user_titles ut
    WHERE ut.id_user = p_id_user;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER TÍTULOS COMPARTIDOS ENTRE DOS USUARIOS
-- ============================
CREATE OR REPLACE FUNCTION get_shared_titles_between_users(
    p_user1_id INTEGER,
    p_user2_id INTEGER
)
RETURNS TABLE (
    title_code VARCHAR,
    title_name VARCHAR,
    title_description VARCHAR,
    user1_earned_at TIMESTAMP,
    user2_earned_at TIMESTAMP
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        t.title_code,
        t.title_name,
        t.title_description,
        ut1.earned_at as user1_earned_at,
        ut2.earned_at as user2_earned_at
    FROM user_titles ut1
    INNER JOIN user_titles ut2 ON ut1.title_code = ut2.title_code
    INNER JOIN titles t ON ut1.title_code = t.title_code
    WHERE ut1.id_user = p_user1_id
    AND ut2.id_user = p_user2_id
    ORDER BY t.title_name ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- FUNCIÓN: OBTENER USUARIOS QUE OBTUVIERON TÍTULO EN UN PERÍODO
-- ============================
CREATE OR REPLACE FUNCTION get_users_who_earned_title_in_period(
    p_title_code VARCHAR,
    p_start_date TIMESTAMP,
    p_end_date TIMESTAMP
)
RETURNS TABLE (
    id_user INTEGER,
    user_name VARCHAR,
    email VARCHAR,
    earned_at TIMESTAMP
)
AS
$$
DECLARE
    v_title_code_normalized VARCHAR;
BEGIN
    v_title_code_normalized := normalize_title_code(p_title_code);
    
    RETURN QUERY
    SELECT
        u.id_user,
        (u.first_name || ' ' || u.last_name)::VARCHAR as user_name,
        u.email,
        ut.earned_at
    FROM user_titles ut
    INNER JOIN users u ON ut.id_user = u.id_user
    WHERE ut.title_code = v_title_code_normalized
    AND ut.earned_at BETWEEN p_start_date AND p_end_date
    ORDER BY ut.earned_at DESC;
END;
$$ LANGUAGE plpgsql;


-- ============================
-- FUNCIÓN: OBTENER TÍTULO MÁS RECIENTE DE UN USUARIO
-- ============================
CREATE OR REPLACE FUNCTION get_user_latest_title(p_id_user INTEGER)
RETURNS TABLE (
    title_code VARCHAR,
    title_name VARCHAR,
    title_description VARCHAR,
    earned_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT t.title_code, t.title_name, t.title_description, ut.earned_at
    FROM user_titles ut
    INNER JOIN titles t ON ut.title_code = t.title_code
    WHERE ut.id_user = p_id_user
    ORDER BY ut.earned_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

/*
  TRIGGER: Asignación automática de títulos por número de sesiones

  Propósito:
    - Después de cada INSERT en la tabla sessions, cuenta las sesiones totales
      de cada usuario participante (id_user1 e id_user2).
    - Según el número de sesiones, asigna automáticamente el título correspondiente
      en la tabla user_titles.

  Umbrales:
    - 1    sesión   → beginner
    - 10   sesiones → enthusiast
    - 50   sesiones → intermediate
    - 100  sesiones → advanced
    - 1000 sesiones → master

  Notas:
    - Usa INSERT ... ON CONFLICT DO NOTHING para evitar duplicados, ya que
      la PK compuesta (id_user, title_code) de user_titles lo protege.
    - Evalúa a ambos usuarios de la sesión.
*/

-- ============================
-- FUNCIÓN AUXILIAR: Asignar título a un usuario específico
-- ============================
CREATE OR REPLACE FUNCTION assign_title_to_user(p_user_id INTEGER)
RETURNS VOID AS
$$
DECLARE
    v_session_count INTEGER;
BEGIN
    -- Contar sesiones totales del usuario (como user1 o user2)
    SELECT COUNT(session_id) INTO v_session_count
    FROM sessions
    WHERE id_user1 = p_user_id OR id_user2 = p_user_id;

    -- Asignar títulos según umbrales (de mayor a menor para asignar todos los que correspondan)

    -- 1000+ sesiones → master
    IF v_session_count >= 1000 THEN
        INSERT INTO user_titles (id_user, title_code)
        VALUES (p_user_id, 'master')
        ON CONFLICT (id_user, title_code) DO NOTHING;
    END IF;

    -- 100+ sesiones → advanced
    IF v_session_count >= 100 THEN
        INSERT INTO user_titles (id_user, title_code)
        VALUES (p_user_id, 'advanced')
        ON CONFLICT (id_user, title_code) DO NOTHING;
    END IF;

    -- 50+ sesiones → intermediate
    IF v_session_count >= 50 THEN
        INSERT INTO user_titles (id_user, title_code)
        VALUES (p_user_id, 'intermediate')
        ON CONFLICT (id_user, title_code) DO NOTHING;
    END IF;

    -- 10+ sesiones → enthusiast
    IF v_session_count >= 10 THEN
        INSERT INTO user_titles (id_user, title_code)
        VALUES (p_user_id, 'enthusiast')
        ON CONFLICT (id_user, title_code) DO NOTHING;
    END IF;

    -- 1+ sesión → beginner
    IF v_session_count >= 1 THEN
        INSERT INTO user_titles (id_user, title_code)
        VALUES (p_user_id, 'beginner')
        ON CONFLICT (id_user, title_code) DO NOTHING;
    END IF;

END;
$$ LANGUAGE plpgsql;


-- ============================
-- TRIGGER FUNCTION: assign_title_by_sessions()
-- ============================
CREATE OR REPLACE FUNCTION assign_title_by_sessions()
RETURNS TRIGGER AS
$$
BEGIN
    -- Evaluar y asignar títulos al usuario 1
    PERFORM assign_title_to_user(NEW.id_user1);

    -- Evaluar y asignar títulos al usuario 2
    PERFORM assign_title_to_user(NEW.id_user2);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ============================
-- TRIGGER: trg_assign_title_after_session
-- Se dispara AFTER INSERT en sessions
-- ============================
DROP TRIGGER IF EXISTS trg_assign_title_after_session ON sessions;

CREATE TRIGGER trg_assign_title_after_session
AFTER INSERT ON sessions
FOR EACH ROW
EXECUTE FUNCTION assign_title_by_sessions();
