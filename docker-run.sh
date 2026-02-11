docker run -d \
  --name app \
  --gpus all \
  --shm-size=2g \
  -p 8000:8000 \
  --restart unless-stopped \
  my-app:latest

docker run -d \
  --name prometheus \
  -p 9090:9090 \
  -v $(pwd)/prometheus.yml:/etc/prometheus/prometheus.yml:ro \
  prom/prometheus

docker run -d \
  --name grafana \
  -p 3333:3000 \
  -v grafana-data:/var/lib/grafana \
  grafana/grafana