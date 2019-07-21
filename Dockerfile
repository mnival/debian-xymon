FROM debian:stable-slim

LABEL maintainer="Michael Nival <docker@mn-home.fr>" \
	name="debian-xymon" \
	description="Debian Stable with the packages xymon nginx-light fcgiwrap supervisor ssmtp s-nail" \
	docker.cmd="printf "ssmtp.ssmtp.conf.mailhub=mail.example.com\nssmtp.ssmtp.conf.AuthUser=user\nssmtp.ssmtp.conf.AuthPass=password\nssmtp.ssmtp.conf.AuthMethod=LOGIN\nssmtp.ssmtp.conf.UseTLS=Yesssmtp.revaliases=local_account:outgoing_address:mailhub[;local_account:outgoing_address:mailhub]\n" > /tmp/env-file && docker run -d -p 80:80 -p 1984:1984 -v /etc/xymon:/etc/xymon -v /var/lib/xymon:/var/lib/xymon --env-file /tmp/env-file --hostname xymon --name xymon mnival/debian-xymon"

RUN printf "deb http://ftp.debian.org/debian/ stable main\ndeb http://ftp.debian.org/debian/ stable-updates main\ndeb http://security.debian.org/ stable/updates main\n" >> /etc/apt/sources.list.d/stable.list && \
	printf "deb http://ftp.debian.org/debian/ oldstable main\ndeb http://ftp.debian.org/debian/ oldstable-updates main\ndeb http://security.debian.org/ oldstable/updates main\n" >> /etc/apt/sources.list.d/oldstable.list && \
	cat /dev/null > /etc/apt/sources.list && \
	export DEBIAN_FRONTEND=noninteractive && \
	apt update && \
	apt -y --no-install-recommends full-upgrade && \
	apt install -y --no-install-recommends xymon nginx-light fcgiwrap supervisor ssmtp s-nail libperl5.28 && \
	update-alternatives --install /usr/bin/mail mail /usr/bin/s-nail 50 && \
	sed -i "s/^CLIENTHOSTNAME.*/CLIENTHOSTNAME=\"HOSTNAME\"/" /etc/default/xymon-client && \
	sed -i "s@^127.0.0.1.*@127.0.0.1\tHOSTNAME\t# bbd http://HOSTNAME/@" /etc/xymon/hosts.cfg && \
	cat /dev/null > /etc/ssmtp/ssmtp.conf && \
	cat /dev/null > /etc/ssmtp/revaliases && \
	echo "Europe/Paris" > /etc/timezone && \
	rm /etc/localtime && \
	dpkg-reconfigure tzdata && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/log/alternatives.log /var/log/dpkg.log /var/log/apt/ /var/cache/debconf/*-old

RUN mkdir /etc/nginx/sites-default-enabled /etc/nginx/sites-default-available && \
	awk '{if ($0 !~ "pass PHP scripts to FastCGI server") {print $0} else {printf "\tinclude /etc/nginx/sites-default-enabled/*.conf;\n%s\n", $0}}' /etc/nginx/sites-available/default > /etc/nginx/sites-available/default.tmp && \
	mv /etc/nginx/sites-available/default.tmp /etc/nginx/sites-available/default

RUN tar -C /etc/xymon -czf /root/xymon-config.tgz . && \
	tar -C /var/lib/xymon -czf /root/xymon-data.tgz .

RUN mkfifo /var/log/xymon/alert.log && \
	mkfifo /var/log/xymon/clientdata.log && \
	mkfifo /var/log/xymon/combostatus.log && \
	mkfifo /var/log/xymon/history.log && \
	mkfifo /var/log/xymon/hostdata.log && \
	mkfifo /var/log/xymon/notifications.log && \
	mkfifo /var/log/xymon/rrd-data.log && \
	mkfifo /var/log/xymon/rrd-status.log && \
	mkfifo /var/log/xymon/xymonclient.log && \
	mkfifo /var/log/xymon/xymond.log && \
	mkfifo /var/log/xymon/xymongen.log && \
	mkfifo /var/log/xymon/xymonlaunch.log && \
	mkfifo /var/log/xymon/xymonnet.log && \
	mkfifo /var/log/xymon/xymonnetagain.log && \
	chown xymon: /var/log/xymon/*.log

RUN rm /var/log/nginx/*.log && \
	mkfifo /var/log/nginx/access.log && \
	mkfifo /var/log/nginx/error.log && \
	chown www-data:adm /var/log/nginx/*.log

ADD start-xymon /usr/local/bin/
ADD start-nginx /usr/local/bin/
ADD conf-ssmtp /usr/local/bin/
ADD read-xymon-log /usr/local/bin/
ADD read-nginx-log /usr/local/bin/
ADD nginx-xymon.conf /etc/nginx/sites-default-available/xymon.conf

RUN ln -sr /etc/nginx/sites-default-available/xymon.conf /etc/nginx/sites-default-enabled/ && \
	ln -sr /usr/lib/xymon/cgi-bin /usr/lib/xymon/xymon-cgi && \
	ln -sr /usr/lib/xymon/cgi-secure /usr/lib/xymon/xymon-seccgi

ADD supervisor-xymon.conf /etc/supervisor/conf.d/xymon.conf
ADD supervisor-fastcgi.conf /etc/supervisor/conf.d/fastcgi.conf
ADD supervisor-nginx.conf /etc/supervisor/conf.d/nginx.conf

ADD event-supervisor/event-supervisor.sh /usr/local/bin/event-supervisor.sh
ADD event-supervisor/supervisor-eventlistener.conf /etc/supervisor/conf.d/eventlistener.conf
RUN sed -i 's@^\(logfile\)=[a-z|A-Z|/|\.]*@\1=/dev/null@' /etc/supervisor/supervisord.conf

EXPOSE 80 1984

VOLUME ["/etc/xymon", "/var/lib/xymon"]

ENTRYPOINT ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
