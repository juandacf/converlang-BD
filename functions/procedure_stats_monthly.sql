-- ============================================================
-- PROCEDIMIENTO: proc_generate_monthly_stats
-- OBJETIVO:
--   Generar estadísticas mensuales de uso de la plataforma,
--   registrar un reporte en la tabla de auditoría y actualizar
--   las métricas de progreso de los usuarios activos en el mes.
-- BENEFICIOS:
--   Permite monitorear el uso mensual, auditar la actividad y
--   mantener actualizadas las métricas de los usuarios.
-- ============================================================

CREATE OR REPLACE PROCEDURE proc_generate_monthly_stats()
LANGUAGE plpgsql
AS $$
DECLARE
    -- Variables para almacenar resultados de métricas generales
    v_total_sessions INT;
    v_total_hours NUMERIC;
    -- Definir el rango de fechas del mes actual
    v_month_start DATE := date_trunc('month', CURRENT_DATE); -- Primer día del mes
    v_month_end   DATE := (date_trunc('month', CURRENT_DATE) + INTERVAL '1 month - 1 day'); -- Último día del mes
BEGIN
    -- ============================================================
    -- 1. Calcular métricas generales del mes actual
    --    - Cuenta total de sesiones y suma de horas registradas
    -- ============================================================
    SELECT COUNT(*), COALESCE(SUM(total_hours),0)
    INTO v_total_sessions, v_total_hours
    FROM user_progress
    WHERE last_updated BETWEEN v_month_start AND v_month_end;

    -- Mostrar resultados en consola (útil para depuración y monitoreo)
    RAISE NOTICE 'Sesiones este mes: %, Horas totales: %', v_total_sessions, v_total_hours;

    -- ============================================================
    -- 2. Insertar reporte de uso en tabla de auditoría
    --    - Registra las métricas calculadas en 'audit_logs'
    --    - Facilita la trazabilidad y el análisis histórico
    -- ============================================================
    INSERT INTO audit_logs (audit_id, table_name, record_id, action, new_values, changed_at)
    VALUES (
        'REPORT_' || to_char(NOW(), 'YYYYMMDDHH24MISS'), -- ID único basado en timestamp
        'monthly_stats',                                 -- Nombre lógico del reporte
        'global',                                        -- Ámbito global del reporte
        'INSERT',                                        -- Acción realizada
        json_build_object('total_sessions', v_total_sessions, 'total_hours', v_total_hours), -- Datos en formato JSON
        NOW()                                            -- Fecha y hora del registro
    );

    -- ============================================================
    -- 3. Actualizar métricas de progreso de usuarios activos
    --    - Suma 1 sesión a cada usuario que tuvo actividad este mes
    --    - Actualiza la fecha de última modificación
    -- ============================================================
    UPDATE user_progress
    SET total_sessions = total_sessions + 1,
        last_updated = NOW()
    WHERE user_id IN (
        -- Usuarios que participaron como id_user1 o id_user2 en sesiones este mes
        SELECT DISTINCT id_user1 FROM sessions WHERE start_time BETWEEN v_month_start AND v_month_end
        UNION
        SELECT DISTINCT id_user2 FROM sessions WHERE start_time BETWEEN v_month_start AND v_month_end
    );

    -- Mensaje de confirmación al finalizar el proceso
    RAISE NOTICE 'Métricas actualizadas correctamente para el mes %', to_char(v_month_start, 'YYYY-MM');
END;
$$;

-- ============================================================
-- EJEMPLOS DE USO Y CONSULTA DE RESULTADOS
-- ============================================================

-- Ejecutar el procedimiento manualmente:
-- CALL proc_generate_monthly_stats();

-- Consultar los últimos reportes generados:
-- SELECT * 
-- FROM audit_logs 
-- WHERE table_name = 'monthly_stats'
-- ORDER BY changed_at DESC
-- LIMIT 5;

-- ============================================================
-- EJEMPLOS DE INSERCIÓN Y ACTUALIZACIÓN EN user_progress
-- ============================================================

-- INSERT INTO user_progress (user_id, language_id, last_updated, total_sessions, total_hours, notes)
-- VALUES (4, 'EN', CURRENT_DATE, 2, 3.5, 'Test user stats');

-- UPDATE user_progress
-- SET total_sessions = total_sessions + 2,
--     total_hours    = total_hours + 3.5,
--     last_updated   = CURRENT_TIMESTAMP,   -- si tienes el trigger BEFORE UPDATE que sella la fecha, puedes omitir
--     notes          = CONCAT_WS(' | ', notes, 'ajuste de prueba +3.5h')
-- WHERE user_id = 2 AND language_id = 'EN';

-- ROLLBACK;

-- CALL proc_generate_monthly_stats();

-- SELECT * FROM audit_logs WHERE table_name = 'monthly_stats' ORDER BY changed_at DESC;
