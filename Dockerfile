FROM ubuntu:22.04 AS base

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pyscard \
    python3-evdev \
    && rm -rf /var/lib/apt/lists/*


FROM base AS runner

RUN apt-get update && apt-get install -y --no-install-recommends \
    pcscd \
    libccid \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --chmod=755 entrypoint.sh /app/entrypoint.sh
COPY rfid-keyboard.py /app/rfid-keyboard.py

ENTRYPOINT ["/app/entrypoint.sh"]