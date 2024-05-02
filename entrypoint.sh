#!/bin/sh

set -eu

LXC_NAME="container"
LXC_CONFIG_FILE="/var/lib/lxc/$LXC_NAME/config"
LXC_ROOTFS_PATH="/var/lib/lxc/$LXC_NAME/rootfs"

if ! [ -d "$LXC_ROOTFS_PATH/etc" ] && [ "${LXC_CREATE:-0}" -ne 0 ]; then
  echo "Creating container..."
  [ "${LXC_CREATE_TEMPLATE}" = "download" ] && apk add lxc-download xz

  lxc-create -n "$LXC_NAME" -t "${LXC_CREATE_TEMPLATE}" -- ${LXC_CREATE_OPTIONS:-}
  echo "Created container"
  echo
fi

# Write a static config file for the container, skip any cgroup flags
grep -v '\.cgroup' /usr/share/lxc/config/common.conf > "$LXC_CONFIG_FILE"

cat <<EOF >> "$LXC_CONFIG_FILE"
## Pull some config from common.conf - can't use the full file due to cgroup options
#lxc.include = /usr/share/lxc/config/common.conf

lxc.mount.auto = cgroup:mixed proc:mixed sys:mixed


lxc.rootfs.path = dir:$LXC_ROOTFS_PATH
lxc.uts.name = ${LXC_HOSTNAME:-$LXC_CONTAINER}
lxc.log.file = /dev/stdout

lxc.apparmor.profile = unchanged
lxc.signal.halt = SIGTERM

lxc.autodev = 1
lxc.tty.max = 1
lxc.pty.max = 1

lxc.mount.entry = shm dev/shm tmpfs defaults,create=dir 0 0
lxc.mount.entry = mqueue dev/mqueue mqueue defaults,optional,create=dir 0 0
EOF

if [ "${LXC_NETWORK:-host}" = "host" ]; then
  echo "Inheriting network, this will overwrite /etc/resolv.conf in the LXC container"
  echo "NB; Ensure the container isn't attempting any network management"
  echo

  echo "lxc.net.0.type = none" >> $LXC_CONFIG_FILE
  rm "$LXC_ROOTFS_PATH/etc/resolv.conf"
  cp /etc/resolv.conf "$LXC_ROOTFS_PATH/etc/resolv.conf"
fi

if [ -n "${LXC_CONFIG_SNIPPET:-}" ]; then
  echo "# Custom config snippet:" >> "$LXC_CONFIG_FILE"
  echo "$LXC_CONFIG_SNIPPET" >> "$LXC_CONFIG_FILE"
fi

if [ "${LXC_LXCFS:-0}" -ne "0" ]; then
  echo "Starting lxcfs..."
  mkdir -p /var/lib/lxcfs
  lxcfs -s -o allow_other /var/lib/lxcfs &

  while ! [ -f /var/lib/lxcfs/proc/uptime ]; do
    sleep 1
  done

  # Avoid touching cgroup mounts
  export SKIP_CGROUP_MOUNTS=1

  echo "Started lxcfs"
  echo
fi

echo "Starting container..."
exec lxc-start -n "$LXC_NAME" -F "$@"
