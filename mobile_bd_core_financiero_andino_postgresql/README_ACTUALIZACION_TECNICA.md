# Actualizacion tecnica de scripts SQL

El runner `99_run_all.sql` ejecuta ahora tambien:

- `05_DML_campanas_ofertas_core_mobile.sql`

Ese script agrega datos requeridos por pantallas que ya existen en Flutter:

- `campanas_activas`: consumida por `GET /campanas`.
- `creditos_preaprobados`: consumida por `GET /clientes/{cliente_id}/ficha`.

Orden tecnico actualizado:

```text
01_DDL_create_tables_core_mobile.sql
02_DML_catalogos_core_mobile.sql
03_DML_clientes_core_mobile.sql
04_DML_cartera_core_mobile.sql
05_DML_campanas_ofertas_core_mobile.sql
```

Tambien se ajusto `consultas_buro.cliente_id` para permitir `NULL`, porque la
pantalla de buro permite consultas por DNI sin estar asociadas necesariamente a
un cliente existente.
