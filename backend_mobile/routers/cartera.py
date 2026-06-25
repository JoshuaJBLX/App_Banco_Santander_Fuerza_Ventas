from datetime import date, datetime, timezone
import hashlib

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional

from database import get_conn, put_conn
from auth import get_asesor_id

router = APIRouter()

_LIMA_LAT, _LIMA_LNG = -12.0464, -77.0428


def _coords_demo(cliente_id, orden_manual: int) -> tuple[float, float]:
    """Coordenadas deterministas alrededor de Lima (clientes sin GPS en BD)."""
    seed = int(hashlib.md5(str(cliente_id).encode()).hexdigest()[:8], 16)
    lat = _LIMA_LAT + ((seed % 200) - 100) * 0.0015 + orden_manual * 0.0003
    lng = _LIMA_LNG + (((seed // 200) % 200) - 100) * 0.0015
    return lat, lng


@router.get("/cartera")
def obtener_cartera(fecha: str, asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()
        query = """SELECT cd.id, cd.asesor_id, cd.cliente_id,
                      c.nombres || ' ' || c.apellidos AS cliente_nombre,
                      c.numero_documento,
                      cd.tipo_gestion, cd.prioridad, cd.score_prioridad,
                      cd.monto_credito, cd.estado_visita,
                      COALESCE(cd.orden_manual, 0) AS orden_manual,
                      cd.fecha_asignacion::text,
                      c.lat, c.lng
               FROM cartera_diaria cd
               JOIN clientes c ON c.id = cd.cliente_id
               WHERE cd.asesor_id = %s AND cd.fecha_asignacion = %s
               ORDER BY cd.orden_manual NULLS LAST, cd.score_prioridad DESC"""
        cur.execute(
            query,
            (asesor_id, fecha),
        )
        rows = cur.fetchall()
        if not rows:
            cur.execute(
                """SELECT MAX(fecha_asignacion)::text
                   FROM cartera_diaria
                   WHERE asesor_id = %s""",
                (asesor_id,),
            )
            ultima_fecha = cur.fetchone()[0]
            if ultima_fecha:
                cur.execute(query, (asesor_id, ultima_fecha))
                rows = cur.fetchall()
        result = []
        for r in rows:
            lat_db, lng_db = r[12], r[13]
            if lat_db is not None and lng_db is not None:
                lat, lng = float(lat_db), float(lng_db)
            else:
                lat, lng = _coords_demo(r[2], int(r[10] or 0))
            result.append({
                "id": r[0],
                "asesor_id": r[1],
                "cliente_id": r[2],
                "cliente_nombre": r[3],
                "documento": r[4],
                "tipo_gestion": r[5],
                "prioridad": r[6],
                "score_prioridad": r[7],
                "monto_credito": float(r[8]) if r[8] else 0,
                "estado_visita": r[9],
                "orden_manual": r[10],
                "fecha_asignacion": r[11],
                "lat": lat,
                "lng": lng,
                "clientes": {
                    "nombres": "",
                    "apellidos": "",
                    "numero_documento": r[4],
                },
            })
        return result
    finally:
        put_conn(conn)


class VisitaRequest(BaseModel):
    resultado: str
    observacion: str = ""
    lat: Optional[float] = None
    lng: Optional[float] = None


@router.post("/cartera/{cartera_id}/visita")
def registrar_visita(cartera_id: str, body: VisitaRequest, asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()
        from datetime import datetime, timezone
        now = datetime.now(timezone.utc)
        cur.execute(
            """UPDATE cartera_diaria
               SET estado_visita = 'visitado',
                   resultado_visita = %s,
                   observacion_visita = %s,
                   timestamp_visita = %s,
                   lat_visita = %s,
                   lng_visita = %s
               WHERE id = %s AND asesor_id = %s""",
            (body.resultado, body.observacion, now, body.lat, body.lng, cartera_id, asesor_id),
        )
        conn.commit()
        return {"ok": True}
    finally:
        put_conn(conn)
