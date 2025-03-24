ConfigureDboxApp(){
username=""
app=""
while [ $# -gt 0 ]; do
    case "$1" in
        --app=*) app="${1#*=}" ;;
        --username=*) username="${1#*=}" ;;
        *) echo "Unknown option: $1"; return 1 ;;
    esac
    shift
done

dbox="app-${app}"


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

if ! podman inspect $dbox; then
    echo "Container $dbox does not exist. Exiting."
    exit 1
fi

distrobox enter -n "$dbox" -- bash -c "sudo /xfer/cymdesk/distrobox/dbox_app_definitions.sh --app=$app --username=$username"

}