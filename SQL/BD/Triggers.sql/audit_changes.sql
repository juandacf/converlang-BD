/*
 EXPLICACIÓN PASO A PASO DEL TRIGGER FUNCTION audit_changes()

  Propósito:
    - Esta función se usa como trigger para auditar cambios (INSERT, UPDATE, DELETE) en tablas importantes.
    - Guarda un registro de cada cambio en la tabla audit_logs, incluyendo los datos antes y después, el usuario, la fecha y la IP.

  Obtención del usuario:
    - Intenta leer el ID de usuario desde el contexto de la aplicación ('app.current_user_id').
    - Si no existe, lo deja en NULL.

  Generación de audit_id:
    - Llama a la función generate_audit_id() para obtener un identificador único para el registro.

  Captura de datos:
    - Según el tipo de operación (TG_OP):
        * DELETE: Guarda los datos antiguos (OLD), no hay datos nuevos.
        * UPDATE: Guarda los datos antiguos (OLD) y los nuevos (NEW).
        * INSERT: Guarda solo los datos nuevos (NEW).

  Inserción en audit_logs:
    - Inserta un registro en la tabla audit_logs con toda la información relevante.
    - El campo record_id se llena según la tabla y el tipo de operación.
    - Si ocurre un error al insertar el registro de auditoría, solo muestra una advertencia y no detiene la operación principal.

  Retorno:
    - Para DELETE, retorna OLD (el registro eliminado).
    - Para INSERT y UPDATE, retorna NEW (el registro nuevo o actualizado).

 USO:
    - Esta función debe asociarse a triggers AFTER INSERT/UPDATE/DELETE en las tablas que se desean auditar.
*/

DROP FUNCTION IF EXISTS audit_changes() CASCADE;
-- TRIGGER FUNCTION: audit_changes()
--   - Audita INSERT/UPDATE/DELETE en tablas críticas
--   - Convierte OLD/NEW a JSON y guarda en audit_logs
--   - Obtiene user_id del contexto 'app.current_user_id' si está disponible
--   - Tolera fallos de auditoría sin bloquear la operación principal
-- ====================================================================
CREATE OR REPLACE FUNCTION audit_changes()  -- Crea o reemplaza la función de auditoría
RETURNS TRIGGER AS $$  -- Función compatible con triggers
DECLARE  -- Variables: instantáneas JSON y metadatos
    old_data JSON;  -- Snapshot previo (para UPDATE/DELETE)
    new_data JSON;  -- Snapshot nuevo (para INSERT/UPDATE)
    table_name TEXT;  -- Nombre de la tabla origen (TG_TABLE_NAME)
    current_user_id INTEGER;  -- Usuario que ejecuta la operación si la app lo define
    audit_id_value TEXT;  -- Identificador único de auditoría
BEGIN  -- Cuerpo principal de la auditoría
    table_name := TG_TABLE_NAME;  -- Asigna el nombre real de la tabla origen
    
    -- Intentar obtener user_id del contexto de sesión
    BEGIN  -- Cuerpo principal de la auditoría
        current_user_id := current_setting('app.current_user_id')::INTEGER;  -- Intenta leer el contexto actual de usuario definido por la app
    EXCEPTION
        WHEN OTHERS THEN
            current_user_id := NULL;
    END;  -- Fin del cuerpo de auditoría
    
    -- Generar audit_id usando la función personalizada
    audit_id_value := generate_audit_id();  -- Obtiene un ID de auditoría externo (debe existir la función)
    
    IF TG_OP = 'DELETE' THEN  -- Manejo específico según operación DML
        old_data := row_to_json(OLD);  -- Convierte la fila vieja a JSON para registrar
        new_data := NULL;
        
    ELSIF TG_OP = 'UPDATE' THEN
        old_data := row_to_json(OLD);  --asignacion de la variable old_data
        new_data := row_to_json(NEW);  -- Convierte la fila nueva a JSON
        
    ELSIF TG_OP = 'INSERT' THEN
        new_data := row_to_json(NEW);  -- Convierte la fila nueva a JSON
        old_data := NULL;
    END IF;
    
    -- Insertar log de auditoría
    BEGIN  -- Cuerpo principal de la auditoría
        INSERT INTO audit_logs (  -- Inserta un registro en la tabla de auditoría
            audit_id, table_name, record_id, action, old_values, new_values, 
            changed_by, changed_at, ip_address
        ) VALUES (
            audit_id_value, table_name, 
            CASE 
                WHEN TG_OP = 'DELETE' THEN 
                    CASE table_name
                        WHEN 'users' THEN OLD.id_user::TEXT
                        WHEN 'sessions' THEN OLD.session_id
                        WHEN 'teacher_profiles' THEN OLD.user_id::TEXT
                        ELSE 'unknown'
                    END
                ELSE 
                    CASE table_name
                        WHEN 'users' THEN NEW.id_user::TEXT
                        WHEN 'sessions' THEN NEW.session_id
                        WHEN 'teacher_profiles' THEN NEW.user_id::TEXT
                        ELSE 'unknown'
                    END
            END,
            TG_OP, old_data, new_data, 
            current_user_id, CURRENT_TIMESTAMP, inet_client_addr()::TEXT  -- Captura la IP del cliente para trazabilidad
        );
    EXCEPTION
        WHEN OTHERS THEN
            -- Si falla la auditoría, no bloqueamos la operación principal
            RAISE WARNING 'Error en auditoría para tabla %: %', table_name, SQLERRM;  -- No interrumpe la transacción si la auditoría falla
    END;  -- Fin del cuerpo de auditoría
    
    -- Retornar el registro apropiado
    IF TG_OP = 'DELETE' THEN  -- Manejo específico según operación DML
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;  
$$ LANGUAGE plpgsql; 
