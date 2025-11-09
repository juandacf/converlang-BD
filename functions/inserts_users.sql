-- Ejecuta cada SELECT para ver el usuario creado como resultado

SELECT * FROM fun_insert_usuarios('John', 'Doe', 'john.doe@example.com', 'hash123', 1, '1990-05-12', 'US', 'john.jpg', 'EN', 'ES', 10, 'BOFAUS', 'Learning Spanish', 'user');
SELECT * FROM fun_insert_usuarios('María', 'López', 'maria.lopez@example.com', 'hash456', 2, '1995-07-19', 'CO', 'maria.jpg', 'ES', 'EN', 10, 'BANCOLOMBIA', 'Aprendiendo inglés', 'user');
SELECT * FROM fun_insert_usuarios('Pierre', 'Dubois', 'pierre.dubois@example.com', 'hash789', 1, '1988-11-05', 'FR', 'pierre.jpg', 'FR', 'EN', 10, 'BNPFR', 'Je veux parler anglais', 'user');
SELECT * FROM fun_insert_usuarios('Emily', 'Smith', 'emily.smith@example.com', 'hash321', 2, '1992-02-20', 'US', 'emily.jpg', 'EN', 'FR', 10, 'BOFAUS', 'Aprendiendo francés', 'user');
SELECT * FROM fun_insert_usuarios('Sophie', 'Martin', 'sophie.martin@example.com', 'hash654', 2, '1998-03-15', 'FR', 'sophie.jpg', 'FR', 'EN', 10, 'BNPFR', 'Je pratique l’anglais', 'user');
SELECT * FROM fun_insert_usuarios('Carlos', 'Ruiz', 'carlos.ruiz@example.com', 'hash987', 1, '1994-09-08', 'CO', 'carlos.jpg', 'ES', 'PT', 10, 'BANCOLOMBIA', 'Aprendiendo portugués', 'user');
SELECT * FROM fun_insert_usuarios('Ana', 'Gómez', 'ana.gomez@example.com', 'hash111', 2, '1999-04-04', 'CO', 'ana.jpg', 'ES', 'FR', 10, 'BANCOLOMBIA', 'Me encanta el francés', 'user');
SELECT * FROM fun_insert_usuarios('Lucas', 'Silva', 'lucas.silva@example.com', 'hash222', 1, '1990-10-17', 'BR', 'lucas.jpg', 'PT', 'ES', 10, 'ITAU', 'Aprendiendo español', 'user');
SELECT * FROM fun_insert_usuarios('Julia', 'Fernández', 'julia.fernandez@example.com', 'hash333', 2, '1989-01-29', 'ES', 'julia.jpg', 'ES', 'EN', 10, 'BBVAES', 'Quiero mejorar mi inglés', 'user');
SELECT * FROM fun_insert_usuarios('Michael', 'Brown', 'michael.brown@example.com', 'hash444', 1, '1987-06-14', 'US', 'michael.jpg', 'EN', 'DE', 10, 'BOFAUS', 'Ich lerne Deutsch', 'user');
-- Nota: idioma DE existe en languages; country se mantiene dentro de tu lista (NO usamos country DE)

SELECT * FROM fun_insert_usuarios('Hans', 'Muller', 'hans.muller@example.com', 'hash555', 1, '1985-12-25', 'FR', 'hans.jpg', 'DE', 'EN', 10, NULL, 'Learning English', 'user');
SELECT * FROM fun_insert_usuarios('Laura', 'Meier', 'laura.meier@example.com', 'hash666', 2, '1993-09-10', 'FR', 'laura.jpg', 'DE', 'ES', 10, NULL, 'Ich liebe Spanisch', 'user');
SELECT * FROM fun_insert_usuarios('Beatriz', 'Campos', 'beatriz.campos@example.com', 'hash777', 2, '1997-03-03', 'CO', 'bea.jpg', 'ES', 'PT', 10, 'BANCOLOMBIA', 'Aprendiendo portugués para viajar', 'user');
SELECT * FROM fun_insert_usuarios('Tiago', 'Souza', 'tiago.souza@example.com', 'hash888', 1, '1996-12-01', 'BR', 'tiago.jpg', 'PT', 'EN', 10, 'ITAU', 'Improve my English', 'user');
SELECT * FROM fun_insert_usuarios('Fernanda', 'Costa', 'fernanda.costa@example.com', 'hash999', 2, '1999-05-22', 'BR', 'fernanda.jpg', 'PT', 'FR', 10, 'ITAU', 'Aprendiendo francés', 'user');
SELECT * FROM fun_insert_usuarios('David', 'Santos', 'david.santos@example.com', 'hash101', 1, '1992-08-10', 'ES', 'david.jpg', 'ES', 'PT', 10, 'BBVAES', 'Practicando portugués', 'user');
SELECT * FROM fun_insert_usuarios('Nathalie', 'Dupont', 'nathalie.dupont@example.com', 'hash202', 2, '1995-11-30', 'FR', 'nathalie.jpg', 'FR', 'ES', 10, 'BNPFR', 'Je veux parler espagnol', 'user');
SELECT * FROM fun_insert_usuarios('Daniel', 'Ramírez', 'daniel.ramirez@example.com', 'hash303', 1, '1990-02-07', 'CO', 'daniel.jpg', 'ES', 'EN', 10, 'BANCOLOMBIA', 'Aprendiendo inglés', 'teacher');
SELECT * FROM fun_insert_usuarios('Samantha', 'Clark', 'samantha.clark@example.com', 'hash404', 2, '1994-08-19', 'US', 'samantha.jpg', 'EN', 'FR', 10, 'BOFAUS', 'Teaching English and learning French', 'teacher');
SELECT * FROM fun_insert_usuarios('Albert', 'García', 'albert.garcia@example.com', 'hash505', 1, '1986-03-14', 'ES', 'albert.jpg', 'ES', 'DE', 10, 'BBVAES', 'Aprendiendo alemán', 'admin');
