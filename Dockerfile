FROM koalaphils/php:7.4-apache

#Apache changes for document root and PHP configuration changes
RUN sed -i "s|/var/www/html|/var/www/html/public|g" /etc/apache2/sites-enabled/000-default.conf \
  ;
COPY opt/php/*.ini /opt/local/etc/php/conf.d/

#Copy codes to html folder
COPY app /var/www/html
#Install composer packages
RUN composer config --global use-github-api false \
  ; rm -rf vendor && mkdir -p vendor && php -d memory_limit=-1 `which composer` install -no --apcu-autoloader --no-scripts --no-progress --no-autoloader --no-cache \
  ;
VOLUME /var/www/html/vendor

#Modify entrypoint to use the packages from composer custom vendor directory
WORKDIR /var/www/html
RUN sed -i "s|exec \"\$@\"||g" /usr/local/bin/docker-php-entrypoint \
  ; echo "rm -rf .env*;\nprintenv | sed 's/=\\(.*\\)/=\"\\\1\"/' > .env.example;" >> /usr/local/bin/docker-php-entrypoint \
  ; echo "chmod -R 777 storage;\n \
    composer dumpautoload -ao --apcu --no-interaction\n" >> /usr/local/bin/docker-php-entrypoint \
  ; echo "if [ -z \"\$APP_KEY\" ]; then echo \"APP_KEY=\" >> .env.example;fi;\n" >> /usr/local/bin/docker-php-entrypoint \
  ; echo "composer run post-root-package-install;\n \
    composer run post-create-project-cmd;\n \
    . \$PWD/.env;\n \
    if [ \"\$APP_KEY\" = \"\" ]; then php artisan key:generate --ansi; fi;\n \
    php artisan config:cache;\n \
    exec \"\$@\";" >> /usr/local/bin/docker-php-entrypoint \
  ;
