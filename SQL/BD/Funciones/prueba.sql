select * from users;

INSERT INTO users (
    first_name, last_name, email, password_hash, gender, birth_date,
    country_id, native_lang_id, target_lang_id, match_quantity, description
) VALUES (
    'Carlos', 'Méndez', 'carlos@test.com', 'h1', 'masculino', '1995-01-01',
    'CO', 'ES', 'EN', 10, 'Probando autoincremental'
);
INSERT INTO users (
    first_name, last_name, email, password_hash, gender, birth_date,
    country_id, native_lang_id, target_lang_id, match_quantity, description
) VALUES (
    'Ana', 'Suárez', 'ana@test.com', 'h2', 'femenino', '1998-05-10',
    'MX', 'ES', 'FR', 8, 'Insert test'
);

INSERT INTO sessions (id_user1, id_user2, session_type, start_time, end_time)
VALUES (3, 4, 'exchange', '2025-09-09 15:00:00', '2025-09-09 16:00:00');

INSERT INTO sessions (id_user1, id_user2, session_type, start_time, end_time)
VALUES (3, 4, 'exchange', '2025-09-09 15:00:00', '2025-09-09 16:00:00')
RETURNING session_id;

INSERT INTO users (
    first_name, last_name, email, password_hash, gender, birth_date,
    country_id, native_lang_id, target_lang_id, match_quantity, description
) VALUES (
    'PruebasSSS', 'UsuariosSSSSS', 'pruebasSSSS@example.com', 'hash123', 'masculino', '2000-01-01',
    'MX', 'ES', 'EN', 5, 'Usuario de prueba'
)
RETURNING id_user;









