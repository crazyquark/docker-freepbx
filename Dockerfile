FROM crazyquark/freepbx:15-base

# Run the install part of the image
RUN cd /usr/src/freepbx \
	&& chown mysql:mysql -R /var/lib/mysql/* \
	&& /etc/init.d/mysql start \
	&& ./start_asterisk start \
	&& ./install -n \
	&& fwconsole chown \
	# && fwconsole ma upgradeall \
	# && fwconsole ma downloadinstall announcement backup bulkhandler ringgroups timeconditions ivr restapi cel \
	&& /etc/init.d/mysql stop \
	&& rm -rf /usr/src/freepbx*

# #recordings data
VOLUME [ "/var/spool/asterisk/monitor" ]
# #database data
VOLUME [ "/var/lib/mysql" ]
# #automatic backup
VOLUME [ "/backup" ]
# #config
VOLUME [ "/etc/asterisk" ]

CMD /run/startup.sh
