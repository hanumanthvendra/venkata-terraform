# Build stage
FROM python:3.13-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc libffi-dev libssl-dev && \
    rm -rf /var/lib/apt/lists/*

ENV VIRTUAL_ENV=/opt/venv
RUN python -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt

# Final stage
FROM python:3.13-slim

# Metadata
LABEL org.opencontainers.image.authors="mahesh@hivemet.com"
LABEL org.opencontainers.image.license="MIT"

# Create non-root user/group
RUN groupadd -g 10000 appgroup && \
    useradd -u 10000 -g appgroup -m -d /home/appuser -s /sbin/nologin appuser

# Copy venv from builder
ENV VIRTUAL_ENV=/opt/venv
COPY --from=builder $VIRTUAL_ENV $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Copy application code
WORKDIR /app
COPY --chown=appuser:appgroup . .

# Security: restrict file permissions
RUN find /app -type f -exec chmod 0444 {} \; && \
    find /app -type d -exec chmod 0755 {} \;

# Expose port
EXPOSE 5500

# Healthcheck (Python stdlib, no curl/wget)
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD python -c "import sys, urllib.request; \
    r=urllib.request.urlopen('http://127.0.0.1:5500/health'); \
    sys.exit(0 if r.status==200 else 1)"
# Temporary directory with write permissions
RUN mkdir -p /tmp && chown appuser:appgroup /tmp
VOLUME /tmp

# Run as non-root
USER appuser

# Start app
CMD ["gunicorn", "-c", "gunicorn.conf.py", "app:app"]
