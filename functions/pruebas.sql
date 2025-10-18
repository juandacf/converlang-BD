-- 1.Validación de Integridad Referencial - Detecta registros huérfanos o referencias rotas
-- 2.Análisis de Datos - Estadísticas y distribuciones de usuarios, sesiones y actividad
-- 3.Detección de Inconsistencias - Identifica violaciones a reglas de negocio
-- 4.Rendimiento y Actividad - Usuarios más activos, progreso por idioma
-- 5.Validación de Reglas de Negocio - Verifica restricciones como edad mínima
-- 6.Pruebas de Transacciones - Simula operaciones complejas con rollback seguro
-- 7.Monitoreo del Sistema - Actividad reciente, notificaciones pendientes
-- 8.Limpieza y Mantenimiento - Identifica datos obsoletos o que requieren limpieza
-- 9.Validación de Funciones - Prueba tus funciones personalizadas
-- 10.Consulta Integral de Salud - Resumen general del estado de la BD
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

-- Verificar que los teachers tengan el rol correspondiente
SELECT 
    tp.user_id,
    u.first_name,
    u.last_name,
    tp.is_verified
FROM teacher_profiles tp
JOIN users u ON tp.user_id = u.id_user
WHERE tp.user_id NOT IN (
    SELECT user_id 
    FROM user_role_assignments 
    WHERE role_code = 'teacher'
);

-- ================================================================
-- 6. PRUEBAS DE TRANSACCIONES
-- ================================================================

-- Simulación de creación de usuario completa con rollback
BEGIN;
    -- Intentar crear usuario
    SELECT fun_insert_usuarios(
        'TestUser',
        'TestLastName', 
        'test@example.com',
        'hash123',
        'masculino',
        '1995-01-01',
        'CO',
        NULL,
        'ES',
        'EN',
        10,
        NULL,
        'Usuario de prueba'
    ) as resultado_insercion;
    
    -- Verificar que se creó
    SELECT id_user, first_name, last_name, email
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
    s.session_type,
    u.first_name as remitente,
    LEFT(cl.message, 50) as mensaje_preview,
    cl.timestamp,
    cl.is_read
FROM chat_logs cl
JOIN sessions s ON cl.session_id = s.session_id
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
    fun_valida_banco('BANCOLCO') as banco_valido,
    fun_valida_banco('NOEXISTE') as banco_invalido;

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
ORDER BY metrica;


-- ====================================================================================================
-- QUERIES DE PRUEBA - INSERCIÓN DE USUARIO Y TEACHER PROFILE
-- ====================================================================================================

-- ================================================================
-- 1. PRUEBA DE INSERCIÓN DE USUARIO USANDO LA FUNCIÓN
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
    'femenino',                -- gender
    '1992-03-15',              -- birth_date
    'MX',                      -- country_id
    NULL,                      -- profile_photo
    'ES',                      -- native_lang_id
    'EN',                      -- target_lang_id
    8,                         -- match_quantity
    'BBVAMX',                  -- bank_id (opcional)
    'Profesora de español interesada en practicar inglés' -- description
) as resultado_insercion;

-- Verificar que el usuario se insertó correctamente
SELECT 
    id_user,
    first_name,
    last_name,
    email,
    gender,
    birth_date,
    country_id,
    native_lang_id,
    target_lang_id,
    match_quantity,
    bank_id,
    description,
    is_active,
    email_verified,
    created_at
FROM users 
WHERE email = 'maria.gonzalez@test.com';

-- Verificar nuevo total de usuarios
SELECT COUNT(*) as total_usuarios_nuevo FROM users;

-- ================================================================
-- 2. ASIGNAR ROL DE TEACHER AL USUARIO RECIÉN CREADO
-- ================================================================

-- Obtener el ID del usuario recién creado
WITH nuevo_usuario AS (
    SELECT id_user 
    FROM users 
    WHERE email = 'maria.gonzalez@test.com'
)
-- Asignar rol de teacher
INSERT INTO user_role_assignments (user_id, role_code, assigned_at, assigned_by)
SELECT 
    nu.id_user,
    'teacher',
    NOW(),
    1  -- Asignado por el admin (usuario ID 1)
FROM nuevo_usuario nu;

-- Verificar que se asignó el rol
SELECT 
    u.id_user,
    u.first_name,
    u.last_name,
    ura.role_code,
    ura.assigned_at
FROM users u
JOIN user_role_assignments ura ON u.id_user = ura.user_id
WHERE u.email = 'maria.gonzalez@test.com';

-- ================================================================
-- 3. CREAR PERFIL DE TEACHER USANDO LA FUNCIÓN
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
    'Disponible lunes a viernes de 14:00 a 20:00 hora México' -- availability_notes
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
-- 4. VERIFICACIONES ADICIONALES DEL AUTOINCREMENTAL
-- ================================================================

-- Insertar otro usuario para verificar que el ID se incrementa correctamente
SELECT fun_insert_usuarios(
    'Carlos',
    'Mendoza', 
    'carlos.mendoza@test.com',
    'hash_password_456',
    'masculino',
    '1988-07-22',
    'CO',
    NULL,
    'ES',
    'FR',
    6,
    'BANCOLCO',
    'Ingeniero colombiano aprendiendo francés'
) as resultado_segundo_usuario;

-- Verificar ambos usuarios y sus IDs consecutivos
SELECT 
    id_user,
    first_name,
    last_name,
    email,
    created_at
FROM users 
WHERE email IN ('maria.gonzalez@test.com', 'carlos.mendoza@test.com')
ORDER BY id_user;

-- ================================================================
-- 5. PRUEBAS DE VALIDACIÓN DE LA FUNCIÓN
-- ================================================================

-- Intentar insertar usuario con email duplicado (debe fallar)
SELECT fun_insert_usuarios(
    'María Duplicate',
    'Test',
    'maria.gonzalez@test.com', -- Email duplicado
    'hash_test',
    'femenino',
    '1995-01-01',
    'MX',
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
    'masculino',
    '2015-01-01', -- Menor de 15 años
    'MX',
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
    'masculino',
    '1990-01-01',
    'XX', -- País inexistente
    NULL,
    'ES',
    'EN',
    5,
    NULL,
    'Prueba país inválido'
) as resultado_pais_invalido;

-- ================================================================
-- 6. CONSULTA FINAL DE VERIFICACIÓN
-- ================================================================

-- Resumen de lo que se creó
SELECT 
    'RESUMEN DE PRUEBAS' as seccion,
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
    'Roles de teacher asignados:',
    COUNT(*)::TEXT
FROM user_role_assignments ura
JOIN users u ON ura.user_id = u.id_user
WHERE u.email = 'maria.gonzalez@test.com' AND ura.role_code = 'teacher'
UNION ALL
SELECT 
    'Rango de IDs usados:',
    MIN(id_user)::TEXT || ' - ' || MAX(id_user)::TEXT
FROM users 
WHERE email IN ('maria.gonzalez@test.com', 'carlos.mendoza@test.com');

-- ================================================================
-- 7. LIMPIEZA OPCIONAL (DESCOMENTA PARA ELIMINAR DATOS DE PRUEBA)
-- ================================================================

/*
-- Si quieres eliminar los datos de prueba después de verificar:

-- Eliminar teacher profile
DELETE FROM teacher_profiles 
WHERE user_id IN (
    SELECT id_user FROM users 
    WHERE email IN ('maria.gonzalez@test.com', 'carlos.mendoza@test.com')
);

-- Eliminar role assignments
DELETE FROM user_role_assignments 
WHERE user_id IN (
    SELECT id_user FROM users 
    WHERE email IN ('maria.gonzalez@test.com', 'carlos.mendoza@test.com')
);

-- Eliminar usuarios
DELETE FROM users 
WHERE email IN ('maria.gonzalez@test.com', 'carlos.mendoza@test.com');

-- Verificar limpieza
SELECT 'Usuarios eliminados' as resultado;
*/

--PRUEBAS PARA ESTABLECER DE FORMA ORGANICA UNA SESION ENTRE DOS USUARIOS.
-- ====================================================================================================
-- ====================================================================================================
-- QUERIES DE PRUEBA
-- ====================================================================================================

-- Verificar likes mutuos existentes
SELECT 
    um.user_1,
    um.user_2,
    u1.first_name || ' ' || u1.last_name as usuario_1,
    u2.first_name || ' ' || u2.last_name as usuario_2,
    fun_verificar_likes_mutuos(um.user_1, um.user_2) as tienen_likes_mutuos
FROM user_matches um
JOIN users u1 ON um.user_1 = u1.id_user
JOIN users u2 ON um.user_2 = u2.id_user
LIMIT 5;

-- Verificar sesiones creadas recientemente
SELECT session_id, id_user1, id_user2, session_type, session_status, created_at 
FROM sessions 
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;

SELECT user_1, user_2, COUNT(*) as veces_duplicado
FROM user_matches
GROUP BY user_1, user_2
HAVING COUNT(*) > 1;

--Validar que usuarios tienesn matches establecidos.
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
ORDER BY ul.like_time;


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
    -- Verificar si ya tienen match
    CASE WHEN EXISTS(
        SELECT 1 FROM user_matches um 
        WHERE (um.user_1 = LEAST(u1.id_user, u2.id_user) AND um.user_2 = GREATEST(u1.id_user, u2.id_user))
    ) THEN 'YA TIENEN MATCH' ELSE 'SIN MATCH' END as estado_match
FROM users u1
CROSS JOIN users u2
WHERE u1.id_user < u2.id_user  -- Evitar duplicados y comparaciones consigo mismo
    AND u1.is_active = TRUE 
    AND u2.is_active = TRUE
    AND NOT EXISTS(
        SELECT 1 FROM user_matches um 
        WHERE (um.user_1 = LEAST(u1.id_user, u2.id_user) AND um.user_2 = GREATEST(u1.id_user, u2.id_user))
    )
ORDER BY u1.id_user, u2.id_user
LIMIT 5;

---------------------------------------------------------------------------------------------
--PRUEBAS DE LA FUNCION LIKES Y MATCHES QUE CREAN LA SESSION SI LAS VALIDACIONES PASAN
---------------------------------------------------------------------------------------------   
-- ====================================================================================================
-- TEST COMPLETO: CREAR MATCH Y PROBAR FUNCIÓN DE SESIÓN
-- ====================================================================================================

-- ================================================================
-- 1. ELEGIR DOS USUARIOS PARA LA PRUEBA
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
    -- Verificar si ya tienen match
    CASE WHEN EXISTS(
        SELECT 1 FROM user_matches um 
        WHERE (um.user_1 = LEAST(u1.id_user, u2.id_user) AND um.user_2 = GREATEST(u1.id_user, u2.id_user))
    ) THEN 'YA TIENEN MATCH' ELSE 'SIN MATCH' END as estado_match
FROM users u1
CROSS JOIN users u2
WHERE u1.id_user < u2.id_user  -- Evitar duplicados y comparaciones consigo mismo
    AND u1.is_active = TRUE 
    AND u2.is_active = TRUE
    AND NOT EXISTS(
        SELECT 1 FROM user_matches um 
        WHERE (um.user_1 = LEAST(u1.id_user, u2.id_user) AND um.user_2 = GREATEST(u1.id_user, u2.id_user))
    )
ORDER BY u1.id_user, u2.id_user
LIMIT 5;

-- ================================================================
-- 2. PROCESO COMPLETO PARA CREAR MATCH (USANDO USUARIOS 5 Y 7 COMO EJEMPLO)
-- ================================================================

-- Variables para la prueba (cambia estos IDs por los que quieras probar)
-- En este ejemplo usaremos usuario 5 y 7

-- Paso 1: Verificar que los usuarios no tengan likes previos
SELECT 
    'Estado inicial de likes entre usuarios 5 y 7:' as descripcion,
    '' as resultado
UNION ALL
SELECT 
    'Like de 5 hacia 7:',
    CASE WHEN EXISTS(SELECT 1 FROM user_likes WHERE id_user_giver = 5 AND id_user_receiver = 7) 
         THEN 'EXISTE' ELSE 'NO EXISTE' END
UNION ALL
SELECT 
    'Like de 7 hacia 5:',
    CASE WHEN EXISTS(SELECT 1 FROM user_likes WHERE id_user_giver = 7 AND id_user_receiver = 5) 
         THEN 'EXISTE' ELSE 'NO EXISTE' END;

-- Paso 2: Crear likes mutuos
INSERT INTO user_likes (id_user_giver, id_user_receiver, like_time)
VALUES 
    (5, 7, NOW()),
    (7, 5, NOW())
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
WHERE (ul.id_user_giver = 5 AND ul.id_user_receiver = 7)
   OR (ul.id_user_giver = 7 AND ul.id_user_receiver = 5)
ORDER BY ul.like_time;

-- Paso 4: Crear match usando la función
SELECT fun_insert_match(5, 7) as resultado_match;

-- Paso 5: Verificar que se creó el match
SELECT 
    um.user_1,
    um.user_2,
    u1.first_name || ' <-> ' || u2.first_name as match_entre,
    um.match_time
FROM user_matches um
JOIN users u1 ON um.user_1 = u1.id_user
JOIN users u2 ON um.user_2 = u2.id_user
WHERE (um.user_1 = 5 AND um.user_2 = 7) OR (um.user_1 = 7 AND um.user_2 = 5);

-- ================================================================
-- 3. PROBAR LA FUNCIÓN DE VALIDACIÓN DE LIKES Y CREACIÓN DE SESIÓN
-- ================================================================

-- Verificar que tienen likes mutuos usando la función auxiliar
SELECT fun_verificar_likes_mutuos(5, 7) as tienen_likes_mutuos;

-- Probar crear sesión de INTERCAMBIO
SELECT fun_validar_likes_y_crear_sesion(
    5::INTEGER,                                              -- user1_id
    7::INTEGER,                                              -- user2_id  
    'exchange'::TEXT,                                        -- session_type
    (NOW() + INTERVAL '1 day')::TIMESTAMP,                   -- start_time
    (NOW() + INTERVAL '1 day 1 hour')::TIMESTAMP,            -- end_time
    'ES'::TEXT,                                              -- language_used
    'Sesión de prueba de intercambio de idiomas'::TEXT       -- session_notes
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
WHERE (s.id_user1 = 5 AND s.id_user2 = 7) OR (s.id_user1 = 7 AND s.id_user2 = 5)
ORDER BY s.created_at DESC
LIMIT 1;

-- Verificar que se creó el registro en exchange_sessions
SELECT 
    es.session_id,
    s.session_type,
    'Creada correctamente en exchange_sessions' as estado
FROM exchange_sessions es
JOIN sessions s ON es.session_id = s.session_id
WHERE (s.id_user1 = 5 AND s.id_user2 = 7) OR (s.id_user1 = 7 AND s.id_user2 = 5)
ORDER BY s.created_at DESC
LIMIT 1;

-- ================================================================
-- 4. PRUEBAS DE VALIDACIÓN (CASOS DE ERROR)
-- ================================================================

-- Intentar crear otra sesión entre los mismos usuarios (debería fallar)
SELECT fun_validar_likes_y_crear_sesion(
    5::INTEGER,                                              -- user1_id
    7::INTEGER,                                              -- user2_id  
    'exchange'::TEXT,                                        -- session_type
    (NOW() + INTERVAL '1 day')::TIMESTAMP,                   -- start_time
    (NOW() + INTERVAL '1 day 1 hour')::TIMESTAMP,            -- end_time
    'ES'::TEXT,                                              -- language_used
    'Sesión de prueba de intercambio de idiomas'::TEXT       -- session_notes
) as resultado_sesion_exchange;

-- Intentar crear sesión con usuarios que no tienen likes mutuos
SELECT fun_validar_likes_y_crear_sesion(
    5::INTEGER, 
    6::INTEGER, 
    'exchange'::TEXT,
    (NOW() + INTERVAL '3 days')::TIMESTAMP,
    (NOW() + INTERVAL '3 days 1 hour')::TIMESTAMP,
    'ES'::TEXT,
    'Sin likes mutuos - debería fallar'::TEXT
) as sin_likes_debe_fallar;

-- Intentar crear sesión de teaching (necesita que uno sea teacher)
SELECT fun_validar_likes_y_crear_sesion(
    5::INTEGER, 
    7::INTEGER, 
    'teaching'::TEXT,
    (NOW() + INTERVAL '4 days')::TIMESTAMP,
    (NOW() + INTERVAL '4 days 1 hour')::TIMESTAMP,
    'ES'::TEXT,
    'Teaching sin teacher verificado'::TEXT
) as teaching_debe_fallar;
-- ================================================================
-- 5. RESUMEN DE LA PRUEBA
-- ================================================================

SELECT 'RESUMEN DE LA PRUEBA COMPLETA' as seccion, '' as detalle
UNION ALL
SELECT '================================', ''
UNION ALL
SELECT 'Likes creados:', 
    (SELECT COUNT(*)::TEXT FROM user_likes 
     WHERE (id_user_giver = 5 AND id_user_receiver = 7) OR (id_user_giver = 7 AND id_user_receiver = 5))
UNION ALL
SELECT 'Matches creados:', 
    (SELECT COUNT(*)::TEXT FROM user_matches 
     WHERE (user_1 = 5 AND user_2 = 7) OR (user_1 = 7 AND user_2 = 5))
UNION ALL
SELECT 'Sesiones creadas:', 
    (SELECT COUNT(*)::TEXT FROM sessions 
     WHERE (id_user1 = 5 AND id_user2 = 7) OR (id_user1 = 7 AND id_user2 = 5))
UNION ALL
SELECT 'Exchange sessions:', 
    (SELECT COUNT(*)::TEXT FROM exchange_sessions es 
     JOIN sessions s ON es.session_id = s.session_id
     WHERE (s.id_user1 = 5 AND s.id_user2 = 7) OR (s.id_user1 = 7 AND s.id_user2 = 5));


--verificasion de la sesion creada
SELECT fun_validar_likes_y_crear_sesion(
    5::INTEGER,                          -- user1_id
    7::INTEGER,                          -- user2_id  
    'exchange'::TEXT,                    -- session_type
    (NOW() + INTERVAL '1 day')::TIMESTAMP,   -- start_time
    (NOW() + INTERVAL '1 day 1 hour')::TIMESTAMP, -- end_time
    'ES'::TEXT,                         -- language_used
    'Sesión de prueba de intercambio de idiomas'::TEXT -- session_notes
) as resultado_sesion;

-- Verificar resultado
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
WHERE (s.id_user1 = 5 AND s.id_user2 = 7) OR (s.id_user1 = 7 AND s.id_user2 = 5)
ORDER BY s.created_at DESC
LIMIT 1;


-- ================================================================
-- 6. LIMPIEZA (OPCIONAL - DESCOMENTA PARA LIMPIAR DATOS DE PRUEBA)
-- ================================================================

/*
-- Si quieres limpiar los datos de prueba después:

DELETE FROM exchange_sessions WHERE session_id IN (
    SELECT session_id FROM sessions 
    WHERE (id_user1 = 5 AND id_user2 = 7) OR (id_user1 = 7 AND id_user2 = 5)
);

DELETE FROM sessions WHERE (id_user1 = 5 AND id_user2 = 7) OR (id_user1 = 7 AND id_user2 = 5);

DELETE FROM user_matches WHERE (user_1 = 5 AND user_2 = 7) OR (user_1 = 7 AND user_2 = 5);

DELETE FROM user_likes WHERE 
    (id_user_giver = 5 AND id_user_receiver = 7) OR (id_user_giver = 7 AND id_user_receiver = 5);

SELECT 'Datos de prueba eliminados' as resultado;
*/