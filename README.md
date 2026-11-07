# ax3600-ath11k-fix

Fix for the Xiaomi AX3600 (IPQ8074, ath11k) rebooting when a Wi-Fi client moves between two SSIDs on the same 2.4 GHz radio. Related: openwrt/openwrt#24864.

## Problem

1. The station leaves BSS A and joins BSS B of the same radio within about a second. The host sends `WMI_PEER_CREATE` for a MAC that is still a peer on the other vdev. The firmware (WLAN.HK.2.9.0.1-02146) asserts `wal_peer_control.c:2904 Assertion is_graceful_to_handle failed`.
2. ath11k crash recovery on AHB then fails (`wmi unified ready event: -110`, NULL dereference) and the whole SoC reboots (1-2 minutes without Wi-Fi, LAN or WAN).

Triggers seen: Tuya devices in pairing mode, apps that "switch network", any client with both SSIDs saved.

## Patches (`patches/`)

| Patch | What |
| --- | --- |
| 950, 951 | AHB crash recovery (CE interrupt enable/disable, disable interrupts on crash recovery). Already in ath-next (a7ab5c835e42, f7a74e131d3f); carried here verbatim for 25.12.5. |
| 952 | `ath11k_peer_create()` refuses (-EBUSY) a peer whose MAC is still a peer on another vdev of the same pdev, without sending it to the firmware. The client retries a few seconds later and connects. |

`openwrt-25.12.5-ax3600-ath11k-fix.mbox` is the same set as one mbox for OpenWrt `package/kernel/mac80211/patches/ath11k/`.

## Build

`build-ath11k-kmods.sh` builds `ath11k.ko` and `ath11k_ahb.ko` for OpenWrt 25.12.5 (kernel 6.12.94, backports 6.18.26) using the official `config.buildinfo`, so the vermagic matches the stock modules. Adjust `VERMAGIC` and `REL` for other releases.

## Install and rollback

Keep the originals first, then replace the two modules in `/lib/modules/6.12.94/` and reboot:

```sh
mkdir -p /root/ath11k-orig && cp /lib/modules/6.12.94/ath11k*.ko /root/ath11k-orig/
# copy the built ath11k.ko and ath11k_ahb.ko to /lib/modules/6.12.94/, then:
reboot
# rollback:
cp /root/ath11k-orig/*.ko /lib/modules/6.12.94/ && reboot
```

`sysupgrade` or `apk upgrade kmod-ath11k*` replaces the modules and brings the bug back.

## Test results (AX3600, 2026-10-30)

Smart plug moved `fedo` to `fedo_iot` and back, the exact sequence that rebooted the router 8 times before (`fedo_iot` -> `fedo` and `fedo` -> `fedo_iot`):

```text
ath11k: peer <mac> still exists on vdev 2, not creating it on vdev 1
ath11k: Failed to add peer / station ...
hostapd: ... associated (aid 1)        # client succeeded on retry, 4 s later
```

No firmware assert and no reboot in either direction.

Use at your own risk. Tested only on an AX3600.
