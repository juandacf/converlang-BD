CREATE OR REPLACE FUNCTION fun_get_potential_users(p_id_user INTEGER)
RETURNS TABLE (
    id_user INTEGER,
    first_name VARCHAR,
    last_name VARCHAR,
    email VARCHAR,
    native_lang_id_out VARCHAR,
    target_lang_id_out VARCHAR,
    description TEXT,
    profile_photo VARCHAR,
    age INTEGER
)
AS $$
DECLARE
    v_user_native VARCHAR(2);
    v_user_target VARCHAR(2);
BEGIN
    -- Obtener los idiomas del usuario base
    SELECT u.native_lang_id, u.target_lang_id
    INTO v_user_native, v_user_target
    FROM users u
    WHERE u.id_user = p_id_user;   

    RETURN QUERY
    SELECT 
        u2.id_user,
        u2.first_name,
        u2.last_name,
        u2.email,
        u2.native_lang_id AS native_lang_id_out,
        u2.target_lang_id AS target_lang_id_out,
        u2.description,
        u2.profile_photo,
        EXTRACT(YEAR FROM age(CURRENT_DATE, u2.birth_date))::INTEGER AS age
    FROM users u2
    WHERE 
        u2.native_lang_id = v_user_target
        AND u2.target_lang_id = v_user_native
        AND u2.id_user <> p_id_user
        AND u2.is_active = TRUE
        AND u2.role_code = 'user'
        AND NOT EXISTS (
            SELECT 1
            FROM user_likes ul
            WHERE ul.id_user_giver = p_id_user
              AND ul.id_user_receiver = u2.id_user
        )
        AND NOT EXISTS (
            SELECT 1
            FROM user_matches m
            WHERE (m.user_1 = p_id_user AND m.user_2 = u2.id_user)
               OR (m.user_2 = p_id_user AND m.user_1 = u2.id_user)
        )
    ORDER BY u2.last_login DESC;
END;
$$ LANGUAGE plpgsql;
