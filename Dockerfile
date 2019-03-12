FROM debian:stable

LABEL maintainer="Michael Nival <docker@mn-home.fr>" \
	name="debian-xymon" \
	description="Debian Stable with Xymon, nginx-light, fcgiwrap, ssmtp, supervisor" \
	docker.cmd="printf "SSMTP_mailhub=mail.example.com\nSSMTP_AuthUser=user\nSSMTP_AuthPass=password\nSSMTP_AuthMethod=LOGIN\nSSMTP_UseTLS=Yes\n" > /tmp/env-file && docker run -d -p 80:80 -p 1984:1984 -v /etc/xymon:/etc/xymon -v /var/lib/xymon:/var/lib/xymon --env-file /tmp/env-file --hostname xymon --name xymon mnival/debian-xymon"

RUN printf "deb http://ftp.debian.org/debian/ stable main\ndeb http://ftp.debian.org/debian/ stable-updates main\ndeb http://security.debian.org/ stable/updates main\n" >> /etc/apt/sources.list.d/stable.list && \
	cat /dev/null > /etc/apt/sources.list && \
	export DEBIAN_FRONTEND=noninteractive && \
	apt update && \
	apt -y --no-install-recommends full-upgrade && \
	apt install -y --no-install-recommends xymon nginx-light fcgiwrap supervisor && \
	echo "Europe/Paris" > /etc/timezone && \
	rm /etc/localtime && \
	dpkg-reconfigure tzdata && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/log/alternatives.log /var/log/dpkg.log /var/log/apt/ /var/cache/debconf/*-old

RUN mkdir /etc/nginx/sites-default-enabled /etc/nginx/sites-default-available && \
	awk '{if ($0 !~ "pass PHP scripts to FastCGI server") {print $0} else {printf "\tinclude /etc/nginx/sites-default-enabled/*.conf;\n%s\n", $0}}' /etc/nginx/sites-available/default > /etc/nginx/sites-available/default.tmp && \
	mv /etc/nginx/sites-available/default.tmp /etc/nginx/sites-available/default

RUN tar -C /etc/xymon -czf /root/xymon-config.tgz . && \
	tar -C /var/lib/xymon -czf /root/xymon-data.tgz .

ADD start-xymon /usr/local/bin/start-xymon
ADD nginx-xymon.conf /etc/nginx/sites-default-available/xymon.conf

RUN ln -sr /etc/nginx/sites-default-available/xymon.conf /etc/nginx/sites-default-enabled/

ADD supervisor-xymon.conf /etc/supervisor/conf.d/xymon.conf
ADD supervisor-fastcgi.conf /etc/supervisor/conf.d/fastcgi.conf
ADD supervisor-nginx.conf /etc/supervisor/conf.d/nginx.conf

ADD event-supervisor/event-supervisor.sh /usr/local/bin/event-supervisor.sh
ADD event-supervisor/supervisor-eventlistener.conf /etc/supervisor/conf.d/eventlistener.conf
RUN sed -i 's/^\(logfile.*\)/#\1/' /etc/supervisor/supervisord.conf

EXPOSE 80 1984

VOLUME ["/etc/xymon", "/var/lib/xymon"]

ENTRYPOINT ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
