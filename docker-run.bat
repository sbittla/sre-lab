@echo off
setlocal EnableDelayedExpansion

echo.
echo =============================================
echo   Starting monitoring stack with shared network
echo =============================================
echo.

:: ───────────────────────────────────────────────
::  1. Create shared network if it doesn't exist
:: ───────────────────────────────────────────────

echo Checking/creating shared network 'monitoring-net'...
docker network ls | findstr monitoring-net >nul
if %ERRORLEVEL% NEQ 0 (
    echo Creating network: monitoring-net
    docker network create monitoring-net
    if !ERRORLEVEL! NEQ 0 (
        echo Failed to create network.
        pause
        exit /b 1
    )
) else (
    echo Network 'monitoring-net' already exists.
)

:: ───────────────────────────────────────────────
::  2. Build the app image (only if missing)
:: ───────────────────────────────────────────────

echo.
echo Checking if my-app:latest exists...
docker image inspect my-app:latest >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Building my-app:latest ...
    docker build -t my-app:latest .
    if !ERRORLEVEL! NEQ 0 (
        echo Build failed. Stopping.
        pause
        exit /b 1
    )
) else (
    echo my-app:latest already exists. Skipping build.
)

:: ───────────────────────────────────────────────
::  3. Remove old containers if they exist
:: ───────────────────────────────────────────────

echo.
echo Cleaning up old containers (if any)...
for %%c in (app prometheus grafana) do (
    docker stop %%c >nul 2>&1
    docker rm   %%c >nul 2>&1
)

:: ───────────────────────────────────────────────
::  4. Start the services on the shared network
:: ───────────────────────────────────────────────

echo.
echo Starting Prometheus ...
docker run -d ^
  --name prometheus ^
  --network monitoring-net ^
  -p 9090:9090 ^
  -v "%CD%\prometheus.yml:/etc/prometheus/prometheus.yml:ro" ^
  --restart unless-stopped ^
  prom/prometheus

if %ERRORLEVEL% NEQ 0 (
    echo Failed to start Prometheus.
    pause
    exit /b 1
)

echo.
echo Starting Grafana ...
docker run -d ^
  --name grafana ^
  --network monitoring-net ^
  -p 3333:3000 ^
  --restart unless-stopped ^
  grafana/grafana

if %ERRORLEVEL% NEQ 0 (
    echo Failed to start Grafana.
    pause
    exit /b 1
)

echo.
echo Starting your app (with GPU support) ...
docker run -d ^
  --name app ^
  --network monitoring-net ^
  --gpus all ^
  --shm-size=2g ^
  -p 8000:8000 ^
  --restart unless-stopped ^
  my-app:latest

if %ERRORLEVEL% NEQ 0 (
    echo Failed to start app.
    pause
    exit /b 1
)

:: ───────────────────────────────────────────────
::  Final instructions
:: ───────────────────────────────────────────────

echo.
echo =============================================
echo  Stack is running on network 'monitoring-net':
echo.
echo  • App        →  http://localhost:8000
echo  • Prometheus →  http://localhost:9090         (from host)
echo  • Grafana    →  http://localhost:3333
echo.
echo  In Grafana[](http://localhost:3333), add Prometheus data source with:
echo      URL = http://prometheus:9090
echo      (username/password: leave blank)
echo      → Save ^& Test should now succeed
echo.
echo  Useful commands:
echo    docker logs -f prometheus
echo    docker logs -f grafana
echo    docker logs -f app
echo.
echo    docker stop app prometheus grafana
echo    docker rm  app prometheus grafana   (after stopping)
echo.
echo    docker network inspect monitoring-net   (to see IPs/connections)
echo =============================================
echo.

pause