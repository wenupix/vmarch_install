#!/bin/bash
HDD_DST="/dev/sda"
MNT_DST="/mnt"
USR_DEF="wenupix"
CTRY_CODE="cl"

echo "==> Iniciando Configuracion de sistema Archlinux"
echo "==> Usando mirror '.$CTRY_CODE'"
mv /etc/pacman.d/mirrorlist /etc/pacman.d/bck_mirrorlist
echo "Server = http://mirror.ufro.cl/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist
echo "Server = http://mirror.archlinux.cl/\$repo/os/\$arch" >> /etc/pacman.d/mirrorlist

echo "==> Despejando '$MNT_DST'"
umount -R /mnt | true
rm -rf /mnt/* | true

# ---
echo "==> Verificando disco $HDD_DST"
# particiones
HDD_NPART=$( fdisk -l $HDD_DST | grep ^$HDD_DST | wc -l )
if [ $HDD_NPART -ne 0 ]; then
    echo "!! AVISO: disco usado."
    echo "  -> Limpiando"
    dd if=/dev/zero of=$HDD_DST bs=8M count=64 oflag=sync status=progress && sync
    #echo "!! Limipiar disco antes de continuar."
    #exit 10
fi

# valores en MB
HDD_BOOT_PARTSZ=512
HDD_SWAP_PARTSZ=1024
HDD_SIZEb=$( lsblk -blpn $HDD_DST | grep disk | awk '{ print $4 }' )
HDD_SIZEM=$( echo $(( $HDD_SIZEb / 1024 / 1024 )) )
HDD_ROOT_PARTSZ=$( echo $(( $HDD_SIZEM - $HDD_BOOT_PARTSZ - $HDD_SWAP_PARTSZ )) )

echo "==> Particionando disco"
parted -s -a optimal $HDD_DST unit MB mklabel msdos mkpart primary ext3 2 $HDD_BOOT_PARTSZ \
set 1 boot on \
mkpart primary ext4 $HDD_BOOT_PARTSZ $HDD_ROOT_PARTSZ \
mkpart primary linux-swap $HDD_ROOT_PARTSZ 100%
echo "==> Verificando tabla de particiones"
parted $HDD_DST print

echo "==> Formateando $HDD_DST\1 (boot)"
mkfs.ext3 "$HDD_DST"1
if [ $? -ne 0 ]; then echo "!! Error."; exit 9; fi
echo "==> Formateando $HDD_DST\2 (root)"
mkfs.ext4 "$HDD_DST"2
if [ $? -ne 0 ]; then echo "!! Error."; exit 9; fi
echo "==> Formateando $HDD_DST\3 (swap)"
mkswap "$HDD_DST"3
if [ $? -ne 0 ]; then echo "!! Error."; exit 9; fi
echo "==> Activando SWAP"
swapon "$HDD_DST"3
if [ $? -ne 0 ]; then echo "!! Error."; exit 9; fi

echo "==> Montando carpetas"
mount "$HDD_DST"2 $MNT_DST
if [ $? -ne 0 ]; then echo "!! Error."; exit 8; fi
mkdir -p $MNT_DST/boot
if [ $? -ne 0 ]; then echo "!! Error."; exit 8; fi
mount "$HDD_DST"1 $MNT_DST/boot
if [ $? -ne 0 ]; then echo "!! Error."; exit 8; fi

echo "==> Instalando paquetes"
pacstrap $MNT_DST base base-devel linux grub networkmanager 
#wget git vim openssh
echo "==> Post-configuracion"
echo "---> fstab"
genfstab -Up $MNT_DST > $MNT_DST/etc/fstab
echo "---> hostname"
echo "vm-archlinux" > $MNT_DST/etc/hostname
echo "---> locale"
echo "LANG=es_CL.UTF-8" > $MNT_DST/etc/locale.conf
echo "---> console locale"
echo "KEYMAP=es" > $MNT_DST/etc/vconsole.conf
echo "---> chroot: locale"
arch-chroot $MNT_DST sed -i 's/#es_CL.UTF-8/es_CL.UTF-8/' /etc/locale.gen
arch-chroot $MNT_DST locale-gen
echo "---> chroot: grub"
arch-chroot $MNT_DST grub-install $HDD_DST
sync
echo "---> chroot: initram"
arch-chroot $MNT_DST mkinitcpio -p linux
sync
echo "---> chroot: grub: configuracion"
arch-chroot $MNT_DST grub-mkconfig -o /boot/grub/grub.cfg
echo "---> chroot: misc"
arch-chroot $MNT_DST echo "root:root" | chpasswd
echo "---> chroot: NetworkManager: activar"
arch-chroot $MNT_DST systemctl enable NetworkManager
#
umount -R $MNT_DST
swapoff "$HDD_DST"3
