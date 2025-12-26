# Debug HTTP API

A debug-only HTTP server runs on `localhost:8888` for programmatic entry management (debug mode only).

## Setup
```bash
adb forward tcp:8888 tcp:8888  # For Android emulator
```

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Status, entry count, valid categories |
| GET | `/entries` | List all entries |
| POST | `/entries` | Add single entry `{"text": "...", "category": "Misc"}` |
| POST | `/entries/bulk` | Add multiple `{"entries": [...]}` |
