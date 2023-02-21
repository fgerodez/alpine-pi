FROM alpine:latest

ARG USER_NAME
ARG USER_PUBLIC_KEY

RUN apk --no-cache add \
	linux-rpi \
	openrc \
	busybox-openrc \
    mdevd-openrc \
	openssh \
	nftables \
	docker \
	wireguard-tools \
	doas \
	tzdata \
	raspberrypi-bootloader \
	chrony \
	e2fsprogs \
    dosfstools

# Configure keyboard
RUN apk add --no-cache kbd-bkeymaps \
	&& mkdir -p /etc/keymap \
	&& cp /usr/share/bkeymaps/fr/fr-azerty.bmap.gz /etc/keymap/fr-azerty.bmap.gz \
	&& echo "KEYMAP=/etc/keymap/fr-azerty.bmap.gz" >> /etc/conf.d/loadkmap \
	&& apk del --no-cache kbd-bkeymaps

RUN rc-update add loadkmap \
	&& rc-update add syslog \
    && rc-update add devfs \
	&& rc-update add swclock \
	&& rc-update add modules  \
	&& rc-update add networking \
	&& rc-update add docker \
	&& rc-update add sshd \
	&& rc-update add nftables \
	&& rc-update add chronyd \
	&& rc-update add mount-ro shutdown \
	&& rc-update add killprocs shutdown \
	&& rc-update add savecache shutdown 

# Create the main user
RUN adduser -D -g $USER_NAME $USER_NAME \
	&& adduser $USER_NAME wheel \
	&& mkdir /home/${USER_NAME}/.ssh \
	&& touch /home/${USER_NAME}/.ssh/authorized_keys \
	&& chmod 700 /home/${USER_NAME}/.ssh/authorized_keys \
	&& echo ${USER_PUBLIC_KEY} >> /home/${USER_NAME}/.ssh/authorized_keys \
	&& chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/.ssh
	&& echo "${USER_NAME}:*" | chpasswd -e

# Allow wheel users to doas
RUN echo "permit persist :wheel" >> /etc/doas.d/doas.conf

# Load necessary modules
RUN echo "wireguard" >> /etc/modules \
	&& echo "cdc_ether" >> /etc/modules \
	&& echo "cdc_subset" >> /etc/modules

# Disable dhcp dns servers
RUN mkdir -p /etc/udhcpc \
	&& echo 'RESOLV_CONF="no"' >> /etc/udhcpc/udhcpc.conf

# Trim down unused initramfs
RUN echo 'features=""' > /etc/mkinitfs/mkinitfs.conf

# Configure ssh
RUN sed -i "s/#Port 22/Port 8444/" /etc/ssh/sshd_config \
	&& sed -i "s/#StrictModes no/StrictModes yes/" /etc/ssh/sshd_config \
	&& sed -i "s/#LoginGraceTime 2m/LoginGraceTime 30/" /etc/ssh/sshd_config \
	&& sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config \
	&& sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config \
	&& sed -i -e "\$aAllowUsers ${USER_NAME}" /etc/ssh/sshd_config

# Setup fstab
RUN echo "/dev/mmcblk0p1  /boot           vfat    defaults                 0       2" > /etc/fstab
RUN echo "/dev/mmcblk0p2  /               ext4    defaults,noatime         0       1" >> /etc/fstab
RUN echo "/dev/sda1       /media/data     ext4    defaults,noatime,nofail  0       3" >> /etc/fstab

ADD config/nftables.nft /etc/
ADD config/interfaces /etc/network
ADD config/config.txt /boot

RUN mkdir -p /var/run/openrc \
	&& touch /var/run/openrc/shutdowntime \
	&& /lib/rc/sbin/swclock --save
