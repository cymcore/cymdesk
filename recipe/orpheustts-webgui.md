.SYNOPSIS
Create realistics voice conversations from text

.DESCRIPTION

.ENVIRONMENT
Known: main
Operating Systems: wsl
Container: podman
Packages: conda
General: gpu enabled

.REPO
https://github.com/Saganaki22/OrpheusTTS-WebUI.git

.EXAMPLE
export GRADIO_SERVER_NAME="0.0.0.0"
conda activate orpheustts-webui
python orpheus_wrapper.py
<access from app-edge>

.NOTES

get the token from ptimmerman01 hugging face bit warden

.STEPS


podman run -itd --device $(nvidia-ctk cdi list|grep nvidia) -p 7860:7860 -v /mnt/c/xfer:/xfer --hostname orpheustts-webgui --name orpheustts-webgui ubuntu:24.04 /bin/bash

podman attach orpheustts-webgui

cd /root

apt update
apt install -y build-essential wget nano git

git config --global credential.helper store
git config --global user.name ptimmerman01
git config --global user.email ptimmerman01@outlook.com

git clone https://github.com/Saganaki22/OrpheusTTS-WebUI.git

cd OrpheusTTS-WebUI

wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda-installer.sh
bash /tmp/miniconda-installer.sh -b
/root/miniconda3/bin/conda init

<restart container>
podman attach orpheustts-webgui

cd /root/OrpheusTTS-WebUI

conda create -y --name orpheustts-webui python=3.10
conda  activate  orpheustts-webui

pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
pip install orpheus-speech gradio huggingface_hub
pip install vllm==0.7.3


huggingface-cli login
