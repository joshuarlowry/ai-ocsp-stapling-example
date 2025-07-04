FROM httpd:2.4-alpine
RUN apk add --no-cache openssl
COPY httpd.conf /usr/local/apache2/conf/httpd.conf
COPY htdocs/ /usr/local/apache2/htdocs/