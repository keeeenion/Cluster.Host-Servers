#!/bin/bash
clear

# Variables

## Ports
ssh_port=""

# Magic
pw_length=""

# Methods

## Displaying a spinner while a command is running
spin() {
	#Parameter 1 = Displayed string
	#Parameter 2 = Command
	
	echo -n "$1... "
	
	$2 &
	PID=$!
	i=1
	sp="/-\|"
	echo -n ' '
	while [ -d /proc/$PID ]
	do
		printf "\b${sp:i++%${#sp}:1}"
	done
}

## Checking if the dependet is already installed, if not we install it
check() {
	if [ 'which $1 ; echo $?' ]
	then # 0 = true
		return 0
	else # 1 = false
		return 1
	fi
}

######## ENTRYPOINT ########

echo "Executable by Keeeenion [me(at)keeeenion.me]"

## Checking for privileges
if [ @EUID -ne 0 ]
	then echo "[-] Please run me as sudo"
	exit
fi

# Creating users and groups
echo "[+] Creating users and groups"
echo "-----------------------------"

## Creating the accounts

## Generating random passwords

# Updating and installing dependencies
echo "[+] Updating and installing dependencies"
echo "----------------------------------------"

spin "Updating" 'apt-get -qq update'
spin "Upgrading" 'apt-get -qq upgrade'

spin 'check "curl"'

# Configuring software
echo ""
echo "[+] Configuring software"
echo "------------------------"

# Hardening and securing the system
echo ""
echo "[+] Hardening and secuting the system"
echo "-------------------------------------"

## Swapping default ports

## Changing passwords

## Implementing a firewall, limiting network access

## Setting up backups

# Summary of the changes
echo ""
echo "[+] Summary of the installation"
echo "-------------------------------"