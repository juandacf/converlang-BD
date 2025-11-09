CREATE OR REPLACE FUNCTION fun_get_potential_users(p_id_user INTEGER)
RETURNS TABLE (
    id_user INTEGER,
    first_name VARCHAR,
    last_name VARCHAR,
    email VARCHAR,
    native_lang_id VARCHAR,
    target_lang_id VARCHAR,
    description TEXT,
    profile_photo VARCHAR
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u2.id_user,
        u2.first_name,
        u2.last_name,
        u2.email,
        u2.native_lang_id,
        u2.target_lang_id,
        u2.description,
        u2.profile_photo
    FROM users u1
    JOIN users u2
        ON u1.native_lang_id = u2.target_lang_id
       AND u1.target_lang_id = u2.native_lang_id
       AND u1.id_user <> u2.id_user
    WHERE u1.id_user = p_id_user
      AND u2.is_active = TRUE
      AND u2.email_verified = TRUE
    ORDER BY u2.last_login DESC
    LIMIT u1.match_quantity;
END;
$$ LANGUAGE plpgsql;
