FROM crazyquark/freepbx:15-base

# Run the install part of the image
RUN cd /usr/src/freepbx \
	&& chown mysql:mysql -R /var/lib/mysql/* \
	&& /etc/init.d/mysql start \
	&& ./start_asterisk start \
	&& sed -i 's/$process = new Process($command);/$process = new Process($command); $process->setTimeout(3600);/' installlib/installcommand.class.php \
	&& ./install -n \
	&& fwconsole chown \
	&& fwconsole ma upgradeall \
	&& fwconsole ma downloadinstall announcement backup bulkhandler ringgroups timeconditions ivr restapi cel \
	&& /etc/init.d/mysql stop \
	&& rm -rf /usr/src/freepbx*

CMD /run/startup.sh