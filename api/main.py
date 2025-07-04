from fastapi import FastAPI, Query

app = FastAPI(title="OCSP Stapling Demo API")


@app.get("/hello")
async def hello(name: str = Query("world", description="Your name")):
    """Simple echo endpoint to prove backend connectivity."""
    return {"message": f"Hello, {name}!"}