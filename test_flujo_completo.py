"""
SCRIPT DE PRUEBA - Flujo completo de originacion (Pasos 7-10)
=============================================================
Cliente: Anaximandro Quispe · DNI: 40118120
Monto: S/1,000 · Plazo: 12 meses · TEA: 43.92%

Uso:
  python test_flujo_completo.py

Requisitos:
  - Backend FastAPI corriendo en http://localhost:8003
  - BD PostgreSQL con datos cargados (99_run_all.sql)
  - Asesor autenticado (login previo para obtener token)

Si no tienes BD cargada, ejecuta primero:
  psql -U postgres -h localhost -d bd_core_mobile -f mobile_bd_core_financiero_andino_postgresql/99_run_all.sql
"""

import requests
import json
import sys
import uuid

BASE = "http://localhost:8003"
TOKEN = None  # Se asigna tras login
SOLICITUD_ID = None
CLIENTE_ID = None

# ============================================================================
# Credenciales de asesor (de 02_DML_catalogos_core_mobile.sql)
# ============================================================================
ASESOR_USER = "V0001"
ASESOR_PASS = "1234"


def api(path, method="GET", body=None):
    """Helper para llamar a la API."""
    url = f"{BASE}{path}"
    headers = {"Content-Type": "application/json"}
    if TOKEN:
        headers["Authorization"] = f"Bearer {TOKEN}"

    print(f"\n{'='*60}")
    print(f">>> {method} {url}")
    if body:
        print(f"    Body: {json.dumps(body, indent=4)}")

    try:
        if method == "GET":
            r = requests.get(url, headers=headers, timeout=10)
        elif method == "POST":
            r = requests.post(url, headers=headers, json=body, timeout=10)
        elif method == "PUT":
            r = requests.put(url, headers=headers, json=body, timeout=10)
        else:
            raise ValueError(f"Metodo no soportado: {method}")

        print(f"    Status: {r.status_code}")
        if r.status_code < 300:
            try:
                data = r.json()
                print(f"    Response: {json.dumps(data, indent=4, default=str)}")
                print(f"    {'✅' if r.status_code < 300 else '❌'} OK")
                return data
            except Exception:
                print(f"    Response: {r.text}")
                return r.text
        else:
            print(f"    ❌ ERROR: {r.text}")
            return None
    except requests.exceptions.ConnectionError:
        print("    ❌ ERROR DE CONEXION - El backend no esta corriendo")
        print("    Ejecuta: uvicorn backend_mobile.main:app --reload --port 8003")
        return None
    except Exception as e:
        print(f"    ❌ ERROR: {e}")
        return None


def paso_login():
    """PASO 0: Autenticacion del asesor."""
    global TOKEN
    print("\n\n" + "█" * 60)
    print("███ PASO 0: LOGIN DEL ASESOR")
    print("█" * 60)

    data = api("/auth/login", "POST", {
        "codigo_empleado": ASESOR_USER,
        "password": ASESOR_PASS,
    })
    if data and "access_token" in data:
        TOKEN = data["access_token"]
        print(f"\n   ✅ Token obtenido: {TOKEN[:30]}...")
        return True
    print("   ❌ Login fallo")
    return False


def paso1_crear_solicitud():
    """PASO 1: Crear solicitud de credito para el cliente."""
    global SOLICITUD_ID, CLIENTE_ID
    print("\n\n" + "█" * 60)
    print("███ PASO 1: CREAR SOLICITUD DE CREDITO")
    print("█" * 60)

    data = api("/solicitudes", "POST", {
        "numero_documento": "40118120",
        "nombres": "Anaximandro",
        "apellidos": "Quispe",
        "telefono": "999888777",
        "tipo_negocio": "Comercio",
        "nombre_negocio": "Bodega Anaximandro",
        "antiguedad_negocio_meses": 36,
        "ingresos_estimados": 2000.00,
        "gastos_mensuales": 500.00,
        "monto_solicitado": 1000.00,
        "plazo_meses": 12,
        "tea_referencial": 43.92,
        "destino_credito": "Capital de trabajo para compra de inventario",
        "moneda": "PEN",
        "tipo_cuota": "mensual",
    })

    if data and "id" in data:
        SOLICITUD_ID = data["id"]
        print(f"\n   ✅ Solicitud ID: {SOLICITUD_ID}")
        print(f"   📋 Expediente: {data.get('numero_expediente', 'N/A')}")
        return True
    return False


def paso2_adjuntar_documentos():
    """PASO 2: Adjuntar 5 documentos."""
    print("\n\n" + "█" * 60)
    print("███ PASO 2: ADJUNTAR DOCUMENTOS (5)")
    print("█" * 60)

    documentos = [
        ("DNI_FRENTE", "DNI Frente"),
        ("DNI_DORSO", "DNI Dorso"),
        ("SUSTENTO_NEGOCIO", "Sustento del Negocio"),
        ("FOTO_NEGOCIO", "Foto del Negocio"),
        ("FOTO_VISITA", "Foto de la Visita"),
    ]

    ok_count = 0
    for tipo, label in documentos:
        data = api("/solicitudes/documentos", "POST", {
            "solicitud_id": SOLICITUD_ID,
            "tipo_documento": tipo,
            "storage_url": f"https://storage.bancoandino.pe/documentos/{SOLICITUD_ID}/{tipo}.jpg",
            "tamanio_kb": 245.50,
        })
        if data and data.get("success"):
            ok_count += 1
            print(f"   ✅ {label} adjuntado")
        else:
            print(f"   ❌ {label} FALLO")

    if ok_count == 5:
        print(f"\n   ✅ {ok_count}/5 documentos adjuntados correctamente")
        return True
    else:
        print(f"\n   ⚠️ Solo {ok_count}/5 documentos adjuntados")
        return False


def paso3_capturar_firma():
    """PASO 3: Capturar firma (firma ficticia en base64)."""
    print("\n\n" + "█" * 60)
    print("███ PASO 3: CAPTURAR FIRMA")
    print("█" * 60)

    # Firma base64 ficticia (un PNG minimo de 1x1 pixel blanco)
    firma_ficticia = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="

    data = api("/solicitudes/firma", "PUT", {
        "solicitud_id": SOLICITUD_ID,
        "firma_base64": firma_ficticia,
    })

    if data and data.get("success"):
        print("   ✅ Firma capturada exitosamente")
        return True
    return False


def paso4_verificar_documentos_y_firma():
    """Verificar en BD que documentos y firma esten registrados."""
    print("\n\n" + "█" * 60)
    print("███ PASO 4: VERIFICACION EN BD")
    print("█" * 60)

    # Obtener datos de la solicitud
    data = api(f"/solicitudes/{SOLICITUD_ID}", "GET")

    if data:
        print(f"\n   📋 Expediente: {data.get('numero_expediente', 'N/A')}")
        print(f"   👤 Cliente: {data.get('cliente_nombre', 'N/A')}")
        print(f"   📄 Documento: {data.get('numero_documento', 'N/A')}")
        print(f"   💰 Monto: S/{data.get('monto_solicitado', 0):.2f}")
        print(f"   📊 Estado: {data.get('estado', 'N/A')}")
        print(f"   ✍️ Tiene firma: {data.get('tiene_firma', False)}")

        if data.get('tiene_firma'):
            print("   ✅ FIRMA CAPTURADA")
            return True
        else:
            print("   ⚠️  SIN FIRMA (revisar backend)")
            return False
    return False


def paso5_promover_al_comite():
    """PASO 5: Promover solicitud al comite."""
    print("\n\n" + "█" * 60)
    print("███ PASO 5: PROMOVER AL COMITE")
    print("█" * 60)

    # Primera promocion: enviado -> recibido_comite
    data = api(f"/solicitudes/{SOLICITUD_ID}/promover", "PUT", {})

    if data and data.get("success"):
        estado = data.get("estado", "N/A")
        print(f"\n   ✅ Estado actual: {estado}")

        # Segunda promocion: recibido_comite -> en_evaluacion
        data2 = api(f"/solicitudes/{SOLICITUD_ID}/promover", "PUT", {})
        if data2 and data2.get("success"):
            print(f"   ✅ Estado tras 2da promocion: {data2.get('estado', 'N/A')}")
            return True
    return False


def paso6_registrar_decision():
    """PASO 6: Registrar decision del comite -> APROBADO."""
    print("\n\n" + "█" * 60)
    print("███ PASO 6: REGISTRAR DECISION DEL COMITE")
    print("█" * 60)

    data = api(f"/solicitudes/{SOLICITUD_ID}/decision", "PUT", {
        "decision": "APROBADO",
        "monto_aprobado": 1000.00,
    })

    if data and data.get("success"):
        print(f"\n   ✅ Decision: {data['estado']}")
        print(f"   💰 Monto aprobado: S/{data.get('monto_aprobado', 0):.2f}")
        return True
    return False


def paso7_desembolso_y_cronograma():
    """PASO 7: Registrar desembolso y generar cronograma."""
    print("\n\n" + "█" * 60)
    print("███ PASO 7: DESEMBOLSO Y CRONOGRAMA")
    print("█" * 60)

    data = api(f"/solicitudes/{SOLICITUD_ID}/desembolso", "POST", {
        "fecha_desembolso": "2026-02-02",
    })

    if data and data.get("success"):
        print(f"\n   ✅ Credito creado: {data.get('cod_cuenta_credito', 'N/A')}")
        print(f"   💰 Monto: S/{data.get('monto_desembolsado', 0):.2f}")
        print(f"   📆 Cuotas: {data.get('cuotas', 0)}")
        print(f"   💵 Cuota mensual: S/{data.get('monto_cuota', 0):.2f}")

        # Mostrar cronograma esperado
        print("\n" + "─" * 50)
        print("   🗓️  CRONOGRAMA ESPERADO (12 cuotas):")
        print("   " + "─" * 50)
        print(f"   {'N°':<4} {'Fecha':<14} {'Cuota':<10} {'Capital':<10} {'Interes':<10} {'Saldo':<10}")
        print("   " + "─" * 50)

        # Calcular cronograma esperado
        monto = 1000.0
        tea = 0.4392
        plazo = 12
        tem = (1 + tea) ** (1 / 12) - 1
        cuota = round(monto * (tem * (1 + tem) ** plazo) / ((1 + tem) ** plazo - 1), 2)

        saldo = monto
        for i in range(1, plazo + 1):
            interes = round(saldo * tem, 2)
            if i == plazo:
                capital = round(saldo, 2)
                cuota_i = round(capital + interes, 2)
            else:
                capital = round(cuota - interes, 2)
                cuota_i = cuota
            saldo = round(saldo - capital, 2)
            if saldo < 0:
                saldo = 0

            # Fecha de pago
            if i == 1:
                mes = 3
                anio = 2026
            else:
                mes = 3 + i - 1
                anio = 2026
                if mes > 12:
                    mes -= 12
                    anio += 1

            print(f"   {i:<4} 03/{mes:02d}/{anio:<6} {cuota_i:<10.2f} {capital:<10.2f} {interes:<10.2f} {saldo:<10.2f}")

        print("   " + "─" * 50)
        return True
    return False


def mostrar_resumen_final():
    """Muestra el resumen de todo el flujo con queries SQL."""
    print("\n\n" + "█" * 60)
    print("███ RESUMEN FINAL - QUERIES SQL PARA VERIFICAR EN BD")
    print("█" * 60)

    print("""
═══════════════════════════════════════════════════════
✅ FLUJO COMPLETO EJECUTADO EXITOSAMENTE

📋 Para verificar en BD, ejecuta:

   psql -U postgres -h localhost -d bd_core_mobile

═══════════════════════════════════════════════════════

📌 1. Ver documentos:
""")
    print(f"""
SELECT tipo_documento, tamanio_kb, created_at
FROM solicitudes_documentos sd
JOIN solicitudes_credito sc ON sd.solicitud_id = sc.id
WHERE sc.cliente_id = (SELECT id FROM clientes WHERE numero_documento = '40118120')
ORDER BY sd.created_at DESC;
""")
    print("📌 2. Ver firma:")
    print("""
SELECT CASE
    WHEN firma_cliente_base64 IS NOT NULL THEN '✅ Firma capturada'
    ELSE '❌ Sin firma'
END as estado_firma
FROM solicitudes_credito
WHERE cliente_id = (SELECT id FROM clientes WHERE numero_documento = '40118120')
ORDER BY created_at DESC;
""")
    print("📌 3. Ver evolucion de estados:")
    print("""
SELECT numero_expediente, estado, created_at, updated_at
FROM solicitudes_credito
WHERE cliente_id = (SELECT id FROM clientes WHERE numero_documento = '40118120')
ORDER BY created_at DESC;
""")
    print("📌 4. Ver credito creado:")
    print("""
SELECT cod_cuenta_credito, monto_desembolsado, saldo_capital,
       estado, fecha_desembolso, tea, cuotas_total
FROM cr_creditos
WHERE cliente_id = (SELECT id FROM clientes WHERE numero_documento = '40118120')
ORDER BY fecha_desembolso DESC;
""")
    print("📌 5. Ver cronograma:")
    print("""
SELECT nro_cuota,
       to_char(fecha_vencimiento, 'DD/MM/YYYY') as fecha,
       monto_cuota, monto_capital, monto_interes, saldo, estado_cuota
FROM cr_cronograma_pagos
WHERE cod_cuenta_credito = (
    SELECT cod_cuenta_credito FROM cr_creditos
    WHERE cliente_id = (SELECT id FROM clientes WHERE numero_documento = '40118120')
    ORDER BY fecha_desembolso DESC LIMIT 1
)
ORDER BY nro_cuota;
""")


def run_all():
    """Ejecuta todos los pasos del flujo."""
    pasos = [
        ("LOGIN", paso_login),
        ("CREAR SOLICITUD", paso1_crear_solicitud),
        ("ADJUNTAR DOCUMENTOS", paso2_adjuntar_documentos),
        ("CAPTURAR FIRMA", paso3_capturar_firma),
        ("VERIFICAR DOCS + FIRMA", paso4_verificar_documentos_y_firma),
        ("PROMOVER AL COMITE", paso5_promover_al_comite),
        ("DECISION DEL COMITE", paso6_registrar_decision),
        ("DESEMBOLSO + CRONOGRAMA", paso7_desembolso_y_cronograma),
    ]

    print("=" * 60)
    print("  🏦 BANCO SANTANDER CONSUMER PERU")
    print("  🚀 FLUJO COMPLETO DE ORIGINACION")
    print("  📋 Caso: Anaximandro Quispe (40118120)")
    print("=" * 60)

    for nombre, fn in pasos:
        if not fn():
            print(f"\n  ❌ FLUJO DETENIDO en paso: {nombre}")
            mostrar_resumen_final()
            sys.exit(1)
        print(f"\n  ✅ {nombre} completado")

    mostrar_resumen_final()
    print("\n\n  🎉 FLUJO COMPLETO EJECUTADO EXITOSAMENTE!")


if __name__ == "__main__":
    run_all()