#!/usr/bin/env bash

# Defined variables
container_name="pythonplay"
container_from_image="docker.io/library/ubuntu:24.04"
container_volumes="-v /mnt/c/xfer/:/xfer/ -v /mnt/c/Users/ptimme01/OneDrive/vol1/scm/play/pythonplay/:/app/"
container_options="-itd"
container_entrypoint="/bin/bash"
image_version="v1"
git_username="ptimmerman01"
git_email="ptimmerman01@outlook.com"
apt_packages=""
conda_env_name="pythonplay"
conda_env_version="3.10"
additional_dockerfile_commands=$(cat << EOF
# Appends to the Dockerfile during Create-DockerfileStage2
RUN apt update && \
  apt install -y build-essential procps sysstat iproute2 iputils-ping net-tools dnsutils traceroute whois

RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda-installer.sh && \
  bash /tmp/miniconda-installer.sh -b && \
  /root/miniconda3/bin/conda init && \
  /root/miniconda3/bin/conda config --set auto_activate_base false 

RUN /root/miniconda3/bin/conda create -y --name $conda_env_name python=$conda_env_version && \
  echo "conda activate $conda_env_name" >> \$HOME/.bashrc

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
  apt install -y jq wget nano git curl vim ca-certificates acl lsof lsb-release openssl

RUN git config --global user.name $git_username && \
  git config --global user.email $git_email

RUN touch \$HOME/.cym_bashrc && \
  echo "source \$HOME/.cym_bashrc" >> \$HOME/.bashrc

EOF
}

Create-DockerfileStage2() {
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
        Show-UserYesOrNo --message="Container $container_name already exists. Press 'y' to delete it 'no' to exit (default is no)?" --color=red --timeout=10
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
        Show-UserYesOrNo --message="Image $image_name already exists. Press 'y' to reuse it or 'n' to delete it" --color=red --timeout=10
            if [ $answer_key == "y" ]; then
                podman rmi -f $image_name
             elif [ $answer_key == "n" ]; then
               should_reuse_image="y"
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

Cleanup() {
    cd $HOME
    rm -Rf ./$build_dir
}

Main() {

    Set-BuildEnvironment

    if [ -z $should_reuse_image ] && [ $should_reuse_image == "y" ]; then
        echo "Reusing existing image: $image_name"
    else
        Create-DockerfileStage1
        Create-DockerfileStage2
        Build-Image
    fi
  
    Run-Container
    Cleanup

}
Main