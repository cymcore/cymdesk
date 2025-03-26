#!/bin/bash
# This script get called inside of a dbox
username=""
app=""
while [ $# -gt 0 ]; do
    case "$1" in
        --app=*) app="${1#*=}" ;;
        --username=*) username="${1#*=}" ;;
        --dbox=*) dbox="${1#*=}" ;;
        *) echo "Unknown option: $1"; return 1 ;;
    esac
    shift
done

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

dbox="app-${app}"

### App Definitions

if [ "$app" == "edge" ]; then
# install microsoft edge
rpm --import https://packages.microsoft.com/keys/microsoft.asc
dnf config-manager addrepo --from-repofile=https://packages.microsoft.com/yumrepos/edge/config.repo
dnf install -y microsoft-edge-stable

# add aliases
cat << EOF >> /home/$username/.cym_bashrc
if podman inspect "$dbox" &> /dev/null; then
    alias edge="nohup distrobox enter -n "$dbox" -- microsoft-edge &> /dev/null &"
fi

EOF
fi

if [ "$app" == "chrome" ]; then
# install google chrome
cat << 'EOF' >> /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl-ssl.google.com/linux/linux_signing_key.pub

EOF
dnf config-manager setopt google-chrome.enabled=1
dnf install -y google-chrome-stable

# add aliases
cat << EOF >> /home/$username/.cym_bashrc
if podman inspect "$dbox" &> /dev/null; then
    alias chrome="nohup distrobox enter -n "$dbox" -- google-chrome-stable &> /dev/null &"
fi

EOF
fi

if [ "$app" == "vlc" ]; then
# install vlc
dnf install -y vlc

# add aliases
cat << EOF >> /home/$username/.cym_bashrc
if podman inspect "$dbox" &> /dev/null; then
    alias vlc="nohup distrobox enter -n "$dbox" -- vlc &> /dev/null &"
fi

EOF
fi

if [ "$app" == "libreoffice" ]; then
# install libreoffice
dnf install -y libreoffice

# add aliases
cat << EOF >> /home/$username/.cym_bashrc
if podman inspect "$dbox" &> /dev/null; then
    alias word="nohup distrobox enter -n "$dbox" -- libreoffice --writer &> /dev/null &"
    alias excel="nohup distrobox enter -n "$dbox" -- libreoffice --calc &> /dev/null &"
fi

EOF
fi

if [ "$app" == "gimp" ]; then
# install gimp
dnf install -y gimp

# add aliases
cat << EOF >> /home/$username/.cym_bashrc
if podman inspect "$dbox" &> /dev/null; then
    alias gimp="nohup distrobox enter -n "$dbox" -- gimp &> /dev/null &"
fi

EOF
fi

if [ "$app" == "inkscape" ]; then
# install inkscape
dnf install -y inkscape

# add aliases
cat << EOF >> /home/$username/.cym_bashrc
if podman inspect "$dbox" &> /dev/null; then
    alias inkscape="nohup distrobox enter -n "$dbox" -- inkscape &> /dev/null &"
fi

EOF
fi

if [ "$app" == "kdenlive" ]; then
# install kdenlive
dnf install -y kdenlive

# add aliases
cat << EOF >> /home/$username/.cym_bashrc
if podman inspect "$dbox" &> /dev/null; then
    alias kdenlive="nohup distrobox enter -n "$dbox" -- kdenlive &> /dev/null &"
fi

EOF
fi
