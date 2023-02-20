FROM alpine:latest

ARG USER_NAME
ARG USER_PUBLIC_KEY

RUN apk --no-cache add \
	linux-rpi \
	openrc \
	busybox-openrc \
	openssh \
	nftables \
	docker \
	wireguard-tools \
	doas \
	tzdata \
	raspberrypi-bootloader \
	chrony 

# Configure keyboard
RUN apk add --no-cache kbd-bkeymaps \
	&& mkdir -p /etc/keymap \
	&& cp /usr/share/bkeymaps/fr/fr-azerty.bmap.gz /etc/keymap/fr-azerty.bmap.gz \
	&& echo "KEYMAP=/etc/keymap/fr-azerty.bmap.gz" >> /etc/conf.d/loadkmap \
	&& apk del --no-cache kbd-bkeymaps

RUN rc-update add modules boot \
	&& rc-update add loadkmap boot \
	&& rc-update add networking boot \
	&& rc-update add sysctl boot \
    && rc-update add sysfs boot \
	&& rc-update add hostname boot \
	&& rc-update add bootmisc boot \
	&& rc-update add syslog boot \
	&& rc-update add localmount boot \
    && rc-update add fsck boot \
    && rc-update add devfs \
	&& rc-update add dmesg \
	&& rc-update add sysfs \
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
	&& chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/.ssh \
	&& chmod 700 /home/${USER_NAME}/.ssh/authorized_keys \
	&& echo ${USER_PUBLIC_KEY} >> /home/${USER_NAME}/.ssh/authorized_keys

# Allow wheel users to doas root
RUN echo "permit persist :wheel" >> /etc/doas.d/doas.conf

# Load necessary modules
RUN echo "wireguard" >> /etc/modules
RUN echo "cdc_ether" >> /etc/modules
RUN echo "cdc_subset" >> /etc/modules

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
RUN echo "/dev/mmcblk0p1  /boot           vfat    defaults          0       2" > /etc/fstab
RUN echo "/dev/mmcblk0p2  /               ext4    defaults,noatime  0       1" >> /etc/fstab
RUN echo "/dev/sda1       /media/data     ext4    defaults,noatime  0       3" >> /etc/fstab

ADD interfaces /etc/network
ADD config.txt /boot
