-- ============================================================================
-- bd_core_mobile — Runner maestro (ejecuta todo en orden con psql)
-- ----------------------------------------------------------------------------
-- Uso desde esta carpeta:
--   1) Crear la base (una sola vez):
--        psql -U postgres -h localhost -c "CREATE DATABASE bd_core_mobile;"
--   2) Cargar todo:
--        psql -U postgres -h localhost -d bd_core_mobile -f 99_run_all.sql
--
-- NOTA: si la base ya tiene datos y quieres recrearla desde cero,
--       descomenta la linea del 00_DDL_drop (BORRA TODO).
-- ============================================================================

\echo '>>> (00) DROP de tablas (desactivado por defecto)'
-- \i 00_DDL_drop_tables_core_mobile.sql

\echo '>>> (01) Creando tablas...'
\i 01_DDL_create_tables_core_mobile.sql

\echo '>>> (02) Catalogos: agencias + asesores...'
\i 02_DML_catalogos_core_mobile.sql

\echo '>>> (03) Clientes + accesos app...'
\i 03_DML_clientes_core_mobile.sql

\echo '>>> (04) Cartera: creditos + cronograma + cobranza...'
\i 04_DML_cartera_core_mobile.sql

\echo '>>> (05) Campanas + ofertas preaprobadas...'
\i 05_DML_campanas_ofertas_core_mobile.sql

\echo '>>> Carga completa.'
