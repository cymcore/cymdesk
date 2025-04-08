.SYNOPSIS
Clone voices

.DESCRIPTION

.ENVIRONMENT
Known: main
Operating Systems: wsl
Container: podman
Packages: conda
General: gpu enabled for decent performance

.REPO
https://github.com/IAHispano/Applio.git

.EXAMPLE
./run-applio.sh 
<access from app-edge>

.NOTES
Used conda so the venv can use 310 python
Had to change app.py to 0.0.0.0 
Had conflict between numpy and numba
- uninstall both and install versions in requirements.txt

.STEPS


podman run -itd --device $(nvidia-ctk cdi list|grep nvidia) -p 6969:6969 -v /mnt/c/xfer:/xfer --hostname applio --name applio ubuntu:24.04 /bin/bash

podman attach applio

cd /root

apt update
apt install -y build-essential wget nano git sudo ffmpeg
apt install -y python3 python3-pip python3-venv

git config --global credential.helper store
git config --global user.name ptimmerman01
git config --global user.email ptimmerman01@outlook.com

wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda-installer.sh
bash /tmp/miniconda-installer.sh -b
/root/miniconda3/bin/conda init

<restart container>
podman attach applio

conda create -y --name applio python=3.10
conda activate applio

cd /root
git clone https://github.com/IAHispano/Applio.git
cd Applio
chmod +x ./*.sh
apt install -y python3-venv
./run-install.sh