FROM httpd:2.4-alpine

# Copy your custom config and static files
COPY httpd.conf /usr/local/apache2/conf/httpd.conf
COPY htdocs/ /usr/local/apache2/htdocs/

EXPOSE 80 443

CMD ["httpd-foreground"]