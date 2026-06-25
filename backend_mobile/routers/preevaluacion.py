import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional

from auth import get_asesor_id
from database import get_conn, put_conn

router = APIRouter()


class PreEvalRequest(BaseModel):
    numero_documento: str
    nombres: str
    apellidos: str = ""
    fecha_nacimiento: Optional[str] = None
    tipo_negocio: str
    antiguedad_negocio_meses: int = 0
    ingresos_estimados: float
    gastos_mensuales: float = 0  # opcional; se estima si no se envia
    monto_solicitado: float
    destino_credito: str


def _calcular_cuota(monto: float, tea: float = 43.92, plazo_meses: int = 12) -> float:
    """Calcula cuota fija mensual usando TEA."""
    tem = (1 + tea / 100) ** (1 / 12) - 1
    if tem <= 0:
        return monto / plazo_meses
    factor = (tem * (1 + tem) ** plazo_meses) / ((1 + tem) ** plazo_meses - 1)
    return round(monto * factor, 2)


def _calcular_puntaje_y_capacidad(
    req: PreEvalRequest,
) -> tuple[str, str, int, bool, float, float, float, str]:
    """
    Retorna:
      calificacion, motivo, puntaje, apto, capacidad_pago, cuota, ratio, recomendacion
    """
    puntaje = 0
    motivos = []

    # Capacidad de pago
    gastos = req.gastos_mensuales if req.gastos_mensuales > 0 else req.ingresos_estimados * 0.30
    capacidad_pago = req.ingresos_estimados - gastos
    if capacidad_pago < 0:
        capacidad_pago = 0

    # Cuota estimada (TEA por defecto 43.92%, 12 meses)
    cuota = _calcular_cuota(req.monto_solicitado)

    # Ratio de endeudamiento
    ratio = (cuota / capacidad_pago * 100) if capacidad_pago > 0 else 999.99

    # Ingresos
    if req.ingresos_estimados >= 3000:
        puntaje += 30
    elif req.ingresos_estimados >= 1500:
        puntaje += 20
    elif req.ingresos_estimados >= 800:
        puntaje += 10
    else:
        motivos.append("Ingresos bajos")

    # Capacidad de pago positiva
    if capacidad_pago <= 0:
        motivos.append("Capacidad de pago insuficiente")

    # Ratio
    if ratio <= 30:
        puntaje += 25
    elif ratio <= 50:
        puntaje += 15
    elif ratio <= 70:
        puntaje += 5
    else:
        motivos.append("Ratio de endeudamiento elevado")

    # Antiguedad
    if req.antiguedad_negocio_meses >= 24:
        puntaje += 25
    elif req.antiguedad_negocio_meses >= 12:
        puntaje += 15
    elif req.antiguedad_negocio_meses >= 6:
        puntaje += 10
    else:
        motivos.append("Antiguedad insuficiente")

    # Monto solicitud vs ingresos
    relacion = req.monto_solicitado / max(req.ingresos_estimados, 1)
    if relacion <= 6:
        puntaje += 25
    elif relacion <= 12:
        puntaje += 15
    elif relacion <= 20:
        puntaje += 5
    else:
        motivos.append("Monto muy alto respecto a ingresos")

    # Tipo negocio
    if req.tipo_negocio in ("Comercio", "Produccion"):
        puntaje += 10
    elif req.tipo_negocio == "Servicios":
        puntaje += 5

    # Destino de credito
    if req.destino_credito and len(req.destino_credito) > 5:
        puntaje += 10

    # Determinar aptitud
    apto = ratio < 30 and capacidad_pago > 0

    if apto and puntaje >= 70:
        calificacion = "APTO"
        motivo = "Cumple con los criterios minimos de evaluacion"
        recomendacion = "Aprobado"
    elif puntaje >= 40:
        calificacion = "REVISAR"
        motivo = "; ".join(motivos) if motivos else "Requiere analisis adicional"
        recomendacion = "Revisar"
    else:
        calificacion = "NO_PROCEDE"
        motivo = "; ".join(motivos) if motivos else "No cumple condiciones minimas"
        recomendacion = "Rechazado"

    return calificacion, motivo, puntaje, apto, round(capacidad_pago, 2), cuota, round(ratio, 2), recomendacion


@router.post("/pre-evaluar")
def pre_evaluar(req: PreEvalRequest, asesor_id: str = Depends(get_asesor_id)):
    # 1. Validar datos basicos
    if not req.numero_documento or len(req.numero_documento) < 6:
        raise HTTPException(status_code=400, detail="Documento invalido")
    if req.monto_solicitado <= 0:
        raise HTTPException(status_code=400, detail="Monto solicitado debe ser mayor a cero")
    if req.ingresos_estimados <= 0:
        raise HTTPException(status_code=400, detail="Ingresos estimados debe ser mayor a cero")

    # 2. Calcular puntaje y capacidad
    calificacion, motivo, puntaje, apto, capacidad_pago, cuota, ratio, recomendacion = (
        _calcular_puntaje_y_capacidad(req)
    )

    # 3. Guardar en consultas_buro (simulado con data de referencia)
    consulta_id = None
    try:
        conn = get_conn()
        cur = conn.cursor()
        consulta_id = str(uuid.uuid4())
        cur.execute(
            """
            INSERT INTO consultas_buro
                (id, asesor_id, dni_consultado, calificacion_sbs,
                 entidades_con_deuda, deuda_total_pen, dias_mayor_mora,
                 en_lista_negra, resultado_json, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                consulta_id,
                asesor_id,
                req.numero_documento,
                "NORMAL" if apto else "CPP",
                1 if apto else 2,
                4500.00 if apto else 8500.00,
                0 if apto else 15,
                not apto,
                # Guardar el resultado completo como JSON
                '{{"calificacion":"{}","puntaje":{},"apto":{},"capacidad_pago":{},'
                '"cuota":{},"ratio":{},"recomendacion":"{}","motivo":"{}"}}'.format(
                    calificacion, puntaje, str(apto).lower(),
                    capacidad_pago, cuota, ratio,
                    recomendacion, motivo.replace('"', '\\"')
                ),
                datetime.now(),
            ),
        )
        conn.commit()
    except Exception:
        # Si falla la BD, igual devolvemos el resultado (no bloqueante)
        pass
    finally:
        try:
            put_conn(conn)
        except Exception:
            pass

    # 4. Devolver resultado enriquecido
    return {
        "calificacion": calificacion,
        "motivo": motivo,
        "puntaje": puntaje,
        "apto": apto,
        "capacidad_pago": capacidad_pago,
        "cuota": cuota,
        "ratio": ratio,
        "recomendacion": recomendacion,
    }