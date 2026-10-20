#!/usr/bin/env bash
# Run in the guest as root, only for the data volume recorded in the deployment outputs.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run as root.' >&2; exit 1; }
volume_id=${1:?Supply the recorded Cinder volume UUID}
size_gib=${2:?Supply the recorded volume size in GiB}
[[ "$volume_id" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]] || exit 2
[[ "$size_gib" =~ ^[1-9][0-9]{0,5}$ ]] || exit 2
# Virtio block devices expose at most 20 characters; SCSI exposes the full UUID.
disk=$(lsblk -dnpo PATH,SERIAL | awk -v full="$volume_id" -v short="${volume_id:0:20}" '$2 == full || $2 == short {print $1}')
[[ "$disk" =~ ^/dev/(sd|vd)[a-z]+$ ]] || { echo 'Expected exactly one disk matching the volume UUID.' >&2; exit 1; }
[[ $(blockdev --getsize64 "$disk") == $((size_gib * 1073741824)) ]] || { echo 'Volume size mismatch.' >&2; exit 1; }
[[ $(lsblk -nr "$disk" | wc -l) == 1 ]] || { echo 'Disk has partitions; refusing to format.' >&2; exit 1; }
fstype=$(blkid -o value -s TYPE "$disk" || true)
if [[ -z "$fstype" ]]; then
  [[ -z $(lsblk -nro MOUNTPOINTS "$disk") && -z $(wipefs --no-act "$disk") ]] || { echo 'Disk is in use or has signatures; refusing to format.' >&2; exit 1; }
  mkfs.ext4 -L platform-data "$disk"
elif [[ "$fstype" != ext4 || $(blkid -o value -s LABEL "$disk") != platform-data ]]; then
  echo 'Unexpected existing filesystem; refusing to modify it.' >&2
  exit 1
fi
uuid=$(blkid -o value -s UUID "$disk")
target=/mnt/platform-data
install -d -m 0755 "$target"
if ! grep -Fq "UUID=$uuid $target " /etc/fstab; then
  if awk -v target="$target" '$1 !~ /^#/ && $2 == target {found=1} END {exit !found}' /etc/fstab; then
    echo 'Mount path already assigned in fstab.' >&2; exit 1
  fi
  printf 'UUID=%s %s ext4 defaults,nofail 0 2\n' "$uuid" "$target" >> /etc/fstab
  systemctl daemon-reload
fi
mountpoint -q "$target" || mount "$target"
[[ $(findmnt -nro UUID "$target") == "$uuid" ]] || { echo 'Wrong volume mounted.' >&2; exit 1; }
printf 'openstack-talk Cinder verification\n' > "$target/infra-check.txt"
sync
grep -Fxq 'openstack-talk Cinder verification' "$target/infra-check.txt"
findmnt "$target"
sha256sum "$target/infra-check.txt"
echo 'PASS Cinder volume mounted persistently and data read/write verified'
