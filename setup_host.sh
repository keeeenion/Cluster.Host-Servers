#!/bin/bash
clear
clear

# Notes:
# Required kernel is above 3.10
# For Ubuntu Precise (12.04), Docker requires the 3.13 kernel version, not yet handeled
# Designed for Ubuntu distros
# I suggest running it on a clean system

# Run as following: bash -c "$(curl -L https://raw.githubusercontent.com/keeeenion/Cluster.Host-Servers/master/setup_host.sh) >/dev/null

#
# Variables
#


ssh_port="22222"

pw_length=""

version=$(lsb_release --release | cut -f2)
codename=$(lsb_release --codename | cut -f2)

#
# Methods
#

# Awesome thanks to https://github.com/tlatsas for the spinner
function _spinner() {
    local on_success="+"
    local on_fail="-"
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
	
	if (( $# == 1 ))
	then
		start_spinner "${1}"
		stop_spinner 0
		return 0
	else
		start_spinner "${1}"
		for (( i=2;i<=$#;i++ ))
		do	
			#basc -c ""
			${!i} >/dev/null 2>&1
			if [ $? > 0 ]
				then output=1
			fi
		done
		stop_spinner $output
		return 0
	fi
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
echo ""

#
# User input
#

## Getting datadog's ID from user
echo "Please specify your Datadog's API key: [ENTER]"
read datadog_key
echo ""

#
# Creating users and groups
#

echo ""
echo "[+] Creating users and groups"
echo "-----------------------------"

if grep -q "docker" /etc/group; then
	spin "Docker group already exists"
else
	spin "Creating a Docker group" 'groupadd docker'
fi

if groups $USER | grep &>/dev/null '\bcustomers\b'; then
    spin "Your user is already part of Docker's group"
else
    spin "Adding Your user to the Docker group" 'usermod -aG docker $USER'
fi

#
# Updating and installing dependencies
#

echo ""
echo "[+] Updating and installing dependencies"
echo "----------------------------------------"

start_spinner "Installing Datadog's agent"
if [ $version == "12.04" ]; then
	echo "deb https://apt.dockerproject.org/repo ubuntu-precise main" > /etc/apt/sources.list.d/docker.list
elif [ $version == "14.04" ]; then
	echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" > /etc/apt/sources.list.d/docker.list
elif [ $version == "15.10" ]; then
	echo "deb https://apt.dockerproject.org/repo ubuntu-wily main" > /etc/apt/sources.list.d/docker.list
elif [ $version == "16.04" ]; then
	echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" > /etc/apt/sources.list.d/docker.list
else
	echo "You must be using a wrong version or something"
	exit
fi
stop_spinner $?

spin "Updating" 'apt-get -qq update -y'
spin "Upgrading" 'apt-get -qq upgrade -y'
spin "Cleaning after updates" 'apt-get -qq clean' 'rm -rf /tmp/*'

spin "Installing curl" 'apt-get -qq install curl -y'
spin "Installing apt specific packages" 'apt-get -qq -y install apt-transport-https ca-certificates'
spin "Adding Docker's GPG key" 'apt-key -qq -y adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D'

spin "Installing openssh server" 'apt-get install openssh-server -y'

# If you are installing on Ubuntu 14.04 or 12.04, apparmor is required
if [ $version == "12.04" ] || [ $version == "14.04" ]
	then spin "Installing apparmor" 'apt-get -qq install apparmor'
fi

if [ $version == "16.04" ] || [ $version == "14.04" ] || [ $version == "15.10" ]
	then spin "Installing recommended packages" 'apt-get -y -qq install linux-image-extra-$(uname -r)'
fi

spin "Installing Docker engine" 'apt-get -qq -y install docker-engine'

start_spinner "Installing Datadog's agent"
DD_API_KEY=$datadog_key bash -c "$(curl -L https://raw.githubusercontent.com/DataDog/dd-agent/master/packaging/datadog-agent/source/install_agent.sh) >/dev/null" 
stop_spinner $?

#
# Configuring
#

echo ""
echo ""
echo "[+] Configuring software"
echo "------------------------"

# Runnables
spin "Running Docker on startup " 'systemctl enable docker'

start_spinner "Grabbing updates every five hours"
crontab -l | { cat; echo "0 */5 * * * apt-get -y -qq update && apt-get -y -qq upgrade"; } | crontab -
stop_spinner $?

#Openssh-server
start_spinner "Configuring openssh server"
sed -i 's/^\(PermitRootLogin\).*/\1 no/' /etc/ssh/sshd_config
sed -i 's/^\(Protocol\).*/\1 2/' /etc/ssh/sshd_config
sed -i 's/^\(AllowUsers\).*/\1 $USER/' /etc/ssh/sshd_config
sed -i 's/^\(HostbasedAuthentication\).*/\1 no/' /etc/ssh/sshd_config
sed -i 's/^\(Port\).*/\1 $ssh_port/' /etc/ssh/sshd_config
sed -i 's/^\(PermitEmptyPasswords\).*/\1 no/' /etc/ssh/sshd_config
stop_spinner $? # Will be improved

# System configurations
echo ""
echo "[+] System configurations"
echo "-------------------------------------"

## Changing privileges for critical folders

## Implementing firewall and adding rules, limiting network access

### Blocking all traffic

### Adding Docker exceptions

## Setting up backups

## Spawn runnables

#
# Restarting services
#

echo ""
echo "[+] Restarting service"
echo "----------------------"
spin "Restarting openssh server" 'service openssh-server reload' 'service openssh-server restart'
spin "Restarting Docker" 'service docker reload' 'service docker restart'

#
# Summary of the excecutable
#


echo ""
echo "[+] Additional info"
echo "-------------------"