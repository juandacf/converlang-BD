-- ================================================================
-- FUNCIÓN: fun_create_password_reset
-- Crea o actualiza un token de recuperación para un usuario.
-- ================================================================
CREATE OR REPLACE FUNCTION fun_create_password_reset(
    p_reset_id VARCHAR(50),
    p_id_user INTEGER,
    p_reset_token VARCHAR(255),
    p_expires_at TIMESTAMP
) RETURNS VOID AS $$
BEGIN
    INSERT INTO password_resets (reset_id, id_user, reset_token, expires_at)
    VALUES (p_reset_id, p_id_user, p_reset_token, p_expires_at)
    ON CONFLICT (id_user) DO UPDATE 
    SET reset_id = EXCLUDED.reset_id, 
        reset_token = EXCLUDED.reset_token, 
        expires_at = EXCLUDED.expires_at;
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- FUNCIÓN: fun_get_password_reset_by_token
-- Obtiene el registro de recuperación basado en el token.
-- ================================================================
CREATE OR REPLACE FUNCTION fun_get_password_reset_by_token(
    p_token VARCHAR(255)
) RETURNS TABLE (id_user INTEGER, expires_at TIMESTAMP) AS $$
BEGIN
    RETURN QUERY
    SELECT pr.id_user, pr.expires_at
    FROM password_resets pr
    WHERE pr.reset_token = p_token;
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- FUNCIÓN: fun_delete_password_reset
-- Elimina un token de recuperación de contraseña para un usuario.
-- ================================================================
CREATE OR REPLACE FUNCTION fun_delete_password_reset(
    p_id_user INTEGER
) RETURNS VOID AS $$
BEGIN
    DELETE FROM password_resets WHERE id_user = p_id_user;
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- FUNCIÓN: fun_update_user_password
-- Actualiza la contraseña hasheada de un usuario.
-- ================================================================
CREATE OR REPLACE FUNCTION fun_update_user_password(
    p_id_user INTEGER,
    p_password_hash VARCHAR(255)
) RETURNS VOID AS $$
BEGIN
    UPDATE users 
    SET password_hash = p_password_hash, 
        updated_at = NOW() 
    WHERE id_user = p_id_user;
END;
$$ LANGUAGE plpgsql;
