dbox=""
username=""
while [ $# -gt 0 ]; do
    case "$1" in
        --dbox=*) dbox="${1#*=}" ;;
        --username=*) userName="${1#*=}" ;;
        *) echo "Unknown option: $1"; return 1 ;;
    esac
    shift
done

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

if podman inspect $dbox; then
    echo "Container 'apps' already exists. Exiting."
    exit 1
fi

# install dnf apps
dnf install -y nano wget vlc gimp

# install microsoft edge
rpm --import https://packages.microsoft.com/keys/microsoft.asc
dnf config-manager addrepo --from-repofile=https://packages.microsoft.com/yumrepos/edge/config.repo
dnf install -y microsoft-edge-stable


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
cat << 'EOF' >> /home/$username/.cym_bashrc
if [ -n "$CONTAINER_ID" ]; then
    alias chrome="google-chrome-stable"
    alias edge="microsoft-edge"

fi