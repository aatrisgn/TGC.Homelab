FROM alpine:3.22

ARG TARGETARCH

COPY binaries/frpc_linux_${TARGETARCH} /usr/local/bin/frpc
COPY frpc.toml /etc/frp/frpc.toml
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/frpc /usr/local/bin/entrypoint.sh

USER 65534

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
