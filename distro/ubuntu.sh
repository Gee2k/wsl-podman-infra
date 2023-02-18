#!/usr/bin/env sh
echo "initializing ubuntu"

# required to be able to add a new repo via apt
sudo apt -y install software-properties-common

# ansible (ubuntu 20.04 repo version ist uralt 2,9,6 vs 3.12.7)
sudo apt-add-repository ppa:ansible/ansible

sudo apt update

# ansible 2.13.7 / podman 3.4.4
sudo apt -y install ansible podman

sudo apt -y upgrade

sudo apt -y autoremove