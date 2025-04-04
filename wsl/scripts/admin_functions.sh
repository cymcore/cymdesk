InstallMicrosoftPackageRepo() {
# Update the list of packages
apt-get update

# Install pre-requisite packages.
apt-get install -y wget apt-transport-https software-properties-common

# Get the version of Ubuntu
source /etc/os-release

# Download the Microsoft repository keys
wget -P /tmp https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb

# Register the Microsoft repository keys
dpkg -i /tmp/packages-microsoft-prod.deb

# Delete the Microsoft repository keys file
rm /tmp/packages-microsoft-prod.deb

# Update the list of packages after we added packages.microsoft.com
apt-get update

}

InstallAptPackage() {

    local packageName=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --packageName=*) packageName="${1#*=}" ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
        shift
    done

    apt install -y $packageName

}

InstallDocker() {

    if which docker; then
        return 1
    fi
    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update

    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

}

ConfigureFlatpak() {

    if ! which flatpak; then
        return 1
    fi

    if ! flatpak remotes | grep flathub; then
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi

    # after installing flatpak, gui apps start slow.  this fixes (but lose print, open files, open url)
    apt remove -y xdg-desktop-portal

}

ConfigurePodman() {

    if ! cat /etc/containers/registries.conf | grep ^.registries.search; then
        echo '[registries.search]' >> /etc/containers/registries.conf
    fi

    if ! cat /etc/containers/registries.conf | grep ^registries.=; then
        echo 'registries = ["docker.io", "registry.access.redhat.com", "registry.fedoraproject.org", "quay.io"]' >> /etc/containers/registries.conf
    fi
   
    if ! cat /etc/sysctl.conf | grep unprivileged_port_start=0; then
        echo 'net.ipv4.ip_unprivileged_port_start=0' >> /etc/sysctl.conf
        sysctl -p
    fi

}

InstallDistrobox() {
    if ! which distrobox; then
        curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sudo sh
    fi

}

UpgradeDistrobox() {
    
    curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sudo sh

}

InstallFlatpakPackage() {

    local packageName=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --packageName=*) packageName="${1#*=}" ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
        shift
    done

    if ! which flatpak; then
        return 1
    fi

    flatpak install -y $packageName

}

AddLocalGroup() {
    local groupName=""
    local groupId=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --groupName=*) groupName="${1#*=}" ;;
            --groupId=*) groupId="${1#*=}" ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
        shift
    done

    if getent group | grep -q $groupName:x:$groupId; then
        return 0
    fi

    if getent group | grep -q $groupName; then
        echo "group name already exists with a different group id"
        return 1
    fi

     if getent group | grep -q $groupId; then
        echo "group id already exists with a different group name"
        return 1
    fi

    addgroup --gid $groupId $groupName

}

AddLocalUser() {
    local userName=""
    local userId=""
    local userComment=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --userName=*) userName="${1#*=}" ;;
            --userId=*) userId="${1#*=}" ;;
            --userComment=*) userComment="${1#*=}" ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
        shift
    done

    if getent passwd | grep -q $userName:x:$userId; then
        return 0
    fi

    if getent passwd | grep -q $userName; then
        echo "user name already exists with a different user id"
        return 1
    fi

     if getent passwd | grep -q $userId; then
        echo "user id already exists with a different user name"
        return 1
    fi

    adduser --uid $userId --gid $userId --comment "${userComment}" $userName
 
}

AddLocalUserToLocalGroup() {
    local userName=""
    local userGroups=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --userName=*) userName="${1#*=}" ;;
            --userGroups=*) userGroups="${1#*=}" ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
        shift
    done

    IFS="," read -r -a userGroupsArray <<< $userGroups
    for groupName in ${userGroupsArray[@]}; do
        usermod -a -G $groupName $userName
    done

}

InstallNvidiaContainerToolkit() {

    local backend=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --backend=*) backend="${1#*=}" ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
        shift
    done

    cd /tmp
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
    && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    sudo apt-get update

    sudo apt-get install -y nvidia-container-toolkit

    if [ "$backend" == "docker" ]; then

        sudo nvidia-ctk runtime configure --runtime=docker
        sudo systemctl restart docker
    fi

    if [ "$backend" == "podman" ]; then

        sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml

    fi

}

