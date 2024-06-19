#!/usr/bin/env fish

#
# Helper script for generating the main ZFS storage pool for media
#

echo "Creating ZFS raidz2 pool 'boiling-rock' using 6 x 20TB drives"

zpool create -f \
  -O xattr=sa \
  -O acltype=posixacl \
  -O atime=off \
  -O relatime=off \
  -O recordsize=1M \
  -O compression=lz4 \
  -o ashift=12 \
  -m /mnt/media \
  boiling-rock \
    raidz2 \
      sdb sdd sde sdf sdg sdh

# Disks: 
#   Disk /dev/sdb: 18.19 TiB, 20000588955648 bytes, 39063650304 sectors
#   Disk /dev/sdd: 18.19 TiB, 20000588955648 bytes, 39063650304 sectors
#   Disk /dev/sde: 18.19 TiB, 20000588955648 bytes, 39063650304 sectors
#   Disk /dev/sdf: 18.19 TiB, 20000588955648 bytes, 39063650304 sectors
#   Disk /dev/sdg: 18.19 TiB, 20000588955648 bytes, 39063650304 sectors
#   Disk /dev/sdh: 18.19 TiB, 20000588955648 bytes, 39063650304 sectors
