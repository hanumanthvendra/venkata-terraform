import multiprocessing
import os

# --- Get CPU limit from K8s ---
cpu_limit = os.getenv("CPU_LIMIT")
if cpu_limit:
    try:
        # Handles fractional CPUs like "0.25"
        cpu_count = max(1, int(float(cpu_limit)))
    except ValueError:
        cpu_count = multiprocessing.cpu_count()
else:
    cpu_count = multiprocessing.cpu_count()

# --- Get Memory limit from K8s ---
mem_limit = os.getenv("MEM_LIMIT")
if mem_limit:
    try:
        # Normalize units from Kubernetes (e.g., "512Mi", "1Gi", "500M")
        mem_limit = mem_limit.lower().strip()
        if mem_limit.endswith("ki"):
            mem_bytes = int(mem_limit[:-2]) * 1024
        elif mem_limit.endswith("mi"):
            mem_bytes = int(mem_limit[:-2]) * 1024 * 1024
        elif mem_limit.endswith("gi"):
            mem_bytes = int(mem_limit[:-2]) * 1024 * 1024 * 1024
        elif mem_limit.endswith("k"):
            mem_bytes = int(mem_limit[:-1]) * 1000
        elif mem_limit.endswith("m"):
            mem_bytes = int(mem_limit[:-1]) * 1000 * 1000
        elif mem_limit.endswith("g"):
            mem_bytes = int(mem_limit[:-1]) * 1000 * 1000 * 1000
        else:
            mem_bytes = int(mem_limit)
    except Exception:
        mem_bytes = None
else:
    mem_bytes = None

# --- Calculate workers ---
# CPU rule: (2 * CPUs) + 1
workers_by_cpu = (cpu_count * 2) + 1

# Memory rule: assume each worker ~ 256MB
workers_by_mem = (mem_bytes // (256 * 1024 * 1024)) if mem_bytes else workers_by_cpu

# Final worker count = min of both rules
workers = max(1, min(workers_by_cpu, workers_by_mem))

# --- Gunicorn config ---
bind = "0.0.0.0:5500"
threads = 2
timeout = 60
graceful_timeout = 30
accesslog = "-"
errorlog = "-"
loglevel = os.getenv("GUNICORN_LOGLEVEL", "info")

print(f"[gunicorn.conf] CPU cores={cpu_count}, mem={mem_bytes}, workers={workers}")
