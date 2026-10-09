#!/bin/bash

# K3s Apt Upgrade
# Runs apt upgrades across the server cluster

set -e

ssh root@rpi4-node-1 -- "apt clean && apt update && apt upgrade -y && apt autoremove -y";
ssh root@rpi4-node-2 -- "apt clean && apt update && apt upgrade -y && apt autoremove -y";
ssh root@rpi4-node-3 -- "apt clean && apt update && apt upgrade -y && apt autoremove -y";
ssh root@rpi4-node-4 -- "apt clean && apt update && apt upgrade -y && apt autoremove -y";
ssh root@rpi4-node-5 -- "apt clean && apt update && apt upgrade -y && apt autoremove -y";
ssh root@rpi5-node-1 -- "apt clean && apt update && apt upgrade -y && apt autoremove -y";
ssh root@rpi5-node-2 -- "apt clean && apt update && apt upgrade -y && apt autoremove -y";
ssh root@rpi5-node-3 -- "apt clean && apt update && apt upgrade -y && apt autoremove -y";
ssh root@rpi5-node-4 -- "apt clean && apt update && apt upgrade -y && apt autoremove -y";
ssh root@rpi5-node-5 -- "apt clean && apt update && apt upgrade -y && apt autoremove -y";