from flask import Flask, Response
from prometheus_client import Counter, generate_latest
import random, time

app = Flask(__name__)

REQUESTS = Counter("app_requests_total", "Total Requests")

@app.route("/")
def home():
    REQUESTS.inc()
    time.sleep(random.uniform(0.1, 0.5))
    return "Hello from SRE demo app!"

@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype="text/plain")

app.run(host="0.0.0.0", port=8000)
