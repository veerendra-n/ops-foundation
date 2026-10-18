#!/bin/sh
# Changes state. Grows partition, LVM and file system to fill the enlarged disk.
set -eu
disk="$1"; part="$2"; src="$3"; lvm="$4"
echo 1 > "/sys/class/block/$disk/device/rescan"
if [ -n "$part" ]; then
  partnum=$(cat "/sys/class/block/$part/partition")
  growpart "/dev/$disk" "$partnum" || [ $? -eq 1 ]   # 1 = nothing to grow
fi
if [ "$lvm" = "true" ]; then
  pvresize "/dev/${part:-$disk}"
  lvextend -r -l +100%FREE "$src"
else
  case "$(findmnt -no FSTYPE "$src")" in
    xfs) xfs_growfs "$src" ;;
    ext2|ext3|ext4) resize2fs "$src" ;;
    *) echo "unsupported file system" >&2; exit 2 ;;
  esac
fi
