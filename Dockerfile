FROM drupal:8-apache
LABEL maintainer="yi-yang-github"

COPY config/php.ini /usr/local/etc/php/

# Essentials
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    apt-utils \
    zlibc zlib1g zlib1g-dev \
    bzip2 \
    zip \
    unzip \
    sudo \
    wget gnupg nano vim shellcheck jq

# Enable Redis
RUN pecl install redis && docker-php-ext-enable redis

# Enable Sockets (for monolog / syslog)
RUN docker-php-ext-install sockets

# Install PHP PECL DBase extension for reading ESRI Shapefiles.
RUN pecl install dbase && rm -rf /tmp/pear && docker-php-ext-enable dbase

# Enable MySQL
RUN apt-get update && apt-get install -y default-mysql-client
RUN docker-php-ext-install pdo_mysql

# GD, opcache, pdo, zip are enabled in upstream drupal dockerfile.

# PHP multilingual / intl
RUN apt-get update && apt-get install -qq -y libicu-dev \
    && docker-php-ext-install intl

# Add Xdebug but not enabled it by default
RUN apt -qy install $PHPIZE_DEPS && pecl install xdebug-2.9.5
#RUN docker-php-ext-enable xdebug

# Copy fake SSL certs for dev site.
COPY ./config/ssl/ssl-cert-snakeoil.key /etc/ssl/private/ssl-cert-snakeoil.key
COPY ./config/ssl/ssl-cert-snakeoil.pem /etc/ssl/certs/ssl-cert-snakeoil.pem

# Enable mod_expires
RUN a2enmod expires

# Enable mod_rewrite
RUN a2enmod rewrite

# Enable Proxy
RUN a2enmod proxy
RUN a2enmod proxy_http
RUN a2enmod ssl
RUN a2enmod headers

# Copy fake SSL certs for dev site.
COPY ./config/ssl/ssl-cert-snakeoil.key /etc/ssl/private/ssl-cert-snakeoil.key
COPY ./config/ssl/ssl-cert-snakeoil.pem /etc/ssl/certs/ssl-cert-snakeoil.pem


COPY ./config/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY ./config/sites-available/001-default-ssl.conf /etc/apache2/sites-available/001-default-ssl.conf

# enable the SSL dev site
RUN a2ensite 001-default-ssl

# We use composer and install drupal at /var/www/web, don't need the drupal
# code from upstream.
RUN rm -rf /var/www/html

# Use the official composer image.
COPY --from=composer:1.10 /usr/bin/composer /usr/local/bin/

ENV COMPOSER_HOME /tmp
ENV PATH /tmp/vendor/bin:$PATH

# See composer version.
RUN composer --ansi --version --no-interaction

# Install Drush (PHP/Drupal)
RUN composer global require drush/drush:9.* && drush --version

# Install node from nodesource, newer verion required by yarn installation.
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - \
 && apt-get install -y nodejs

# Add yarn (npm replacement)
# - Needs to have apt-transport-https otherwise will have build error.
RUN sudo apt install apt-transport-https
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
RUN sudo apt update && sudo apt install -y yarn
# Ensure it's installed
RUN yarn --version

# Add Cypress in Drupal dev, so we can run drush from cypress tests.
RUN yarn global add cypress --dev && which cypress
# Ensure it's installed
RUN cypress version

# FROM https://github.com/cypress-io/cypress-docker-images/blob/master/base/ubuntu16/Dockerfile
# and https://on.cypress.io/required-dependencies
# apt-get install libgtk2.0-0 libgtk-3-0 libgbm-dev libnotify-dev libgconf-2-4 libnss3 libxss1 libasound2 libxtst6 xauth xvfb

# Install Cypress dependencies (separate commands to avoid time outs)
#  The libgbm-dev is required for cypress > 5.0
RUN apt-get install -y \
    libgtk2.0-0 libgtk-3-0 libgbm-dev
RUN apt-get install -y \
    libnotify-dev
RUN apt-get install -y \
    libgconf-2-4 \
    libnss3 \
    libxss1
RUN apt-get install -y \
    libasound2 \
    libxtst6 xauth xvfb


WORKDIR /var/www


