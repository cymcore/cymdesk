#!/bin/bash

#TODO set flatpak permissions possible (bottles and texteditor)

### Error Handling
set -xe

### Handle params

### Defined variables

### Derived variables
relativeRoot="$(dirname "$0")"

### Custom

### Source scripts
source $relativeRoot/scripts/base.sh
source $relativeRoot/scripts/admin_functions.sh
source $relativeRoot/scripts/user_functions.sh

wsl_base() {

    # Create os groups
    for groupItem in "${osGroups[@]}"; do 
        declare -A groupDetail
        GetDictionaryItemFromArrayItem "$groupItem" groupDetail
        AddLocalGroup --groupName=${groupDetail[name]} --groupId=${groupDetail[id]}

    done   

    # Create groups for users
    for userItem in "${osUsers[@]}"; do 
        declare -A groupDetail
        GetDictionaryItemFromArrayItem "$userItem" groupDetail
        AddLocalGroup --groupName=${groupDetail[name]} --groupId=${groupDetail[id]}

    done

    # Create users
    for userItem in "${osUsers[@]}"; do 
        declare -A userDetail
        GetDictionaryItemFromArrayItem "$userItem" userDetail
        AddLocalUser --userName=${userDetail[name]} --userId=${userDetail[id]} --userComment="${userDetail[desc]}"

    done

    # Put users in groups
    for userItem in "${osUsers[@]}"; do 
        declare -A userDetail
        GetDictionaryItemFromArrayItem "$userItem" userDetail
        AddLocalUserToLocalGroup --userName=${userDetail[name]} --userGroups=${userDetail[groups]} 

    done

    # Create users .cym_bashrc
    for userItem in "${osUsers[@]}"; do 
        declare -A userDetail
        GetDictionaryItemFromArrayItem "$userItem" userDetail
        CreateCymBashrc --userName=${userDetail[name]}

    done

    # Create intial .gitconfig from .cym_bashrc
    for userItem in "${osUsers[@]}"; do 
        declare -A userDetail
        GetDictionaryItemFromArrayItem "$userItem" userDetail
        CreateGitConfig --userName=${userDetail[name]} --userEmail=${userDetail[email]}

    done

    apt update

    # Install apt packages
    for packageItem in "${aptPackages[@]}"; do 
        declare -A packageDetail
        GetDictionaryItemFromArrayItem "$packageItem" packageDetail
        InstallAptPackage --packageName=${packageDetail[package]}

    done

    ConfigureFlatpak
    ConfigurePodman
    InstallDistrobox

    if [ "$installDocker" -eq 1 ]; then
        InstallDocker
    fi
  
    # Install flatpak packages
    for flatpakItem in "${flatpakPackages[@]}"; do 
        declare -A flatpakDetail
        GetDictionaryItemFromArrayItem "$flatpakItem" flatpakDetail
        InstallFlatpakPackage --packageName=${flatpakDetail[package]}

    done

    # Add flatpak aliases to .cym_bashrc for users
    for userItem in "${osUsers[@]}"; do 
        declare -A userDetail
        GetDictionaryItemFromArrayItem "$userItem" userDetail
        for flatpakItem in "${flatpakPackages[@]}"; do 
            declare -A flatpakDetail
            GetDictionaryItemFromArrayItem "$flatpakItem" flatpakDetail
            AddFlatpakAliasToCymBashrc --userName=${userDetail[name]} --packageName=${flatpakDetail[package]} --packageAlias=${flatpakDetail[alias]}
        done
    done

    # Add distroxbox prompt to .cym_bashrc for users
    for userItem in "${osUsers[@]}"; do 
        declare -A userDetail
        GetDictionaryItemFromArrayItem "$userItem" userDetail
        AddDistroboxPromptToCymBashrc --userName=${userDetail[name]}

    done

    # Add kate notepad alias to .cym_bashrc for users
    for userItem in "${osUsers[@]}"; do 
        declare -A userDetail
        GetDictionaryItemFromArrayItem "$userItem" userDetail
        AddKateNotepadToCymBashrc --userName=${userDetail[name]}

    done
}

init__windev__root() {

    osGroups=(
        "name=duo_sudo;id=3000"
        "name=duo_users;id=3001"
        "name=docker;id=3002"
    )
    
    osUsers=(
        "name=root;id=0;desc=Root;groups=root;email=root@cymcore.com"
        "name=ptimme01;id=1000;desc=Paul Timmerman;groups=docker,users;email=ptimme01@outlook.com"
    )

    aptPackages=(
        "package=podman"
        "package=flatpak"
        "package=thunar"
    )

    flatpakPackages=(
        "package=com.github.tchx84.Flatseal;alias=flatseal"
        "package=com.usebottles.bottles;alias=bottles"
        "package=org.kde.okular;alias=okular"
        "package=org.kde.kate;alias=kate"
    )
    
    # A 1 means install docker, 0 means don't install
    installDocker = 1
    
    wsl_base
    
}

windev__ptimme01() {

    distrobox create -n apps -i quay.io/fedora/fedora:41 --yes --volume /mnt/c/xfer:/xfer:rw --additional-packages "git tmux vim nano wget"
    distrobox enter -n apps -- bash -c "sudo /xfer/cymdesk/distrobox/create_apps.sh --dbox=apps --username=ptimme01"
    InstallMiniConda
}

### Set HostUserProfile (depends on if called with -Init) and runs function
if [ "$1" == "-Init" ]; then
    hostUserProfile="init__${HOSTNAME}__${USER}"
    if declare -F "$hostUserProfile" &>/dev/null; then
        $hostUserProfile
    fi
else
    hostUserProfile="${HOSTNAME}__${USER}"
    if declare -F "$hostUserProfile" &>/dev/null; then
        $hostUserProfile
    fi

fi
