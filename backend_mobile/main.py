from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers import (
    auth,
    cartera,
    clientes,
    solicitudes,
    preevaluacion,
    buro,
    cobranza,
    alertas,
    campanas,
    reportes,
)

app = FastAPI(
    title="Banco Santander Consumer Perú - Backend Mobile Fuerza de Ventas",
    description="API REST para la app Flutter de oficiales de credito en campo",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, tags=["Auth"])
app.include_router(cartera.router, tags=["Cartera"])
app.include_router(clientes.router, tags=["Clientes"])
app.include_router(solicitudes.router, tags=["Solicitudes"])
app.include_router(preevaluacion.router, tags=["Pre-evaluacion"])
app.include_router(buro.router, tags=["Buro"])
app.include_router(cobranza.router, tags=["Cobranza"])
app.include_router(alertas.router, tags=["Alertas"])
app.include_router(campanas.router, tags=["Campanas"])
app.include_router(reportes.router, tags=["Reportes"])


@app.get("/")
def root():
    return {"app": "Banco Santander Consumer Perú Mobile API", "version": "1.0.0", "status": "running"}
