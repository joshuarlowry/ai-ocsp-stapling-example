from fastapi import FastAPI, Query

app = FastAPI(title="OCSP Stapling Demo API")


@app.get("/")
async def root():
    """Health-check & welcome route."""
    return {"status": "ok", "msg": "OCSP Stapling Demo backend is alive"}


@app.get("/hello")
async def hello(name: str = Query("world", description="Your name")):
    """Simple echo endpoint to prove backend connectivity."""
    return {"message": f"Hello, {name}!"}