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

ssh_ignore(){
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $*
}

ssh_victim(){
    ssh_ignore root@"${public_ip}" $*
}

# build the system configuration
nix build .#nixosConfigurations."${server_name}".config.system.build.toplevel

# copy the configuration to the target machine
export NIX_SSHOPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
nix-copy-closure -s root@"${public_ip}" $(readlink ./result)

# register it to the system profile
ssh_victim nix-env --profile /nix/var/nix/profiles/system --set $(readlink ./result)

# activate the new configuration
ssh_victim $(readlink ./result)/bin/switch-to-configuration switch 
