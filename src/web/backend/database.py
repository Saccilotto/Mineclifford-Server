import aiosqlite
from pathlib import Path

DB_PATH = Path(__file__).parent.parent.parent.parent / "data" / "mineclifford.db"
db_connection = None

async def get_db():
    global db_connection
    if db_connection is None:
        DB_PATH.parent.mkdir(parents=True, exist_ok=True)
        db_connection = await aiosqlite.connect(str(DB_PATH))
        db_connection.row_factory = aiosqlite.Row
    return db_connection

async def init_db():
    db = await get_db()

    await db.execute("""
        CREATE TABLE IF NOT EXISTS servers (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            server_type TEXT NOT NULL,
            version TEXT NOT NULL,
            status TEXT NOT NULL,
            config TEXT NOT NULL,
            ip_address TEXT,
            port INTEGER DEFAULT 25565,
            container_id TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    await db.execute("""
        CREATE TABLE IF NOT EXISTS deployments (
            id TEXT PRIMARY KEY,
            server_id TEXT NOT NULL,
            terraform_state TEXT,
            ansible_output TEXT,
            status TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (server_id) REFERENCES servers(id)
        )
    """)

    await db.commit()

async def close_db():
    global db_connection
    if db_connection:
        await db_connection.close()
