from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from database import get_conn, put_conn
from auth import verify_password, create_token

router = APIRouter()


class LoginRequest(BaseModel):
    codigo_empleado: str
    password: str


@router.post("/auth/login")
def login(req: LoginRequest):
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            """SELECT id, codigo_empleado, nombres, apellidos, agencia_id, perfil, activo, password_hash
               FROM asesores
               WHERE codigo_empleado = %s AND activo = TRUE""",
            (req.codigo_empleado,),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciales invalidas")

        asesor_id, cod, nombres, apellidos, agencia_id, perfil, activo, pw_hash = row

        if not verify_password(req.password, pw_hash):
            cur.execute(
                "UPDATE asesores SET intentos_fallidos = intentos_fallidos + 1 WHERE id = %s",
                (asesor_id,),
            )
            conn.commit()
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciales invalidas")

        cur.execute("UPDATE asesores SET intentos_fallidos = 0, bloqueado_hasta = NULL WHERE id = %s", (asesor_id,))
        conn.commit()

        token = create_token(asesor_id, cod)
        return {
            "access_token": token,
            "asesor": {
                "id": asesor_id,
                "codigo_empleado": cod,
                "nombres": nombres,
                "apellidos": apellidos,
                "agencia_id": agencia_id,
                "perfil": perfil,
                "activo": activo,
            },
        }
    finally:
        put_conn(conn)
