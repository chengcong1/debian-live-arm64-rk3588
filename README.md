# Rock 5B Live ISO (Debian trixie + KDE Plasma + Armbian kernel 6.18)

[![image_build](https://github.com/amazingfate/rk3588-live-iso/workflows/Build/badge.svg)](https://github.com/amazingfate/rk3588-live-iso/actions/workflows/build.yml)

为 Radxa Rock 5B（RK3588）构建可直接启动的 Live ISO，也可以安装到 SD 卡 / eMMC / NVMe。

| 组件 | 说明 |
| --- | --- |
| 主板 | Radxa Rock 5B（RK3588，其他 rk3588 板子可改 DTB 后使用） |
| 内核 | Armbian `current` 分支 **6.18.x**（`linux-image-current-rockchip64`，上游主线 + panthor） |
| 用户空间 | **Debian trixie**（13） |
| 桌面 | **KDE Plasma 6**（trixie 自带 Mesa，panthor 开箱可用，不再需要 panfork/rockchip-multimedia PPA） |
| 引导 | GRUB EFI（ISO 内 `grub-efi-arm64`）+ 设备树（DTB）自动加载 |
| 安装器 | Calamares（`calamares-settings-debian`） |

## 三个镜像变体（三个工作流）

| 工作流 | 镜像 | 内核 | 固件 | 桌面 |
| --- | --- | --- | --- | --- |
| `.github/workflows/build.yml` | `lb-config-trixie.sh` | Armbian `current-rockchip64` = **6.18.x LTS** | `armbian-firmware`（含 Armbian 框架包） | KDE Plasma 6 |
| `.github/workflows/build-edge.yml` | `lb-config-trixie-edge.sh` | Armbian `edge-rockchip64` = **7.x 主线**（当前 7.1.8，Armbian 已把 edge 指向 7.2，发布后自动变为 7.2.x） | 纯 Debian 固件（`firmware-realtek` / `firmware-misc-nonfree`） | KDE Plasma 6 完整版 + 中文输入法 + LibreOffice + Firefox |
| `.github/workflows/build-current.yml` | `lb-config-trixie-current.sh` | Armbian `current-rockchip64` = **6.18.x LTS** | 纯 Debian 固件（同上） | 与变体2 相同（共用 `additional-packages.trixie-edge`） |

变体2 与变体3 **不包含任何 Armbian 框架组件**（无 `armbian-firmware`、无 `armbian-bsp-cli-*`、无 `armbian-config`），
Armbian 源仅用于提供内核（`linux-image/dtb/headers-{edge,current}-rockchip64`），且只写入 chroot 阶段，
打好的系统里 apt 源是纯 Debian。变体2/3 只差一个内核分支，用户空间完全一致。

> 注意：Armbian 源里目前**没有 7.2.8**：`edge` 分支已发布的是 7.1.8（源码包 `linux-7.1.8`），
> 7.2.0 目前只给 Qualcomm sm8550 构建过。因此这里用 `edge-rockchip64` 取“最新主线”，
> Armbian 每周重建，一旦发布 7.2.x 就会自动用上。若要立刻上 7.2+，只能自行编译内核或等上游发布。

## 构建流程

1. 用 `live-build`（来自 salsa 的 master 分支）打上 3 个补丁：
   * `grub-dtb.patch` —— Live 菜单里按 SMBIOS 选择并加载 `/live/dtb/rockchip/<board>.dtb`
     （找不到时回退到 `rk3588-rock-5b.dtb`）
   * `0001-binary_linux-image-install-dtbs.patch` —— 把 `/boot/dtb-*` 复制到 ISO 的 `live/dtb`
   * `remove-raspi-firmware.patch` —— arm64 上排除 `raspi-firmware`
2. 执行 `lb-config-trixie.sh`：Debian trixie 归档 + Armbian apt 源（`trixie main trixie-utils trixie-desktop`）。
3. `lb build` 生成 `debian-trixie-kde-rock5b-live-arm64.hybrid.iso`。

主要文件：

```
lb-config-trixie.sh                     # 变体1: 6.18 LTS 内核 + armbian-firmware
additional-packages.trixie              # 变体1 的包列表
lb-config-trixie-edge.sh                # 变体2: edge 7.x 内核 + 纯 Debian 固件（无 Armbian 框架）
lb-config-trixie-current.sh             # 变体3: current 6.18 LTS 内核 + 纯 Debian 固件（无 Armbian 框架）
additional-packages.trixie-edge         # 变体2/3 共用包列表（KDE 完整版 + fcitx5 + LibreOffice + Firefox）
customize-chroot-trixie.hook.chroot     # 三个变体共用：Calamares、locale、声卡命名、fcitx5
10_linux                                # 安装到目标系统的 /etc/grub.d/10_linux（含 DTB 逻辑）
networkmanager.yaml                     # netplan: 使用 NetworkManager 渲染
grub-dtb.patch                          # live-build: Live 菜单加载 DTB
0001-binary_linux-image-install-dtbs.patch
remove-raspi-firmware.patch
.github/workflows/build.yml             # CI（变体1）
.github/workflows/build-edge.yml        # CI（变体2）
.github/workflows/build-current.yml     # CI（变体3）
```

## 在本地构建

需要一台 **arm64** Debian/Ubuntu 主机（或直接使用 CI）：

```sh
sudo apt install debootstrap squashfs-tools xorriso mtools grub-efi-arm64-bin qemu-user-static

# 编译带 DTB 支持的 live-build
git clone https://salsa.debian.org/live-team/live-build.git -b master --depth=1
cd live-build
patch -p1 < ../grub-dtb.patch
patch -p1 < ../0001-binary_linux-image-install-dtbs.patch
patch -p1 < ../remove-raspi-firmware.patch
dpkg-buildpackage -us -uc && sudo apt install ../live-build_*_all.deb
cd ..

# 配置并构建
mkdir iso-build && cd iso-build
cp ../lb-config-trixie.sh lb-config.sh
cp ../additional-packages.trixie additional-packages
cp ../customize-chroot-trixie.hook.chroot customize-chroot.hook.chroot
cp ../networkmanager.yaml . && cp ../10_linux .
chmod +x lb-config.sh && ./lb-config.sh
sudo lb build
```

构建**变体2**（edge 7.x 内核 + 无 Armbian 框架）时把前两行换成：

```sh
cp ../lb-config-trixie-edge.sh lb-config.sh
cp ../additional-packages.trixie-edge additional-packages
```

## 如何启动 Rock 5B

ISO 本身**不含 Rockchip 引导头**（`idbloader.img`/`u-boot.itb`），它是通过 UEFI 启动的，所以需要板上已有一套 UEFI 固件：

* 把 ISO 写入 U 盘后插到板子上；或
* 使用 [Ventoy](https://www.ventoy.net/)（arm64 版）把 ISO 放到 U 盘，用板载 UEFI 从 ISO 启动；或
* 直接把 ISO 作为 UEFI 的可启动设备（U 盘 / NVMe）。

GRUB 的 Live 菜单会：

```
smbios -t 11 -s 4 --set=devicetreename          # 从 UEFI 取板名
devicetree /live/dtb/rockchip/$devicetreename   # 找到就加载
# 找不到则回退：/live/dtb/rockchip/rk3588-rock-5b.dtb
```

> **注意**：如果固件的 SMBIOS OEM 字符串不是 DTB 文件名（例如某些 EDK2 rk3588 固件只提供 ACPI），
> 会走上面的 `rk3588-rock-5b.dtb` 回退分支。若你的板子不是 Rock 5B，请把
> `grub-dtb.patch` 和 `10_linux` 里的回退 DTB 名字改成对应的文件名
> （如 `rk3588-rock-5b-plus.dtb`、`rk3588-rock-5a.dtb`）。

### Live 系统账号

| 用户 | 密码 | 说明 |
| --- | --- | --- |
| `user` | `live` | Live 用户，自动登录由 `live-config` 自带的 `0085-sddm` 组件处理（不额外定制） |
| root | — | 通过 `sudo` 使用 |

安装到磁盘时使用桌面上的 **Install System**（Calamares）。

## 内核版本 / 更换内核分支

内核包名由 `--linux-flavours` 决定（`linux-image-<flavour>`），常见取值：

| flavour | 内核 | 说明 |
| --- | --- | --- |
| `current-rockchip64` | **6.18.x (LTS)** | 默认，主线内核，含 panthor（GPU 加速）、VOP2（HDMI/DP） |
| `edge-rockchip64` | 7.x | 最新主线，可能不稳定 |
| `vendor-rk35xx` | 6.1 BSP | Rockchip 厂商内核（多媒体硬解支持最好，需配套 PPA/Mesa） |

改 `lb-config-trixie.sh` 里的 `--linux-flavours` 即可，同时按需调整
`customize-chroot-trixie.hook.chroot` 的 DTB 回退逻辑和 `additional-packages.trixie` 中的固件/Mesa 包。

## 定制要点

* **桌面**：变体1 用 `additional-packages.trixie` 里的 `kde-plasma-desktop` 及配套包；
  变体2 用 `additional-packages.trixie-edge`：`kde-plasma-desktop` + `kde-standard` + 常用应用
  （Dolphin/Kate/Okular/Ark/Gwenview/KCalc/KDE Connect/Discover/print-manager）+ LibreOffice + GIMP + mpv + Firefox。
  变体2 有意**不含** KMail/Akonadi 等 PIM 组件（体积大、首次启动慢）：需要时在桌面里
  `sudo apt install kmail kontact` 即可，或直接把 `task-kde-desktop` 加进包列表。
  想换成 GNOME/XFCE 就替换对应段落（`gnome` / `xfce4` + `gdm3` / `lightdm`）。
* **固件**：只用 Armbian 的 `armbian-firmware`（已确认包含
  `arm/mali/arch10.8/mali_csffw.bin`、`rtw89/rtw8852b_fw-1.bin`、`rtl_bt/rtl8852bu_fw.bin`）。
  该包声明 `Provides/Conflicts: linux-firmware, firmware-realtek, firmware-ralink,
  firmware-samsung, firmware-brcm80211`，因此 `lb-config-trixie.sh` 里必须设
  `--firmware-chroot false`；否则 live-build（`LB_FIRMWARE_CHROOT` 默认 `true`）会把 Debian 所有
  `firmware-*` 自动塞进 chroot，报 `held broken packages`。
  若要改用纯 Debian 固件：删掉 `armbian-firmware`，把该行改回 `true`，并在此列出
  `firmware-realtek` / `firmware-misc-nonfree`。
* **中文支持**：`fonts-noto-cjk`/`fonts-noto-color-emoji` 已包含；`zh_CN.UTF-8` locale 已在 chroot hook 中生成，
  可在 Calamares 安装界面选择中文，或在 Live 里执行 `localectl set-locale zh_CN.UTF-8`。
  变体2（`additional-packages.trixie-edge`）还装有 **fcitx5 + 拼音**：hook 会执行 `im-config -n fcitx5`、
  写入 `/etc/environment.d/90-fcitx5.conf` 与 `/etc/xdg/autostart/fcitx5.desktop`，进入桌面后用 `Ctrl+Space` 切换中英文。
* **自动登录**：沿用 `live-config` 自带的 `0085-sddm` 组件——它在 Live 启动时把 `[Autologin]`
  写进 `/etc/sddm.conf`，只影响 Live 会话，不会带入安装后的系统。**不要**再往
  `/etc/sddm.conf.d/` 里塞自己的配置：`conf.d/*.conf` 优先级高于 `/etc/sddm.conf`，
  会覆盖掉它（`Session=` 名字不对时自动登录会静默失效，退化成登录界面）。
* **音频设备名**：`90-naming-audios.rules` 给 HDMI0/HDMI1/HDMI-In/DP0/ES8316 起名。

## 下载与合并分卷

Release 里的镜像按大小自动选择发布形式（GitHub 单个资产上限 2 GiB）：

* 镜像 **> 1900 MiB**：切成 **1800 MiB 分卷**上传，文件名形如
  `….hybrid.iso.part00`、`.part01` …；
* 镜像 **≤ 1900 MiB**：直接以单文件 `<iso>` 上传，无需合并。

两种情况都会附带 `<iso>.sha256` 和 `RESTORE.txt`。分卷时 `<iso>.sha256` 的**第 1 行是合并后整镜像的
校验值**，其后每行对应一个分卷（所以下载后可以先校验每个分卷是否完整，再合并校验整镜像）：

```sh
cat <iso>.part* > <iso>
sha256sum -c <iso>.sha256      # 整镜像与各分卷都会校验
```

Windows 可用 `copy /b <iso>.part00 + <iso>.part01 <iso>`（分卷多时用 `for %f in (...) do copy /b`），
或直接用 7-Zip 的“合并文件”。工作流在切分后还会**重新拼回并比对校验值**，确认无误才删除原始 ISO
（同时节省 runner 磁盘），因此上传的分卷一定是可复原的。

## 常见报错

* `armbian-firmware : Conflicts: firmware-realtek ...` / `E: held broken packages`
  —— `--firmware-chroot` 没关。live-build 默认会自动安装 Debian 的全部 `firmware-*`，
  与 `armbian-firmware` 冲突，解决方式见上面「定制要点 / 固件」。
* `patch does not apply` —— live-build master 上游改动，重新生成
  `grub-dtb.patch` / `0001-binary_linux-image-install-dtbs.patch` / `remove-raspi-firmware.patch` 的上下文。

## 已知限制

* ISO 不包含 Rock 5B 的 U-Boot/引导头，需要板上有 UEFI 固件（或改用 Ventoy）。
* 使用厂商 BSP 内核（`vendor-rk35xx`）时硬件解码最好，但需要额外的 Mesa/多媒体源；
  本仓库默认走主线 6.18 + Debian Mesa。
* 首次构建需要下载约 1.5–2 GB 软件包，CI 构建时间约 40–70 分钟。
