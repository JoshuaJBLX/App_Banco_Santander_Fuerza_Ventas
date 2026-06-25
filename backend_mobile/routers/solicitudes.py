import uuid
from datetime import datetime, timezone, timedelta
from math import pow
from psycopg2.extras import Json

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional, Any

from database import get_conn, put_conn
from auth import get_asesor_id

router = APIRouter()


# ============================================================================
# MODELOS
# ============================================================================

class DocumentoRequest(BaseModel):
    solicitud_id: str
    tipo_documento: str  # DNI_FRENTE, DNI_DORSO, SUSTENTO_NEGOCIO, FOTO_NEGOCIO, FOTO_VISITA
    storage_url: str
    tamanio_kb: float


class FirmaRequest(BaseModel):
    solicitud_id: str
    firma_base64: str


class DecisionRequest(BaseModel):
    decision: str  # APROBADO, CONDICIONADO, RECHAZADO
    monto_aprobado: Optional[float] = None
    condicion_adicional: Optional[str] = None
    motivo_rechazo: Optional[str] = None


class DesembolsoRequest(BaseModel):
    fecha_desembolso: str  # YYYY-MM-DD


# ============================================================================
# ENDPOINTS EXISTENTES
# ============================================================================

@router.post("/solicitudes")
def crear_solicitud(datos: dict[str, Any], asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()
        solicitud_id = str(uuid.uuid4())
        now = datetime.now(timezone.utc)

        # Buscar o crear cliente por documento
        doc = datos.get("numero_documento", "")
        cur.execute("SELECT id FROM clientes WHERE numero_documento = %s", (doc,))
        row = cur.fetchone()
        if row:
            cliente_id = row[0]
        else:
            cliente_id = str(uuid.uuid4())
            cur.execute(
                """INSERT INTO clientes (id, numero_documento, nombres, apellidos, telefono,
                   tipo_negocio, nombre_negocio, antiguedad_negocio_meses, ingresos_estimados,
                   created_at, updated_at)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                (
                    cliente_id,
                    doc,
                    datos.get("nombres", ""),
                    datos.get("apellidos", ""),
                    datos.get("telefono"),
                    datos.get("tipo_negocio"),
                    datos.get("nombre_negocio"),
                    datos.get("antiguedad_negocio_meses"),
                    datos.get("ingresos_estimados"),
                    now, now,
                ),
            )

        numero_expediente = f"EXP-{now.strftime('%Y%m%d')}-{solicitud_id[:8].upper()}"

        cur.execute(
            """INSERT INTO solicitudes_credito
               (id, numero_expediente, asesor_id, cliente_id, canal,
                tipo_negocio, nombre_negocio, antiguedad_negocio_meses,
                ingresos_estimados, gastos_mensuales, patrimonio_estimado,
                tiene_conyuge, conyuge_json,
                monto_solicitado, plazo_meses, moneda, tipo_cuota,
                destino_credito, cuota_estimada, tea_referencial,
                estado, firma_cliente_base64, lat_captura, lng_captura,
                created_at, updated_at)
               VALUES (%s, %s, %s, %s, %s,
                       %s, %s, %s, %s, %s, %s,
                       %s, %s::jsonb,
                       %s, %s, %s, %s,
                       %s, %s, %s,
                       %s, %s, %s, %s,
                       %s, %s)""",
            (
                solicitud_id, numero_expediente, asesor_id, cliente_id, "asesor",
                datos.get("tipo_negocio"), datos.get("nombre_negocio"),
                datos.get("antiguedad_negocio_meses"),
                datos.get("ingresos_estimados"), datos.get("gastos_mensuales"),
                datos.get("patrimonio_estimado"),
                datos.get("tiene_conyuge", False),
                Json(datos.get("conyuge_json")) if datos.get("conyuge_json") is not None else None,
                datos.get("monto_solicitado"), datos.get("plazo_meses"),
                datos.get("moneda", "PEN"), datos.get("tipo_cuota", "mensual"),
                datos.get("destino_credito"), datos.get("cuota_estimada"),
                datos.get("tea_referencial"),
                "enviado", datos.get("firma_cliente_base64"),
                datos.get("lat_captura"), datos.get("lng_captura"),
                now, now,
            ),
        )

        conn.commit()
        return {"id": solicitud_id, "numero_expediente": numero_expediente, "estado": "enviado"}
    finally:
        put_conn(conn)


@router.get("/solicitudes")
def listar_solicitudes(asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            """SELECT s.id, s.numero_expediente,
                      c.nombres || ' ' || c.apellidos AS cliente_nombre,
                      s.monto_solicitado, s.monto_aprobado, s.estado,
                      s.created_at::text
               FROM solicitudes_credito s
               JOIN clientes c ON c.id = s.cliente_id
               WHERE s.asesor_id = %s
               ORDER BY s.created_at DESC""",
            (asesor_id,),
        )
        result = []
        for r in cur.fetchall():
            result.append({
                "id": r[0],
                "numero_expediente": r[1],
                "cliente_nombre": r[2],
                "monto_solicitado": float(r[3]) if r[3] else 0,
                "monto_aprobado": float(r[4]) if r[4] else 0,
                "estado": r[5],
                "created_at": r[6],
            })
        return result
    finally:
        put_conn(conn)


@router.get("/solicitudes/{solicitud_id}")
def obtener_solicitud(solicitud_id: str, asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            """SELECT s.id, s.numero_expediente,
                      c.nombres || ' ' || c.apellidos AS cliente_nombre,
                      c.numero_documento, c.nombres, c.apellidos,
                      s.monto_solicitado, s.monto_aprobado, s.estado,
                      s.plazo_meses, s.tea_referencial, s.destino_credito,
                      s.created_at::text, s.firma_cliente_base64
               FROM solicitudes_credito s
               JOIN clientes c ON c.id = s.cliente_id
               WHERE s.id = %s""",
            (solicitud_id,),
        )
        r = cur.fetchone()
        if not r:
            raise HTTPException(status_code=404, detail="Solicitud no encontrada")
        return {
            "id": r[0],
            "numero_expediente": r[1],
            "cliente_nombre": r[2],
            "numero_documento": r[3],
            "nombres": r[4],
            "apellidos": r[5],
            "monto_solicitado": float(r[6]) if r[6] else 0,
            "monto_aprobado": float(r[7]) if r[7] else 0,
            "estado": r[8],
            "plazo_meses": r[9],
            "tea_referencial": float(r[10]) if r[10] else 0,
            "destino_credito": r[11],
            "created_at": r[12],
            "tiene_firma": r[13] is not None,
        }
    finally:
        put_conn(conn)


@router.get("/solicitudes/{solicitud_id}/notas")
def listar_notas(solicitud_id: str, asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT id, contenido FROM solicitudes_notas_internas WHERE solicitud_id = %s ORDER BY created_at DESC",
            (solicitud_id,),
        )
        return [{"id": r[0], "contenido": r[1]} for r in cur.fetchall()]
    finally:
        put_conn(conn)


class NotaRequest(BaseModel):
    contenido: str


@router.post("/solicitudes/{solicitud_id}/notas")
def agregar_nota(solicitud_id: str, body: NotaRequest, asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()
        nota_id = str(uuid.uuid4())
        cur.execute(
            "INSERT INTO solicitudes_notas_internas (id, solicitud_id, asesor_id, contenido, created_at) VALUES (%s, %s, %s, %s, %s)",
            (nota_id, solicitud_id, asesor_id, body.contenido, datetime.now(timezone.utc)),
        )
        conn.commit()
        return {"ok": True}
    finally:
        put_conn(conn)


# ============================================================================
# 1. ENDPOINT: ADJUNTAR DOCUMENTOS
# ============================================================================

@router.post("/solicitudes/documentos")
def adjuntar_documento(data: DocumentoRequest, asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()
        # Verificar solicitud
        cur.execute("SELECT id FROM solicitudes_credito WHERE id = %s", (data.solicitud_id,))
        if not cur.fetchone():
            raise HTTPException(status_code=404, detail="Solicitud no encontrada")

        # Guardar documento
        documento_id = str(uuid.uuid4())
        now = datetime.now(timezone.utc)
        cur.execute(
            """INSERT INTO solicitudes_documentos
               (id, solicitud_id, tipo_documento, storage_url, tamanio_kb, created_at)
               VALUES (%s, %s, %s, %s, %s, %s)""",
            (documento_id, data.solicitud_id, data.tipo_documento,
             data.storage_url, data.tamanio_kb, now),
        )
        conn.commit()
        return {
            "success": True,
            "message": "Documento adjuntado exitosamente",
            "documento_id": documento_id,
        }
    finally:
        put_conn(conn)


# ============================================================================
# 2. ENDPOINT: CAPTURAR FIRMA
# ============================================================================

@router.put("/solicitudes/firma")
def capturar_firma(data: FirmaRequest, asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()
        # Verificar solicitud
        cur.execute("SELECT id FROM solicitudes_credito WHERE id = %s", (data.solicitud_id,))
        if not cur.fetchone():
            raise HTTPException(status_code=404, detail="Solicitud no encontrada")

        # Guardar firma
        cur.execute(
            "UPDATE solicitudes_credito SET firma_cliente_base64 = %s, updated_at = %s WHERE id = %s",
            (data.firma_base64, datetime.now(timezone.utc), data.solicitud_id),
        )
        conn.commit()
        return {
            "success": True,
            "message": "Firma capturada exitosamente",
        }
    finally:
        put_conn(conn)


# ============================================================================
# 3. ENDPOINT: PROMOVER AL COMITÉ
# ============================================================================

@router.put("/solicitudes/{solicitud_id}/promover")
def promover_solicitud(solicitud_id: str, asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT id, estado, numero_expediente FROM solicitudes_credito WHERE id = %s",
                     (solicitud_id,))
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Solicitud no encontrada")

        estado_actual = row[1]
        if estado_actual not in ("enviado", "recibido_comite"):
            raise HTTPException(
                status_code=400,
                detail=f"Estado actual '{estado_actual}' no permite promover",
            )

        # Avanzar estado
        if estado_actual == "enviado":
            nuevo_estado = "recibido_comite"
        else:  # recibido_comite
            nuevo_estado = "en_evaluacion"

        now = datetime.now(timezone.utc)
        cur.execute(
            "UPDATE solicitudes_credito SET estado = %s, updated_at = %s WHERE id = %s",
            (nuevo_estado, now, solicitud_id),
        )

        # Crear sync_outbox
        outbox_id = str(uuid.uuid4())
        cur.execute(
            """INSERT INTO sync_outbox
               (id, entidad, entidad_id, operacion, payload, estado, created_at)
               VALUES (%s, %s, %s, %s, %s::jsonb, %s, %s)""",
            (
                outbox_id,
                "solicitudes_credito",
                solicitud_id,
                "UPDATE",
                Json({
                    "numero_expediente": row[2],
                    "estado": nuevo_estado,
                    "fecha_cambio": now.isoformat(),
                }),
                "pendiente",
                now,
            ),
        )
        conn.commit()
        return {"success": True, "estado": nuevo_estado}
    finally:
        put_conn(conn)


# ============================================================================
# 4. ENDPOINT: REGISTRAR DECISIÓN DEL COMITÉ
# ============================================================================

@router.put("/solicitudes/{solicitud_id}/decision")
def registrar_decision(solicitud_id: str, data: DecisionRequest,
                       asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT id, estado FROM solicitudes_credito WHERE id = %s", (solicitud_id,))
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Solicitud no encontrada")

        if row[1] != "en_evaluacion":
            raise HTTPException(
                status_code=400,
                detail=f"La solicitud debe estar en 'en_evaluacion'. Estado actual: {row[1]}",
            )

        if data.decision == "APROBADO":
            if data.monto_aprobado is None:
                raise HTTPException(status_code=400, detail="monto_aprobado requerido para APROBADO")
            cur.execute(
                "UPDATE solicitudes_credito SET estado = 'aprobado', monto_aprobado = %s, updated_at = %s WHERE id = %s",
                (data.monto_aprobado, datetime.now(timezone.utc), solicitud_id),
            )

        elif data.decision == "CONDICIONADO":
            if data.monto_aprobado is None:
                raise HTTPException(status_code=400, detail="monto_aprobado requerido para CONDICIONADO")
            cur.execute(
                """UPDATE solicitudes_credito
                   SET estado = 'condicionado', monto_aprobado = %s,
                       condicion_adicional = %s, updated_at = %s
                   WHERE id = %s""",
                (data.monto_aprobado, data.condicion_adicional,
                 datetime.now(timezone.utc), solicitud_id),
            )

        elif data.decision == "RECHAZADO":
            cur.execute(
                "UPDATE solicitudes_credito SET estado = 'rechazado', motivo_rechazo = %s, updated_at = %s WHERE id = %s",
                (data.motivo_rechazo, datetime.now(timezone.utc), solicitud_id),
            )

        else:
            raise HTTPException(
                status_code=400,
                detail="Decision invalida. Use: APROBADO, CONDICIONADO o RECHAZADO",
            )

        conn.commit()

        # Retornar el estado actualizado
        cur.execute(
            "SELECT estado, monto_aprobado FROM solicitudes_credito WHERE id = %s",
            (solicitud_id,),
        )
        r = cur.fetchone()
        return {
            "success": True,
            "estado": r[0],
            "monto_aprobado": float(r[1]) if r[1] else None,
        }
    finally:
        put_conn(conn)


# ============================================================================
# 5. ENDPOINT: REGISTRAR DESEMBOLSO Y GENERAR CRONOGRAMA
# ============================================================================

@router.post("/solicitudes/{solicitud_id}/desembolso")
def registrar_desembolso(solicitud_id: str, data: DesembolsoRequest,
                         asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()

        # 1. Verificar solicitud
        cur.execute(
            """SELECT s.id, s.estado, s.monto_aprobado, s.cliente_id,
                      s.plazo_meses, s.tea_referencial
               FROM solicitudes_credito s
               WHERE s.id = %s""",
            (solicitud_id,),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Solicitud no encontrada")

        if row[1] != "aprobado":
            raise HTTPException(
                status_code=400,
                detail=f"La solicitud debe estar 'aprobado'. Estado actual: {row[1]}",
            )

        fecha_desembolso = datetime.strptime(data.fecha_desembolso, "%Y-%m-%d").date()
        monto = float(row[2])
        cliente_id = row[3]
        plazo = row[4] or 12
        tea = float(row[5]) / 100 if row[5] else 0.4392

        # 2. Crear credito en cr_creditos
        credito_id = str(uuid.uuid4())
        cod_cuenta = f"CR-{fecha_desembolso.strftime('%Y%m%d')}-{str(uuid.uuid4())[:6].upper()}"
        now = datetime.now(timezone.utc)

        cur.execute(
            """INSERT INTO cr_creditos
               (id, cod_cuenta_credito, cliente_id, producto,
                monto_desembolsado, saldo_capital, saldo_total,
                dias_mora, estado, fecha_desembolso, tea,
                cuotas_total, cuotas_pagadas, sync_at)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
            (
                credito_id, cod_cuenta, cliente_id,
                "Credito Empresarial - Microempresa",
                monto, monto, monto,
                0, "activo", fecha_desembolso,
                tea, plazo, 0, now,
            ),
        )

        # 3. Generar cronograma (amortizacion francesa)
        tem = pow(1 + tea, 1.0 / 12.0) - 1
        if tem <= 0:
            tem = 0.01  # fallback

        # Formula de cuota francesa
        cuota = monto * (tem * pow(1 + tem, plazo)) / (pow(1 + tem, plazo) - 1)
        cuota = round(cuota, 2)

        saldo = monto
        # Primera cuota: dia 3 del mes siguiente
        if fecha_desembolso.month == 12:
            f_pago = fecha_desembolso.replace(year=fecha_desembolso.year + 1, month=1, day=3)
        else:
            f_pago = fecha_desembolso.replace(month=fecha_desembolso.month + 1, day=3)

        for i in range(1, plazo + 1):
            interes = round(saldo * tem, 2)

            if i == plazo:
                # Ultima cuota: ajustar para saldar exacto
                capital = saldo
                cuota_ajustada = round(capital + interes, 2)
            else:
                capital = round(cuota - interes, 2)
                cuota_ajustada = cuota

            saldo = round(saldo - capital, 2)
            if saldo < 0:
                saldo = 0

            cronograma_id = str(uuid.uuid4())
            cur.execute(
                """INSERT INTO cr_cronograma_pagos
                   (id, cod_cuenta_credito, nro_cuota, fecha_vencimiento,
                    monto_cuota, monto_capital, monto_interes, saldo,
                    estado_cuota, sync_at)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                (
                    cronograma_id, cod_cuenta, i, f_pago,
                    cuota_ajustada, capital, interes,
                    saldo, "pendiente", now,
                ),
            )

            # Calcular siguiente fecha de pago (dia 3 del mes siguiente)
            if f_pago.month == 12:
                f_pago = f_pago.replace(year=f_pago.year + 1, month=1, day=3)
            else:
                f_pago = f_pago.replace(month=f_pago.month + 1, day=3)

        # 4. Actualizar solicitud a desembolsado
        cur.execute(
            "UPDATE solicitudes_credito SET estado = 'desembolsado', updated_at = %s WHERE id = %s",
            (now, solicitud_id),
        )

        # 5. Crear sync_outbox
        outbox_id = str(uuid.uuid4())
        cur.execute(
            """INSERT INTO sync_outbox
               (id, entidad, entidad_id, operacion, payload, estado, created_at)
               VALUES (%s, %s, %s, %s, %s::jsonb, %s, %s)""",
            (
                outbox_id,
                "cr_creditos",
                credito_id,
                "INSERT",
                Json({
                    "cod_cuenta_credito": cod_cuenta,
                    "cliente_id": cliente_id,
                    "monto": monto,
                    "fecha_desembolso": fecha_desembolso.isoformat(),
                }),
                "pendiente",
                now,
            ),
        )

        conn.commit()
        return {
            "success": True,
            "cod_cuenta_credito": cod_cuenta,
            "monto_desembolsado": monto,
            "cuotas": plazo,
            "monto_cuota": cuota,
        }
    finally:
        put_conn(conn)