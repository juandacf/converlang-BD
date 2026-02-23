-- ============================================================
-- FUNCIONES POSTGRESQL PARA MÉTRICAS DE USUARIO
-- Tablas: sessions, user_matches, chat_logs, users, countries
-- ============================================================

-- 1. Usuario preferido (con quien más sesiones/videollamadas tiene)
CREATE OR REPLACE FUNCTION fun_get_preferred_match_user(p_user_id INT)
RETURNS TABLE(
  id_user INT,
  first_name VARCHAR,
  last_name VARCHAR,
  profile_photo VARCHAR,
  interaction_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
    SELECT
      u.id_user,
      u.first_name,
      u.last_name,
      u.profile_photo,
      SUM(1)::BIGINT AS interaction_count
    FROM sessions s
    JOIN users u ON (
      (s.id_user1 = p_user_id AND u.id_user = s.id_user2) OR
      (s.id_user2 = p_user_id AND u.id_user = s.id_user1)
    )
    GROUP BY u.id_user, u.first_name, u.last_name, u.profile_photo
    ORDER BY interaction_count DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;


-- 2. Países de los matches del usuario
CREATE OR REPLACE FUNCTION fun_get_match_countries(p_user_id INT)
RETURNS TABLE(
  country_name VARCHAR,
  match_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
    SELECT
      c.country_name,
      SUM(1)::BIGINT AS match_count
    FROM user_matches m
    JOIN users u ON (
      (m.user_1 = p_user_id AND u.id_user = m.user_2) OR
      (m.user_2 = p_user_id AND u.id_user = m.user_1)
    )
    JOIN countries c ON c.country_code = u.country_id
    GROUP BY c.country_name
    ORDER BY match_count DESC;
END;
$$ LANGUAGE plpgsql;


-- 3. Palabras más usadas en chats
CREATE OR REPLACE FUNCTION fun_get_chat_words(p_user_id INT)
RETURNS TABLE(
  word TEXT,
  frequency BIGINT
) AS $$
BEGIN
  RETURN QUERY
    SELECT
      LOWER(w.word) AS word,
      SUM(1)::BIGINT AS frequency
    FROM chat_logs cl
    JOIN user_matches m ON cl.match_id = m.match_id
    CROSS JOIN LATERAL unnest(string_to_array(cl.message, ' ')) AS w(word)
    WHERE cl.sender_id = p_user_id
      AND LENGTH(w.word) > 3
      AND LOWER(w.word) NOT IN (
        'para', 'como', 'pero', 'esto', 'esta', 'esos', 'esas',
        'that', 'this', 'with', 'have', 'from', 'they', 'been',
        'will', 'would', 'could', 'should', 'what', 'when', 'where',
        'just', 'more', 'some', 'than', 'them', 'then', 'very',
        'also', 'does', 'your', 'each', 'make', 'like', 'long',
        'look', 'many', 'most', 'only', 'over', 'such', 'take',
        'come', 'know', 'bien', 'aqui', 'algo', 'otro', 'otra',
        'hola', 'yeah', 'okay', 'jaja', 'haha', 'jeje'
      )
    GROUP BY LOWER(w.word)
    ORDER BY frequency DESC
    LIMIT 20;
END;
$$ LANGUAGE plpgsql;


-- 4. Matches nuevos en los últimos 30 días
CREATE OR REPLACE FUNCTION fun_get_new_matches_count(p_user_id INT)
RETURNS TABLE(
  new_matches BIGINT
) AS $$
BEGIN
  RETURN QUERY
    SELECT SUM(1)::BIGINT AS new_matches
    FROM user_matches m
    WHERE (m.user_1 = p_user_id OR m.user_2 = p_user_id)
      AND m.match_time >= NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;


-- 5. Promedio de mensajes por videollamada
CREATE OR REPLACE FUNCTION fun_get_avg_interactions_per_call(p_user_id INT)
RETURNS TABLE(
  avg_interactions NUMERIC
) AS $$
BEGIN
  RETURN QUERY
    SELECT
      COALESCE(
        ROUND(
          (SELECT SUM(1)::NUMERIC FROM chat_logs cl2
           JOIN user_matches m2 ON cl2.match_id = m2.match_id
           WHERE cl2.sender_id = p_user_id
          ) /
          NULLIF(
            (SELECT SUM(1)::NUMERIC FROM sessions s2
             WHERE s2.id_user1 = p_user_id OR s2.id_user2 = p_user_id),
            0
          ),
          1
        ),
        0
      ) AS avg_interactions;
END;
$$ LANGUAGE plpgsql;
