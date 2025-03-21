CreateCymBashrc() {
    local userName=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --userName=*) userName="${1#*=}" ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
        shift
    done

    if [[ $userName == "root" ]]; then
        homePath="/root"
    else
        homePath="/home/$userName"
    fi

    if [ ! -f $homePath/.cym_bashrc ]; then
        touch $homePath/.cym_bashrc
        chown $userName:$userName $homePath/.cym_bashrc
        echo -e "#!/bin/bash\n  " > $homePath/.cym_bashrc
    fi

    if ! cat $homePath/.bashrc | grep source.*cym_bashrc; then
        echo "source $homePath/.cym_bashrc" >> $homePath/.bashrc
    fi

}

AddFlatpakAliasToCymBashrc() {
    local userName=""
    local packageName=""
    local packageAlias=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --userName=*) userName="${1#*=}" ;;
            --packageName=*) packageName="${1#*=}" ;;
            --packageAlias=*) packageAlias="${1#*=}" ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
        shift
    done

    if [[ $userName == "root" ]]; then
        cymBashrcFile="/root/.cym_bashrc"
    else
        cymBashrcFile="/home/$userName/.cym_bashrc"
    fi

    if ! cat $cymBashrcFile | grep $packageName; then
        echo "alias $packageAlias=\"flatpak run $packageName &\"" >> $cymBashrcFile
    fi

}

CreateGitConfig() {
    local userName=""
    local userEmail=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --userName=*) userName="${1#*=}" ;;
            --userEmail=*) userEmail="${1#*=}" ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
        shift
    done

    if [[ $userName == "root" ]]; then
        gitconfigFile="/root/.gitconfig"
    else
        gitconfigFile="/home/$userName/.gitconfig"
    fi

    if [[ $userName == "root" ]]; then
        cymBashrcFile="/root/.cym_bashrc"
    else
        cymBashrcFile="/home/$userName/.cym_bashrc"
    fi

    cat << EOF >> $cymBashrcFile
if [ ! -f $gitconfigFile ]; then
    git config --global user.name $userName
    git config --global user.email $userEmail
fi

EOF

}

InstallMiniConda() {
    if [ "$EUID" -ne 0 ]; then
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda-installer.sh
        bash /tmp/miniconda-installer.sh -b
        /home/$USER/miniconda3/bin/conda init
        source /home/$USER/.bashrc
        conda config --set auto_activate_base false
    fi

}

AddDistroboxPromptToCymBashrc() {
    local userName=""
  
    while [ $# -gt 0 ]; do
        case "$1" in
            --userName=*) userName="${1#*=}" ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
        shift
    done

    if [[ $userName == "root" ]]; then
        cymBashrcFile="/root/.cym_bashrc"
    else
        cymBashrcFile="/home/$userName/.cym_bashrc"
    fi

    if ! cat $cymBashrcFile | grep CONTAINER_ID; then
    cat << 'EOF' >> $cymBashrcFile
if [ -n "$CONTAINER_ID" ]; then
    PS1='\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h-${CONTAINER_ID}\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$'
fi

EOF
    fi

}

