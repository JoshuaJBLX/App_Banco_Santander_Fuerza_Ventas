-- ============================================================================
-- bd_core_mobile — 00) DROP de todas las tablas (re-ejecucion limpia)
-- ----------------------------------------------------------------------------
-- Ejecutar SOLO si se quiere recrear la base desde cero.
-- El orden no importa porque se usa CASCADE.
-- ============================================================================

DROP TABLE IF EXISTS sync_log                     CASCADE;
DROP TABLE IF EXISTS sync_outbox                  CASCADE;
DROP TABLE IF EXISTS notificaciones               CASCADE;
DROP TABLE IF EXISTS operaciones_cliente          CASCADE;
DROP TABLE IF EXISTS tarjetas                     CASCADE;
DROP TABLE IF EXISTS usuarios_cliente             CASCADE;
DROP TABLE IF EXISTS solicitudes_notas_internas   CASCADE;
DROP TABLE IF EXISTS alertas_cartera              CASCADE;
DROP TABLE IF EXISTS acciones_cobranza            CASCADE;
DROP TABLE IF EXISTS consultas_buro               CASCADE;
DROP TABLE IF EXISTS solicitudes_documentos       CASCADE;
DROP TABLE IF EXISTS solicitudes_credito          CASCADE;
DROP TABLE IF EXISTS campanas_activas             CASCADE;
DROP TABLE IF EXISTS cartera_diaria               CASCADE;
DROP TABLE IF EXISTS creditos_preaprobados        CASCADE;
DROP TABLE IF EXISTS cr_movimientos               CASCADE;
DROP TABLE IF EXISTS cr_cuentas_ahorro            CASCADE;
DROP TABLE IF EXISTS cr_cronograma_pagos          CASCADE;
DROP TABLE IF EXISTS cr_creditos                  CASCADE;
DROP TABLE IF EXISTS clientes                     CASCADE;
DROP TABLE IF EXISTS asesores                     CASCADE;
DROP TABLE IF EXISTS agencias                     CASCADE;

-- ============================================================================
-- FIN drop
-- ============================================================================
