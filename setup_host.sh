#!/bin/bash
clear

# Notes:
# Required kernel is above 3.10
# For Ubuntu Precise (12.04), Docker requires the 3.13 kernel version
# Designed for Ubuntu distro
# I suggest running on a clean system

#
# Variables
#


ssh_port=""

pw_length=""

version='sb_release --release | cut -f2'
codename='lsb_release --codename | cut -f2'

#
# Methods
#

# Awesome thanks to https://github.com/tlatsas for the spinner
function _spinner() {
    # $1 start/stop
    #
    # on start: $2 display message
    # on stop : $2 process exit status
    #           $3 spinner function pid (supplied from stop_spinner)

    local on_success="DONE"
    local on_fail="FAIL"
    local white="\e[1;37m"
    local green="\e[1;32m"
    local red="\e[1;31m"
    local nc="\e[0m"

    case $1 in
        start)
            # calculate the column where spinner and status msg will be displayed
            let column=$(tput cols)-${#2}-8
            # display message and position the cursor in $column column
            echo -ne ${2}
            printf "%${column}s"

            # start spinner
            i=1
            sp='\|/-'
            delay=${SPINNER_DELAY:-0.15}

            while :
            do
                printf "\b${sp:i++%${#sp}:1}"
                sleep $delay
            done
            ;;
        stop)
            if [[ -z ${3} ]]; then
                echo "spinner is not running.."
                exit 1
            fi

            kill $3 > /dev/null 2>&1

            # inform the user uppon success or failure
            echo -en "\b["
            if [[ $2 -eq 0 ]]; then
                echo -en "${green}${on_success}${nc}"
            else
                echo -en "${red}${on_fail}${nc}"
            fi
            echo -e "]"
            ;;
        *)
            echo "invalid argument, try {start/stop}"
            exit 1
            ;;
    esac
}

function start_spinner {
    # $1 : Displayed string
    _spinner "start" "${1}" &
    # set global spinner pid
    _sp_pid=$!
    disown
}

function stop_spinner {
    # $1 : command exit status
    _spinner "stop" $1 $_sp_pid
    unset _sp_pid
}

## Displaying a spinner while a command is running
spin() {
	# $1 : Displayed string
	# $2 : Command
	
	start_spinner ${1}
	for ((i=2;i<=$#;i++))
	do
		${!i} >/dev/null 2>&1
		if [ $? > 0 ]
			then output=1
		fi
	done
	stop_spinner $output
}

#
# ENTRYPOINT
#


echo "Executable for setting up Cluster.HOST nodes"
echo "Keeeenion [me(at)keeeenion.me]"
echo ""

## Checking for privileges
if [ $EUID -ne 0 ]
	then echo "[-] Please run me with sudo privileges"
	exit
fi

#
# User input
#

## Getting datadog's ID from user
echo "Please specify your Datadog's API key: [ENTER]"
read datadog_key

#
# Creating users and groups
#

echo "[+] Creating users and groups"
echo "-----------------------------"

spin "Creating a Docker group" 'groupadd docker'
spin "Adding Your account to the Docker group" 'usermod -aG docker $USER'

## Creating accounts when needed

## Generating random passwords

#
# Updating and installing dependencies
#

echo "[+] Updating and installing dependencies"
echo "----------------------------------------"

if [ $version == "12.04" ]; then
	spin "Adding docker sources" 'echo "deb https://apt.dockerproject.org/repo ubuntu-precise main" > /etc/apt/sources.list.d/docker.list'
elif [ $version == "14.04" ]; then
	spin "Adding docker sources" 'echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" > /etc/apt/sources.list.d/docker.list'
elif [ $version == "15.10" ]; then
	spin "Adding docker sources" 'echo "deb deb https://apt.dockerproject.org/repo ubuntu-wily main" > /etc/apt/sources.list.d/docker.list'
elif [ $version == "16.04" ]; then
	spin "Adding docker sources" 'echo "deb deb https://apt.dockerproject.org/repo ubuntu-xenial main" > /etc/apt/sources.list.d/docker.list'
else
	echo "You must be using a wrong version or something"
	exit
fi

spin "Updating" 'apt-get -qq update'
spin "Upgrading" 'apt-get -qq upgrade'
spin "Cleaning after updates" 'apt-get -qq clean' 'rm -rf /tmp/*'

spin "Installing curl" 'apt-get -qq install curl'
spin "Installing " 'apt-get -qq install apt-transport-https ca-certificates'
spin "Adding Docker's GPG key" 'apt-key -qq adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D'

# If you are installing on Ubuntu 14.04 or 12.04, apparmor is required
if [ $version == "12.04" ] || [ $version == "14.04" ]
	then spin "Installing apparmor" 'apt-get -qq install apparmor'
fi

if [ $version == "16.04" ] || [ $version == "14.04" ] || [ $version == "15.10" ]
	spin "Installing recommended packages" 'apt-get -qq install linux-image-extra-$(uname -r)'
fi

spin "Installing Docker engine" 'apt-get -qq install docker-engine'

start_spinner "Installing Datadog's agent"
DD_API_KEY=${datadog_key} bash -c "$(curl -L https://raw.githubusercontent.com/DataDog/dd-agent/master/packaging/datadog-agent/source/install_agent.sh) >/dev/null" 
stop_spinner $?

#
# Configuring software
#


echo ""
echo "[+] Configuring software"
echo "------------------------"

## Startup runnables
spin "Running Docker on startup " 'systemctl enable docker'

start_spinner "Grabbing updates every five hours"
crontab -l | { cat; echo "0 */5 * * * apt-get -qq update && apt-get -qq upgrade"; } | crontab -
stop_spinner $?

# Hardening and securing the system
echo ""
echo "[+] Hardening and securing the system"
echo "-------------------------------------"

## Swapping default ports

## Locking out the root user

## Changing passwords

## Changing privileges for critical folders

## Implementing firewall and adding rules, limiting network access

### Blocking all traffic

### Adding Docker exceptions

## Setting up backups

## Spawn runnables

#
# Summary of the excecutable
#


echo ""
echo "[+] Summary of the installation"
echo "-------------------------------"