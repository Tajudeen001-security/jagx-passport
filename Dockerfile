# JagX Passport — container image
# By JagX and JRILICENSE

FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    JAGX_PASSPORT_DB=/data/jagx_passport.db

WORKDIR /app

# Install dependencies first so the layer caches across code changes.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY jagx_passport ./jagx_passport
COPY README.md LICENSE ./

# The store lives on a volume so keys and credentials survive restarts.
RUN mkdir -p /data
VOLUME ["/data"]

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health').status==200 else 1)"

CMD ["python", "-m", "jagx_passport", "serve", "--host", "0.0.0.0", "--port", "8000"]
