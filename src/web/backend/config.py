from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str = "sqlite:///data/mineclifford.db"
    log_level: str = "INFO"
    cors_origins: list = ["http://localhost:3000"]

    class Config:
        env_file = ".env"

settings = Settings()
