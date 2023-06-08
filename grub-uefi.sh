#!/bin/bash

VERSION=mantic

function InitBasicSystem(){
	mkdir chroot
	debootstrap mantic chroot http://mirrors.aliyun.com/ubuntu
}

function CopyBasicConfigFiles(){
	cp /etc/hosts chroot/etc/hosts
	cp /etc/resolv.conf chroot/etc/resolv.conf
	cat > chroot/etc/apt/sources.list << EOF
# UPDATE APT SOURCES
deb https://mirrors.aliyun.com/ubuntu/ ${VERSION} main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ ${VERSION} main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ ${VERSION}-updates main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ ${VERSION}-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ ${VERSION}-security main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ ${VERSION}-security main restricted universe multiverse
# UPDATE APT SOURCES DONE
EOF

}

function BindMountPoints(){
	mount --bind /dev chroot/dev
	chroot chroot mount none -t proc /proc
	chroot chroot mount none -t sysfs /sys
	chroot chroot mount none -t devpts /dev/pts
}

function SetRootPassword(){
	yes 123456 | chroot chroot passwd
}

function InstallLiveCDBasicPackages(){
	chroot chroot apt update
	chroot chroot apt-get install --yes dbus
	chroot chroot dbus-uuidgen > /var/lib/dbus/machine-id

	chroot chroot apt-get install -y ubuntu-standard casper
	chroot chroot apt-get install --yes discover laptop-detect os-prober
	chroot chroot apt-get install --yes linux-image-generic 
}

function InstallLiveCDPackages(){
	#remove Grub 2
	chroot chroot apt purge -y grub-pc grub-pc-bin
	#install Grub 2 for UEFI Systems
	chroot chroot apt install -y grub-efi-amd64-signed 
	#install network support
	chroot chroot apt install -y dhcpcd5 net-tools network-manager
	#install build Env
	chroot chroot apt install -y build-essential automake autoconf gawk m4 apt-build bison dialog dpkg-dev
	#install debootstrap
	chroot chroot apt install -y debootstrap
	#install livecd
	chroot chroot apt install -y squashfs-tools mtools xorriso genisoimage
	#install Desktop
	chroot chroot apt install -y gparted ubuntu-desktop
	#install VM Drivers
	chroot chroot apt install -y open-vm-tools virtualbox-dkms
	#install openssh
	chroot chroot apt install -y openssh-server openssh-client
	#install vcs
	chroot chroot apt install -y git subversion mercurial
	install apt-mirror
	chroot chroot apt install -y apt-mirror
	#Do Some Manual Configurations
	chroot chroot
}

function RemoveTemporaryFiles(){
	chroot chroot rm /var/lib/dbus/machine-id
	chroot chroot apt-get clean
	chroot chroot rm -rf /tmp/*
	chroot chroot rm /etc/resolv.conf
}

function UnbindMountPoints(){
	chroot chroot umount /proc
	chroot chroot umount /sys
	chroot chroot umount /dev/pts
	umount chroot/dev
}

function CreateLiveCDStructures(){
	mkdir -p image/{casper,install}

	cp chroot/boot/vmlinuz-6.2.*-generic image/casper/vmlinuz
	cp chroot/boot/initrd.img-6.2.*-generic image/casper/initrd.lz

	mkdir -p image/boot/grub

	cat > image/boot/grub/grub.cfg << EOF
	insmod efi_gop
	insmod efi_uga
	font=unicode
	insmod part_msdos
	insmod ext2
	set root=(cd0,gpt3)

	if loadfont \$font ; then
	  set gfxmode=auto
	  insmod gfxterm
	  set locale_dir=$prefix/locale
	  set lang=en_US
	  insmod gettext
	  set gfxmode=auto;
	  set gfxpayload=keep;
	fi
	terminal_output gfxterm

	fi
	### END /etc/grub.d/00_header ###

	### BEGIN /etc/grub.d/05_debian_theme ###
	set menu_color_normal=white/black
	set menu_color_highlight=black/light-gray
	#set_background_image "images/tile.png";

	set menu_color_normal=white/black
	set menu_color_highlight=black/light-gray
	if background_color 0,0,0; then
	  clear
	fi
	### END /etc/grub.d/05_debian_theme ###


	menuentry 'Try KSLinux Live CD' --class ubuntu --class gnu-linux --class gnu --class os {
		insmod gzio
		if [ x\$grub_platform = xxen ]; then insmod xzio; insmod lzopio; fi
		linux	/casper/vmlinuz file=/cdrom/preseed/ubuntu.seed boot=casper quiet splash
		initrd	/casper/initrd.lz
	}

	menuentry 'Check CD' --class ubuntu --class gnu-linux --class gnu --class os {
		insmod gzio
		if [ x\$grub_platform = xxen ]; then insmod xzio; insmod lzopio; fi
		linux	/casper/vmlinuz boot=casper integrity-check quiet splash
		initrd	/casper/initrd.lz
	}
EOF

	sudo chroot chroot dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee image/casper/filesystem.manifest
	sudo cp -v image/casper/filesystem.manifest image/casper/filesystem.manifest-desktop
	REMOVE='ubiquity ubiquity-frontend-gtk ubiquity-frontend-kde casper lupin-casper live-initramfs user-setup discover1 xresprobe os-prober libdebian-installer4'
	for i in $REMOVE 
	do
			sudo sed -i "/${i}/d" image/casper/filesystem.manifest-desktop
	done

	mksquashfs chroot image/casper/filesystem.squashfs -e boot
	printf $(sudo du -sx --block-size=1 chroot | cut -f1) > image/casper/filesystem.size

	cat > image/README.diskdefines <<EOF
	#define DISKNAME  KSLinux 23.10
	#define TYPE  binary
	#define TYPEbinary  1
	#define ARCH  amd64
	#define ARCHamd64  1
	#define DISKNUM  1
	#define DISKNUM1  1
	#define TOTALNUM  0
	#define TOTALNUM0  1
EOF

	touch image/ubuntu

	mkdir image/.disk
	cd image/.disk
	touch base_installable
	echo "full_cd/single" > cd_type
	echo "KSLinux Build-Env 23.10" > info  # Update version number to match your OS version
	echo "https://www.ksyuki.com/" > release_notes_url
	cd ../..

	(cd image && find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > md5sum.txt)

}

function CreateLiveCDISO(){
	cd image
	#sudo mkisofs -r -V "$IMAGE_NAME" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ../ubuntu-remix.iso .
	grub-mkrescue -o ../live.iso .
	cd ..
}

function Main(){
	InitBasicSystem
	CopyBasicConfigFiles
	BindMountPoints
	SetRootPassword
	InstallLiveCDBasicPackages
	InstallLiveCDPackages
	RemoveTemporaryFiles
	UnbindMountPoints
	CreateLiveCDStructures
	CreateLiveCDISO
}

Main
