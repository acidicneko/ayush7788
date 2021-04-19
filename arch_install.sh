echo Welcome to Claw\'s Arch Install Script

if [[ $# -eq 0 ]] ; then
	echo Checking network connectivity...
	ping 5 archlinux.org

	if [[ $? -eq 0 ]] ; then
		echo Please connect to network
		exit 1
	fi

	echo Review partitions...
	lsblk

	read -p "Choose a root partition (prefix it with /dev/): " ROOT

	read -p "Choose a home partition (prefix it with /dev/): " HOME

	read -p "Choose a swap partition (prefix it with /dev/): " SWAP

	read -p "Choose a EFI System Partition(prefix it with /dev/): " ESP

	read -p "Enter a root password: " ROOTPASS
	read -p "Enter your username: " USRNAME
	read -p "Enter password for $USRNAME: " PASSWORD
	
	read -p "Enter your timezone(eg. Asia/Kolkata): " TZONE
	touch config.sh
	echo "ROOTPASS=$ROOTPASS" >> config.sh
	echo "USRNAME=$USRNAME" >> config.sh
	echo "PASSWORD=$PASSWORD" >> config.sh
	echo "TZONE=$TZONE" >> config.sh
	echo Formatting partitions...
	mkfs.ext4 $ROOT
	mkfs.ext4 $HOME
	mkswap $SWAP

	echo Mounting patitions...
	mount $ROOT /mnt
	mkdir /mnt/home
	mkdir -p /mnt/boot/efi

	mount $HOME /mnt/home
	mount $ESP /mnt/boot/efi
	swapon $SWAP

	echo Installing base system to $ROOT...
	pacstrap /mnt base base-devel linux linux-firmware vim grub os-prober ntfs-3g sudo efibootmgr NetworkManager

	echo Generating fstab...
	genfstab -U /mnt >> /mnt/etc/fstab

	cp arch-install.sh /mnt/arch-install.sh
	cp config.sh /mnt/config.sh
	
	echo Changing root to /mnt...
	arch-chroot /mnt ./arch-install.sh chroot
fi

if [[ "$1" = "chroot" ]] ; then
	. ./config.sh
	echo Configuring Time Zone...
	ln -sf /usr/share/zoneinfo/$TZONE /etc/localtime
	hwclock --systohc

	echo Localization...
	echo LANG=en_US.UTF-8 >> /etc/locale.conf
	echo en_US.UTF-8 UTF-8 >> /etc/locale.gen

	locale-gen

	echo Configuring host...
	echo $HOSTNAME >> /etc/hostname
	echo "127.0.0.1	localhost" >> /etc/hosts
	echo "::1" >> /etc/hosts
	echo "127.0.1.1	$HOSTNAME.localdomain	$HOSTNAME" >> /etc/hosts
	
	echo Configuring root user password...
	echo -e "$ROOTPASS\n$ROOTPASS" | passwd
	
	
	echo Adding user $USRNAME...
	useradd -m -g users -G wheel -s /bin/bash $USRNAME
	
	echo -e "$PASSWORD\n$PASSWORD" | passwd $USRNAME
	
	grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Arch Linux"
	grub-mkconfig -o /boot/grub/grub.cfg
	
	echo Configuring additional settings...
	systemctl enable sudo
	systemctl enable NetworkManager
	
	umount -R /mnt
	echo Arch Linux installed! Please reboot...
fi