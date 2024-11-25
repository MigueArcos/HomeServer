#!/usr/bin/env bash
echo "Usb event: $1 $2 $3 $4" >> /tmp/docker_usb.log
UpSeconds="$(cat /proc/uptime | grep -o '^[0-9]\+')" # The Upseconds are used because when the host is turning on, a lot of devices trigger this event resulting in errors, so this event only gets fired when the device is up for at least 60 seconds and the major number of the device is 189 (usb device)

if [ $3 -ne 189 ] || [ -z "$2" ] || [ $4 -eq 0 ] || [ $UpSeconds -lt 60 ]
        then
        exit 1;
fi

if [ "$1" == "added" ]
        then
        echo "Starting containers" >> /tmp/docker_usb.log
        ComposeResult=$(/usr/bin/docker compose -f /path/to/compose/docker-compose.yml up -d 2>&1) ## Run docker-compose in case a device is turning on and the containers using that device are dead.
        echo "ComposeResult = $ComposeResult" >> /tmp/docker_usb.log 
fi

if [ ! -z "$(docker ps -qf name=cups_service)" ] # cups_service is the name of the container I want to add the devices
        then
        if [ "$1" == "added" ]
                then
                # docker exec cups_service mkdir -p $2
                docker exec cups_service mknod $2 c $3 $4
                docker exec cups_service chmod -R 777 $2
                echo "Adding $2 to docker (cups_service)" >> /tmp/docker_usb.log
        else
                docker exec cups_service rm $2
                echo "Removing $2 from docker (cups_service)" >> /tmp/docker_usb.log
        fi
fi

if [ ! -z "$(docker ps -qf name=sane_scanner_service)" ]
       then
       if [ "$1" == "added" ]
               then
               docker exec -u 0 sane_scanner_service mknod $2 c $3 $4
               docker exec -u 0 sane_scanner_service chmod -R 777 $2
               echo "Adding $2 to docker (sane_scanner_service)" >> /tmp/docker_usb.log
       else
               docker exec -u 0 sane_scanner_service rm $2
               echo "Removing $2 from docker (sane_scanner_service)" >> /tmp/docker_usb.log
       fi
fi
