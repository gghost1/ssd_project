FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    ca-certificates \
    clang \
    curl \
    file \
    git \
    lld \
    make \
    perl \
    python3 \
    xz-utils \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /work
COPY . .

RUN chmod +x scripts/*.sh && ./scripts/build_openssl.sh && make fuzz-build

CMD ["make", "fuzz"]
