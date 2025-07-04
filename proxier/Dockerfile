FROM ghcr.io/nginxinc/alpine-fips:latest

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    perl \
    pcre \
    apr \
    apr-util \
    wget \
    tar \
    libtool \
    make \
    openssl-dev

# Set Apache version
ENV APACHE_VERSION=2.4.59

# Download and build Apache httpd from source
RUN wget https://downloads.apache.org/httpd/httpd-$APACHE_VERSION.tar.gz \
    && tar -xzf httpd-$APACHE_VERSION.tar.gz \
    && cd httpd-$APACHE_VERSION \
    && ./configure --enable-ssl --with-ssl=/usr --enable-so --with-included-apr --enable-mods-shared=all \
    && make \
    && make install

# Clean up build dependencies and source
RUN rm -rf /httpd-$APACHE_VERSION* \
    && apk del build-base wget tar make libtool

# Copy configuration and static files
COPY httpd.conf /usr/local/apache2/conf/httpd.conf
COPY htdocs/ /usr/local/apache2/htdocs/

# Expose ports
EXPOSE 80 443

# Set entrypoint
CMD ["/usr/local/apache2/bin/httpd", "-DFOREGROUND"]