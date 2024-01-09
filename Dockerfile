FROM ghcr.io/koalaphils/php:8.2-cli-alpine

COPY --link --from=composer/composer /usr/bin/composer /usr/local/bin/composer
RUN composer config --global use-github-api false

COPY opt/php/*.ini $PHP_INI_DIR/conf.d/
#Copy codes to html folder
COPY app /app
WORKDIR /app

#Apache changes for document root and PHP configuration changes
ENV OCTANE_SERVER=swoole
ENV CACHE_DRIVER=octane
RUN docker-php-ext-enable  \
    apcu \
    event \
    opcache \
    pcntl \
    pdo_mysql \
    swoole \
    zip \
  ; rm -rf vendor && mkdir -p vendor && php -d memory_limit=-1 `which composer` install -no --apcu-autoloader --no-scripts --no-progress --no-autoloader --no-cache \
  ; php -d memory_limit=-1 `which composer` require --prefer-stable -Wno --apcu-autoloader --no-scripts --no-progress --no-cache -W laravel/octane \
  ; cp -rf /app /var/www/html;

#Modify entrypoint to use the packages from composer custom vendor directory
WORKDIR /var/www/html
RUN sed -i "s|exec \"\$@\"||g" `which docker-php-entrypoint` \
  ; printf " \
    rm -rf vendor; ln -s /app/vendor vendor; \
    composer dumpautoload -ao --apcu --no-interaction; \
    php artisan octane:install --server=swoole; \
    rm -rf .env*; \
    printenv | sed 's/=\\(.*\\)/=\"\\\1\"/' > .env.example; \
    if [ -z \"\$APP_KEY\" ]; then echo \"APP_KEY=\" >> .env.example;fi; \
    composer run post-root-package-install; \
    composer run post-create-project-cmd; \
    . \$PWD/.env; \
    if [ \"\$APP_KEY\" = \"\" ]; then php artisan key:generate --ansi; fi; \
    php artisan optimize:clear; \
    php artisan config:cache; \
    php artisan migrate --force; \
    set +e; php artisan psgc:parse; set -e; \
    php artisan optimize; \
    php artisan event:cache; \
    exec \"\$@\"; \
    " >> `which docker-php-entrypoint`;

CMD ["php", "artisan", "octane:start", "--port=80", "--host=0.0.0.0"]
EXPOSE 80
