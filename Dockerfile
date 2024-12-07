ARG GO_VERSION=latest
ARG RUNTIME_IMAGE=alpine:3.21.0

FROM cimg/go:${GO_VERSION} AS builder
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
USER root
RUN addgroup -S derp && adduser -S derp -G derp
COPY --from=builder /root/derp /etc/derp
RUN chown -R derp:derp /etc/derp
RUN chmod +x /etc/derp/derper

USER derp
ENV DERP_HOSTNAME="derp.myself.com"
ENV DERP_ADDR=":33445"
ENTRYPOINT ["sh", "-c", "/etc/derp/derper -hostname ${DERP_HOSTNAME} \
  -c /etc/derp/derper.key \
  -a ${DERP_ADDR} \
  -certmode manual -certdir /etc/derp/cert"]
