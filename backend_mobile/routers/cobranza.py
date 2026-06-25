import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from typing import Optional

from database import get_conn, put_conn
from auth import get_asesor_id

router = APIRouter()


@router.get("/cobranza/mora")
def obtener_mora(asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            """SELECT cr.id, cr.cod_cuenta_credito, cr.cliente_id,
                      c.nombres || ' ' || c.apellidos AS cliente_nombre,
                      c.numero_documento, c.telefono,
                      cr.dias_mora,
                      cr.saldo_total - cr.saldo_capital AS monto_vencido
               FROM cr_creditos cr
               JOIN clientes c ON c.id = cr.cliente_id
               JOIN cartera_diaria cd ON cd.cliente_id = cr.cliente_id
               WHERE cd.asesor_id = %s AND cr.dias_mora > 0
               ORDER BY cr.dias_mora DESC""",
            (asesor_id,),
        )
        result = []
        for r in cur.fetchall():
            result.append({
                "id": r[0],
                "cod_cuenta_credito": r[1],
                "cliente_id": r[2],
                "cliente_nombre": r[3],
                "documento": r[4],
                "telefono": r[5],
                "dias_mora": r[6],
                "monto_vencido": float(r[7]) if r[7] else 0,
            })
        return result
    finally:
        put_conn(conn)


class AccionCobranzaRequest(BaseModel):
    cliente_id: str
    cod_cuenta_credito: Optional[str] = None
    tipo_gestion: str  # visita, llamada, mensaje
    resultado: str  # compromiso_pago, pago_parcial, sin_contacto, se_niega
    monto_pagado: Optional[float] = None
    fecha_compromiso: Optional[str] = None
    monto_compromiso: Optional[float] = None
    observaciones: str = ""
    lat: Optional[float] = None
    lng: Optional[float] = None


@router.post("/cobranza/accion")
def registrar_accion(body: AccionCobranzaRequest, asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()
        accion_id = str(uuid.uuid4())
        cur.execute(
            """INSERT INTO acciones_cobranza
               (id, asesor_id, cliente_id, cod_cuenta_credito, tipo_gestion,
                resultado, monto_pagado, fecha_compromiso, monto_compromiso,
                observaciones, lat, lng, timestamp_gestion, pendiente_sync)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
            (
                accion_id, asesor_id, body.cliente_id, body.cod_cuenta_credito,
                body.tipo_gestion, body.resultado,
                body.monto_pagado, body.fecha_compromiso, body.monto_compromiso,
                body.observaciones, body.lat, body.lng,
                datetime.now(timezone.utc), False,
            ),
        )
        conn.commit()
        return {"ok": True}
    finally:
        put_conn(conn)
