FROM debian:8

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
	&& apt-get upgrade -y \
	&& apt-get install -y build-essential openssh-server apache2 mysql-server\
	mysql-client bison flex php5 php5-curl php5-cli php5-mysql php-pear php5-gd curl sox\
	libncurses5-dev libssl-dev libmysqlclient-dev mpg123 libxml2-dev libnewt-dev sqlite3\
	libsqlite3-dev pkg-config automake libtool autoconf git unixodbc-dev uuid uuid-dev\
	libasound2-dev libogg-dev libvorbis-dev libicu-dev libcurl4-openssl-dev libical-dev libneon27-dev libsrtp0-dev\
	libspandsp-dev sudo libmyodbc subversion libtool-bin python-dev\
	aptitude cron fail2ban net-tools vim wget \
	&& rm -rf /var/lib/apt/lists/*

RUN cd /usr/src \
	&& wget -O jansson.tar.gz https://github.com/akheron/jansson/archive/v2.7.tar.gz \
	&& tar xfz jansson.tar.gz \
	&& rm -f jansson.tar.gz \
	&& cd jansson-* \
	&& autoreconf -i \
	&& ./configure \
	&& make \
	&& make install \
	&& rm -r /usr/src/jansson*

RUN cd /usr/src \
	&& wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-15.7.3.tar.gz \
	&& tar xfz asterisk-15.7.3.tar.gz \
	&& rm -f asterisk-15.7.3.tar.gz \
	&& cd asterisk-* \
	&& contrib/scripts/get_mp3_source.sh \
	&& ./configure --with-resample --with-pjproject-bundled --with-jansson-bundled --with-ssl=ssl --with-srtp \
	&& make menuselect/menuselect menuselect-tree menuselect.makeopts \
	&& menuselect/menuselect --disable BUILD_NATIVE --enable app_confbridge --enable app_fax \
                             --enable app_macro --enable format_mp3 \
                             --enable BETTER_BACKTRACES --disable MOH-OPSOUND-WAV --enable MOH-OPSOUND-GSM \
	&& make \
	&& make install \
	&& make samples \
	&& make config \
	&& ldconfig \
	&& update-rc.d -f asterisk remove \
	&& rm -r /usr/src/asterisk*

RUN useradd -m asterisk \
	&& chown asterisk. /var/run/asterisk \
	&& chown -R asterisk. /etc/asterisk \
	&& chown -R asterisk. /var/lib/asterisk \
	&& chown -R asterisk. /var/log/asterisk \
	&& chown -R asterisk. /var/spool/asterisk \
	&& chown -R asterisk. /usr/lib/asterisk \
	&& rm -rf /var/www/html

RUN sed -i 's/^upload_max_filesize = 2M/upload_max_filesize = 120M/' /etc/php5/apache2/php.ini \
	&& sed -i 's/^memory_limit = 128M/memory_limit = 256M/' /etc/php5/apache2/php.ini \
	&& cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf_orig \
	&& sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf \
	&& sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

COPY ./config/odbcinst.ini /etc/odbcinst.ini
COPY ./config/odbc.ini /etc/odbc.ini

RUN cd /usr/src \
	&& wget http://mirror.freepbx.org/modules/packages/freepbx/freepbx-14.0-latest.tgz \
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
	git checkout tags/$BCG729_VERSION ; \
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
	make install && \
	cp etc/dongle.conf /etc/asterisk/ 

RUN apt-get install usb-modeswitch usb-modeswitch-data

RUN sed -i 's/^user		= mysql/user		= root/' /etc/mysql/my.cnf

COPY ./run /run
RUN chmod +x /run/*

RUN chown asterisk:asterisk -R /var/spool/asterisk

CMD /run/startup.sh

EXPOSE 80 3306 5060 5061 5160 5161 4569 10000-20000/udp

#recordings data
VOLUME [ "/var/spool/asterisk/monitor" ]
#database data
VOLUME [ "/var/lib/mysql" ]
#automatic backup
VOLUME [ "/backup" ]
