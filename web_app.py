from flask import Flask, jsonify
import os
import psycopg2

app = Flask(__name__)

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_NAME = os.getenv("DB_NAME", "appdb")
DB_USER = os.getenv("DB_USER", "appuser")
DB_PASS = os.getenv("DB_PASS", "ChangeMe123!")
DB_PORT = os.getenv("DB_PORT", "5432")

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASS, port=DB_PORT
    )

@app.get("/")
def home():
    return jsonify(message="Hello from the app")

@app.get("/db-check")
def db_check():
    try:
        with get_db_connection() as conn, conn.cursor() as cur:
            cur.execute("SELECT version();")
            version = cur.fetchone()[0]
        return jsonify(status="ok", postgres_version=version)
    except Exception as e:
        return jsonify(status="error", message=str(e)), 500

@app.get("/healthz")
def health():
    return ("ok", 200)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)