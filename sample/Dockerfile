# Simple sample Dockerfile to build with buildkit in Firecracker
FROM alpine:3.19

# Install basic utilities
RUN apk add --no-cache \
    curl \
    bash \
    git

# Create a simple app
RUN echo '#!/bin/sh' > /app.sh && \
    echo 'echo "Hello from a container built by BuildKit in Firecracker!"' >> /app.sh && \
    chmod +x /app.sh

ENTRYPOINT ["/app.sh"]
