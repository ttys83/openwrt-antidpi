FROM debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash bison build-essential bzip2 ca-certificates coreutils file findutils flex \
    gawk git gzip libncurses-dev libssl-dev make patch perl python3 \
    python3-distutils rsync tar unzip wget which xz-utils zstd \
    squashfs-tools u-boot-tools \
    && rm -rf /var/lib/apt/lists/*
