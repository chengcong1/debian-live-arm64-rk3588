# Rock 5B (RK3588) + Armbian kernel 6.18 (#current branch) + Debian trixie + KDE Plasma
#
#   * kernel/dtb/headers come from the Armbian apt repository
#     (linux-image|linux-dtb|linux-headers-current-rockchip64 -> 6.18.x)
#   * the userspace/desktop is plain Debian trixie (Plasma 6 from trixie itself,
#     no panfork/rockchip-multimedia PPA is required any more, kernel 6.18
#     ships panthor and trixie ships a matching Mesa)
#   * GRUB loads the board device tree (see grub-dtb.patch / 10_linux),
#     so the ISO boots on a Rock 5B running UEFI firmware
#   * firmware comes exclusively from armbian-firmware. LB_FIRMWARE_CHROOT
#     defaults to 'true', which makes live-build add *every* Debian firmware-*
#     package found in Contents-*.gz to the chroot; armbian-firmware declares
#     "Provides/Conflicts: linux-firmware, firmware-brcm80211, firmware-ralink,
#     firmware-samsung, firmware-realtek", so that combination is unsatisfiable
#     ("held broken packages"). Hence --firmware-chroot false below. If you
#     prefer Debian's own firmware packages, drop armbian-firmware from
#     additional-packages.trixie and set this back to true.

LB_IMAGE_NAME="debian-trixie-kde-rock5b-live" lb config \
	--architecture arm64 \
	--archive-areas 'contrib main non-free non-free-firmware' \
	--parent-archive-areas 'contrib main non-free non-free-firmware' \
	--debian-installer-distribution trixie \
	--distribution trixie \
	--distribution-chroot trixie \
	--distribution-binary trixie \
	--bootloaders grub-efi \
	--compression xz \
	--firmware-chroot false \
	--bootappend-live "boot=live components quiet splash console=ttyS2,1500000 console=tty0" \
	--keyring-packages "debian-archive-keyring ca-certificates fontconfig-config initramfs-tools" \
	--linux-packages "linux-image linux-dtb linux-headers" \
	--linux-flavours "current-rockchip64" \
	--parent-mirror-bootstrap "http://ftp.debian.org/debian/" \
	--parent-mirror-chroot "http://ftp.debian.org/debian/" \
	--parent-mirror-chroot-security "http://security.debian.org/debian-security/" \
	--parent-mirror-binary "http://ftp.debian.org/debian/" \
	--parent-mirror-binary-security "http://security.debian.org/debian-security/" \
	--parent-mirror-debian-installer "http://ftp.debian.org/debian/" \
	--mirror-bootstrap "http://ftp.debian.org/debian/" \
	--mirror-chroot "http://ftp.debian.org/debian/" \
	--mirror-chroot-security "http://security.debian.org/debian-security/" \
	--mirror-binary "http://ftp.debian.org/debian/" \
	--mirror-binary-security "http://security.debian.org/debian-security/" \
	--mirror-debian-installer "http://ftp.debian.org/debian/"

# Armbian repository (trixie). "current" is the 6.18 LTS branch for rk3588,
# use 7.x with edge-rockchip64 or the Rockchip BSP 6.1 with vendor-rk35xx.
echo "deb https://apt.armbian.com trixie main trixie-utils trixie-desktop" > config/archives/live.list.chroot
echo "deb https://apt.armbian.com trixie main trixie-utils trixie-desktop" > config/archives/live.list.binary

wget https://raw.githubusercontent.com/armbian/build/main/config/armbian.key
gpg --dearmor < armbian.key > armbian.gpg
cp armbian.gpg config/archives/armbian.key.binary
cp armbian.gpg config/archives/armbian.key.chroot

# Packages that are only needed inside the live system
cp additional-packages config/package-lists/additional-packages.list.chroot

# Let NetworkManager manage every interface
mkdir -p config/includes.chroot_after_packages/etc/netplan
cp networkmanager.yaml config/includes.chroot_after_packages/etc/netplan

cp customize-chroot.hook.chroot config/hooks/live
mkdir -p config/includes.chroot_after_packages/etc/grub.d/
cp 10_linux config/includes.chroot_after_packages/etc/grub.d/
