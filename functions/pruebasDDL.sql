-- ====================================================================================================
-- SCRIPT DE PRUEBAS REESTRUCTURADO - CONVERLANG DATABASE
-- ====================================================================================================
-- 1. Validación de Integridad Referencial - Detecta registros huérfanos o referencias rotas
-- 2. Análisis de Datos - Estadísticas y distribuciones de usuarios, sesiones y actividad
-- 3. Detección de Inconsistencias - Identifica violaciones a reglas de negocio
-- 4. Rendimiento y Actividad - Usuarios más activos, progreso por idioma
-- 5. Validación de Reglas de Negocio - Verifica restricciones como edad mínima
-- 6. Pruebas de Transacciones - Simula operaciones complejas con rollback seguro
-- 7. Monitoreo del Sistema - Actividad reciente, notificaciones pendientes
-- 8. Limpieza y Mantenimiento - Identifica datos obsoletos o que requieren limpieza
-- 9. Validación de Funciones - Prueba funciones personalizadas
-- 10. Consulta Integral de Salud - Resumen general del estado de la BD
-- 11. Pruebas de Inserción de Usuarios y Teachers
-- 12. Pruebas de Matches y Sesiones

-- ================================================================
-- 1. VALIDACIÓN DE INTEGRIDAD REFERENCIAL
-- ================================================================

-- Verificar usuarios sin país válido
SELECT u.id_user, u.first_name, u.last_name, u.country_id
FROM users u
LEFT JOIN countries c ON u.country_id = c.country_code
WHERE c.country_code IS NULL;

-- Verificar usuarios con idiomas inválidos
SELECT u.id_user, u.first_name, u.native_lang_id, u.target_lang_id
FROM users u
LEFT JOIN languages ln ON u.native_lang_id = ln.language_code
LEFT JOIN languages lt ON u.target_lang_id = lt.language_code
WHERE ln.language_code IS NULL OR lt.language_code IS NULL;

-- Verificar sesiones con usuarios inexistentes
SELECT s.session_id, s.id_user1, s.id_user2
FROM sessions s
LEFT JOIN users u1 ON s.id_user1 = u1.id_user
LEFT JOIN users u2 ON s.id_user2 = u2.id_user
WHERE u1.id_user IS NULL OR u2.id_user IS NULL;

-- Verificar matches sin likes mutuos
SELECT um.user_1, um.user_2, um.match_time
FROM user_matches um
WHERE NOT EXISTS (
    SELECT 1 FROM user_likes ul1 
    WHERE ul1.id_user_giver = um.user_1 AND ul1.id_user_receiver = um.user_2
) OR NOT EXISTS (
    SELECT 1 FROM user_likes ul2 
    WHERE ul2.id_user_giver = um.user_2 AND ul2.id_user_receiver = um.user_1
);

-- ================================================================
-- 2. CONSULTAS DE ANÁLISIS DE DATOS
-- ================================================================

-- Distribución de usuarios por país y porcentaje de uso
SELECT 
    c.country_name,
    COUNT(u.id_user) as total_usuarios,
    COUNT(CASE WHEN u.is_active THEN 1 END) as usuarios_activos,
    CASE 
        WHEN COUNT(u.id_user) = 0 THEN 0
        ELSE ROUND(
            COUNT(CASE WHEN u.is_active THEN 1 END) * 100.0 / COUNT(u.id_user), 
            2
        )
    END as porcentaje_activos
FROM countries c
LEFT JOIN users u ON c.country_code = u.country_id
GROUP BY c.country_code, c.country_name
ORDER BY total_usuarios DESC;

-- Top 10 combinaciones de idiomas más populares
SELECT 
    ln.language_name as idioma_nativo,
    lt.language_name as idioma_objetivo,
    COUNT(*) as cantidad_usuarios
FROM users u
JOIN languages ln ON u.native_lang_id = ln.language_code
JOIN languages lt ON u.target_lang_id = lt.language_code
WHERE u.is_active = TRUE
GROUP BY ln.language_name, lt.language_name
ORDER BY cantidad_usuarios DESC
LIMIT 10;

-- Estadísticas de sesiones por tipo y estado
SELECT 
    session_type,
    session_status,
    COUNT(*) as cantidad,
    AVG(EXTRACT(EPOCH FROM (end_time - start_time))/3600) as promedio_horas
FROM sessions
WHERE start_time IS NOT NULL AND end_time IS NOT NULL
GROUP BY session_type, session_status
ORDER BY session_type, session_status;

-- Profesores más activos y mejor calificados
SELECT 
    u.first_name || ' ' || u.last_name as profesor,
    tp.teaching_language_id as idioma_enseña,
    tp.hourly_rate as tarifa_hora,
    COUNT(ts.session_id) as sesiones_enseñanza,
    AVG(ts.student_rating) as calificacion_promedio
FROM teacher_profiles tp
JOIN users u ON tp.user_id = u.id_user
LEFT JOIN teaching_sessions ts ON tp.user_id = ts.teacher_profile_id
WHERE tp.is_verified = TRUE
GROUP BY u.id_user, u.first_name, u.last_name, tp.teaching_language_id, tp.hourly_rate
HAVING COUNT(ts.session_id) > 0
ORDER BY calificacion_promedio DESC NULLS LAST, sesiones_enseñanza DESC;

-- Distribución de usuarios por rol
SELECT 
    COALESCE(u.role_code, 'sin_rol') as rol,
    ur.role_name,
    COUNT(*) as cantidad_usuarios,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM users), 2) as porcentaje
FROM users u
LEFT JOIN user_roles ur ON u.role_code = ur.role_code
GROUP BY u.role_code, ur.role_name
ORDER BY cantidad_usuarios DESC;

-- ================================================================
-- 3. DETECCIÓN DE INCONSISTENCIAS
-- ================================================================

-- Usuarios que se dieron like a sí mismos (no debería existir)
SELECT id_user_giver, id_user_receiver, like_time
FROM user_likes
WHERE id_user_giver = id_user_receiver;

-- Matches donde user_1 no es menor que user_2 (viola constraint)
SELECT user_1, user_2, match_time
FROM user_matches
WHERE user_1 >= user_2;

-- Sesiones donde un usuario participa consigo mismo
SELECT session_id, id_user1, id_user2, session_type
FROM sessions
WHERE id_user1 = id_user2;

-- Teaching sessions donde el teacher no tiene perfil verificado
SELECT 
    ts.session_id,
    ts.teacher_profile_id,
    tp.is_verified,
    u.first_name || ' ' || u.last_name as teacher_name
FROM teaching_sessions ts
JOIN teacher_profiles tp ON ts.teacher_profile_id = tp.user_id
JOIN users u ON tp.user_id = u.id_user
WHERE tp.is_verified = FALSE;

-- Matches duplicados (no debería existir)
SELECT user_1, user_2, COUNT(*) as veces_duplicado
FROM user_matches
GROUP BY user_1, user_2
HAVING COUNT(*) > 1;

-- Teachers sin rol de teacher asignado
SELECT 
    tp.user_id,
    u.first_name || ' ' || u.last_name as nombre,
    u.role_code,
    tp.is_verified
FROM teacher_profiles tp
JOIN users u ON tp.user_id = u.id_user
WHERE u.role_code != 'teacher' OR u.role_code IS NULL;

-- ================================================================
-- 4. CONSULTAS DE RENDIMIENTO Y ACTIVIDAD
-- ================================================================

-- Usuarios más activos (por número de sesiones)
SELECT 
    u.id_user,
    u.first_name || ' ' || u.last_name as nombre_completo,
    u.country_id,
    COUNT(DISTINCT s1.session_id) + COUNT(DISTINCT s2.session_id) as total_sesiones,
    MAX(GREATEST(
        COALESCE(s1.start_time, '1900-01-01'::timestamp),
        COALESCE(s2.start_time, '1900-01-01'::timestamp)
    )) as ultima_sesion
FROM users u
LEFT JOIN sessions s1 ON u.id_user = s1.id_user1
LEFT JOIN sessions s2 ON u.id_user = s2.id_user2
WHERE u.is_active = TRUE
GROUP BY u.id_user, u.first_name, u.last_name, u.country_id
ORDER BY total_sesiones DESC
LIMIT 20;

-- Progreso de usuarios por idioma
SELECT 
    u.first_name || ' ' || u.last_name as usuario,
    l.language_name as idioma,
    up.total_sessions as sesiones_completadas,
    up.total_hours as horas_acumuladas,
    up.last_updated as ultima_actualizacion,
    up.notes as notas_progreso
FROM user_progress up
JOIN users u ON up.user_id = u.id_user
JOIN languages l ON up.language_id = l.language_code
WHERE up.total_sessions > 0
ORDER BY up.total_hours DESC, up.total_sessions DESC;

-- ================================================================
-- 5. VALIDACIÓN DE REGLAS DE NEGOCIO
-- ================================================================

-- Verificar edad mínima (15 años)
SELECT 
    id_user,
    first_name,
    last_name,
    birth_date,
    EXTRACT(YEAR FROM AGE(birth_date)) as edad
FROM users
WHERE birth_date > CURRENT_DATE - INTERVAL '15 years';

-- Usuarios con idioma nativo igual al objetivo (no debería existir)
SELECT 
    id_user,
    first_name,
    last_name,
    native_lang_id,
    target_lang_id
FROM users
WHERE native_lang_id = target_lang_id;

-- Verificar que los teachers tengan rol teacher
SELECT 
    tp.user_id,
    u.first_name,
    u.last_name,
    u.role_code,
    tp.is_verified
FROM teacher_profiles tp
JOIN users u ON tp.user_id = u.id_user
WHERE u.role_code != 'teacher' OR u.role_code IS NULL;

-- ================================================================
-- 6. PRUEBAS DE TRANSACCIONES
-- ================================================================

-- Simulación de creación de usuario completa con rollback
BEGIN;
    -- Intentar crear usuario con SETOF users
    SELECT * FROM fun_insert_usuarios(
        'TestUser',
        'TestLastName', 
        'test@example.com',
        'hash123',
        1,  -- gender_id como INTEGER
        DATE '1995-01-01',
        'CO',
        NULL,
        'ES',
        'EN',
        10,
        NULL,
        'Usuario de prueba',
        'user'  -- rol del usuario
    );
    
    -- Verificar que se creó
    SELECT id_user, first_name, last_name, email, role_code
    FROM users 
    WHERE email = 'test@example.com';
    
    -- Rollback para no afectar datos reales
ROLLBACK;

-- Prueba de creación de match
BEGIN;
    -- Crear likes mutuos primero
    INSERT INTO user_likes (id_user_giver, id_user_receiver, like_time)
    VALUES (1, 3, NOW()), (3, 1, NOW())
    ON CONFLICT DO NOTHING;
    
    -- Intentar crear match
    SELECT fun_insert_match(1, 3) as resultado_match;
    
    -- Verificar resultado
    SELECT user_1, user_2, match_time
    FROM user_matches
    WHERE (user_1 = 1 AND user_2 = 3) OR (user_1 = 3 AND user_2 = 1);
    
ROLLBACK;

-- ================================================================
-- 7. CONSULTAS DE MONITOREO DEL SISTEMA
-- ================================================================

-- Actividad reciente en chat logs
SELECT 
    cl.message_id,
    um.user_1,
    um.user_2,
    u.first_name as remitente,
    LEFT(cl.message, 50) as mensaje_preview,
    cl.timestamp,
    cl.is_read
FROM chat_logs cl
JOIN user_matches um ON cl.match_id = um.match_id
JOIN users u ON cl.sender_id = u.id_user
WHERE cl.timestamp > NOW() - INTERVAL '7 days'
ORDER BY cl.timestamp DESC
LIMIT 20;

-- Notificaciones no leídas por usuario
SELECT 
    u.first_name || ' ' || u.last_name as usuario,
    COUNT(*) as notificaciones_pendientes,
    MIN(n.created_at) as mas_antigua,
    MAX(n.created_at) as mas_reciente
FROM notifications n
JOIN users u ON n.user_id = u.id_user
WHERE n.is_read = FALSE AND (n.expires_at IS NULL OR n.expires_at > NOW())
GROUP BY u.id_user, u.first_name, u.last_name
ORDER BY notificaciones_pendientes DESC;

-- Estadísticas de uso de funciones personalizadas
SELECT 
    table_name,
    action,
    COUNT(*) as operaciones,
    MAX(changed_at) as ultima_operacion
FROM audit_logs
WHERE changed_at > NOW() - INTERVAL '30 days'
GROUP BY table_name, action
ORDER BY table_name, action;

-- ================================================================
-- 8. CONSULTAS DE LIMPIEZA Y MANTENIMIENTO
-- ================================================================

-- Sesiones programadas que pasaron su fecha (candidatas para actualizar estado)
SELECT 
    session_id,
    session_type,
    start_time,
    session_status,
    EXTRACT(DAYS FROM (NOW() - start_time)) as dias_vencida
FROM sessions
WHERE session_status = 'scheduled' 
    AND start_time < NOW() - INTERVAL '1 day'
ORDER BY start_time;

-- Notificaciones expiradas (candidatas para limpieza)
SELECT 
    notification_id,
    user_id,
    title,
    expires_at,
    EXTRACT(DAYS FROM (NOW() - expires_at)) as dias_expirada
FROM notifications
WHERE expires_at IS NOT NULL 
    AND expires_at < NOW()
    AND is_read = FALSE
ORDER BY expires_at;

-- Usuarios inactivos hace más de 6 meses
SELECT 
    id_user,
    first_name,
    last_name,
    email,
    last_login,
    EXTRACT(DAYS FROM (NOW() - last_login)) as dias_inactivo
FROM users
WHERE last_login < NOW() - INTERVAL '180 days'
    AND is_active = TRUE
ORDER BY last_login;

-- ================================================================
-- 9. VALIDACIÓN DE FUNCIONES AUTOMÁTICAS
-- ================================================================

-- Probar función de incremento de usuarios
SELECT fun_increm_user() as proximo_id_usuario;

-- Probar generación de session_id
SELECT fun_increme_session() as nuevo_session_id;

-- Probar generación de message_id
SELECT fun_increme_message() as nuevo_message_id;

-- Verificar validaciones de idiomas, países y bancos
SELECT 
    fun_valida_idioma('ES') as idioma_es_valido,
    fun_valida_idioma('ZZ') as idioma_zz_invalido,
    fun_valida_pais('CO') as pais_co_valido,
    fun_valida_pais('XX') as pais_xx_invalido,
    fun_valida_banco('BANCOLOMBIA') as banco_valido,
    fun_valida_banco('NOEXISTE') as banco_invalido;

-- Probar validación de usuario
SELECT 
    fun_valida_usuario(1) as usuario_1_valido,
    fun_valida_usuario(9999) as usuario_9999_invalido;

-- ================================================================
-- 10. CONSULTA INTEGRAL DE SALUD DE LA BD
-- ================================================================

-- Resumen general del estado de la base de datos
SELECT 
    'Usuarios totales' as metrica, COUNT(*)::TEXT as valor
FROM users
UNION ALL
SELECT 'Usuarios activos', COUNT(*)::TEXT FROM users WHERE is_active = TRUE
UNION ALL
SELECT 'Profesores verificados', COUNT(*)::TEXT FROM teacher_profiles WHERE is_verified = TRUE
UNION ALL
SELECT 'Sesiones completadas', COUNT(*)::TEXT FROM sessions WHERE session_status = 'completed'
UNION ALL
SELECT 'Matches activos', COUNT(*)::TEXT FROM user_matches
UNION ALL
SELECT 'Mensajes enviados', COUNT(*)::TEXT FROM chat_logs
UNION ALL
SELECT 'Notificaciones pendientes', COUNT(*)::TEXT FROM notifications WHERE is_read = FALSE
UNION ALL
SELECT 'Usuarios por rol - Admin', COUNT(*)::TEXT FROM users WHERE role_code = 'admin'
UNION ALL
SELECT 'Usuarios por rol - Teacher', COUNT(*)::TEXT FROM users WHERE role_code = 'teacher'
UNION ALL
SELECT 'Usuarios por rol - User', COUNT(*)::TEXT FROM users WHERE role_code = 'user'
ORDER BY metrica;

-- ====================================================================================================
-- 11. PRUEBAS DE INSERCIÓN DE USUARIOS Y TEACHER PROFILES
-- ====================================================================================================

-- ================================================================
-- 11.1. PRUEBA DE INSERCIÓN DE USUARIO USANDO LA FUNCIÓN
-- ================================================================

-- Verificar próximo ID que se asignará
SELECT fun_increm_user() as proximo_id_usuario;

-- Verificar cantidad actual de usuarios
SELECT COUNT(*) as total_usuarios_actual FROM users;

-- INSERTAR NUEVO USUARIO USANDO LA FUNCIÓN
SELECT fun_insert_usuarios(
    'María',                    -- first_name
    'González',                 -- last_name  
    'maria.gonzalez@test.com', -- email
    'hash_password_123',        -- password_hash
    2,                          -- gender_id (2 = Femenino)
    '1992-03-15',              -- birth_date
    'CO',                       -- country_id
    NULL,                       -- profile_photo
    'ES',                       -- native_lang_id
    'EN',                       -- target_lang_id
    8,                          -- match_quantity
    'BANCOLOMBIA',              -- bank_id
    'Profesora de español interesada en practicar inglés' -- description
) as resultado_insercion;

-- Verificar que el usuario se insertó correctamente
SELECT 
    id_user,
    first_name,
    last_name,
    email,
    gender_id,
    birth_date,
    country_id,
    native_lang_id,
    target_lang_id,
    match_quantity,
    bank_id,
    role_code,
    description,
    is_active,
    email_verified,
    created_at
FROM users 
WHERE email = 'maria.gonzalez@test.com';

-- Verificar nuevo total de usuarios
SELECT COUNT(*) as total_usuarios_nuevo FROM users;

-- ================================================================
-- 11.2. ACTUALIZAR ROL DEL USUARIO A TEACHER
-- ================================================================

-- Obtener el ID del usuario recién creado y actualizar su rol
WITH nuevo_usuario AS (
    SELECT id_user 
    FROM users 
    WHERE email = 'maria.gonzalez@test.com'
)
UPDATE users
SET role_code = 'teacher',
    updated_at = NOW()
WHERE id_user = (SELECT id_user FROM nuevo_usuario);

-- Verificar que se actualizó el rol
SELECT 
    u.id_user,
    u.first_name,
    u.last_name,
    u.role_code,
    ur.role_name,
    u.updated_at
FROM users u
JOIN user_roles ur ON u.role_code = ur.role_code
WHERE u.email = 'maria.gonzalez@test.com';

-- ================================================================
-- 11.3. CREAR PERFIL DE TEACHER USANDO LA FUNCIÓN
-- ================================================================

-- Usar la función para crear el perfil de teacher
WITH nuevo_teacher AS (
    SELECT id_user 
    FROM users 
    WHERE email = 'maria.gonzalez@test.com'
)
SELECT fun_insert_teacher_profile(
    nt.id_user,                     -- user_id
    'ES',                           -- teaching_language_id (enseña español)
    'DELE C2',                      -- lang_certification
    'Licenciatura en Filología Hispánica', -- academic_title
    'Certificado de 4 años enseñando ELE', -- experience_certification
    25.00,                          -- hourly_rate
    'Español para negocios y conversación', -- specialization
    4,                              -- years_experience
    'Disponible lunes a viernes de 14:00 a 20:00' -- availability_notes
) as resultado_teacher_profile
FROM nuevo_teacher nt;

-- Verificar que se creó el perfil de teacher
SELECT 
    tp.user_id,
    u.first_name || ' ' || u.last_name as nombre_completo,
    tp.teaching_language_id,
    tp.lang_certification,
    tp.academic_title,
    tp.experience_certification,
    tp.hourly_rate,
    tp.specialization,
    tp.years_experience,
    tp.availability_notes,
    tp.is_verified,
    tp.created_at
FROM teacher_profiles tp
JOIN users u ON tp.user_id = u.id_user
WHERE u.email = 'maria.gonzalez@test.com';

-- ================================================================
-- 11.4. VERIFICACIONES ADICIONALES DEL AUTOINCREMENTAL
-- ================================================================

-- Insertar otro usuario para verificar que el ID se incrementa correctamente
SELECT fun_insert_usuarios(
    'Carlos',
    'Mendoza', 
    'carlos.mendoza@test.com',
    'hash_password_456',
    1,  -- gender_id (1 = Masculino)
    '1988-07-22',
    'CO',
    NULL,
    'ES',
    'FR',
    6,
    'BANCOLOMBIA',
    'Ingeniero colombiano aprendiendo francés'
) as resultado_segundo_usuario;

-- Verificar ambos usuarios y sus IDs consecutivos
SELECT 
    id_user,
    first_name,
    last_name,
    email,
    gender_id,
    role_code,
    created_at
FROM users 
WHERE email IN ('maria.gonzalez@test.com', 'carlos.mendoza@test.com')
ORDER BY id_user;

-- ================================================================
-- 11.5. PRUEBAS DE VALIDACIÓN DE LA FUNCIÓN
-- ================================================================

-- Intentar insertar usuario con email duplicado (debe fallar)
SELECT fun_insert_usuarios(
    'María Duplicate',
    'Test',
    'maria.gonzalez@test.com', -- Email duplicado
    'hash_test',
    2,
    '1995-01-01',
    'CO',
    NULL,
    'ES',
    'EN',
    5,
    NULL,
    'Prueba de email duplicado'
) as resultado_email_duplicado;

-- Intentar insertar usuario menor de 15 años (debe fallar)
SELECT fun_insert_usuarios(
    'Niño',
    'Test',
    'nino.test@test.com',
    'hash_test',
    1,
    '2015-01-01', -- Menor de 15 años
    'CO',
    NULL,
    'ES',
    'EN',
    5,
    NULL,
    'Prueba de edad'
) as resultado_menor_edad;

-- Intentar insertar usuario con país inválido (debe fallar)
SELECT fun_insert_usuarios(
    'País',
    'Inválido',
    'pais.invalido@test.com',
    'hash_test',
    1,
    '1990-01-01',
    'XX', -- País inexistente
    NULL,
    'ES',
    'EN',
    5,
    NULL,
    'Prueba país inválido'
) as resultado_pais_invalido;

-- Intentar insertar usuario con idioma nativo igual al objetivo (debe fallar)
SELECT fun_insert_usuarios(
    'Idiomas',
    'Iguales',
    'idiomas.iguales@test.com',
    'hash_test',
    1,
    '1990-01-01',
    'CO',
    NULL,
    'ES',
    'ES', -- Mismo idioma nativo y objetivo
    5,
    NULL,
    'Prueba idiomas iguales'
) as resultado_idiomas_iguales;

-- ================================================================
-- 11.6. RESUMEN DE PRUEBAS DE INSERCIÓN
-- ================================================================

SELECT 
    'RESUMEN DE PRUEBAS DE INSERCIÓN' as seccion,
    '' as detalle
UNION ALL
SELECT 
    'Usuarios creados exitosamente:',
    COUNT(*)::TEXT
FROM users 
WHERE email IN ('maria.gonzalez@test.com', 'carlos.mendoza@test.com')
UNION ALL
SELECT 
    'Teachers profiles creados:',
    COUNT(*)::TEXT
FROM teacher_profiles tp
JOIN users u ON tp.user_id = u.id_user
WHERE u.email = 'maria.gonzalez@test.com'
UNION ALL
SELECT 
    'Rango de IDs usados:',
    MIN(id_user)::TEXT || ' - ' || MAX(id_user)::TEXT
FROM users 
WHERE email IN ('maria.gonzalez@test.com', 'carlos.mendoza@test.com');

-- ====================================================================================================
-- 12. PRUEBAS DE MATCHES Y SESIONES
-- ====================================================================================================

-- ================================================================
-- 12.1. VERIFICAR USUARIOS DISPONIBLES PARA MATCH
-- ================================================================

-- Ver usuarios disponibles (que no tengan match entre sí)
SELECT 
    u1.id_user as user_1,
    u1.first_name || ' ' || u1.last_name as usuario_1,
    u1.native_lang_id as idioma_nativo_1,
    u1.target_lang_id as idioma_objetivo_1,
    u2.id_user as user_2,
    u2.first_name || ' ' || u2.last_name as usuario_2,
    u2.native_lang_id as idioma_nativo_2,
    u2.target_lang_id as idioma_objetivo_2,
    CASE WHEN EXISTS(
        SELECT 1 FROM user_matches um 
        WHERE (um.user_1 = LEAST(u1.id_user, u2.id_user) AND um.user_2 = GREATEST(u1.id_user, u2.id_user))
    ) THEN 'YA TIENEN MATCH' ELSE 'SIN MATCH' END as estado_match
FROM users u1
CROSS JOIN users u2
WHERE u1.id_user < u2.id_user
    AND u1.is_active = TRUE 
    AND u2.is_active = TRUE
    AND NOT EXISTS(
        SELECT 1 FROM user_matches um 
        WHERE (um.user_1 = LEAST(u1.id_user, u2.id_user) AND um.user_2 = GREATEST(u1.id_user, u2.id_user))
    )
ORDER BY u1.id_user, u2.id_user
LIMIT 10;

-- ================================================================
-- 12.2. PROCESO COMPLETO PARA CREAR MATCH
-- ================================================================
-- Usaremos usuarios 2 y 3 como ejemplo

-- Paso 1: Verificar estado inicial de likes
SELECT 
    'Estado inicial de likes entre usuarios 2 y 3:' as descripcion,
    '' as resultado
UNION ALL
SELECT 
    'Like de 2 hacia 3:',
    CASE WHEN EXISTS(SELECT 1 FROM user_likes WHERE id_user_giver = 2 AND id_user_receiver = 3) 
         THEN 'EXISTE' ELSE 'NO EXISTE' END
UNION ALL
SELECT 
    'Like de 3 hacia 2:',
    CASE WHEN EXISTS(SELECT 1 FROM user_likes WHERE id_user_giver = 3 AND id_user_receiver = 2) 
         THEN 'EXISTE' ELSE 'NO EXISTE' END;

-- Paso 2: Crear likes mutuos
INSERT INTO user_likes (id_user_giver, id_user_receiver, like_time)
VALUES 
    (2, 3, NOW()),
    (3, 2, NOW())
ON CONFLICT (id_user_giver, id_user_receiver) DO NOTHING;

-- Paso 3: Verificar que se crearon los likes
SELECT 
    ul.id_user_giver,
    ul.id_user_receiver,
    u1.first_name || ' dio like a ' || u2.first_name as accion,
    ul.like_time
FROM user_likes ul
JOIN users u1 ON ul.id_user_giver = u1.id_user
JOIN users u2 ON ul.id_user_receiver = u2.id_user
WHERE (ul.id_user_giver = 2 AND ul.id_user_receiver = 3)
   OR (ul.id_user_giver = 3 AND ul.id_user_receiver = 2)
ORDER BY ul.like_time;

-- Paso 4: Crear match usando la función
SELECT fun_insert_match(2, 3) as resultado_match;

-- Paso 5: Verificar que se creó el match
SELECT 
    um.match_id,
    um.user_1,
    um.user_2,
    u1.first_name || ' <-> ' || u2.first_name as match_entre,
    um.match_time
FROM user_matches um
JOIN users u1 ON um.user_1 = u1.id_user
JOIN users u2 ON um.user_2 = u2.id_user
WHERE (um.user_1 = 2 AND um.user_2 = 3) OR (um.user_1 = 3 AND um.user_2 = 2);

-- ================================================================
-- 12.3. PRUEBAS DE CREACIÓN DE SESIONES
-- ================================================================

-- Verificar que tienen likes mutuos usando la función auxiliar
SELECT fun_verificar_likes_mutuos(2, 3) as tienen_likes_mutuos;

-- Probar crear sesión de INTERCAMBIO
SELECT fun_validar_likes_y_crear_sesion(
    2,                                                       -- user1_id
    3,                                                       -- user2_id  
    'exchange',                                              -- session_type
    (NOW() + INTERVAL '1 day')::TIMESTAMP,                   -- start_time
    (NOW() + INTERVAL '1 day 1 hour')::TIMESTAMP,            -- end_time
    'ES',                                                    -- language_used
    'Sesión de prueba de intercambio de idiomas'             -- session_notes
) as resultado_sesion_exchange;

-- Verificar que se creó la sesión
SELECT 
    s.session_id,
    s.id_user1,
    s.id_user2,
    u1.first_name || ' <-> ' || u2.first_name as sesion_entre,
    s.session_type,
    s.session_status,
    s.start_time,
    s.end_time,
    s.language_used,
    s.session_notes,
    s.created_at
FROM sessions s
JOIN users u1 ON s.id_user1 = u1.id_user
JOIN users u2 ON s.id_user2 = u2.id_user
WHERE (s.id_user1 = 2 AND s.id_user2 = 3) OR (s.id_user1 = 3 AND s.id_user2 = 2)
ORDER BY s.created_at DESC
LIMIT 1;

-- Verificar que se creó el registro en exchange_sessions
SELECT 
    es.session_id,
    s.session_type,
    'Creada correctamente en exchange_sessions' as estado
FROM exchange_sessions es
JOIN sessions s ON es.session_id = s.session_id
WHERE (s.id_user1 = 2 AND s.id_user2 = 3) OR (s.id_user1 = 3 AND s.id_user2 = 2)
ORDER BY s.created_at DESC
LIMIT 1;

-- ================================================================
-- 12.4. PRUEBAS DE VALIDACIÓN DE SESIONES (CASOS DE ERROR)
-- ================================================================

-- Intentar crear otra sesión entre los mismos usuarios (debería fallar - sesión activa)
SELECT fun_validar_likes_y_crear_sesion(
    2,
    3,
    'exchange',
    (NOW() + INTERVAL '2 days')::TIMESTAMP,
    (NOW() + INTERVAL '2 days 1 hour')::TIMESTAMP,
    'EN',
    'Intento duplicado - debería fallar'
) as sesion_duplicada_debe_fallar;

-- Intentar crear sesión con usuarios que no tienen likes mutuos
SELECT fun_validar_likes_y_crear_sesion(
    2,
    4,
    'exchange',
    (NOW() + INTERVAL '3 days')::TIMESTAMP,
    (NOW() + INTERVAL '3 days 1 hour')::TIMESTAMP,
    'ES',
    'Sin likes mutuos - debería fallar'
) as sin_likes_debe_fallar;

-- Intentar crear sesión de teaching (necesita que uno sea teacher verificado)
SELECT fun_validar_likes_y_crear_sesion(
    2,
    3,
    'teaching',
    (NOW() + INTERVAL '4 days')::TIMESTAMP,
    (NOW() + INTERVAL '4 days 1 hour')::TIMESTAMP,
    'EN',
    'Teaching sin teacher verificado'
) as teaching_debe_fallar;

-- Intentar crear sesión con usuario consigo mismo (debe fallar)
SELECT fun_validar_likes_y_crear_sesion(
    2,
    2,
    'exchange',
    (NOW() + INTERVAL '5 days')::TIMESTAMP,
    (NOW() + INTERVAL '5 days 1 hour')::TIMESTAMP,
    'ES',
    'Usuario consigo mismo - debe fallar'
) as mismo_usuario_debe_fallar;

-- ================================================================
-- 12.5. VERIFICAR MATCHES Y LIKES EXISTENTES
-- ================================================================

-- Ver todos los likes de un usuario específico
SELECT 
    ul.id_user_giver as dador,
    ul.id_user_receiver as receptor,
    u1.first_name as nombre_dador,
    u2.first_name as nombre_receptor,
    ul.like_time
FROM user_likes ul
JOIN users u1 ON ul.id_user_giver = u1.id_user  
JOIN users u2 ON ul.id_user_receiver = u2.id_user
WHERE ul.id_user_giver = 1 OR ul.id_user_receiver = 1
ORDER BY ul.like_time DESC;

-- Ver todos los matches con detalle
SELECT 
    um.match_id,
    um.user_1,
    um.user_2,
    u1.first_name || ' ' || u1.last_name as usuario_1,
    u2.first_name || ' ' || u2.last_name as usuario_2,
    u1.native_lang_id || ' -> ' || u1.target_lang_id as idiomas_usuario_1,
    u2.native_lang_id || ' -> ' || u2.target_lang_id as idiomas_usuario_2,
    um.match_time,
    fun_verificar_likes_mutuos(um.user_1, um.user_2) as likes_mutuos_validos
FROM user_matches um
JOIN users u1 ON um.user_1 = u1.id_user
JOIN users u2 ON um.user_2 = u2.id_user
ORDER BY um.match_time DESC;

-- Ver sesiones recientes con sus participantes
SELECT 
    s.session_id,
    s.session_type,
    s.session_status,
    u1.first_name || ' ' || u1.last_name as usuario_1,
    u2.first_name || ' ' || u2.last_name as usuario_2,
    s.start_time,
    s.end_time,
    s.language_used,
    CASE 
        WHEN s.end_time IS NOT NULL AND s.start_time IS NOT NULL 
        THEN EXTRACT(EPOCH FROM (s.end_time - s.start_time))/3600 
        ELSE NULL 
    END as duracion_horas
FROM sessions s
JOIN users u1 ON s.id_user1 = u1.id_user
JOIN users u2 ON s.id_user2 = u2.id_user
ORDER BY s.created_at DESC
LIMIT 10;

-- ================================================================
-- 12.6. RESUMEN DE PRUEBAS DE MATCHES Y SESIONES
-- ================================================================

SELECT 'RESUMEN DE PRUEBAS DE MATCHES Y SESIONES' as seccion, '' as detalle
UNION ALL
SELECT '==========================================', ''
UNION ALL
SELECT 'Likes totales creados:', 
    (SELECT COUNT(*)::TEXT FROM user_likes)
UNION ALL
SELECT 'Matches totales:', 
    (SELECT COUNT(*)::TEXT FROM user_matches)
UNION ALL
SELECT 'Sesiones totales:', 
    (SELECT COUNT(*)::TEXT FROM sessions)
UNION ALL
SELECT 'Sesiones de intercambio:', 
    (SELECT COUNT(*)::TEXT FROM exchange_sessions)
UNION ALL
SELECT 'Sesiones de enseñanza:', 
    (SELECT COUNT(*)::TEXT FROM teaching_sessions)
UNION ALL
SELECT 'Sesiones completadas:', 
    (SELECT COUNT(*)::TEXT FROM sessions WHERE session_status = 'completed')
UNION ALL
SELECT 'Sesiones programadas:', 
    (SELECT COUNT(*)::TEXT FROM sessions WHERE session_status = 'scheduled')
UNION ALL
SELECT 'Matches con likes mutuos válidos:',
    (SELECT COUNT(*)::TEXT FROM user_matches um 
     WHERE fun_verificar_likes_mutuos(um.user_1, um.user_2) = TRUE);

-- ====================================================================================================
-- 13. PRUEBAS DE CHAT Y MENSAJERÍA
-- ====================================================================================================

-- ================================================================
-- 13.1. CREAR MENSAJES DE PRUEBA
-- ================================================================

-- Verificar matches existentes para crear mensajes
SELECT 
    um.match_id,
    u1.first_name || ' <-> ' || u2.first_name as match_entre
FROM user_matches um
JOIN users u1 ON um.user_1 = u1.id_user
JOIN users u2 ON um.user_2 = u2.id_user
LIMIT 5;

-- Insertar mensajes de prueba (usando match_id existente)
-- Nota: Ajusta el match_id según los matches que tengas en tu BD
INSERT INTO chat_logs (match_id, sender_id, message, timestamp)
VALUES 
    (1, 1, '¡Hola! ¿Cómo estás?', NOW()),
    (1, 3, 'Hi! I am great, thanks! How about you?', NOW() + INTERVAL '2 minutes')
ON CONFLICT DO NOTHING;

-- Verificar mensajes creados
SELECT 
    cl.message_id,
    cl.match_id,
    u.first_name as remitente,
    cl.message,
    cl.timestamp,
    cl.is_read
FROM chat_logs cl
JOIN users u ON cl.sender_id = u.id_user
ORDER BY cl.timestamp DESC
LIMIT 10;

-- ================================================================
-- 13.2. ESTADÍSTICAS DE MENSAJERÍA
-- ================================================================

-- Mensajes por match
SELECT 
    um.match_id,
    u1.first_name || ' <-> ' || u2.first_name as match_entre,
    COUNT(cl.message_id) as total_mensajes,
    COUNT(CASE WHEN cl.is_read THEN 1 END) as mensajes_leidos,
    COUNT(CASE WHEN NOT cl.is_read THEN 1 END) as mensajes_no_leidos,
    MAX(cl.timestamp) as ultimo_mensaje
FROM user_matches um
JOIN users u1 ON um.user_1 = u1.id_user
JOIN users u2 ON um.user_2 = u2.id_user
LEFT JOIN chat_logs cl ON um.match_id = cl.match_id
GROUP BY um.match_id, u1.first_name, u2.first_name
ORDER BY ultimo_mensaje DESC NULLS LAST;

-- Usuarios más activos en chat
SELECT 
    u.id_user,
    u.first_name || ' ' || u.last_name as usuario,
    COUNT(cl.message_id) as mensajes_enviados,
    MAX(cl.timestamp) as ultimo_mensaje_enviado
FROM users u
LEFT JOIN chat_logs cl ON u.id_user = cl.sender_id
GROUP BY u.id_user, u.first_name, u.last_name
HAVING COUNT(cl.message_id) > 0
ORDER BY mensajes_enviados DESC
LIMIT 10;

-- ====================================================================================================
-- 14. PRUEBAS DE NOTIFICACIONES
-- ====================================================================================================

-- ================================================================
-- 14.1. CREAR NOTIFICACIONES DE PRUEBA
-- ================================================================

-- Crear notificaciones de diferentes tipos
INSERT INTO notifications (notification_id, user_id, title, message, notification_type, related_entity_type, related_entity_id)
VALUES
    ('NOT_TEST_001', 1, 'Nuevo match', '¡Has hecho match con un nuevo usuario!', 'match', 'user_match', '1'),
    ('NOT_TEST_002', 1, 'Sesión próxima', 'Tu sesión comienza en 1 hora', 'session', 'session', 'SES_001')
ON CONFLICT DO NOTHING;

-- Verificar notificaciones creadas
SELECT 
    n.notification_id,
    u.first_name as destinatario,
    n.title,
    n.message,
    n.notification_type,
    n.is_read,
    n.created_at
FROM notifications n
JOIN users u ON n.user_id = u.id_user
ORDER BY n.created_at DESC
LIMIT 10;

-- ================================================================
-- 14.2. ESTADÍSTICAS DE NOTIFICACIONES
-- ================================================================

-- Notificaciones por usuario
SELECT 
    u.first_name || ' ' || u.last_name as usuario,
    COUNT(*) as total_notificaciones,
    COUNT(CASE WHEN n.is_read THEN 1 END) as leidas,
    COUNT(CASE WHEN NOT n.is_read THEN 1 END) as no_leidas
FROM users u
LEFT JOIN notifications n ON u.id_user = n.user_id
GROUP BY u.id_user, u.first_name, u.last_name
HAVING COUNT(*) > 0
ORDER BY total_notificaciones DESC;

-- Notificaciones por tipo
SELECT 
    notification_type,
    COUNT(*) as cantidad,
    COUNT(CASE WHEN is_read THEN 1 END) as leidas,
    COUNT(CASE WHEN NOT is_read THEN 1 END) as no_leidas
FROM notifications
GROUP BY notification_type
ORDER BY cantidad DESC;

-- ====================================================================================================
-- 15. PRUEBAS DE PROGRESO DE USUARIOS
-- ====================================================================================================

-- ================================================================
-- 15.1. ACTUALIZAR PROGRESO DE USUARIOS
-- ================================================================

-- Insertar o actualizar progreso
INSERT INTO user_progress (user_id, language_id, total_sessions, total_hours, notes)
VALUES 
    (1, 'EN', 10, 15.5, 'Excelente progreso en conversación'),
    (3, 'ES', 8, 12.0, 'Mejorando gramática')
ON CONFLICT (user_id, language_id) 
DO UPDATE SET 
    total_sessions = user_progress.total_sessions + EXCLUDED.total_sessions,
    total_hours = user_progress.total_hours + EXCLUDED.total_hours,
    last_updated = NOW(),
    notes = EXCLUDED.notes;

-- Verificar progreso actualizado
SELECT 
    u.first_name || ' ' || u.last_name as usuario,
    l.language_name as idioma,
    up.total_sessions,
    up.total_hours,
    ROUND(up.total_hours / NULLIF(up.total_sessions, 0), 2) as promedio_horas_por_sesion,
    up.notes,
    up.last_updated
FROM user_progress up
JOIN users u ON up.user_id = u.id_user
JOIN languages l ON up.language_id = l.language_code
ORDER BY up.total_hours DESC;

-- ================================================================
-- 15.2. RANKING DE PROGRESO
-- ================================================================

-- Top usuarios por horas de práctica
SELECT 
    u.first_name || ' ' || u.last_name as usuario,
    l.language_name as idioma_aprendiendo,
    up.total_hours as horas_totales,
    up.total_sessions as sesiones_totales,
    RANK() OVER (ORDER BY up.total_hours DESC) as ranking_horas
FROM user_progress up
JOIN users u ON up.user_id = u.id_user
JOIN languages l ON up.language_id = l.language_code
ORDER BY up.total_hours DESC
LIMIT 10;

-- Progreso promedio por idioma
SELECT 
    l.language_name as idioma,
    COUNT(DISTINCT up.user_id) as usuarios_aprendiendo,
    ROUND(AVG(up.total_sessions), 2) as promedio_sesiones,
    ROUND(AVG(up.total_hours), 2) as promedio_horas
FROM user_progress up
JOIN languages l ON up.language_id = l.language_code
GROUP BY l.language_code, l.language_name
ORDER BY usuarios_aprendiendo DESC;

-- ====================================================================================================
-- 16. LIMPIEZA DE DATOS DE PRUEBA (OPCIONAL)
-- ====================================================================================================

/*
-- ================================================================
-- DESCOMENTA ESTA SECCIÓN SI DESEAS ELIMINAR LOS DATOS DE PRUEBA
-- ================================================================

-- Eliminar notificaciones de prueba
DELETE FROM notifications 
WHERE notification_id LIKE 'NOT_TEST_%';

-- Eliminar mensajes de prueba
DELETE FROM chat_logs 
WHERE message_id IN (
    SELECT message_id FROM chat_logs 
    WHERE timestamp > NOW() - INTERVAL '1 hour'
);

-- Eliminar sesiones de prueba
DELETE FROM exchange_sessions WHERE session_id IN (
    SELECT session_id FROM sessions 
    WHERE created_at > NOW() - INTERVAL '1 hour'
);

DELETE FROM teaching_sessions WHERE session_id IN (
    SELECT session_id FROM sessions 
    WHERE created_at > NOW() - INTERVAL '1 hour'
);

DELETE FROM sessions WHERE created_at > NOW() - INTERVAL '1 hour';

-- Eliminar matches de prueba
DELETE FROM user_matches WHERE match_time > NOW() - INTERVAL '1 hour';

-- Eliminar likes de prueba
DELETE FROM user_likes WHERE like_time > NOW() - INTERVAL '1 hour';

-- Eliminar teacher profiles de prueba
DELETE FROM teacher_profiles 
WHERE user_id IN (
    SELECT id_user FROM users 
    WHERE email IN ('maria.gonzalez@test.com', 'carlos.mendoza@test.com')
);

-- Eliminar usuarios de prueba
DELETE FROM users 
WHERE email IN ('maria.gonzalez@test.com', 'carlos.mendoza@test.com');

SELECT 'Datos de prueba eliminados exitosamente' as resultado;
*/

-- ====================================================================================================
-- 17. CONSULTA FINAL - ESTADO COMPLETO DEL SISTEMA
-- ====================================================================================================

SELECT 
    '===========================================' as separador,
    'ESTADO FINAL DEL SISTEMA DESPUÉS DE PRUEBAS' as titulo,
    '===========================================' as separador2
UNION ALL
SELECT '', 'USUARIOS', ''
UNION ALL
SELECT 'Total usuarios:', COUNT(*)::TEXT, '' FROM users
UNION ALL
SELECT 'Usuarios activos:', COUNT(*)::TEXT, '' FROM users WHERE is_active = TRUE
UNION ALL
SELECT 'Usuarios con rol admin:', COUNT(*)::TEXT, '' FROM users WHERE role_code = 'admin'
UNION ALL
SELECT 'Usuarios con rol teacher:', COUNT(*)::TEXT, '' FROM users WHERE role_code = 'teacher'
UNION ALL
SELECT 'Usuarios con rol user:', COUNT(*)::TEXT, '' FROM users WHERE role_code = 'user'
UNION ALL
SELECT '', 'TEACHERS', ''
UNION ALL
SELECT 'Teachers totales:', COUNT(*)::TEXT, '' FROM teacher_profiles
UNION ALL
SELECT 'Teachers verificados:', COUNT(*)::TEXT, '' FROM teacher_profiles WHERE is_verified = TRUE
UNION ALL
SELECT '', 'ACTIVIDAD', ''
UNION ALL
SELECT 'Likes totales:', COUNT(*)::TEXT, '' FROM user_likes
UNION ALL
SELECT 'Matches totales:', COUNT(*)::TEXT, '' FROM user_matches
UNION ALL
SELECT 'Sesiones totales:', COUNT(*)::TEXT, '' FROM sessions
UNION ALL
SELECT 'Sesiones completadas:', COUNT(*)::TEXT, '' FROM sessions WHERE session_status = 'completed'
UNION ALL
SELECT 'Sesiones programadas:', COUNT(*)::TEXT, '' FROM sessions WHERE session_status = 'scheduled'
UNION ALL
SELECT '', 'COMUNICACIÓN', ''
UNION ALL
SELECT 'Mensajes totales:', COUNT(*)::TEXT, '' FROM chat_logs
UNION ALL
SELECT 'Mensajes no leídos:', COUNT(*)::TEXT, '' FROM chat_logs WHERE is_read = FALSE
UNION ALL
SELECT 'Notificaciones totales:', COUNT(*)::TEXT, '' FROM notifications
UNION ALL
SELECT 'Notificaciones pendientes:', COUNT(*)::TEXT, '' FROM notifications WHERE is_read = FALSE
UNION ALL
SELECT '', 'PROGRESO', ''
UNION ALL
SELECT 'Usuarios con progreso registrado:', COUNT(DISTINCT user_id)::TEXT, '' FROM user_progress
UNION ALL
SELECT 'Total horas de práctica:', ROUND(SUM(total_hours), 2)::TEXT, '' FROM user_progress
UNION ALL
SELECT 'Total sesiones de práctica:', SUM(total_sessions)::TEXT, '' FROM user_progress;

-- ====================================================================================================
-- FIN DEL SCRIPT DE PRUEBAS
-- ====================================================================================================