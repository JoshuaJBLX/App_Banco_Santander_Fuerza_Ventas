-- ============================================================================
-- bd_core_mobile - 05) CAMPANAS + OFERTAS PREAPROBADAS
-- ----------------------------------------------------------------------------
-- Datos de apoyo para las pantallas Flutter:
--   - /campanas consume campanas_activas.
--   - /clientes/{id}/ficha consume creditos_preaprobados.
-- Se generan datos deterministas sobre los 600 clientes ya creados.
-- ============================================================================

DO $$
DECLARE
    n          INT;
    v_cli_id   UUID;
    v_ase_id   UUID;
    v_tipo     TEXT;
    v_monto    NUMERIC;
BEGIN
    FOR n IN 1..600 LOOP
        SELECT id INTO v_cli_id
        FROM clientes
        WHERE cod_cliente = 'C' || lpad(n::text, 4, '0');

        SELECT asesor_id INTO v_ase_id
        FROM cartera_diaria
        WHERE cliente_id = v_cli_id
        ORDER BY fecha_asignacion DESC
        LIMIT 1;

        IF v_cli_id IS NULL OR v_ase_id IS NULL THEN
            CONTINUE;
        END IF;

        IF (n % 3) = 0 THEN
            v_monto := 3000 + ((n * 137) % 180) * 100;
            INSERT INTO creditos_preaprobados (
                cliente_id, asesor_id, monto_maximo, plazo_sugerido_meses,
                tea_referencial, score_confianza, vigente,
                fecha_calculo, fecha_vencimiento
            ) VALUES (
                v_cli_id, v_ase_id, v_monto,
                (ARRAY[12, 18, 24, 36])[((n - 1) % 4) + 1],
                28 + (n % 12),
                55 + (n % 40),
                TRUE,
                CURRENT_DATE,
                CURRENT_DATE + INTERVAL '30 days'
            );
        END IF;

        IF (n % 5) = 0 THEN
            v_tipo := CASE WHEN (n % 2) = 0 THEN 'renovacion' ELSE 'ampliacion' END;
            v_monto := 2500 + ((n * 97) % 160) * 100;
            INSERT INTO campanas_activas (
                asesor_id, cliente_id, tipo, monto_ofertado,
                fecha_vencimiento, activa
            ) VALUES (
                v_ase_id, v_cli_id, v_tipo, v_monto,
                CURRENT_DATE + ((5 + (n % 25)) || ' days')::interval,
                TRUE
            );
        END IF;
    END LOOP;

    RAISE NOTICE 'Ofertas preaprobadas: % | Campanas activas: %',
        (SELECT COUNT(*) FROM creditos_preaprobados),
        (SELECT COUNT(*) FROM campanas_activas);
END $$;

-- ============================================================================
-- FIN campanas + ofertas
-- ============================================================================
