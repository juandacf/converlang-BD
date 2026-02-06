--Funcion que se ejecuta cuando un usuario es reportado 3 veces, tenemos una funcion que aumenta el contador de reportes
--y este trigger se encarga de inactivar al usuario

CREATE OR REPLACE FUNCTION trg_enforce_inactivation()
RETURNS TRIGGER AS $$
BEGIN
    -- Si el nuevo conteo llega al umbral, inactivamos automáticamente
    IF NEW.report_quantity >= 3 THEN
        NEW.is_active := FALSE;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_report_limit
BEFORE UPDATE OF report_quantity ON users -- Solo se dispara si cambia el contador
FOR EACH ROW
EXECUTE FUNCTION trg_enforce_inactivation();