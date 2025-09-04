import asyncio
import json
import struct
from contextlib import asynccontextmanager, suppress
from datetime import datetime
from pathlib import Path
from typing import Any

import polars as pl
import uvicorn
from fastapi import Depends, FastAPI, HTTPException, Query, WebSocket, WebSocketDisconnect
from loguru import logger
from pydantic import BaseModel
from pydantic_settings import BaseSettings
from dotenv import load_dotenv

import socketio


_ = load_dotenv()


# --- Configuration ---
class Settings(BaseSettings):
    HOST: str = "0.0.0.0"
    PORT: int = 8765
    SECRET_KEY: str = "supersecretkey"  # Change this in your environment
    LOG_FILE: Path = Path("reactor_log.parquet")
    LOG_INTERVAL_SECONDS: int = 60


settings = Settings()
print(settings)

# --- Pydantic Models ---
class ReactorDataModel(BaseModel):
    timestamp: datetime | None = None
    temperature: float = 0.0
    fuel_level: float = 0.0
    coolant_level: float = 0.0
    waste_level: float = 0.0
    status: bool | str = False
    burn_rate: float = 0.0
    actual_burn_rate: float = 0.0
    alert_status: int = 0


class ControlCommand(BaseModel):
    command: str
    value: str | int | float | bool | None = None


# --- State Management ---
class DataManager:
    def __init__(self, log_file: Path):
        self.reactor_data: ReactorDataModel = ReactorDataModel()
        self.data_buffer: list[ReactorDataModel] = []
        self._lock: asyncio.Lock = asyncio.Lock()
        self.log_file: Path = log_file
        self.data_log: pl.DataFrame = self._load_or_initialize_log()

    def _load_or_initialize_log(self) -> pl.DataFrame:
        """Load existing data log or initialize a new one."""
        schema = {
            "timestamp": pl.Datetime,
            "temperature": pl.Float32,
            "fuel_level": pl.Float32,
            "coolant_level": pl.Float32,
            "waste_level": pl.Float32,
            "status": pl.Boolean,
            "burn_rate": pl.Float32,
            "actual_burn_rate": pl.Float32,
            "alert_status": pl.UInt8,
        }
        if self.log_file.exists():
            logger.info(f"Loading existing data log from {self.log_file}")
            return pl.read_parquet(self.log_file)
        logger.info("Initializing new data log")
        return pl.DataFrame(schema=schema)

    async def add_log_entry(self, reactor_data: ReactorDataModel):
        """Add a new entry to the data buffer."""
        log_entry = reactor_data.model_copy(update={"timestamp": datetime.now()})
        async with self._lock:
            self.data_buffer.append(log_entry)

    async def flush_buffer_to_log(self):
        """Flush the data buffer to the main Polars DataFrame."""
        async with self._lock:
            if not self.data_buffer:
                return
            new_data = pl.DataFrame([item.model_dump() for item in self.data_buffer])
            self.data_log = pl.concat([self.data_log, new_data])
            self.data_buffer.clear()
        logger.info(f"Flushed {len(new_data)} records to data log.")

    async def save_log_to_disk(self):
        """Save the data log to a Parquet file."""
        await self.flush_buffer_to_log()
        async with self._lock:
            if not self.data_log.is_empty():
                self.data_log.write_parquet(self.log_file)
                logger.info(f"Saved data log to {self.log_file}")


class ConnectionManager:
    def __init__(self):
        self.computercraft_connections: dict[str, WebSocket] = {}
        self.esp8266_connected: bool = False
        self._lock: asyncio.Lock = asyncio.Lock()

    async def add_computercraft(self, computer_id: str, websocket: WebSocket):
        async with self._lock:
            self.computercraft_connections[computer_id] = websocket

    async def remove_computercraft(self, computer_id: str):
        async with self._lock:
            if computer_id in self.computercraft_connections:
                del self.computercraft_connections[computer_id]

    async def set_esp8266_connected(self, status: bool):
        async with self._lock:
            self.esp8266_connected = status


# --- Background Task for Data Logging ---
async def periodic_data_saver(interval: int):
    """Periodically save the data log to disk."""
    while True:
        await asyncio.sleep(interval)
        await data_manager.save_log_to_disk()


# --- WebSocket Security ---
async def get_secret_key(secret: str = Query(..., title="Secret Key for WebSocket authentication")): # pyright: ignore[reportCallInDefaultInitializer]
    if secret != settings.SECRET_KEY:
        raise HTTPException(status_code=403, detail="Invalid secret key")
    return secret  # Return the validated secret


@asynccontextmanager
async def lifespan(_app: FastAPI):
    """Handle application lifespan events."""
    # Startup
    task = asyncio.create_task(periodic_data_saver(settings.LOG_INTERVAL_SECONDS))
    yield
    # Shutdown
    _cancelled = task.cancel()
    with suppress(asyncio.CancelledError):
        await task


# --- FastAPI & SocketIO Setup ---
app = FastAPI(title="Reactor Monitoring System", version="2.0.0", lifespan=lifespan)
sio = socketio.AsyncServer(async_mode="asgi", cors_allowed_origins="*")
combined_app = socketio.ASGIApp(sio, app)

conn_manager = ConnectionManager()
data_manager = DataManager(log_file=settings.LOG_FILE)


# --- WebSocket Endpoint for ComputerCraft ---
@app.websocket("/ws/computercraft/{computer_id}")
async def websocket_endpoint(
    websocket: WebSocket, computer_id: str, _: str = Depends(get_secret_key) # pyright: ignore[reportCallInDefaultInitializer]
):
    await websocket.accept()
    await conn_manager.add_computercraft(computer_id, websocket)
    logger.info(f"ComputerCraft {computer_id} connected")

    try:
        while True:
            data = await websocket.receive_text()
            logger.debug(f"Received from ComputerCraft {computer_id}: {data}")

            try:
                reactor_data = ReactorDataModel.model_validate_json(data)
                data_manager.reactor_data = reactor_data
                await data_manager.add_log_entry(reactor_data)

                if conn_manager.esp8266_connected:
                    await send_to_esp8266(reactor_data)

            except json.JSONDecodeError:
                logger.error("Failed to parse JSON from ComputerCraft")
                continue

    except WebSocketDisconnect:
        logger.info(f"ComputerCraft {computer_id} disconnected")
        await conn_manager.remove_computercraft(computer_id)


# --- ESP8266 Communication ---
async def send_to_esp8266(data: ReactorDataModel):
    """Send data to ESP8266 via SocketIO after packing it into a binary format."""
    try:
        # Format: [Header:1byte][Temp:2B][Fuel:2B][Coolant:2B][Waste:2B][Status:1B][Alert:1B][Checksum:1B]
        packet = struct.pack(
            "!BHHHHBB",
            0xAA,  # Header
            min(int(data.temperature * 10), 65535),
            min(int(data.fuel_level * 10), 65535),
            min(int(data.coolant_level * 10), 65535),
            min(int(data.waste_level * 10), 65535),
            1 if data.status else 0,
            data.alert_status,
            0x55,  # Simplified checksum
        )
        # The python-socketio library has limited type hints for its dynamic event system,
        # so we use pyright: ignore to suppress type checker warnings for sio.emit.
        await sio.emit("reactor_data", {"data": packet.hex()})  # pyright: ignore[reportUnknownMemberType]
        logger.debug("Sent data to ESP8266")

    except Exception as e:
        logger.error(f"Failed to send data to ESP8266: {e}")


# --- SocketIO Event Handlers for ESP8266 ---
# The @sio.event decorator is not fully recognized by static type checkers,
# leading to `reportUntypedFunctionDecorator` warnings. We ignore them here.
@sio.event  # pyright: ignore[reportUntypedFunctionDecorator, reportUnknownMemberType]
async def connect(sid: str, _environ: dict[str, Any]): # pyright: ignore[reportExplicitAny]
    logger.info(f"ESP8266 connected with sid: {sid}")
    await conn_manager.set_esp8266_connected(True)


@sio.event  # pyright: ignore[reportUntypedFunctionDecorator, reportUnknownMemberType]
async def disconnect(sid: str):
    logger.info(f"ESP8266 disconnected with sid: {sid}")
    await conn_manager.set_esp8266_connected(False)


@sio.event  # pyright: ignore[reportUntypedFunctionDecorator, reportUnknownMemberType]
async def control_command(sid: str, data: dict[str, Any]): # pyright: ignore[reportExplicitAny]
    try:
        command = ControlCommand.model_validate(data)
        logger.info(f"Received control command from ESP8266: {command}")

        command_data = command.model_dump_json()
        for computer_id, websocket in conn_manager.computercraft_connections.items():
            try:
                await websocket.send_text(command_data)
            except Exception as e:
                logger.error(f"Failed to send command to ComputerCraft {computer_id}: {e}")
    except Exception as e:
        logger.error(f"Invalid control command from {sid}: {data}, error: {e}")


# --- REST API Endpoints ---
@app.get("/status")
async def get_status():
    """Get current system status."""
    return {
        "computercraft_connections": list(conn_manager.computercraft_connections.keys()),
        "esp8266_connected": conn_manager.esp8266_connected,
        "reactor_data": data_manager.reactor_data,
    }


@app.get("/data")
async def get_data_log(limit: int = 100):
    """Get recent data log entries."""
    await data_manager.flush_buffer_to_log()
    return data_manager.data_log.tail(limit).to_dicts()


# --- Main Entry Point ---
if __name__ == "__main__":
    logger.info("Starting Reactor Monitoring Server...")
    uvicorn.run(
        "main:combined_app",
        host=settings.HOST,
        port=settings.PORT,
        reload=True,
    )