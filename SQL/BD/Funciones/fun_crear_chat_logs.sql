-- Secuencia y función
CREATE SEQUENCE IF NOT EXISTS seq_messages START 1;

CREATE OR REPLACE FUNCTION fun_increme_message()
RETURNS TEXT AS $$
BEGIN
  RETURN 'MSG_' || to_char(NOW(), 'YYYYMMDD') || '_' ||
         lpad(nextval('seq_messages')::text, 3, '0');
END;
$$ LANGUAGE plpgsql;

-- Default en la columna
ALTER TABLE chat_logs
ALTER COLUMN message_id SET DEFAULT fun_increme_message();

