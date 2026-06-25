-- ============================================================================
-- bd_core_mobile — 02) CATALOGOS  (datos genericos: agencias + asesores)
-- ----------------------------------------------------------------------------
-- 3 agencias ficticias y 30 asesores (10 por agencia). Datos de demostracion.
-- Login de la app Fuerza de Ventas:  codigo_empleado = 0001..0030
-- Contrasena para TODOS los asesores:  1234
--   (hash bcrypt valido, verificado contra passlib/CryptContext del backend)
-- ============================================================================

-- ── Agencias (nombres genericos, sin geolocalizacion real) ───────────────────
INSERT INTO agencias (cod_agencia, nombre, region, lat, lng, activa) VALUES
    ('AG-01', 'Agencia Norte',  NULL, NULL, NULL, TRUE),
    ('AG-02', 'Agencia Centro', NULL, NULL, NULL, TRUE),
    ('AG-03', 'Agencia Sur',    NULL, NULL, NULL, TRUE);

-- ── Asesores (cod_agencia se resuelve por JOIN; hash bcrypt unico de '1234') ──
INSERT INTO asesores (cod_asesor, codigo_empleado, nombres, apellidos, agencia_id, perfil, password_hash)
SELECT v.cod_asesor, v.codigo_empleado, v.nombres, v.apellidos, a.id, v.perfil,
       '$2b$12$D.eZtoXYYW79A0.tN9XwgOz4.t2fIqnGbiNoEY.n4Bvq6u/prRrTe'
FROM (VALUES
    -- AGENCIA NORTE (0001-0010)
    ('A001','0001','Carlos','Ramirez Quispe',  'AG-01','supervisor'),
    ('A002','0002','Lucia','Flores Mamani',     'AG-01','operador'),
    ('A003','0003','Jorge','Huaman Condori',    'AG-01','operador'),
    ('A004','0004','Rosa','Apaza Vargas',       'AG-01','operador'),
    ('A005','0005','Miguel','Ccahua Soto',      'AG-01','operador'),
    ('A006','0006','Elena','Quispe Ramos',      'AG-01','operador'),
    ('A007','0007','Victor','Mamani Huanca',    'AG-01','operador'),
    ('A008','0008','Sofia','Condori Lazo',      'AG-01','operador'),
    ('A009','0009','Raul','Vargas Inga',        'AG-01','operador'),
    ('A010','0010','Carmen','Soto Ñahui',       'AG-01','operador'),
    -- AGENCIA CENTRO (0011-0020)
    ('A011','0011','Pedro','Gutierrez Rojas',   'AG-02','supervisor'),
    ('A012','0012','Ana','Castro Paredes',      'AG-02','operador'),
    ('A013','0013','Luis','Meza Quinto',        'AG-02','operador'),
    ('A014','0014','Diana','Aliaga Camargo',    'AG-02','operador'),
    ('A015','0015','Oscar','Baldeon Sinche',    'AG-02','operador'),
    ('A016','0016','Patricia','Riveros Yupanqui','AG-02','operador'),
    ('A017','0017','Hector','Caceres Bullon',   'AG-02','operador'),
    ('A018','0018','Gloria','Espinoza Matos',   'AG-02','operador'),
    ('A019','0019','Javier','Pariona Taipe',    'AG-02','operador'),
    ('A020','0020','Nadia','Lopez Curo',        'AG-02','operador'),
    -- AGENCIA SUR (0021-0030)
    ('A021','0021','Fernando','Salazar Beraun', 'AG-03','supervisor'),
    ('A022','0022','Monica','Orihuela Cardenas','AG-03','operador'),
    ('A023','0023','Cesar','Bravo Galarza',     'AG-03','operador'),
    ('A024','0024','Veronica','Hinostroza Lozano','AG-03','operador'),
    ('A025','0025','Daniel','Maravi Surichaqui', 'AG-03','operador'),
    ('A026','0026','Karina','Poma Astuhuaman',  'AG-03','operador'),
    ('A027','0027','Renato','Chuquillanqui Veliz','AG-03','operador'),
    ('A028','0028','Ingrid','Ramos Palomino',   'AG-03','operador'),
    ('A029','0029','Alex','Quispe Bendezu',     'AG-03','operador'),
    ('A030','0030','Yesenia','Huaroc Pacheco',  'AG-03','operador')
) AS v(cod_asesor, codigo_empleado, nombres, apellidos, cod_agencia, perfil)
JOIN agencias a ON a.cod_agencia = v.cod_agencia;

-- ── Verificacion rapida ──────────────────────────────────────────────────────
-- SELECT ag.nombre, COUNT(*) FROM asesores a JOIN agencias ag ON ag.id=a.agencia_id GROUP BY ag.nombre;
--   Agencia Norte  -> 10
--   Agencia Centro -> 10
--   Agencia Sur    -> 10

-- ============================================================================
-- FIN catalogos
-- ============================================================================
