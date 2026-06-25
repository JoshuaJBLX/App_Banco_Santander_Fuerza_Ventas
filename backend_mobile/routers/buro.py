import uuid
from datetime import datetime, timezone
from psycopg2.extras import Json

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from typing import Optional

from database import get_conn, put_conn
from auth import get_asesor_id

router = APIRouter()


class BuroRequest(BaseModel):
    dni: str
    cliente_id: Optional[str] = None


def _simular_buro(dni: str) -> dict:
    """Simula respuesta de central de riesgo basado en el DNI."""
    ultimo = int(dni[-1]) if dni else 0
    if ultimo in (0, 9):
        return {
            "calificacion_sbs": "Deficiente",
            "entidades_con_deuda": 4,
            "deuda_total": 25000.0,
            "mayor_deuda": 12000.0,
            "dias_mayor_mora": 75,
            "en_lista_negra": True,
            "motivo_bloqueo": "Registro en lista de morosidad SBS con mas de 60 dias de atraso.",
            "interpretacion": "Cliente con calificacion Deficiente. Presenta deuda significativa en 4 entidades con mora de 75 dias. Bloqueado para nuevo credito.",
        }
    elif ultimo in (1, 2):
        return {
            "calificacion_sbs": "Normal",
            "entidades_con_deuda": 1,
            "deuda_total": 3500.0,
            "mayor_deuda": 3500.0,
            "dias_mayor_mora": 0,
            "en_lista_negra": False,
            "motivo_bloqueo": None,
            "interpretacion": "Cliente con calificacion Normal. Solo tiene 1 entidad reportada con deuda moderada. Sin mora. Buen historial crediticio.",
        }
    elif ultimo in (3, 4):
        return {
            "calificacion_sbs": "CPP",
            "entidades_con_deuda": 2,
            "deuda_total": 8500.0,
            "mayor_deuda": 6000.0,
            "dias_mayor_mora": 15,
            "en_lista_negra": False,
            "motivo_bloqueo": None,
            "interpretacion": "Cliente con calificacion CPP (Con Problemas Potenciales). Mora leve de 15 dias. Evaluar con cautela.",
        }
    elif ultimo in (5, 6):
        return {
            "calificacion_sbs": "Dudoso",
            "entidades_con_deuda": 3,
            "deuda_total": 18000.0,
            "mayor_deuda": 10000.0,
            "dias_mayor_mora": 90,
            "en_lista_negra": False,
            "motivo_bloqueo": None,
            "interpretacion": "Cliente con calificacion Dudoso. Mora prolongada de 90 dias. Alta probabilidad de incumplimiento.",
        }
    else:
        return {
            "calificacion_sbs": "Normal",
            "entidades_con_deuda": 2,
            "deuda_total": 5000.0,
            "mayor_deuda": 3000.0,
            "dias_mayor_mora": 0,
            "en_lista_negra": False,
            "motivo_bloqueo": None,
            "interpretacion": "Cliente con calificacion Normal. Deuda moderada distribuida en 2 entidades. Sin reporte de mora.",
        }


@router.post("/buro/consulta")
def consultar_buro(req: BuroRequest, asesor_id: str = Depends(get_asesor_id)):
    conn = get_conn()
    try:
        cur = conn.cursor()
        resultado = _simular_buro(req.dni)

        # Registrar consulta en BD
        consulta_id = str(uuid.uuid4())
        cur.execute(
            """INSERT INTO consultas_buro
               (id, asesor_id, cliente_id, dni_consultado, calificacion_sbs,
                entidades_con_deuda, deuda_total_pen, mayor_deuda, dias_mayor_mora,
                en_lista_negra, motivo_bloqueo, resultado_json, created_at)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s)""",
            (
                consulta_id, asesor_id, req.cliente_id, req.dni,
                resultado["calificacion_sbs"],
                resultado["entidades_con_deuda"], resultado["deuda_total"],
                resultado["mayor_deuda"], resultado["dias_mayor_mora"],
                resultado["en_lista_negra"], resultado["motivo_bloqueo"],
                Json(resultado), datetime.now(timezone.utc),
            ),
        )
        conn.commit()

        return resultado
    finally:
        put_conn(conn)
