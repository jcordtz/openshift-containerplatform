#!/bin/bash
echo $(date) " - Starting Script"

USER=$1
PASSWORD="$2"
POOL_ID=$3

# Register Host with Cloud Access Subscription
echo $(date) " - Register host with Cloud Access Subscription"

subscription-manager register --username="$USER" --password="$PASSWORD"
if [ $? -eq 0 ]
then
   echo "Subscribed successfully"
else
   echo "Incorrect Username and / or Password specified"
   exit 3
fi

subscription-manager attach --pool=$POOL_ID
if [ $? -eq 0 ]
then
   echo "Pool attached successfully"
else
   echo "Incorrect Pool ID or no entitlements available"
   exit 4
fi

# Disable all repositories and enable only the required ones
echo $(date) " - Disabling all repositories and enabling only the required repos"

subscription-manager repos --disable="*"

subscription-manager repos \
    --enable="rhel-7-server-rpms" \
    --enable="rhel-7-server-extras-rpms" \
    --enable="rhel-7-server-ose-3.4-rpms"

# Install and enable Cockpit
echo $(date) " - Installing and enabling Cockpit"

yum -y install cockpit

systemctl enable cockpit.socket
systemctl start cockpit.socket

# Install base packages and update system to latest packages
echo $(date) " - Install base packages and update system to latest packages"

yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion
systemctl stop firewalld
systemctl start iptables

yum -y update --exclude=WALinuxAgent

# Install Docker 1.12
echo $(date) " - Installing Docker 1.12"

yum -y install docker
sed -i -e "s#^OPTIONS='--selinux-enabled'#OPTIONS='--selinux-enabled --insecure-registry 172.30.0.0/16'#" /etc/sysconfig/docker

# Create thin pool logical volume for Docker
echo $(date) " - Creating thin pool logical volume for Docker and staring service"

#DOCKERVG=$( sfdisk -l | grep -i Disk | grep -v "3824" | grep -v "1827" | awk -F ":" '{ print $1 }' | awk '{ print $2 }' )
DOCKERVG=$( sfdisk -l | grep -E '16709|66837|133544' | awk -F ":" '{ print $1 }' | awk '{ print $2 }' )

echo "DEVS=${DOCKERVG}" >> /etc/sysconfig/docker-storage-setup
echo "VG=docker-vg" >> /etc/sysconfig/docker-storage-setup
docker-storage-setup
if [ $? -eq 0 ]
then
   echo "Docker thin pool logical volume created successfully"
else
   echo "Error creating logical volume for Docker"
   exit 5
fi

# Enable and start Docker services

systemctl enable docker
systemctl start docker

reboot 0

echo $(date) " - Script Complete"

