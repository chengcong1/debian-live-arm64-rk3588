# Rock 5B (RK3588) + Armbian *current* kernel (6.18.x LTS) + Debian trixie + KDE
#
# "no Armbian framework" flavour, 6.18 LTS branch:
#   * ONLY the kernel packages (linux-image/linux-dtb/linux-headers) come from
#     the Armbian apt repository. No armbian-firmware, no armbian-bsp-cli-*,
#     no armbian-config, nothing else from the Armbian tree is installed.
#   * Firmware comes from Debian (firmware-realtek + firmware-misc-nonfree are
#     listed explicitly, the remaining firmware-* packages are added by
#     live-build's own firmware selection - LB_FIRMWARE_CHROOT defaults to
#     true, so do NOT set --firmware-chroot false here). Verified coverage:
#       firmware-misc-nonfree -> lib/firmware/arm/mali/arch10.8/mali_csffw.bin
#       firmware-realtek      -> lib/firmware/rtw89/rtw8852b_fw-1.bin
#                                lib/firmware/rtl_bt/rtl8852bu_fw.bin
#   * Desktop/applications come from additional-packages.trixie-edge, which is
#     shared with the edge kernel variant (the list is kernel independent).
#
# Kernel mapping (Armbian apt repo, checked 2026-09):
#   current-rockchip64      -> 6.18.x LTS   <- used here
#   edge-rockchip64         -> 7.x
#   vendor-rk35xx           -> 6.1 BSP
# Difference to lb-config-trixie.sh (the other 6.18 image): that one installs
# armbian-firmware and therefore has to disable live-build's firmware
# selection; this one stays on Debian firmware only.

# fail loudly instead of silently building an unusable repository
set -e

LB_IMAGE_NAME="debian-trixie-kde-current-rock5b-live" lb config \
	--architecture arm64 \
	--archive-areas 'contrib main non-free non-free-firmware' \
	--parent-archive-areas 'contrib main non-free non-free-firmware' \
	--debian-installer-distribution trixie \
	--distribution trixie \
	--distribution-chroot trixie \
	--distribution-binary trixie \
	--bootloaders grub-efi \
	--compression xz \
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

# Armbian apt repository -- REQUIRED: it is the source of the kernel packages.
# If this block is removed/commented out the build dies later with
#   E: Unable to locate package linux-image-current-rockchip64
# No Armbian framework package is requested anywhere, only
# linux-image/linux-dtb/linux-headers-current-rockchip64.
# Chroot stage only: the shipped system keeps plain Debian sources.
echo "deb https://apt.armbian.com trixie main" > config/archives/live.list.chroot

# Signing key: primary = the Armbian build tree, fallback = the key served by
# the repository itself, so a blocked raw.githubusercontent.com does not break
# the build. `test -s` + set -e make a failed download abort the build.
if ! wget -q -O armbian.key https://raw.githubusercontent.com/armbian/build/main/config/armbian.key; then
	wget -q -O armbian.key https://apt.armbian.com/armbian.key
fi
test -s armbian.key
gpg --batch --yes --dearmor < armbian.key > armbian.gpg
test -s armbian.gpg
cp armbian.gpg config/archives/armbian.key.chroot

# Packages that are only needed inside the live system
# (shared with the edge variant; the workflow copies
#  additional-packages.trixie-edge to ./additional-packages)
cp additional-packages config/package-lists/additional-packages.list.chroot

# Let NetworkManager manage every interface
mkdir -p config/includes.chroot_after_packages/etc/netplan
cp networkmanager.yaml config/includes.chroot_after_packages/etc/netplan

cp customize-chroot.hook.chroot config/hooks/live
mkdir -p config/includes.chroot_after_packages/etc/grub.d/
cp 10_linux config/includes.chroot_after_packages/etc/grub.d/
