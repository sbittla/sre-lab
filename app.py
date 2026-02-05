from flask import Flask, Response
from prometheus_client import Counter, Histogram, Summary, Gauge, generate_latest
import random, time
import torch
import threading

app = Flask(__name__)

# Original counter
REQUESTS = Counter("app_requests_total", "Total Requests")

# New: Histogram for request latency (buckets in seconds: good for 0.1-0.5s delays + extras)
LATENCY_HIST = Histogram(
    "app_request_latency_seconds",
    "Request latency in seconds",
    buckets=[0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.75, 1.0, 2.0, float("inf")]
)

# New: Summary for request latency (quantiles like p50, p90, p99)
LATENCY_SUM = Summary(
    "app_request_latency_seconds_summary",
    "Summary of request latency in seconds"
)

# New: Gauge for current active requests (goes up/down)
ACTIVE_REQUESTS = Gauge("app_active_requests", "Number of active requests")

# New: GPU-related Gauges (assuming NVIDIA GPU with CUDA/PyTorch available)
GPU_MEMORY_USED = Gauge("gpu_memory_used_bytes", "GPU memory used in bytes")
GPU_MEMORY_TOTAL = Gauge("gpu_memory_total_bytes", "Total GPU memory in bytes")
GPU_UTILIZATION = Gauge("gpu_utilization_percent", "GPU utilization percentage")

# Function to simulate GPU-intensive work (matrix multiplications to spike usage)
def gpu_intensive_work(duration_factor=1):
    if torch.cuda.is_available():
        device = torch.device("cuda")
        # Create large matrices (e.g., 1000x1000) and multiply in a loop
        size = 1000
        a = torch.randn(size, size, device=device)
        b = torch.randn(size, size, device=device)
        # Loop to increase usage: ~0.1-0.5s worth, scaled by factor
        loops = int(100 * duration_factor)  # Adjust for more/less usage
        for _ in range(loops):
            c = torch.matmul(a, b)  # GPU matrix mul
            torch.cuda.synchronize()  # Ensure completion
        return True
    else:
        print("Warning: No CUDA GPU available - falling back to CPU sleep")
        return False

# Background thread to update GPU gauges periodically (every 5s)
def update_gpu_metrics():
    while True:
        if torch.cuda.is_available():
            GPU_MEMORY_TOTAL.set(torch.cuda.get_device_properties(0).total_memory)
            GPU_MEMORY_USED.set(torch.cuda.memory_allocated())
            GPU_UTILIZATION.set(torch.cuda.utilization())  # Requires PyTorch >=2.1
        time.sleep(5)  # Update interval

# Start the background thread
threading.Thread(target=update_gpu_metrics, daemon=True).start()

@app.route("/")
def home():
    ACTIVE_REQUESTS.inc()  # Increment active requests
    start_time = time.time()

    # Original: Increment counter
    REQUESTS.inc()

    # Simulate variable work: Random factor 0.5-2.0 for duration/intensity
    factor = random.uniform(0.5, 2.0)

    # GPU work instead of sleep (increases GPU usage)
    used_gpu = gpu_intensive_work(factor)

    # Fallback to original sleep if no GPU
    if not used_gpu:
        time.sleep(random.uniform(0.1, 0.5) * factor)

    # Observe latency for Histogram and Summary
    latency = time.time() - start_time
    LATENCY_HIST.observe(latency)
    LATENCY_SUM.observe(latency)

    ACTIVE_REQUESTS.dec()  # Decrement active requests

    return "Hello from SRE demo app! (Processed with GPU: {})".format(used_gpu)

@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype="text/plain")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)