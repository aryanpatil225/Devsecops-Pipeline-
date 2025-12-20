from fastapi import FastAPI
from fastapi.responses import HTMLResponse

app = FastAPI(title="DevSecOps Demo App")

@app.get("/")
async def root():
    return HTMLResponse("""
    <html>
        <head>
            <title>DevSecOps Assignment</title>
            <style>
                body { font-family: Arial; text-align: center; margin-top: 100px; }
                h1 { color: #2563eb; }
                .container { max-width: 600px; margin: 0 auto; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🚀 DevSecOps Pipeline Demo</h1>
                <p>FastAPI app deployed successfully via Jenkins + Terraform!</p>
                <p><strong>Status:</strong> ✅ Secure & Production Ready</p>
            </div>
        </body>
    </html>
    """)

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "devsecops-demo"}
