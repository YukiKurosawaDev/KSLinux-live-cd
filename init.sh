#! /bin/bash
mkdir -p /opt/ksl

VERSION=noble

cat > /etc/apt/sources.list << EOF
# UPDATE APT SOURCES
deb http://mirrors.aliyun.com/ubuntu/ ${VERSION} main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ ${VERSION} main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ ${VERSION}-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ ${VERSION}-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ ${VERSION}-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ ${VERSION}-security main restricted universe multiverse
# UPDATE APT SOURCES DONE
EOF

apt update
apt install -y debootstrap xorriso grub-common ca-certificates sudo squashfs-tools mtools genisoimage grub-efi-amd64-signed 
