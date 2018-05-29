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

lxc_part() {
    title "LXC part started"
    message "Fetching image first"
    lxc launch images:archlinux/current/amd64 $MACHINE

    message "LXC part comepleted"
    lxc_show
}

lxc_show() {
    lxc list | grep $MACHINE
}

machine_config() {
    title "configuring machine"

    message "starting dhcpcd"
    lxc_exec dhcpcd eth0
    message "dhcpcd started"
    lxc_show

    message "installing packages"
    lxc_exec pacman -Syyu --noconfirm
    lxc_exec pacman -S ${APPS[@]} --noconfirm

    message "Configuring sudo" 
    lxc_exec sed -i '/%wheel.*NOPASSWD/ s/^# //' /etc/sudoers

    message "creating user"
    lxc_exec useradd -m -g users -G wheel -s /usr/bin/bash $user

    message "fetching prompt"
    lxc_sudo git clone https://github.com/prasannax1/config.git
    lxc_sudo cp /home/$user/config/.*rc /home/$user -v

    #message "Set password for user"
    #lxc_exec passwd $user

    #message "starting openssh"
    #lxc_exec systemctl enable sshd.socket
    #lxc_exec systemctl start sshd.socket

    message "configuring machine done"
}

lxc_exec() {
    debug "Running $@"
    lxc exec $MACHINE -- "$@"
}

lxc_sudo() {
    debug "running $@"
    lxc exec $MACHINE -- sudo --login --user $user "$@"
}

host_config() {
    title "configuring host side"
    IP="$(lxc_show | awk -F"|" ' { print $4 } ' | awk ' { print $1 } ')"

    debug "IP=${IP}"
    message "adding user to .ssh/config"
    cat >> .ssh/config <<EOF
Host $MACHINE
    Hostname $IP
    User $user

EOF

    message "sending public key to machine"
    lxc_exec mkdir -pv /home/${user}/.ssh/
    lxc_exec chmod 700 /home/${user}/.ssh/
    cat ~/.ssh/id_rsa.pub | lxc_exec tee -a /home/${user}/.ssh/authorized_keys
    lxc_exec chmod 600 /home/${user}/.ssh/authorized_keys

}

init() {
    DEBUG=1
    MACHINE=$1
    user=pras
    APPS=(sudo vim git)
}

main() {
    init $1
    title "started script"
    lxc_part
    machine_config
    #host_config
    message "script completed"
    warning "use lsh command to connect to host"
}

main $@
