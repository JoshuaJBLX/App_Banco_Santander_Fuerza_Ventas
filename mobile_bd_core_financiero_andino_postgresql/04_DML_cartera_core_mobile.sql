-- ============================================================================
-- bd_core_mobile — 04) CARTERA  (creditos + cronograma + cartera del dia +
--                                alertas + acciones de cobranza)
-- ----------------------------------------------------------------------------
-- Para cada uno de los 600 clientes (C0001..C0600) se genera 1 credito.
-- Reparto por asesor (20 clientes c/u) y por estado de cartera:
--     posicion  1..12  ->  VIGENTE  (al dia, dias_mora = 0)
--     posicion 13..17  ->  VENCIDA  (atraso 5..29 dias)
--     posicion 18..20  ->  MORA     (atraso 60..90 dias)
--   => por asesor: 12 vigente / 5 vencida / 3 mora
--   => total: 360 vigente / 150 vencida / 90 mora
-- Mapeo: cliente C(n) -> asesor codigo_empleado = lpad( ((n-1) DIV 20)+1 , 4).
-- Fechas relativas a CURRENT_DATE (la data se mantiene "fresca").
-- ============================================================================

DO $$
DECLARE
    n            INT;
    v_pos        INT;      -- 1..20 posicion del cliente dentro del asesor
    v_aseidx     INT;      -- 1..30 numero de asesor
    v_bucket     TEXT;     -- vigente | vencida | mora
    v_cli_id     UUID;
    v_ase_id     UUID;
    v_age_id     UUID;
    v_codcred    TEXT;
    -- financieros
    v_monto      NUMERIC;
    v_tea        NUMERIC;
    v_cuotas     INT;
    v_elapsed    INT;
    v_pagadas    INT;
    v_total      NUMERIC;
    v_cuota      NUMERIC;
    v_cap        NUMERIC;
    v_int        NUMERIC;
    v_desemb     DATE;
    v_diasmora   INT;
    v_estado     TEXT;
    v_calif      TEXT;
    v_saldocap   NUMERIC;
    v_saldotot   NUMERIC;
    -- cronograma
    k            INT;
    v_fven       DATE;
    v_estcuota   TEXT;
    v_fpago      DATE;
    v_saldo      NUMERIC;
    -- cartera diaria
    v_tipogest   TEXT;
    v_prioridad  TEXT;
    v_score      INT;
BEGIN
    FOR n IN 1..600 LOOP
        v_aseidx := ((n - 1) / 20) + 1;          -- 1..30
        v_pos    := ((n - 1) % 20) + 1;          -- 1..20

        IF    v_pos <= 12 THEN v_bucket := 'vigente';
        ELSIF v_pos <= 17 THEN v_bucket := 'vencida';
        ELSE                   v_bucket := 'mora';
        END IF;

        SELECT id INTO v_cli_id FROM clientes  WHERE cod_cliente = 'C' || lpad(n::text, 4, '0');
        SELECT a.id, a.agencia_id INTO v_ase_id, v_age_id
            FROM asesores a WHERE a.codigo_empleado = lpad(v_aseidx::text, 4, '0');

        v_codcred := 'CRED-' || lpad(n::text, 5, '0');

        -- ── Parametros del credito ───────────────────────────────────────────
        v_monto  := 5000 + ((n * 317) % 251) * 100;                 -- 5 000 .. 30 100
        v_tea    := 28 + (n % 20);                                  -- 28 .. 47 %
        v_cuotas := (ARRAY[12, 18, 24, 36])[((n - 1) % 4) + 1];
        v_elapsed := GREATEST(3, v_cuotas / 3);                     -- meses transcurridos

        v_total := round(v_monto + v_monto * (v_tea / 100.0) * (v_cuotas / 12.0), 2);
        v_cuota := round(v_total / v_cuotas, 2);
        v_cap   := round(v_monto / v_cuotas, 2);
        v_int   := round(v_cuota - v_cap, 2);

        -- Desembolso: hace v_elapsed meses + un desfase de 5..29 dias.
        v_desemb := (CURRENT_DATE
                     - (v_elapsed || ' months')::interval
                     - ((5 + (n % 25)) || ' days')::interval)::date;

        IF v_bucket = 'vigente' THEN
            v_pagadas  := v_elapsed;          -- al dia
            v_estado   := 'vigente';
            v_calif    := 'normal';
        ELSIF v_bucket = 'vencida' THEN
            v_pagadas  := v_elapsed - 1;      -- debe la ultima cuota vencida
            v_estado   := 'vencido';
            v_calif    := 'cpp';
        ELSE  -- mora
            v_pagadas  := GREATEST(v_elapsed - 3, 1);  -- 3 cuotas vencidas
            v_estado   := 'vencido';
            v_calif    := CASE WHEN (n % 2) = 0 THEN 'deficiente' ELSE 'dudoso' END;
        END IF;

        -- dias de mora reales = dias desde el vencimiento de la 1ra cuota impaga
        IF v_bucket = 'vigente' THEN
            v_diasmora := 0;
        ELSE
            v_diasmora := CURRENT_DATE
                        - (v_desemb + ((v_pagadas + 1) || ' months')::interval)::date;
            IF v_diasmora < 0 THEN v_diasmora := 0; END IF;
        END IF;

        v_saldocap := round(GREATEST(v_monto - v_cap * v_pagadas, 0), 2);
        v_saldotot := round(v_cuota * (v_cuotas - v_pagadas), 2);

        -- ── cr_creditos ──────────────────────────────────────────────────────
        INSERT INTO cr_creditos (
            cod_cuenta_credito, cliente_id, producto, monto_desembolsado,
            saldo_capital, saldo_total, dias_mora, calificacion_interna, estado,
            fecha_desembolso, tea, cuotas_total, cuotas_pagadas
        ) VALUES (
            v_codcred, v_cli_id,
            (ARRAY['Capital de Trabajo','Credito Negocio','Microcredito','Credito Pyme'])[((n - 1) % 4) + 1],
            v_monto, v_saldocap, v_saldotot, v_diasmora, v_calif, v_estado,
            v_desemb, v_tea, v_cuotas, v_pagadas
        );

        -- ── cr_cronograma_pagos ──────────────────────────────────────────────
        FOR k IN 1..v_cuotas LOOP
            v_fven  := (v_desemb + (k || ' months')::interval)::date;
            v_saldo := round(GREATEST(v_monto - v_cap * k, 0), 2);

            IF k <= v_pagadas THEN
                v_estcuota := 'pagada';
                v_fpago    := v_fven - ((1 + (n % 5)) || ' days')::interval;
            ELSIF v_fven < CURRENT_DATE THEN
                v_estcuota := 'vencida';
                v_fpago    := NULL;
            ELSE
                v_estcuota := 'pendiente';
                v_fpago    := NULL;
            END IF;

            INSERT INTO cr_cronograma_pagos (
                cod_cuenta_credito, nro_cuota, fecha_vencimiento, monto_cuota,
                monto_capital, monto_interes, saldo, estado_cuota, fecha_pago
            ) VALUES (
                v_codcred, k, v_fven, v_cuota, v_cap, v_int, v_saldo, v_estcuota, v_fpago
            );
        END LOOP;

        -- ── cartera_diaria (gestion del dia) ─────────────────────────────────
        IF v_bucket = 'vigente' THEN
            v_tipogest  := (ARRAY['RENOVACION','AMPLIACION','NUEVA_SOLICITUD','SEGUIMIENTO'])[((n - 1) % 4) + 1];
            v_prioridad := (ARRAY['normal','media'])[((n - 1) % 2) + 1];
            v_score     := 10 + (n % 40);
        ELSIF v_bucket = 'vencida' THEN
            v_tipogest  := 'RECUPERACION_MORA';
            v_prioridad := 'media';
            v_score     := 50 + (n % 30);
        ELSE
            v_tipogest  := 'RECUPERACION_MORA';
            v_prioridad := 'alta';
            v_score     := 80 + (n % 20);
        END IF;

        INSERT INTO cartera_diaria (
            asesor_id, cliente_id, agencia_id, fecha_asignacion, tipo_gestion,
            prioridad, score_prioridad, monto_credito, estado_visita, orden_manual
        ) VALUES (
            v_ase_id, v_cli_id, v_age_id, CURRENT_DATE, v_tipogest,
            v_prioridad, v_score, v_monto, 'pendiente', v_pos
        );

        -- ── Alertas + acciones de cobranza (solo vencida / mora) ─────────────
        IF v_bucket <> 'vigente' THEN
            INSERT INTO alertas_cartera (asesor_id, cliente_id, tipo_alerta, mensaje, leida)
            VALUES (
                v_ase_id, v_cli_id,
                CASE
                    WHEN v_diasmora <= 3  THEN 'primer_dia_mora'
                    WHEN v_diasmora <= 60 THEN 'mora_30d'
                    ELSE 'mora_60d'
                END,
                'Credito ' || v_codcred || ' con ' || v_diasmora || ' dias de atraso. Saldo S/ ' || v_saldotot,
                FALSE
            );

            INSERT INTO acciones_cobranza (
                asesor_id, cliente_id, cod_cuenta_credito, tipo_gestion, resultado,
                monto_pagado, fecha_compromiso, monto_compromiso, observaciones
            ) VALUES (
                v_ase_id, v_cli_id, v_codcred,
                (ARRAY['visita','llamada','mensaje'])[((n - 1) % 3) + 1],
                (ARRAY['compromiso_pago','pago_parcial','sin_contacto','se_niega'])[((n - 1) % 4) + 1],
                CASE WHEN (n % 4) = 1 THEN round(v_cuota / 2, 2) ELSE NULL END,
                CASE WHEN (n % 4) = 0 THEN CURRENT_DATE + ((3 + (n % 7)) || ' days')::interval ELSE NULL END,
                CASE WHEN (n % 4) = 0 THEN v_cuota ELSE NULL END,
                'Gestion de recuperacion generada por simulacion.'
            );
        END IF;
    END LOOP;

    RAISE NOTICE 'Creditos: %  | Cuotas: %  | Cartera dia: %  | Alertas: %  | Cobranzas: %',
        (SELECT COUNT(*) FROM cr_creditos),
        (SELECT COUNT(*) FROM cr_cronograma_pagos),
        (SELECT COUNT(*) FROM cartera_diaria),
        (SELECT COUNT(*) FROM alertas_cartera),
        (SELECT COUNT(*) FROM acciones_cobranza);
END $$;

-- ============================================================================
-- VERIFICACION: distribucion de cartera por agencia y estado
-- ----------------------------------------------------------------------------
-- SELECT ag.nombre AS agencia,
--        SUM((c.estado='vigente')::int)                          AS vigentes,
--        SUM((c.estado='vencido' AND c.dias_mora<=30)::int)      AS vencidos,
--        SUM((c.estado='vencido' AND c.dias_mora>30)::int)       AS en_mora,
--        COUNT(*)                                                AS total
-- FROM cr_creditos c
-- JOIN clientes      cl ON cl.id = c.cliente_id
-- JOIN cartera_diaria cd ON cd.cliente_id = cl.id
-- JOIN agencias      ag ON ag.id = cd.agencia_id
-- GROUP BY ag.nombre ORDER BY ag.nombre;
--   Cada agencia -> 120 vigentes / 50 vencidos / 30 en_mora / 200 total
-- ============================================================================
-- FIN cartera
-- ============================================================================
