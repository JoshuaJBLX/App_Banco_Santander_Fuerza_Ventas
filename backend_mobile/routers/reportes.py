from fastapi import APIRouter, Depends

from database import get_conn, put_conn
from auth import get_asesor_id

router = APIRouter()


@router.get("/reportes/productividad")
def productividad_mensual(asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()

        cur.execute(
            "SELECT perfil, agencia_id FROM asesores WHERE id = %s",
            (asesor_id,),
        )
        row = cur.fetchone()
        if not row:
            return []

        perfil, agencia_id = row
        filtro_asesor = ""
        params = []
        if perfil not in ("supervisor", "administrador", "super_operador"):
            filtro_asesor = "WHERE a.id = %s"
            params.append(asesor_id)
        elif perfil == "supervisor":
            filtro_asesor = "WHERE a.agencia_id = %s"
            params.append(agencia_id)

        cur.execute(
            f"""SELECT a.nombres || ' ' || a.apellidos AS asesor_nombre,
                       COUNT(s.id) FILTER (WHERE s.estado IN ('enviado','recibido_comite','en_evaluacion','aprobado','condicionado','rechazado','desembolsado')) AS enviadas,
                       COUNT(s.id) FILTER (WHERE s.estado IN ('aprobado','desembolsado')) AS aprobadas,
                       COUNT(s.id) FILTER (WHERE s.estado = 'desembolsado') AS desembolsadas,
                       COALESCE(SUM(s.monto_solicitado), 0) AS monto_total
                FROM asesores a
                LEFT JOIN solicitudes_credito s
                  ON s.asesor_id = a.id
                 AND date_trunc('month', s.created_at) = date_trunc('month', CURRENT_DATE)
                {filtro_asesor}
                GROUP BY a.id, a.nombres, a.apellidos
                ORDER BY enviadas DESC, asesor_nombre ASC""",
            params,
        )

        result = []
        for r in cur.fetchall():
            enviadas = int(r[1] or 0)
            aprobadas = int(r[2] or 0)
            tasa = round((aprobadas / enviadas) * 100, 2) if enviadas else 0
            result.append(
                {
                    "asesor_nombre": r[0],
                    "enviadas": enviadas,
                    "aprobadas": aprobadas,
                    "desembolsadas": int(r[3] or 0),
                    "monto_total": float(r[4] or 0),
                    "tasa_aprobacion": tasa,
                }
            )
        return result
    finally:
        put_conn(conn)
