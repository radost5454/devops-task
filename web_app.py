from flask import Flask, jsonify
import socket

app = Flask(__name__)

@app.get("/")
def home():
    return jsonify(
        message="Hello from Flask on GCP!",
        host=socket.gethostname()
    )

@app.get("/healthz")
def health():
    return ("ok", 200)

if __name__ == "__main__":
    # Local development
    app.run(host="0.0.0.0", port=8080)
