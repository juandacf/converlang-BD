/*
    . Función 'fun_increme_user':
        - Retorna el siguiente valor disponible de la secuencia.
        - Permite obtener un nuevo ID de usuario de forma controlada y segura 
        desde la aplicación o procedimientos almacenados.
*/

CREATE OR REPLACE FUNCTION fun_increm_user()
RETURNS INTEGER AS $$
DECLARE
    v_next_id INTEGER;
BEGIN
    SELECT COALESCE(MAX(id_user), 0) + 1
    INTO v_next_id
    FROM users;

    RETURN v_next_id;
END;
$$ LANGUAGE plpgsql;

-- se agigna la función como default en id_user
ALTER TABLE users
ALTER COLUMN id_user SET DEFAULT fun_increm_user();