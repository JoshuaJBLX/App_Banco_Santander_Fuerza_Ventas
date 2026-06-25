# Scripts de la base de datos `bd_core_mobile`

Scripts SQL **secuenciales** para crear desde cero y poblar la base operacional
de canales móviles del Banco Santander Consumer Perú (backend FastAPI mobile, puerto 8003).

Generados a partir del esquema real del proyecto
`back_core_mobile_santander_consumer_peru_fastapi` y **validados** ejecutándolos en una
base PostgreSQL 18 temporal.

## Orden de ejecución

| # | Archivo | Qué hace |
|---|---------|----------|
| 00 | `00_DDL_drop_tables_core_mobile.sql` | Elimina todas las tablas (re-ejecución limpia). **Opcional / destructivo.** |
| 01 | `01_DDL_create_tables_core_mobile.sql` | Crea las 22 tablas, índices y la extensión `pgcrypto`. |
| 02 | `02_DML_catalogos_core_mobile.sql` | Catálogos genéricos: **3 agencias** + **30 asesores**. |
| 03 | `03_DML_clientes_core_mobile.sql` | **600 clientes** + sus accesos a la app de clientes. |
| 04 | `04_DML_cartera_core_mobile.sql` | **600 créditos** (vigente/vencida/mora) + cronograma + cartera del día + alertas + cobranza. |
| 99 | `99_run_all.sql` | Runner que ejecuta 01→04 en orden con `psql`. |

## Cómo cargar

```powershell
# 1) Crear la base (una sola vez)
psql -U postgres -h localhost -c "CREATE DATABASE bd_core_mobile;"

# 2) Cargar todo en orden
psql -U postgres -h localhost -d bd_core_mobile -f 99_run_all.sql
```

> Si `psql` no está en el PATH, búscalo en
> `C:\Program Files\PostgreSQL\18\bin\psql.exe`, o ejecuta los archivos uno a uno
> desde pgAdmin (Query Tool → abrir archivo → Run), respetando el orden 01→04.

## Simulación de datos generada

- **3 agencias** ficticias: Agencia Norte, Agencia Centro, Agencia Sur.
- **30 asesores** (10 por agencia). Login app Fuerza de Ventas:
  `codigo_empleado` = `0001`…`0030`, **contraseña = `1234`** (hash bcrypt real).
  El primer asesor de cada agencia es `supervisor`, el resto `operador`.
- **600 clientes** (20 por asesor). `cod_cliente` = `C0001`…`C0600`,
  DNI = `40000001`…`40000600`. Cada cliente accede a la app de clientes con
  `username` = su DNI y **contraseña = `1234`**.
- **600 créditos**, distribuidos por asesor y por estado de cartera:

  | Estado | Por asesor | Total | Características |
  |--------|-----------:|------:|----------------|
  | **Vigente** | 12 | 360 | al día, `dias_mora = 0`, calificación `normal` |
  | **Vencida** | 5 | 150 | atraso 5–29 días, estado `vencido`, calif. `cpp` |
  | **En mora** | 3 | 90 | atraso 60–90 días, estado `vencido`, calif. `deficiente`/`dudoso` |

- **13 500 cuotas** de cronograma (pagadas / vencidas / pendientes coherentes con la fecha).
- **240 alertas de cartera** y **240 acciones de cobranza** (solo para vencidos y mora).

Distribución verificada por agencia: **120 vigente / 50 vencida / 30 mora / 200 total** cada una.

> La generación es **determinista** (sin valores aleatorios) y usa fechas
> relativas a `CURRENT_DATE`, por lo que re-ejecutar produce siempre los mismos
> datos y la mora se mantiene "fresca".
