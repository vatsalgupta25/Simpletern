from flask import Flask, request
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time

app = Flask(__name__)

# Define Prometheus metrics
REQUEST_COUNT = Counter(
    'request_count', 'App Request Count',
    ['method', 'endpoint', 'http_status']
)
REQUEST_LATENCY = Histogram(
    'request_latency_seconds', 'Request latency',
    ['endpoint']
)

@app.before_request
def before_request():
    request.start_time = time.time()

@app.after_request
def after_request(response):
    request_latency = time.time() - request.start_time
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.endpoint or 'none',
        http_status=response.status_code
    ).inc()
    REQUEST_LATENCY.labels(
        endpoint=request.endpoint or 'none'
    ).observe(request_latency)
    return response

@app.route('/')
def hello():
    return 'Hello this is Vatsal here, trying to deploy this.'

@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0',port=5000)  # Changed this line to listen on all interfaces
