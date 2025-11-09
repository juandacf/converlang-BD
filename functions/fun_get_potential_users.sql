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
DECLARE
    v_limit INTEGER;
    v_native_lang VARCHAR(2);
    v_target_lang VARCHAR(2);
BEGIN
    -- Obtener datos del usuario base
    SELECT match_quantity, native_lang_id, target_lang_id
    INTO v_limit, v_native_lang, v_target_lang
    FROM users
    WHERE users.id_user = p_id_user;

    IF v_limit IS NULL THEN
        RAISE EXCEPTION 'No existe un usuario con id %', p_id_user;
    END IF;

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
    FROM users u2
    WHERE u2.native_lang_id = v_target_lang
      AND u2.target_lang_id = v_native_lang
      AND u2.id_user <> p_id_user
      AND u2.is_active = TRUE
      AND u2.email_verified = TRUE
    ORDER BY u2.last_login DESC
    LIMIT v_limit;
END;
$$ LANGUAGE plpgsql;
