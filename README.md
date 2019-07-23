# FreePBX on Docker (ARMv7)

FreePBX container image for running a complete Asterisk server.

With this container you can create a telephony system in your office or house with integration among various office branches and integration to external VOIP providers with features such as call recording and IVR (interactive voice response) Menus.

This image adapts the source image for ARMv7, branches 14-armhf, 15-armhf.
Definitely not for production.

### Image includes

 * Asterisk 15(14-armhf branch)/16(15-armhf branch)
 * FreePBX 14/15
 * Automatic backup script


### Run FreePBX image

docker-compose.yml
```
version: '3.3'
services:
  freepbx:
    image: crazyquark/freepbx:14-armhf
    network_mode: host
    restart: always
    volumes:
      - freepbx-backup:/backup
      - freepbx-recordings:/var/spool/asterisk/monitor

volumes:
  freepbx-backup:
  freepbx-recordings:
```

* Run ```docker-compose up -d```

* Open admin panel at http://localhost/

### Sample host preparation

* Install Ubuntu 18.04

* Install Docker + Docker Compose

* Configure network

  * edit /etc/netplan/50-cloud-init.yaml

```
network:
    ethernets:
        eno1:
            addresses:
               - 10.1.2.5/22
               - 10.223.49.234/29
            nameservers:
               addresses: [10.1.1.254,8.8.8.8]
            gateway4: 10.1.1.254
            routes:
               - to: 10.128.0.0/9
                 via: 10.223.49.233
    version: 2
```

  * run ```netplan apply```

  * In this example suppose you have a VOIP provider in another network (10.223.x.x) connected to the Asterisk host. You can skip routes and the secondary address if not needed

  * Run this container

  

