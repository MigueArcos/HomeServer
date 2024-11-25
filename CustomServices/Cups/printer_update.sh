#!/bin/sh
/usr/bin/inotifywait -m -e close_write,moved_to,create /etc/cups | 
while read -r directory events filename; do
	if [ "$filename" = "printers.conf" ]; then
		rm -rf /services/AirPrint-*.service
		/airprint_generate.py -H localhost -p 631 -d /services
		cp /etc/cups/printers.conf /config/printers.conf
		rsync -avh /services/ /etc/avahi/services/
	fi
	if [ "$filename" = "cupsd.conf" ]; then
		cp /etc/cups/cupsd.conf /config/cupsd.conf
	fi
done
