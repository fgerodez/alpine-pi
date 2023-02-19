FROM alpine:latest

ARG USER_NAME
ARG USER_PUBLIC_KEY

RUN apk --no-cache add \
	linux-rpi \
	openrc \
	openssh \
	nftables \
	docker \
	wireguard-tools \
	doas \
	tzdata \
	raspberrypi-bootloader \
    chrony

RUN rc-update add docker \
	&& rc-update add sshd \
	&& rc-update add nftables \
    && rc-update add chronyd

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

# Disable dhcp dns servers
RUN mkdir -p /etc/udhcpc \
	&& echo 'RESOLV_CONF="no"' >> /etc/udhcpc/udhcpc.conf

# Trim down unused initramfs
RUN echo 'features=""' > /etc/mkinitfs/mkinitfs.conf

# Configure ssh
RUN sed -i "s/#Port 22/Port 8444/" /etc/ssh/sshd_config \
	&& sed -i "s/#StrictModes: no/StrictModes: yes/" /etc/ssh/sshd_config \
	&& sed -i "s/#LoginGraceTime 2m/LoginGraceTime 30/" /etc/ssh/sshd_config \
	&& sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config \
	&& sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config \
	&& sed -i -e "\$aAllowUsers: ${USER_NAME}" /etc/ssh/sshd_config

ADD interfaces /etc/network
ADD config.txt /boot
