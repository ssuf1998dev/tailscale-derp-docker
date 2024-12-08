ARG GO_VERSION=1.23.1-bookworm
ARG RUNTIME_IMAGE=alpine:3.21.0

FROM golang:${GO_VERSION} AS builder
ARG TAILSCALE_VERSION

WORKDIR /root
USER root

COPY patches patches
COPY build.sh build.sh
RUN mkdir -p derp/cert

RUN bash build.sh ${TAILSCALE_VERSION}
RUN CGO_ENABLED=0 go build -C tailscale/cmd/derper -o /root/derp/derper
RUN openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
  -keyout derp/cert/derp.myself.com.key -out derp/cert/derp.myself.com.crt \
  -subj "/CN=derp.myself.com" -addext "subjectAltName=DNS:derp.myself.com"

FROM ${RUNTIME_IMAGE}
ENV DERP_HOSTNAME="derp.myself.com"
ENV DERP_ADDR=":33445"
ENV DERP_HTTP_PORT="80"
ENV DERP_CERT_DIR="/app/derp/cert"
ENV DERP_STUN="true"
ENV DERP_VERIFY_CLIENTS="false"

USER root
RUN addgroup -S derp && adduser -S derp -G derp
COPY --from=builder /root/derp /app/derp
RUN chown -R derp:derp /app/derp
RUN chmod +x /app/derp/derper

USER derp

ENTRYPOINT ["sh", "-c", "/app/derp/derper \
  -hostname ${DERP_HOSTNAME} \
  -a ${DERP_ADDR} \
  -http-port ${DERP_HTTP_PORT} \
  -certmode manual -certdir ${DERP_CERT_DIR} \
  -stun=${DERP_STUN} \
  -verify-clients=${DERP_VERIFY_CLIENTS} \
  -c /app/derp/derper.key"]
