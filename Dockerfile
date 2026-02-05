FROM python:3.11-slim

WORKDIR /app

# Install build dependencies only if needed (gcc usually only for compiling native extensions)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first → better layer caching
#COPY requirements.txt ./
#RUN pip install --no-cache-dir -r requirements.txt

# If you don't use requirements.txt yet → you can keep inline installs
# RUN pip install --no-cache-dir \
 RUN pip install \
     flask \
     prometheus_client \
     torch torchvision torchaudio

# For CUDA (uncomment when ready + use appropriate CUDA tag, e.g. python:3.11-slim-bookworm)
# RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Copy application code last
COPY . .

# Use exec form with **double quotes**
CMD ["python", "app.py"]