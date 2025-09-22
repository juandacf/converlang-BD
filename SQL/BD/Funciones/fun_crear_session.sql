-- Crear secuencia
CREATE SEQUENCE IF NOT EXISTS seq_sessions START 1;

-- Crear función generadora
CREATE OR REPLACE FUNCTION fun_increme_session()
RETURNS TEXT AS $$
BEGIN
  RETURN 'SES_' || to_char(NOW(), 'YYYYMMDD') || '_' ||
         lpad(nextval('seq_sessions')::text, 3, '0');
END;
$$ LANGUAGE plpgsql;

-- Asignar la función como DEFAULT a la columna
ALTER TABLE sessions
ALTER COLUMN session_id SET DEFAULT fun_increme_session();