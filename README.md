# Running this repo
To run this repo just create a .env file in the root path with the following content:
```
HOST_IP=192.168.1.64
SHARED_DISK_MOUNT_POINT=/media/shared-hdd
```
Then after the environment variables are set just run ```docker-compose up -d```.

# Udev Rules in Docker
By default, serial devices are mounted so that only root users can access the device. We need to add a Udev rule to make them readable by non-root users. Udev is the device manager for the Linux kernel and handles what happens when something like a serial device is plugged in. For security reasons, most Docker containers execute their processes under a non-root user. This means we need to change some permissions to give that user access to the serial device. We can do this by defining Udev rules.

We must use Udev rules in order to be able to use devices (usb or something else) inside the Docker containers.

With Udev rules we can use also a SymLink to define a static name for a device, since each time a device is disconnected and then reconnected it changes its identifier so we can not use the current device identifier, it's better to use a static name.

For example the following udev rule would make that each time a device is connected it always has the desired name, so it can be found under ***/dev/{customDeviceName}***
```bash
SUBSYSTEM=="usb", ATTRS{idVendor}=="{deviceIdVendor}", ATTR{idProduct}=="{deviceIdProduct}", MODE="0666", SYMLINK+="{customDeviceName}"
```
Where ***deviceIdVendor*** and ***deviceIdProduct*** can be found using the command **lsusb** and ***customDeviceName*** is the desired name for the device.

This is a sample output line of the command **lsusb**
```bash
Bus 001 Device 002: ID {deviceIdVendor}:{deviceIdProduct} Brother Industries, Ltd DCP-T310
```

Udev rules are processed in lexical order, so the number does care. It's common the location of Udev rules to be ***/etc/udev/rules.d***.

Reference:
> https://unix.stackexchange.com/questions/66901/how-to-bind-usb-device-under-a-static-name#answer-183492
# How to use cgroup rules to access devices properly in Docker containers?
By default when a container is started it can communicate with the devices provided when it was created, but if a device is disconnected and connected again (or turned off) the container lost connection with that device, so it's necessary to add cgroup rules to handle devices reconnection.

If you would like to dynamically access USB devices which can be plugged in while the Docker container is already running, for example access a just attached usb webcam at ***/dev/bus/usb/001/002***, you can add a cgroup rule when starting the container. This option does not need a --privileged container and only allows access to specific types of hardware.

The steps to create a cgroup rule are the following:

## Step 1
Find the device(s) major, to do so run the following command:
```bash
ls -la /dev/bus/usb/001/002 # Where /dev/bus/usb/001/002 can be found with lsusb and it's the identifier of the usb device
```
The ouput of the command is something like this:
```bash
crw-rw-rw- 1 root lp 189, 1 feb 19 08:08 /dev/bus/usb/001/002 # In this case 189 is the major number for usb devices
```


## Step 2
Now the idea is to add a script which would be run every time your USB device is plugged in or plugged out. Some explanation about custom rules [here](https://linuxconfig.org/tutorial-on-how-to-write-basic-udev-rules-in-linux) and [here](https://stackoverflow.com/questions/13699241/passing-arguments-to-shell-script-from-udev-rules-file/14982520#14982520). On ubuntu, you should create file ```/etc/udev/rules.d/99-docker-usb.rules``` as superuser (sudo).
The content of the Udev rule is something like this:
```bash
ACTION=="add", SUBSYSTEM=="usb", RUN+="/usr/local/bin/docker_usb.sh 'added' '%E{DEVNAME}' '%M' '%m'"
ACTION=="remove", SUBSYSTEM=="usb", RUN+="/usr/local/bin/docker_usb.sh 'removed' '%E{DEVNAME}' '%M' '%m'"
```
This file adds new entry to your rules, basically saying: Every time usb device is plugged in (-add) or plugged out (-remove) run the provided script and pass some parameters. If you want to be more specific, you can use ```udevadm info  --name=<device name>``` to find other parameters by which you can filter devices or use a specific Udev rule for each device like described above. You can test the rules as suggested [here](https://superuser.com/questions/677106/how-to-check-if-a-udev-rule-fired/1530226#1530226). To apply those rules:
```bash
user@~$ sudo udevadm trigger
user@~$ sudo udevadm control --reload 
```
The content of the script ***docker_usb.sh*** can be found in this repo under ***Scripts/docker_usb.sh***.

Don't forget to make the script executable by running ```sudo chmod +x /usr/local/bin/docker_usb.sh```

## Step 3
Add rules when starting the Docker container.
- Add a ```--device-cgroup-rule='c {majorNumber}:* rmw'``` rule for every type of device you want access to
- Add access to Udev information so Docker containers can get more info on your usb devices with ```-v /run/udev:/run/udev:ro```
- Map the /dev volume to your Docker container with ```-v /dev:/dev``` or ```-v /dev/bus/usb:/dev/bus/usb```

References: 
> https://stackoverflow.com/questions/24225647/docker-a-way-to-give-access-to-a-host-usb-or-serial-device#answer-66427245
> 
> https://docs.docker.com/engine/reference/commandline/create/#dealing-with-dynamically-created-devices---device-cgroup-rule

# Install Canon Scanner as a container
The most important part here is to make the scanner work locally on the Host machine using the **pixma** backend.
\
The backends are a series of libraries used by sane to work with a wide range of scanners from multiple brands, apparently ***escl*** works pretty well with my **Pixma** (G-2060) scanner but I was unable to share the scanner on the network using this backend.
So, in order to make this scanner work on the container the first is going to be update the Host Sane binaries.
To do so, run the following commands:
```bash
sudo add-apt-repository ppa:sane-project/sane-git
sudo apt-get update
sudo apt install libsane libsane1 libsane-common sane-utils
```
Now edit **/etc/sane.d/dll.conf** to look like this in the host machine.
```bash
# This configuration allows us to use the pixma backend and disable all the other unnecesary backends (this way the scanner detection is faster)
net
# escl
pixma
# delete or comment all the other backends
```
And edit **/etc/sane.d/dll.conf** to look like this in the host machine.
```bash
# This configuration is to share the scanner in the host network and the internal docker networks
192.168.1.0/24
172.17.0.0/16
172.16.0.0/12
```
Finally, in the host machine run the following commands (Removing **ippusbxd** is very important otherwise the **pixma** backend does not work):
```bash
sudo apt remove ippusbxd
sudo usermod -a -G dialout $USER
sudo shutdown -r now
```
And this way when running the container we are going to connect to the scanner attached on the host machine, to do so, add the following environment variable when running the **sbs20/scanservjs:latest** container: **SANED_NET_HOSTS=${HOST_IP:-192.168.1.64}**.
\
This way the **/etc/sane.d/net.conf** in the container has an entry with the ip address of the host machine in order to reach the network scanner.
Since we are not going to use more backends in the container we can delete all the other backends except the **net** backend.
In this repo I included this configuration under **./Configurations/sane_dll.conf**, we can simply use it by attching this volume to the container to avoid manually editing files: **./Configurations/sane_dll.conf:/etc/sane.d/dll.conf**
