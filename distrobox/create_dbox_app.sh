CreateDboxApp(){
image=""
app=""
while [ $# -gt 0 ]; do
    case "$1" in
        --app=*) app="${1#*=}" ;;
        --image=*) image="${1#*=}" ;;
        *) echo "Unknown option: $1"; return 1 ;;
    esac
    shift
done

dbox="app-${app}"
externalXferPath="/mnt/c/xfer"

if [ ! -d $externalXferPath ]; then
    echo "External xfer path not present"
    exit 1
fi

if [ "$EUID" -eq 0 ]; then
    echo "Please do not run as root"
    exit 1
fi

if ! which podman; then
    exit 1
fi

if ! which distrobox; then
    exit 1
fi

if podman inspect $dbox; then
    echo "Container $dbox already exists. Exiting."
    exit 1
fi

distrobox create -n "$dbox" -i "$image" --yes --volume $externalXferPath:/xfer:rw --additional-packages "git tmux vim nano wget"

}

