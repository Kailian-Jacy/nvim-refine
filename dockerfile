FROM --platform=linux/amd64 ubuntu:22.04

ARG LISTEN_IP=0.0.0.0
ARG LISTEN_PORT=9099
ARG DEBIAN_FRONTEND=noninteractive

EXPOSE ${LISTEN_PORT}

# Install system dependencies in a single layer, clean apt cache
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    zsh curl coreutils git gcc ca-certificates make cmake \
    procps pstree \
  && rm -rf /var/lib/apt/lists/*

COPY . /app/
WORKDIR /app

RUN chmod +x ./setup.sh \
  && /bin/zsh -e ./setup.sh

# Write entrypoint script
RUN printf '#!/bin/zsh\nset -e\n\nLISTEN_IP="${LISTEN_IP:-0.0.0.0}"\nLISTEN_PORT="${LISTEN_PORT:-9099}"\n\nwhile true; do\n    echo "[$(date)] Starting neovim server on ${LISTEN_IP}:${LISTEN_PORT}..."\n    nvim --headless --listen "${LISTEN_IP}:${LISTEN_PORT}"\n    echo "[$(date)] Neovim server stopped. Restarting in 1s..."\n    sleep 1\ndone\n' > /app/docker-entrypoint.sh \
  && chmod +x /app/docker-entrypoint.sh

# Run as non-root user for security (optional, uncomment if desired)
# RUN useradd -m nvimuser && chown -R nvimuser:nvimuser /app
# USER nvimuser

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD nvim --headless -c 'echo "ok"' -c 'quit' 2>/dev/null || exit 1

ENTRYPOINT ["/app/docker-entrypoint.sh"]
