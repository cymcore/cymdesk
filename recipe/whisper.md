.SYNOPSIS
Create outstanding text from speech.

.DESCRIPTION

.ENVIRONMENT
Known: main
Operating Systems: wsl
Container: podman
Packages: conda
General: gpu enabled for decent performance

.REPO
https://github.com/openai/whisper.git

.EXAMPLE
conda activate whisper
whisper bama.mp3 --model medium.en

.NOTES
whisper /xfer/downloads/samuel_f5.mp3 --output_format txt --output_dir ./ --model medium.en
- use json to get text in a single line (e.g. to use with f5)
.STEPS


podman run -itd --device $(nvidia-ctk cdi list|grep nvidia) -v /mnt/c/xfer:/xfer --hostname whisper --name whisper ubuntu:24.04 /bin/bash

podman attach whisper

cd /root

apt update
apt install -y build-essential wget nano git

git config --global credential.helper store
git config --global user.name ptimmerman01
git config --global user.email ptimmerman01@outlook.com

git clone https://github.com/openai/whisper.git


wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda-installer.sh
bash /tmp/miniconda-installer.sh -b
/root/miniconda3/bin/conda init

<restart container>
podman attach whisper

cd /root/whisper

conda create -y --name whisper python=3.10
conda activate whisper
conda install -y -c conda-forge ffmpeg
conda install -y cuda -c nvidia
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
pip install -U openai-whisper






