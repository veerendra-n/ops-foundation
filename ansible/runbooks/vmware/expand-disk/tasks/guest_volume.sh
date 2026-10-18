#!/bin/sh
# Read-only. Size, use and backing disk serial of a Linux mount point. Prints one JSON object.
set -eu
mnt="$1"
src=$(findmnt -no SOURCE --target "$mnt")
size_kb=$(df -Pk "$mnt" | awk 'NR==2 {print $2}')
used_pct=$(df -Pk "$mnt" | awk 'NR==2 {gsub("%","",$5); print $5}')
lvm=false
if [ "$(lsblk -no TYPE "$src" | head -1)" = "lvm" ]; then lvm=true; fi
# Walk down to the physical disk (one PV assumed; more than one is escalated).
disks=$(lsblk -nso NAME,TYPE "$src" | awk '$2=="disk" {print $1}' | sed 's/^[^a-z0-9]*//' | sort -u)
count=$(printf '%s\n' "$disks" | grep -c . || true)
disk=$(printf '%s\n' "$disks" | head -1)
serial=$(lsblk -dno SERIAL "/dev/$disk" 2>/dev/null | tr -cd '0-9A-Fa-f' | tr 'A-F' 'a-f')
part=$(lsblk -nso NAME,TYPE "$src" | awk '$2=="part" {print $1}' | sed 's/^[^a-z0-9]*//' | head -1)
printf '{"serial":"%s","size_gb":%s,"used_pct":%s,"lvm":%s,"disk":"%s","partition":"%s","source":"%s","blocked":%s}\n' \
  "$serial" "$(awk -v k="$size_kb" 'BEGIN {printf "%.1f", k/1048576}')" "$used_pct" "$lvm" "$disk" "$part" "$src" \
  "$( [ "$count" -gt 1 ] && echo true || echo false )"
