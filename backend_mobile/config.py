from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    db_host: str = "localhost"
    db_port: int = 5432
    db_name: str = "bd_core_mobile"
    db_user: str = "postgres"
    db_password: str = "postgres"

    jwt_secret: str = "santander-consumer-peru-mobile-secret-key-cambiar-en-prod"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 480  # 8h

    @property
    def database_url(self) -> str:
        return f"postgresql://{self.db_user}:{self.db_password}@{self.db_host}:{self.db_port}/{self.db_name}"


settings = Settings()
