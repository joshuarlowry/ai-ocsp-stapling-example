FROM alpine:3.19
RUN apk add --no-cache openssl
WORKDIR /certs
COPY run.sh /run.sh
RUN chmod +x /run.sh
EXPOSE 8080
CMD ["/run.sh"]