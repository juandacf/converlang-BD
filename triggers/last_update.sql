
-- TRIGGER: update_user_progress_timestamp
-- OBJETIVO: Mantener actualizada la columna 'last_updated'
--           en la tabla 'user_progress' cada vez que se
--           modifica un registro.
-- BENEFICIO: Garantiza la trazabilidad de los cambios
--            sin depender de la aplicación cliente.

-- Elimina el trigger si ya existe para evitar duplicados
DROP TRIGGER IF EXISTS trg_update_progress_timestamp ON user_progress;

-- FUNCIÓN: update_progress_timestamp()
--   Esta función se ejecuta antes de cada UPDATE en la tabla 'user_progress'.
--   Su propósito es actualizar automáticamente el campo 'last_updated'
--   con la fecha y hora actual del sistema.
-- ============================================
CREATE OR REPLACE FUNCTION update_progress_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    -- Asigna la fecha y hora actual al campo 'last_updated'
    NEW.last_updated = CURRENT_TIMESTAMP;
    -- Devuelve la fila modificada para continuar con el UPDATE
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- TRIGGER: update_user_progress_timestamp
--   Este trigger se activa ANTES de cada UPDATE en la tabla 'user_progress'.
--   Llama a la función 'update_progress_timestamp' para sellar la fecha y hora
--   de la última modificación.
-- ============================================
CREATE TRIGGER update_user_progress_timestamp 
    BEFORE UPDATE ON user_progress 
    FOR EACH ROW EXECUTE FUNCTION update_progress_timestamp();
