#!/usr/bin/env bash
# pushify.sh

set -e
[ ! -z "$DEBUG" ] && set -x

# validate arguments
USAGE(){
    echo "Usage: `basename $0` <server_name>"
    exit 2
}

if [ -z "$1" ]; then
    USAGE
fi

server_name="$1"
public_ip=$(cat ./hosts/${server_name}/public-ip)

# build the system configuration
nix build .#nixosConfigurations."${server_name}".config.system.build.toplevel

# copy the configuration to the target machine
export NIX_SSHOPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
nix-copy-closure -s root@"${public_ip}" $(readlink ./result)

# activate the new configuration
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@"${public_ip}" $(readlink ./result)/bin/switch-to-configuration switch
