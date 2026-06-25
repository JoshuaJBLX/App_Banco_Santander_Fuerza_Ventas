from datetime import datetime, timezone

from fastapi import APIRouter, Depends

from database import get_conn, put_conn
from auth import get_asesor_id

router = APIRouter()


@router.get("/alertas")
def listar_alertas(asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            """SELECT a.id, a.cliente_id,
                      c.nombres || ' ' || c.apellidos AS cliente_nombre,
                      a.tipo_alerta, a.mensaje, a.leida
               FROM alertas_cartera a
               JOIN clientes c ON c.id = a.cliente_id
               WHERE a.asesor_id = %s
               ORDER BY a.created_at DESC""",
            (asesor_id,),
        )
        result = []
        for r in cur.fetchall():
            result.append({
                "id": r[0],
                "cliente_id": r[1],
                "cliente_nombre": r[2],
                "tipo_alerta": r[3],
                "mensaje": r[4],
                "leida": r[5],
            })
        return result
    finally:
        put_conn(conn)


@router.get("/alertas/no-leidas")
def contar_no_leidas(asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT COUNT(*) FROM alertas_cartera WHERE asesor_id = %s AND leida = FALSE",
            (asesor_id,),
        )
        return {"no_leidas": cur.fetchone()[0]}
    finally:
        put_conn(conn)


@router.post("/alertas/{alerta_id}/leer")
def marcar_leida(alerta_id: str, asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "UPDATE alertas_cartera SET leida = TRUE WHERE id = %s AND asesor_id = %s",
            (alerta_id, asesor_id),
        )
        conn.commit()
        return {"ok": True}
    finally:
        put_conn(conn)
