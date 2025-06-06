#!/bin/bash

VERSION=noble
MIRROR=https://mirrors.aliyun.com/ubuntu/

set -e

function DownloadThirdPartyOrMyPackages(){
	# Download base_file package from my repo
	if [ ! -f base-files_99kslinux24.04_amd64.deb ]; then
		echo "Please download and compile base_file package from my repo:"
		echo "https://github.com/Yuki-Kurosawa/KSLinux_base-files"
		echo "Then place it in the same directory as this script."
		exit 1
	fi

	# Download code package from microsoft
	if [ ! -f code_amd64.deb ]; then
		curl -L -o code_amd64.deb 'https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64'
	fi

	# Download google-chrome from google
	if [ ! -f chrome_amd64.deb ];then
		curl -L -o chrome_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
	fi

}

function CreateFolders(){
	mkdir chroot
	mkdir image
	mkdir iso
	mkdir -p chroot{/usr/share/man,/usr/share/doc,/usr/share/info,/var/lib/apt/lists,/var/cache/apt}
}

function MountTmpFolders(){
	mount -t tmpfs tmpfs chroot/usr/share/man
	mount -t tmpfs tmpfs chroot/usr/share/doc
	mount -t tmpfs tmpfs chroot/usr/share/info
	mount -t tmpfs tmpfs chroot/var/lib/apt/lists
	mount -t tmpfs tmpfs chroot/var/cache/apt
}

function UnmountTmpFolders(){
	umount chroot/usr/share/man
	umount chroot/usr/share/doc
	umount chroot/usr/share/info
	umount chroot/var/lib/apt/lists
	umount chroot/var/cache/apt
}

function InitBasicSystem(){
	debootstrap ${VERSION} chroot http://mirrors.aliyun.com/ubuntu
}

function CopyBasicConfigFiles(){
	cp /etc/hosts chroot/etc/hosts
	cp /etc/resolv.conf chroot/etc/resolv.conf
	cat > chroot/etc/apt/sources.list << EOF
# UPDATE APT SOURCES
deb ${MIRROR} ${VERSION} main restricted universe multiverse
deb-src ${MIRROR} ${VERSION} main restricted universe multiverse
deb ${MIRROR} ${VERSION}-updates main restricted universe multiverse
deb-src ${MIRROR} ${VERSION}-updates main restricted universe multiverse
deb ${MIRROR} ${VERSION}-security main restricted universe multiverse
deb-src ${MIRROR} ${VERSION}-security main restricted universe multiverse
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
	chroot chroot apt install -y dbus
	chroot chroot dbus-uuidgen > /var/lib/dbus/machine-id

	chroot chroot apt install -y ubuntu-standard casper
	chroot chroot apt install -y discover laptop-detect os-prober
	chroot chroot apt install -y linux-image-generic linux-headers-generic
}

function InstallLiveCDPackages(){
	#remove Grub 2
	chroot chroot apt purge -y grub-pc grub-pc-bin
	#install Grub 2 for UEFI Systems
	chroot chroot apt install -y grub-efi-amd64-signed 
	#install network support
	chroot chroot apt install -y dhcpcd5 net-tools network-manager
	#install build Env
	chroot chroot apt install -y build-essential automake autoconf gawk m4 bison dialog dpkg-dev
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
	#install kernel build dependencies
	chroot chroot apt install flex bison libelf-dev libssl-dev curl build-essential git libxml2-utils cpio -y

	#install third-party and my packages
	cp -Rv *.deb chroot/
	cat > chroot/install.sh << EOF
dpkg -i base-files_99kslinux24.04_amd64.deb
dpkg -i code_amd64.deb
dpkg -i chrome_amd64.deb
EOF

	chmod a+x chroot/install.sh

	chroot chroot /install.sh
	rm chroot/install.sh
	rm chroot/*.deb

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

	cp chroot/boot/vmlinuz-6.8.*-generic image/casper/vmlinuz
	cp chroot/boot/initrd.img-6.8.*-generic image/casper/initrd.lz

	mkdir -p image/boot/grub

	cat > image/boot/grub/grub.cfg << EOF
	insmod efi_gop
	insmod efi_uga
	font=unicode
	insmod part_msdos
	insmod ext2
	search --set=root --file /casper/filesystem.squashfs

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
	#define DISKNAME  KSLinux 24.04
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
	echo "KSLinux Build-Env 24.04" > info  # Update version number to match your OS version
	echo "https://www.ksyuki.com/" > release_notes_url
	cd ../..

	(cd image && find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > md5sum.txt)

}

function CreateLiveCDISO(){
	cd image
	#sudo mkisofs -r -V "$IMAGE_NAME" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ../ubuntu-remix.iso .
	grub-mkrescue -o ../iso/live.iso .
	cd ..
	rm -rf image
	cp iso/live.iso ./
	rm -rf iso
}

function Cleanup(){
	rm -rf chroot
}

function Main(){
	DownloadThirdPartyOrMyPackages
	CreateFolders
	MountTmpFolders
	InitBasicSystem
	CopyBasicConfigFiles
	BindMountPoints
	SetRootPassword
	InstallLiveCDBasicPackages
	InstallLiveCDPackages
	RemoveTemporaryFiles
	UnmountTmpFolders
	UnbindMountPoints
	CreateLiveCDStructures
	CreateLiveCDISO
	Cleanup
}

Main
