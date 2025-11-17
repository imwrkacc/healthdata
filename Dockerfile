FROM python:3.11-slim

LABEL maintainer="healthkit-exporter"
LABEL description="Apple Health Data to Prometheus Exporter"

# Create app directory
WORKDIR /app

# Copy the exporter script
COPY health_exporter.py .

# Create directory for health data
RUN mkdir -p /data

# Expose Prometheus metrics port
EXPOSE 9090

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:9090/health')" || exit 1

# Run the exporter
# Users should mount their export file at /data/export.zip
ENTRYPOINT ["python3", "health_exporter.py"]
CMD ["--file", "/data/export.zip", "--host", "0.0.0.0", "--port", "9090"]
