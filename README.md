# MAX98937 speaker for Redmi Note 7 (lavender) on Nura / postmarketOS 7.2.x

Русский: нижний динамик Redmi Note 7 не работает на mainline-ядре, потому что
в device tree нет усилителя MAX98937. Этот репозиторий содержит проверенный
рецепт: 6 апстрим-патчей, включающих драйвер `max98927` с переведённой картой
регистров MAX98937, узел в DT и UCM-секцию `Speaker`.

English: enables the built-in speaker (MAX98937, driven by `max98927`) on
Xiaomi Redmi Note 7 / lavender running Nura (postmarketOS) with a 7.2.x
sdm660-mainline kernel.

## Status / проверено

- Device: Redmi Note 7 (lavender), panel NT36672A **tianma**, 4 GB.
- OS: Nura edge, kernel `7.2.15-sdm660` (sdm660-mainline + local IPA v2.6L wip2/rxfix).
- Verified 2026-11-21: `dmesg` → `max98927 1-003a: MAX98937 revisionID: 0x43`,
  `lsmod` → `snd_soc_max98927`, `pactl` → `HiFi (Mic, Speaker)`,
  `speaker-test -D pulse -c 2 -t sine -f 500` слышен пользователем.
- Does **not** change IPA/modem. Do not `rmmod ipa` and never install `ipa2-lite` on sdm660.

## What is inside

- `patches/` — 6 original commits from `mest2011/linux` branch
  `lavender-max98937` (PR sdm660-mainline/linux#262). Apply in this order:
  `dbc2287a5a7c` → `d7f4a37a9caa` → `6b0e0b372b50` → `2b32d2ff3854` →
  `b53d61f37d8c` → `29f06975b3c2`. All six apply cleanly to 7.2.15.
  They add `CONFIG_SND_SOC_MAX98927=m`, the `max98937` compatible/regmap,
  a 1 ms reset pulse, and the `blsp_i2c6@0x3a` / `PRI_MI2S_RX` DT link.
- `ucm/HiFi.conf` — `SectionDevice."Speaker"` from
  `mest2011/alsa-ucm-conf` branch `lavender-speaker-lpi`.
- `build-example.sh` — exact build commands used (rootless LLVM-19 toolchain).

## Build (host, as normal user)

```sh
KDIR=/path/to/linux-7.2.15          # your clean sdm660-mainline tree
cd "$KDIR"
for p in /path/to/this/repo/patches/*.patch; do git apply "$p"; done
scripts/config --module SND_SOC_MAX98927
git add -A && git -c user.email=you@example.com -c user.name=You commit -m 'lavender: MAX98937 speaker'
git tag -f -a v7.2.15 -m v7.2.15 HEAD      # release must be exactly 7.2.15-sdm660
make ARCH=arm64 LLVM=-19 olddefconfig
make ARCH=arm64 LLVM=-19 -j4 M=sound/soc/codecs modules
make ARCH=arm64 LLVM=-19 -j4 qcom/sdm660-xiaomi-lavender-tianma.dtb
```

Notes:

- `LLVM=-19` uses clang-19/ld.lld-19 from `PATH`. For a rootless toolchain add
  `PATH=~/toolchain/root/usr/bin:$PATH LD_LIBRARY_PATH=~/toolchain/root/usr/lib/x86_64-linux-gnu`
  plus `M4`, `BISON_PKGDATADIR`, `HOSTCFLAGS`, `HOSTLDFLAGS` (see `build-example.sh`).
- An annotated tag at HEAD is required: otherwise `setlocalversion` appends `+`
  or `-dirty` and the module directory will not match `/lib/modules/7.2.15-sdm660`.
- If the new module is not produced on the first `make M=...`, `touch .config`
  and re-run — kbuild caches `modules.order`.
- The device has no `zstd` binary: compress with `zstd -19 -q -o snd-soc-max98927.ko.zst snd-soc-max98927.ko` on the host.

## Install (on the phone, root)

1. **Back up first**: `/boot/{vmlinuz,initramfs,boot.img,*.dtb}`, `/boot/dtbs`,
   and `/lib/modules/7.2.15-sdm660`.
2. Install `snd-soc-max98927.ko.zst` into
   `/lib/modules/7.2.15-sdm660/kernel/sound/soc/codecs/`, run `depmod 7.2.15-sdm660`.
3. Add `snd_soc_max98927` to `/etc/modules` (the module file is
   `snd-soc-max98927.ko`; `modprobe max98927` does **not** work).
4. Install the DTB to **both** `/boot/dtbs/qcom/sdm660-xiaomi-lavender-tianma.dtb`
   and `/boot/sdm660-xiaomi-lavender-tianma.dtb` (deviceinfo points at the first).
5. Run `mkinitfs`. On this system it can overwrite the DTB in `/boot/dtbs` with
   an older copy and sometimes fail with `cpio: write too long` on
   `modules.symbols.bin` — just re-run it. **After** it succeeds, re-install the
   new DTB, then rebuild only the boot image:
   `mkdir -p /tmp/bd; cp /boot/vmlinuz /boot/initramfs /tmp/bd/;
   boot-deploy -i initramfs -d /tmp/bd -o /boot`.
6. UCM: in this Nura build PulseAudio is started without `ALSA_CONFIG_UCM2`, so
   a user-level `~/.config/environment.d/` override is ignored. Copy
   `ucm/HiFi.conf` to `/usr/share/alsa/ucm2/Xiaomi/lavender/HiFi.conf`
   (back up the old file), then `pulseaudio -k; pulseaudio --start`.
7. Reboot (user action). Verify: `dmesg | grep -i max98927`, `lsmod | grep 98927`,
   `pactl list cards | grep 'Active Profile'`, `speaker-test -D pulse -c 2 -t sine -f 500`.
   Start with modest gain (`Speaker Volume` 2, `Digital Volume` 48) — there is no
   Android DSM speaker protection here.

## Attribution / лицензии

Kernel patches are GPL-2.0-only, original authors Miguel Sobral Teixeira
(`mest2011`) and Franco Ortiz. UCM file is BSD-3-Clause from
`mest2011/alsa-ucm-conf`. See `ATTRIBUTION.md`; packaging/docs here are MIT.
This is an independent, unaffiliated port.
