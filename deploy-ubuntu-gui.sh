#!/bin/bash

GREEN="$(tput setaf 2)"
RED="$(tput setaf 1)"
BLUE="$(tput setaf 4)"
YELLOW="$(tput setaf 3)"
MAGENTA="$(tput setaf 5)"
CYAN="$(tput setaf 6)"
WHITE="$(tput setaf 7)"
BLACK="$(tput setaf 0)"
BGREEN="$(tput setab 2)"
BRED="$(tput setab 1)"
BBLUE="$(tput setab 4)"
BYELLOW="$(tput setab 3)"
BMAGENTA="$(tput setab 5)"
BCYAN="$(tput setab 6)"
BWHITE="$(tput setab 7)"
BBLACK="$(tput setab 0)"
RESET="$(tput sgr0)"

title() {
    echo "${GREEN}================================================${RESET}"
    echo "${CYAN}" $@ "${RESET}"
    echo "${GREEN}================================================${RESET}"
}

message() {
    echo "${YELLOW}" $@ "${RESET}"
}

warning() {
    echo "${MAGENTA}" $@ "${RESET}"
}

error() {
    echo "${RED}" $@ "${RESET}"
}

debug() {
    if [ "x${DEBUG}" != "x" ]; then
        echo >&2 "${BLUE}" $@ "${RESET}"
    fi
}

lxc_init() {
    title "LXC part started"
    message "Fetching image first"
    #lxc launch images:ubuntu/bionic/amd64 $MACHINE
    lxc launch ubuntu:b $MACHINE

    sleep 5
    message "LXC part comepleted"
    lxc_show
}

lxc_show() {
    lxc list | grep $MACHINE
}

machine_config() {
    title "configuring machine"

    message "installing packages"
    lxc_exec apt update
    lxc_exec apt upgrade -y
    lxc_exec apt install -y mesa-utils alsa-utils x11-apps git

    message "mapping UID"
    lxc config set $MACHINE raw.idmap "both $UID 1000"

    message "restarting machine once"
    lxc restart $MACHINE

    message "Configuring sudo" 
    lxc_exec sed -i '/^%sudo/ s/ALL$/NOPASSWD: ALL/' /etc/sudoers

    message "adding X related files"
    lxc config device add $MACHINE X0 disk \
        path=/tmp/.X11-unix/X0 \
        source=/tmp/.X11-unix/X0 
    lxc config device add $MACHINE Xauthority disk \
        path=/home/ubuntu/.Xauthority \
        source=${XAUTHORITY}

    echo "export DISPLAY=:0" | \
        lxc_sudo tee -a /home/ubuntu/.profile

    message "adding GPU"
    lxc config device add $MACHINE mygpu gpu
    lxc config device set $MACHINE mygpu uid 100
    lxc config device set $MACHINE mygpu gid 1000

    message "adding pulse audio"
    echo "
    echo export PULSE_SERVER=\"tcp:\`ip route show 0/0 | awk \'{print \$3}\'\`\" >> ~/.profile
    mkdir -p ~/.config/pulse/
    echo export PULSE_COOKIE=/home/ubuntu/.config/pulse/cookie >> ~/.profile
    " | lxc_sudo
    lxc config device add $MACHINE PACookie disk \
        path=/home/ubuntu/.config/pulse/cookie \
        source=/home/${USER}/.config/pulse/cookie

    message "getting prompt from github"
    lxc_sudo git clone https://github.com/prasannax1/config.git
    lxc_sudo cp /home/ubuntu/config/.*rc /home/ubuntu -v

    message "restarting again"
    lxc restart $MACHINE
}

lxc_exec() {
    debug "Running $@"
    lxc exec $MACHINE -- "$@"
}

lxc_sudo() {
    debug "running $@"
    lxc exec $MACHINE -- sudo --login --user $USER "$@"
}

init() {
    DEBUG=1
    MACHINE=$1
    USER=ubuntu
}

main() {
    init $1
    title "started script"
    lxc_init
    machine_config
    message "script completed"
    warning "use lsh command to connect to host"
}

main $@
