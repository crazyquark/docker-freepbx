FROM debian:10

ENV DEBIAN_FRONTEND noninteractive

### NodeJS 10
RUN apt-get update && apt-get install -y curl && \
curl -sL https://deb.nodesource.com/setup_11.x | bash - && \
apt-get install -y nodejs

RUN     apt-get upgrade -y \
	&& apt-get install -y build-essential openssh-server apache2 mysql-server\
	mysql-client bison flex php5 php5-curl php5-cli php5-mysql php-pear php5-gd curl sox\
	libncurses5-dev libssl-dev libmysqlclient-dev mpg123 libxml2-dev libnewt-dev sqlite3 libresample1-dev\
	libsqlite3-dev pkg-config automake libtool autoconf git unixodbc-dev uuid uuid-dev\
	libasound2-dev libjansson-dev libogg-dev libvorbis-dev libicu-dev libcurl4-openssl-dev libical-dev libneon27-dev libsrtp0-dev\
	libspandsp-dev sudo libmyodbc subversion libtool-bin python-dev\
	aptitude cron fail2ban net-tools nano wget \
	&& rm -rf /var/lib/apt/lists/*

RUN apt-get install asterisk apache2 libapache2-mod-fcgid build-essential openssh-server apache2 mariadb-server  mariadb-client bison flex php7.0 php7.0-curl php7.0-cli php7.0-pdo php7.0-mysql php7.0-mbstring php7.0-xml curl sox  libncurses5-dev libssl-dev mpg123 libxml2-dev libnewt-dev sqlite3  libsqlite3-dev pkg-config automake libtool autoconf git unixodbc-dev uuid uuid-dev  libasound2-dev libogg-dev libvorbis-dev libicu-dev libcurl4-openssl-dev libical-dev libneon27-dev libsrtp0-dev  libspandsp-dev sudo subversion libtool-bin python-dev unixodbc dirmngr sendmail nodejs
RUN systemctl stop asterisk

RUN rm -rf /etc/asterisk \
	&& mkdir /etc/asterisk \
	&& touch /etc/asterisk/{modules,cdr}.conf \
	&& chown asterisk. /var/run/asterisk \
	&& chown -R asterisk. /etc/asterisk \
	&& chown -R asterisk. /var/{lib,log,spool}/asterisk \
	&& chown -R asterisk. /usr/lib/asterisk \
	&& rm -rf /var/www/html

RUN sed -i 's/^upload_max_filesize = 2M/upload_max_filesize = 120M/' /etc/php5/apache2/php.ini \
	&& sed -i 's/^memory_limit = 128M/memory_limit = 256M/' /etc/php5/apache2/php.ini \
	&& cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf_orig \
	&& sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf \
	&& sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

COPY ./config/odbcinst.ini /etc/odbcinst.ini
COPY ./config/odbc.ini /etc/odbc.ini

COPY ./config/exim4/exim4.conf /etc/exim4/exim4.conf

RUN cd /usr/src \
	&& wget http://mirror.freepbx.org/modules/packages/freepbx/freepbx-15.0-latest.tgz \
	&& tar xfz freepbx-14.0-latest.tgz \
	&& rm -f freepbx-14.0-latest.tgz \
	&& cd freepbx \
	&& chown mysql:mysql -R /var/lib/mysql/* \
	&& /etc/init.d/mysql start \
	&& ./start_asterisk start \
	&& ./install -n \
	&& fwconsole chown \
	&& fwconsole ma upgradeall \
	&& fwconsole ma downloadinstall announcement backup bulkhandler ringgroups timeconditions ivr restapi cel \
	&& /etc/init.d/mysql stop \
	&& rm -rf /usr/src/freepbx*

RUN a2enmod rewrite

#### Add G729 Codecs
RUN	git clone https://github.com/BelledonneCommunications/bcg729 /usr/src/bcg729 ; \
	cd /usr/src/bcg729 ; \
	git checkout tags/1.0.4 ; \
	./autogen.sh ; \
	./configure --libdir=/lib ; \
	make ; \
	make install ; \
	\
	mkdir -p /usr/src/asterisk-g72x ; \
	curl https://bitbucket.org/arkadi/asterisk-g72x/get/default.tar.gz | tar xvfz - --strip 1 -C /usr/src/asterisk-g72x ; \
	cd /usr/src/asterisk-g72x ; \
	./autogen.sh ; \
	./configure CFLAGS='-march=armv7' --with-bcg729 --with-asterisk${ASTERISK_VERSION}0 --enable-penryn; \
	make ; \
	make install

RUN	cd /usr/src && git clone https://github.com/wdoekes/asterisk-chan-dongle.git && \
	cd asterisk-chan-dongle && \
	./bootstrap && \
	./configure --with-astversion=14.7.5 && \
	make && \
	make install

COPY ./config/asterisk/dongle.conf /etc/asterisk/dongle.conf 

RUN sed -i 's/^user		= mysql/user		= root/' /etc/mysql/my.cnf

COPY ./run /run
RUN chmod +x /run/*

RUN chown asterisk:asterisk -R /var/spool/asterisk

CMD /run/startup.sh

EXPOSE 80 3306 5060/udp 5160/udp 5061 5161 4569 10000-20000/udp

#recordings data
VOLUME [ "/var/spool/asterisk/monitor" ]
#database data
VOLUME [ "/var/lib/mysql" ]
#automatic backup
VOLUME [ "/backup" ]
#config
VOLUME [ "/etc/asterisk" ]
