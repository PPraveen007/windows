#!/bin/bash
set -e

# Load .env file variables
if [ -f .env ]; then
  set -o allexport
  source .env
  set +o allexport
fi

# Check if Docker network exists
if ! docker network ls --format '{{.Name}}' | grep -qw "$VLAN_NETWORK_NAME"; then
  echo "Creating Docker macvlan network $VLAN_NETWORK_NAME ..."
  docker network create -d macvlan \
    --subnet="$VLAN_SUBNET" \
    --gateway="$VLAN_GATEWAY" \
    --ip-range="$VLAN_IP_RANGE" \
    -o parent="$VLAN_PARENT" \
    "$VLAN_NETWORK_NAME"
else
  echo "Docker network $VLAN_NETWORK_NAME already exists"
fi

# Check if 'adhost' interface exists; if not, add it
if ! ip link show adhost &> /dev/null; then
  echo "Creating macvlan interface adhost ..."
  sudo ip link add adhost link "$VLAN_PARENT" type macvlan mode bridge
  sudo ip addr add "$ADHOST_IP" dev adhost
  sudo ip link set adhost up
  sudo ip route add "$VLAN_ROUTE" dev adhost
else
  echo "Interface adhost already exists"
fi
