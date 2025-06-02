
.SYNOPSIS
Creates voice clones tts.

.DESCRIPTION

.ENVIRONMENT
Known: main
Operating Systems: wsl
Container: podman
Packages: conda
General: gpu enabled

.REPO
https://github.com/SWivid/F5-TTS.git

.EXAMPLE
conda activate f5-tts

f5-tts_infer-gradio --port 7860 --host 0.0.0.0
# the above is nice because it will give a web page and automatically do whisper transcription on reference audio

f5-tts_infer-cli --model F5TTS_v1_Base \
--ref_audio "provide_prompt_wav_path_here.wav" \
--ref_text "The content, subtitle or transcription of reference audio." \
--gen_text "Some text you want TTS model generate for you."

### in windows
conda install ffmpeg
f5-tts_infer-gradio --port 7860 --host 127.0.0.1
.NOTES

.STEPS



podman run -itd --device $(nvidia-ctk cdi list|grep nvidia) -p 7860:7860 -v /mnt/c/xfer:/xfer --hostname f5-tts --name f5-tts ubuntu:24.04 /bin/bash

podman attach f5-tts



apt update
apt install -y build-essential wget nano git ffmpeg curl

git config --global credential.helper store
git config --global user.name ptimmerman01
git config --global user.email ptimmerman01@outlook.com

cd /root
git clone https://github.com/SWivid/F5-TTS.git


wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda-installer.sh
bash /tmp/miniconda-installer.sh -b
/root/miniconda3/bin/conda init

<restart container for conda>
podman restart f5-tts
podman attach f5-tts



conda create -y --name f5-tts python=3.10
conda activate f5-tts

cd /root/F5-TTS

pip install torch==2.4.0+cu124 torchaudio==2.4.0+cu124 --extra-index-url https://download.pytorch.org/whl/cu124
pip install -e .