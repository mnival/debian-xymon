Docker debian-xymon
============

Configuration Docker with Debian Stable and packages :
    xymon
	xymon-client
	nginx-light
	fcgiwrap
	ssmtp
	supervisor

Quick Start
===========
    docker run -d -p 80:80 -p 1984:1984 -v /etc/xymon:/etc/xymon -v /var/lib/xymon:/var/lib/xymon --name xymon mnival/debian-xymon

Interfaces
===========

Ports
-------

* 80 -- Nginx (Web Interface)
* 1984 -- Xymon

Volumes
-------

* /etc/xymon -- all xymon configuration data
* /var/lib/xymon -- xymon data (monitoring state)

Maintainer
==========

Please submit all issues/suggestions/bugs via
https://github.com/mnival/debian-xymon
