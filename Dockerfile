FROM debian:10

ENV DEBIAN_FRONTEND noninteractive

ENV ASTERISK_VERSION=16.2.1

RUN apt-get update && apt-get install -y curl wget

### PHP
RUN wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg \
	&& echo "deb https://packages.sury.org/php/ buster main" > /etc/apt/sources.list.d/php.list

### NodeJS 11
RUN	curl -sL https://deb.nodesource.com/setup_11.x | bash - && \
	apt-get install -y nodejs

RUN apt-get update && apt-get upgrade -y

RUN apt-get install -y asterisk asterisk-dev nano apache2 libapache2-mod-fcgid build-essential mariadb-server mariadb-client \
	bison flex openssh-server aptitude cron fail2ban net-tools \
	php7.0 php7.0-curl php7.0-cli php7.0-pdo php7.0-mysql php7.0-mbstring php7.0-xml curl sox \
	libncurses5-dev libssl-dev mpg123 libxml2-dev libnewt-dev sqlite3  libsqlite3-dev \
	pkg-config automake libtool autoconf \
	git unixodbc-dev uuid uuid-dev \
	libasound2-dev libogg-dev libvorbis-dev libicu-dev libcurl4-openssl-dev libical-dev libneon27-dev libspandsp-dev sudo subversion \
	libtool-bin python-dev unixodbc dirmngr exim4 ca-certificates

RUN service asterisk stop
	
RUN  rm -rf /var/lib/apt/lists/*

RUN rm -rf /etc/asterisk \
	&& mkdir /etc/asterisk \
	&& touch /etc/asterisk/modules.conf \
	&& touch /etc/asterisk/cdr.conf \	
	&& chown asterisk. /var/run/asterisk \
	&& chown -R asterisk. /etc/asterisk \
	&& chown -R asterisk. /var/lib/asterisk \
	&& chown -R asterisk. /var/log/asterisk \
	&& chown -R asterisk. /var/spool/asterisk \	
	&& chown -R asterisk. /usr/lib/asterisk \
	&& rm -rf /var/www/html

RUN sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/7.0/apache2/php.ini \
	&& cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf_orig \
	&& sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf \
	&& sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

RUN a2enmod rewrite
RUN service apache2 restart

RUN cd /usr/src \
	&& wget http://mirror.freepbx.org/modules/packages/freepbx/freepbx-15.0-latest.tgz \
	&& tar xfz freepbx-15.0-latest.tgz \
	&& rm -f freepbx-15.0-latest.tgz

#### Add G729 Codecs
RUN	git clone https://github.com/BelledonneCommunications/bcg729 /usr/src/bcg729 ; \
	cd /usr/src/bcg729 ; \
	git checkout tags/1.0.4 ; \
	./autogen.sh ; \
	./configure --libdir=/lib ; \
	make ; \
	make install
	
RUN	mkdir -p /usr/src/asterisk-g72x ; \
	# Why does this need -k(--insecure?)
	git clone https://bitbucket.org/arkadi/asterisk-g72x /usr/src/asterisk-g72x ; \
	cd /usr/src/asterisk-g72x ; \
	./autogen.sh

RUN cd /usr/src/asterisk-g72x ; \
	./configure --with-bcg729 ; \
	make ; \
	make install

RUN	cd /usr/src && git clone https://github.com/wdoekes/asterisk-chan-dongle.git && \
	cd asterisk-chan-dongle && \
	./bootstrap && \
	./configure --with-astversion=${ASTERISK_VERSION} && \
	make && \
	make install

# Copy files
COPY ./config/asterisk/dongle.conf /etc/asterisk/dongle.conf 
COPY ./config/exim4/exim4.conf /etc/exim4/exim4.conf
ADD ./run /run

# Fix permissions
RUN chmod +x /run/*
RUN chown asterisk:asterisk -R /var/spool/asterisk
RUN chown mysql:mysql -R /var/lib/mysql/*

# Finally, run install
RUN /run/install.sh

EXPOSE 80 3306 5060/udp 5160/udp 5061 5161 4569 18000-18030/udp

# Recordings data
VOLUME [ "/var/spool/asterisk/monitor" ]
# Database data
VOLUME [ "/var/lib/mysql" ]
# Automatic backup
VOLUME [ "/backup" ]

CMD /run/startup.sh
