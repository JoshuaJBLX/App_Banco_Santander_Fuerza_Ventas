from fastapi import APIRouter, Depends

from database import get_conn, put_conn
from auth import get_asesor_id

router = APIRouter()


@router.get("/campanas")
def listar_campanas(asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()
        query = """SELECT ca.id, ca.cliente_id,
                      c.nombres || ' ' || c.apellidos AS cliente_nombre,
                      ca.tipo, ca.monto_ofertado,
                      GREATEST((ca.fecha_vencimiento - CURRENT_DATE), 0) AS dias_restantes
               FROM campanas_activas ca
               JOIN clientes c ON c.id = ca.cliente_id
               WHERE ca.asesor_id = %s
                 AND ca.activa = TRUE
                 AND (ca.fecha_vencimiento IS NULL OR ca.fecha_vencimiento >= CURRENT_DATE)
               ORDER BY ca.fecha_vencimiento NULLS LAST, ca.monto_ofertado DESC"""
        cur.execute(
            query,
            (asesor_id,),
        )
        rows = cur.fetchall()
        if not rows:
            cur.execute(
                """SELECT ca.id, ca.cliente_id,
                          c.nombres || ' ' || c.apellidos AS cliente_nombre,
                          ca.tipo, ca.monto_ofertado,
                          GREATEST((ca.fecha_vencimiento - CURRENT_DATE), 0) AS dias_restantes
                   FROM campanas_activas ca
                   JOIN clientes c ON c.id = ca.cliente_id
                   WHERE ca.asesor_id = %s
                     AND ca.activa = TRUE
                   ORDER BY ca.fecha_vencimiento DESC NULLS LAST, ca.monto_ofertado DESC
                   LIMIT 20""",
                (asesor_id,),
            )
            rows = cur.fetchall()
        return [
            {
                "id": r[0],
                "cliente_id": r[1],
                "cliente_nombre": r[2],
                "tipo": r[3],
                "monto_ofertado": float(r[4]) if r[4] else 0,
                "dias_restantes": r[5] or 0,
            }
            for r in rows
        ]
    finally:
        put_conn(conn)
