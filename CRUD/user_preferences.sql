CREATE OR REPLACE FUNCTION create_default_user_preferences()
RETURNS TRIGGER AS
$$
BEGIN
    INSERT INTO user_preferences (
        user_id,
        theme,
        language_code,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id_user,
        TRUE,          -- Modo luminoso
        'EN',          -- Idioma interfaz
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    )
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_create_default_user_preferences
AFTER INSERT ON users
FOR EACH ROW
EXECUTE FUNCTION create_default_user_preferences();


CREATE OR REPLACE FUNCTION update_user_preferences(
    p_user_id INTEGER,
    p_theme BOOLEAN DEFAULT NULL,
    p_language_code VARCHAR(2) DEFAULT NULL
)
RETURNS TEXT
AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    -- ============================
    -- VALIDAR USUARIO
    -- ============================
    SELECT EXISTS (
        SELECT 1
        FROM users u
        WHERE u.id_user = p_user_id
    ) INTO v_exists;

    IF NOT v_exists THEN
        RAISE EXCEPTION 'El usuario con ID % no existe.', p_user_id;
    END IF;

    -- ============================
    -- VALIDAR QUE EXISTAN PREFERENCIAS
    -- ============================
    SELECT EXISTS (
        SELECT 1
        FROM user_preferences up
        WHERE up.user_id = p_user_id
    ) INTO v_exists;

    IF NOT v_exists THEN
        RAISE EXCEPTION 'El usuario % no tiene preferencias registradas.', p_user_id;
    END IF;

    -- ============================
    -- VALIDAR IDIOMA (SI VIENE)
    -- ============================
    IF p_language_code IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1
            FROM languages l
            WHERE l.language_code = UPPER(p_language_code)
        ) INTO v_exists;

        IF NOT v_exists THEN
            RAISE EXCEPTION 'El idioma % no es válido.', p_language_code;
        END IF;
    END IF;

    -- ============================
    -- ACTUALIZAR PREFERENCIAS
    -- ============================
    UPDATE user_preferences up
    SET
        theme = COALESCE(p_theme, up.theme),
        language_code = COALESCE(UPPER(p_language_code), up.language_code),
        updated_at = CURRENT_TIMESTAMP
    WHERE up.user_id = p_user_id;

    RETURN 'Preferencias actualizadas correctamente';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_user_preferences(
    p_user_id INTEGER
)
RETURNS TABLE (
    user_id INTEGER,
    theme BOOLEAN,
    language_code VARCHAR(2),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
)
AS
$$
DECLARE
    v_exists BOOLEAN;
BEGIN
    -- ============================
    -- VALIDAR USUARIO
    -- ============================
    SELECT EXISTS (
        SELECT 1
        FROM users u
        WHERE u.id_user = p_user_id
    ) INTO v_exists;

    IF NOT v_exists THEN
        RAISE EXCEPTION 'El usuario con ID % no existe.', p_user_id;
    END IF;

    -- ============================
    -- VALIDAR QUE EXISTAN PREFERENCIAS
    -- ============================
    SELECT EXISTS (
        SELECT 1
        FROM user_preferences up
        WHERE up.user_id = p_user_id
    ) INTO v_exists;

    IF NOT v_exists THEN
        RAISE EXCEPTION 'El usuario % no tiene preferencias registradas.', p_user_id;
    END IF;

    -- ============================
    -- DEVOLVER PREFERENCIAS
    -- ============================
    RETURN QUERY
    SELECT
        up.user_id,
        up.theme,
        up.language_code,
        up.created_at,
        up.updated_at
    FROM user_preferences up
    WHERE up.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

