-- ============================================================================
-- Verificacion rapida de datos cargados en bd_core_mobile
-- Ejecutar con:
--   psql -U postgres -h localhost -d bd_core_mobile -f 98_verificar_datos.sql
-- ============================================================================

\echo '>>> Conteos principales'
SELECT 'agencias' AS tabla, COUNT(*) AS total FROM agencias
UNION ALL SELECT 'asesores', COUNT(*) FROM asesores
UNION ALL SELECT 'clientes', COUNT(*) FROM clientes
UNION ALL SELECT 'cr_creditos', COUNT(*) FROM cr_creditos
UNION ALL SELECT 'cartera_diaria', COUNT(*) FROM cartera_diaria
UNION ALL SELECT 'alertas_cartera', COUNT(*) FROM alertas_cartera
UNION ALL SELECT 'acciones_cobranza', COUNT(*) FROM acciones_cobranza
UNION ALL SELECT 'creditos_preaprobados', COUNT(*) FROM creditos_preaprobados
UNION ALL SELECT 'campanas_activas', COUNT(*) FROM campanas_activas
ORDER BY tabla;

\echo '>>> Fechas de cartera disponibles'
SELECT fecha_asignacion, COUNT(*) AS clientes
FROM cartera_diaria
GROUP BY fecha_asignacion
ORDER BY fecha_asignacion DESC;

\echo '>>> Cartera por asesor demo'
SELECT a.codigo_empleado, a.nombres || ' ' || a.apellidos AS asesor,
       cd.fecha_asignacion, COUNT(*) AS clientes
FROM cartera_diaria cd
JOIN asesores a ON a.id = cd.asesor_id
GROUP BY a.codigo_empleado, asesor, cd.fecha_asignacion
ORDER BY a.codigo_empleado, cd.fecha_asignacion DESC
LIMIT 30;

\echo '>>> Login demo disponible'
SELECT codigo_empleado, nombres || ' ' || apellidos AS asesor, perfil, activo
FROM asesores
ORDER BY codigo_empleado
LIMIT 10;
