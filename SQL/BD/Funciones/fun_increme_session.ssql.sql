CREATE OR REPLACE FUNCTION fun_increme_session()
RETURNS TEXT AS $$
BEGIN
  RETURN 'SES_' || to_char(NOW(), 'YYYYMMDD') || '_' ||
         lpad(nextval('seq_sessions')::text, 3, '0');
END;
$$ LANGUAGE plpgsql;