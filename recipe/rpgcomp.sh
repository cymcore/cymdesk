#!/usr/bin/env bash


# if user other than root, this will change permissions on the host bind mounts using setfacl so the container user and host user can access them
# podman maps container root to the host $UID user (meaning it does not use /etc/subuid)
# remember podman container break out results in the host user that ran the podman container

# Defined variables
container_name="rpgcomp"
container_from_image="docker.io/library/ubuntu:24.04"
#container_volumes="-v /mnt/c/xfer/:/xfer/ -v /mnt/c/Users/ptimme01/OneDrive/vol1/scm/play/pythonplay/:/app/"
container_volumes="-v /home/ptimme01/scm/rpgcomp:/home/ptimme01/scm/rpgcomp/"
container_options="-itd"
container_entrypoint="/bin/bash"
image_version="v1"
# for a root container, set the username to root, uid and gid to zero, and home to /root
username="ptimme01"
home_path="/home/ptimme01"
user_uid="2001"
user_gid="2001"
git_username="ptimme01"
git_email="ptimme01@outlook.com"
apt_packages=""
conda_env_name="rpgcomp"
conda_env_version="3.10"
additional_dockerfile_commands=$(cat << EOF
# Appends to the Dockerfile during Create-DockerfileStage3

WORKDIR $home_path/scm/rpgcomp

EOF
)

# Derived variables
image_name=$container_name
build_dir="build_$container_name"

# ────── Functions ──────

Create-DockerfileStage1() {
cat << EOF > Dockerfile
FROM $container_from_image

RUN apt update && \
    apt install -y \
    jq \
    wget \
    nano \
    git \
    curl \
    vim \
    ca-certificates \
    acl \
    lsof \
    lsb-release \
    openssl \
    build-essential \
    procps \
    sysstat \
    iproute2 \
    iputils-ping \
    net-tools \
    dnsutils \
    traceroute \
    whois

RUN rm -rf /var/lib/apt/lists/*

EOF

if [ "$username" != "root" ]; then

cat << EOF >> Dockerfile

RUN groupadd -g $user_gid $username && \
    useradd -m -u $user_uid -g $user_gid -s /bin/bash $username

EOF
fi
}

Create-DockerfileStage2() {
cat << EOF >> Dockerfile
# Appends to the Dockerfile during Create-DockerfileStage2

# Switch to the user
USER $username
WORKDIR $home_path

RUN git config --global user.name $git_username && \
  git config --global user.email $git_email

### Begin Miniconda installation
ENV CONDA_PLUGINS_AUTO_ACCEPT_TOS=yes

RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda-installer.sh && \
  bash /tmp/miniconda-installer.sh -b && \
  $home_path/miniconda3/bin/conda init && \
  $home_path/miniconda3/bin/conda config --set auto_activate_base false 

RUN $home_path/miniconda3/bin/conda create -y --name $conda_env_name python=$conda_env_version && \
  echo "conda activate $conda_env_name" >> $home_path/.cym_bashrc

### End Miniconda installation

RUN touch $home_path/.cym_bashrc && \
  echo "source $home_path/.cym_bashrc" >> $home_path/.bashrc
  
EOF
}

Create-DockerfileStage3() {
    printf "%s\n" "$additional_dockerfile_commands" >> ./Dockerfile

}

Run-Container() {
    podman run $container_options $container_volumes --name $container_name --hostname $container_name $image_name:$image_version $container_entrypoint

}

Build-Image() {
    podman build -t $image_name:$image_version -f Dockerfile .
}

Show-UserYesOrNo() {
    # ────── Returns ──────
    # $answer_key as either "y" or "n"

    # ────── Parameters ──────
    local message=""
    local color=""
    local timeout=""
  
    while [ $# -gt 0 ]; do
        case "$1" in
            --message=*) message="${1#*=}" ;;
            --color=*) color="${1#*=}" ;;
            --timeout=*) timeout="${1#*=}" ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
        shift
    done

    # ────── Color lookup ──────
    declare -A COLORS=(
    [red]=$'\e[31m'
    [yellow]=$'\e[33m'
    [green]=$'\e[32m'
    )
    reset=$'\e[0m'

    # Validate color choice
    [[ -z ${COLORS[$color]} ]] && {
    echo "Invalid color: $color  (use red | yellow | green)"
    exit 1
    }

    # ────── Show the message in the requested color ──────
    echo -e "${COLORS[$color]}${message}${reset}"

    # ────── Countdown with non‑blocking key check ──────
    for ((t=timeout; t>=0; --t)); do
    printf "\rTime remaining: %2d " "$t"

    # Wait up to 1 s for a single key‑press
    if read -n1 -t1 key; then
        case "$key" in
        y|Y)
            answer_key="y"
            break
            ;;
        n|N)
            answer_key="n"
            break
            ;;
        *)  : ;;   # ignore any other key
        esac
    fi
    done
    echo    # final newline
}

Set-BuildEnvironment() {
    cd $HOME
    rm -Rf ./$build_dir
    mkdir -p $build_dir
    cd $build_dir
    touch ./Dockerfile
    
    Test-DoesContainerExist
    if [ $does_container_exist -eq 0 ]; then
        Show-UserYesOrNo --message="Container $container_name already exists. Press 'y' to delete it 'no' to exit (default is no)?" --color=red --timeout=20
            if [ $answer_key == "y" ]; then
                podman rm -f $container_name
            elif [ $answer_key == "n" ]; then
                echo "User selected not to remove the container. Exiting."
                exit 1
            else
                echo "No action taken. Container $container_name will not be removed."
                echo "Exiting."
                exit 1
             fi
    fi



    Test-DoesImageExist
    if [ $does_image_exist -eq 0 ]; then
        Show-UserYesOrNo --message="Image $image_name already exists. Press 'y' to delete it or 'n' to reuse it" --color=red --timeout=20
            if [ $answer_key == "y" ]; then
                podman rmi -f $image_name
             elif [ $answer_key == "n" ]; then
               should_reuse_image="true"
            else
                echo "No action taken. Image $image_name will not be removed."
                echo "Exiting."
                exit 1
             fi
    fi


}
Test-DoesContainerExist() {
    if podman ps -a --format '{{.Names}}' | grep -q "^$container_name$" ; then
        does_container_exist=0
    else
        does_container_exist=1
    fi

}

Test-DoesImageExist() {
    if podman images --format '{{.Repository}}:{{.Tag}}' | grep -q "$image_name:$image_version$" ; then
        does_image_exist=0
    else
        does_image_exist=1
    fi

}

Set-BindMountsPermissions() {

    if [ "$username" = "root" ]; then
        return
    fi

    # Extract the starting ID from /etc/subuid for the given username
    start_uid=$(grep "^$USERNAME:" /etc/subuid | cut -d: -f2)

    if [ -z "$start_uid" ]; then
    echo "Error: No subuid entry found for $USERNAME in /etc/subuid"
    exit 1
    fi

    # Calculate the mapped host UID
    host_uid=$(($start_uid + $user_uid - 1))

    # Initialize empty array
    host_dirs=()

    # Loop through each volume mapping and get host paths
    for vol in $container_volumes; do
        # Skip entries starting with -v
        if [[ "$vol" == "-v" ]]; then
            continue
        fi

        # Split host:container by colon
        host_path="${vol%%:*}"
        container_path="${vol#*:}"

        # Append host path to array
        host_dirs+=("$host_path")
    done

    for dir in "${host_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            echo "Bind mount host directory $dir does not exist. Exiting."
            exit 1
        else
            echo "Setting ACLs on bind mount host directory: $dir"
            setfacl -R -m u:$host_uid:rwx "$dir"
            setfacl -R -d -m u:$host_uid:rwx "$dir"
            setfacl -R -m u:$USERNAME:rwx "$dir"
            setfacl -R -d -m u:$USERNAME:rwx "$dir"
        fi

    done


}

Cleanup() {
    cd $HOME
    rm -Rf ./$build_dir
}

Main() {
    Set-BindMountsPermissions
    Set-BuildEnvironment

    if [ "$should_reuse_image" == "true" ]; then
        echo "Reusing existing image: $image_name"
    else
        Create-DockerfileStage1
        Create-DockerfileStage2
        Create-DockerfileStage3
        Build-Image
    fi
  
    Run-Container
    Cleanup

}
Main