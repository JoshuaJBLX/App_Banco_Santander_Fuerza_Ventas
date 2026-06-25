from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional

from database import get_conn, put_conn
from auth import get_asesor_id

router = APIRouter()


@router.get("/clientes/{cliente_id}/ficha")
def obtener_ficha(cliente_id: str, asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()

        # Cliente
        cur.execute(
            """SELECT id, numero_documento, nombres, apellidos, telefono, direccion,
                      tipo_negocio, nombre_negocio, antiguedad_negocio_meses, calificacion_sbs
               FROM clientes WHERE id = %s""",
            (cliente_id,),
        )
        c = cur.fetchone()
        if not c:
            raise HTTPException(status_code=404, detail="Cliente no encontrado")

        cliente_data = {
            "id": c[0], "numero_documento": c[1], "nombres": c[2],
            "apellidos": c[3], "telefono": c[4], "direccion": c[5],
            "tipo_negocio": c[6], "nombre_negocio": c[7],
            "antiguedad_negocio_meses": c[8], "calificacion_sbs": c[9] or "NORMAL",
        }

        # Posicion
        cur.execute(
            """SELECT COALESCE(SUM(saldo_total), 0),
                      COUNT(*) FILTER (WHERE estado = 'vigente'),
                      COUNT(*) FILTER (WHERE dias_mora > 0),
                      COALESCE(MAX(dias_mora), 0)
               FROM cr_creditos WHERE cliente_id = %s""",
            (cliente_id,),
        )
        p = cur.fetchone()
        posicion = {
            "deuda_total": float(p[0]),
            "cuentas_vigentes": p[1],
            "cuentas_mora": p[2],
            "dias_mayor_mora": p[3],
        }

        # Historial creditos
        cur.execute(
            """SELECT producto, monto_desembolsado, tea, estado, dias_mora,
                      cuotas_total, cuotas_pagadas
               FROM cr_creditos WHERE cliente_id = %s ORDER BY fecha_desembolso DESC""",
            (cliente_id,),
        )
        historial = []
        for r in cur.fetchall():
            historial.append({
                "producto": r[0],
                "monto_desembolsado": float(r[1]) if r[1] else 0,
                "plazo_meses": r[6] or 0,
                "tea": float(r[2]) if r[2] else 0,
                "estado": r[3],
                "dias_mora": r[4],
                "cuotas_total": r[5],
                "cuotas_pagadas": r[6],
            })

        # Oferta preaprobada
        cur.execute(
            """SELECT monto_maximo, plazo_sugerido_meses, tea_referencial,
                      score_confianza, fecha_vencimiento::text
               FROM creditos_preaprobados
               WHERE cliente_id = %s AND vigente = TRUE
               ORDER BY fecha_calculo DESC LIMIT 1""",
            (cliente_id,),
        )
        o = cur.fetchone()
        oferta = None
        if o:
            oferta = {
                "monto_maximo": float(o[0]),
                "plazo_sugerido_meses": o[1],
                "tea_referencial": float(o[2]) if o[2] else 0,
                "score_confianza": o[3],
                "fecha_vencimiento": o[4],
            }

        # Comportamiento (12 meses mock)
        comportamiento = [1, 1, 1, 1, 2, 2, 1, 1, 1, 1, 1, 1]
        indicadores = {
            "pct_puntual": 83.3,
            "dias_prom_mora": 5,
            "monto_pagado": float(p[0]) * 0.6 if p[0] else 0,
        }

        return {
            "cliente": cliente_data,
            "posicion": posicion,
            "historial": historial,
            "oferta": oferta,
            "comportamiento": comportamiento,
            "indicadores": indicadores,
        }
    finally:
        put_conn(conn)


class UbicacionRequest(BaseModel):
    lat: float
    lng: float
    direccion: Optional[str] = None


@router.post("/clientes/{cliente_id}/ubicacion")
def actualizar_ubicacion(cliente_id: str, body: UbicacionRequest, asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "UPDATE clientes SET lat = %s, lng = %s, direccion = COALESCE(%s, direccion) WHERE id = %s",
            (body.lat, body.lng, body.direccion, cliente_id),
        )
        conn.commit()
        return {"ok": True}
    finally:
        put_conn(conn)
