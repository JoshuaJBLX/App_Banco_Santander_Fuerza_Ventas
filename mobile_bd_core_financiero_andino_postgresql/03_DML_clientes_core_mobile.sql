-- ============================================================================
-- bd_core_mobile — 03) CLIENTES  (600 clientes + acceso a la app de clientes)
-- ----------------------------------------------------------------------------
-- 30 asesores x 20 clientes = 600 clientes.
--   cod_cliente : C0001 .. C0600   (numero correlativo = clave de mapeo)
--   numero_documento (DNI) : 40000001 .. 40000600
--   Reparto por asesor: clientes C(20k+1 .. 20k+20) -> asesor k+1 (script 04).
-- Cada cliente tiene acceso a la app:  username = DNI   ·   password = 1234
-- Generacion DETERMINISTA (sin random) -> re-ejecutar produce los mismos datos.
-- ============================================================================

DO $$
DECLARE
    v_nombres   TEXT[] := ARRAY[
        'Maria','Jose','Rosa','Pedro','Lucia','Juan','Carmen','Luis','Ana','Cesar',
        'Sonia','Walter','Yolanda','Marco','Elena','Raul','Gladys','Hugo','Nilda','Edwin'];
    v_apellidos TEXT[] := ARRAY[
        'Quispe','Mamani','Condori','Apaza','Huaman','Vargas','Flores','Ccahua','Soto','Ramos',
        'Inga','Ñahui','Lazo','Huanca','Taipe','Pariona','Aliaga','Meza','Poma','Maravi',
        'Orihuela','Bravo','Salazar','Beraun','Surichaqui'];
    v_negocios  TEXT[] := ARRAY[
        'bodega','restaurante','ferreteria','farmacia','peluqueria',
        'taller mecanico','sastreria','libreria','carpinteria','polleria'];
    n        INT;
    v_dni    TEXT;
    v_nom    TEXT;
    v_ape    TEXT;
    v_neg    TEXT;
    v_hash   TEXT := '$2b$12$D.eZtoXYYW79A0.tN9XwgOz4.t2fIqnGbiNoEY.n4Bvq6u/prRrTe';
    v_cli_id UUID;
BEGIN
    FOR n IN 1..600 LOOP
        v_dni := lpad((40000000 + n)::text, 8, '0');
        v_nom := v_nombres[((n - 1) % array_length(v_nombres, 1)) + 1];
        v_ape := v_apellidos[((n * 7  - 1) % array_length(v_apellidos, 1)) + 1] || ' ' ||
                 v_apellidos[((n * 13 - 1) % array_length(v_apellidos, 1)) + 1];
        v_neg := v_negocios[((n - 1) % array_length(v_negocios, 1)) + 1];

        INSERT INTO clientes (
            cod_cliente, numero_documento, tipo_documento, nombres, apellidos,
            fecha_nacimiento, estado_civil, telefono, email, direccion,
            tipo_negocio, nombre_negocio, antiguedad_negocio_meses, ingresos_estimados,
            lat, lng, calificacion_sbs, es_prospecto
        ) VALUES (
            'C' || lpad(n::text, 4, '0'),
            v_dni, 'DNI', v_nom, v_ape,
            DATE '1972-01-01' + ((n * 97) % 9000),
            (ARRAY['soltero','casado','conviviente','viudo'])[((n - 1) % 4) + 1],
            '9' || lpad(((n * 811) % 100000000)::text, 8, '0'),
            lower(v_nom) || '.' || lower(split_part(v_ape, ' ', 1)) || n || '@correo.com',
            'Av. Principal ' || (100 + (n % 900)) || ' - ' ||
                (ARRAY['Agencia Norte','Agencia Centro','Agencia Sur'])[((n - 1) / 200) + 1],
            v_neg, initcap(v_neg) || ' ' || v_nom,
            6 + (n % 90),
            800 + (n % 40) * 150,
            NULL, NULL,
            (ARRAY['Normal','Normal','Normal','CPP','Deficiente'])[((n - 1) % 5) + 1],
            FALSE
        )
        RETURNING id INTO v_cli_id;

        -- Acceso a la app de clientes (appbanco_s8)
        INSERT INTO usuarios_cliente (cliente_id, username, password_hash, activo)
        VALUES (v_cli_id, v_dni, v_hash, TRUE);
    END LOOP;

    RAISE NOTICE 'Clientes insertados: %  | Accesos app: %',
        (SELECT COUNT(*) FROM clientes),
        (SELECT COUNT(*) FROM usuarios_cliente);
END $$;

-- ============================================================================
-- FIN clientes
-- ============================================================================
