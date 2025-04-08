.SYNOPSIS
Create one shot voice clone with tts.

.DESCRIPTION

.ENVIRONMENT
Known: main
Operating Systems: wsl
Container: podman
Packages: conda
General: gpu enabled

.REPO
https://github.com/metavoiceio/metavoice-src

.EXAMPLE
python3 ./myapp.py

.NOTES
cloned voices go in ./assets

.STEPS


podman run -itd --device $(nvidia-ctk cdi list|grep nvidia) -v /mnt/c/xfer:/xfer --hostname metavoice-src --name metavoice-src ubuntu:24.04 /bin/bash

podman attach metavoice-src



apt update
apt install -y build-essential wget nano git ffmpeg pipx curl

git config --global credential.helper store
git config --global user.name ptimmerman01
git config --global user.email ptimmerman01@outlook.com

cd /root
git clone https://github.com/metavoiceio/metavoice-src


wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda-installer.sh
bash /tmp/miniconda-installer.sh -b
/root/miniconda3/bin/conda init

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

<restart container for both rust and conda>
podman restart metavoice-src
podman attach metavoice-src

cd /root/metavoice-src

conda create -y --name metavoice-src python=3.10
conda activate metavoice-src

### xformers line gave hash issues, so this hack work around it
cp ./requirements.txt ./requirements.txt_orig
<then in the requirements.txt, copy xformers line, then remove xformers line and hashes for it>
touch requirements_xformers.txt
<xformers==0.0.22.post7 ; python_version >= "3.10" and python_version < "4.0">
<copy the xformers line into it -- no hashes>

pip install -r requirements_xformers.txt
pip install -r ./requirements.txt
pip install -e .
pip install torch==2.2.1 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
<some dependicies erros, but that is ok>

ln -s /usr/lib/wsl/drivers/nv_dispsi.inf_amd64_3efa186d0d770b7a/libcuda.so.1 /usr/lib/libcuda.so
ldconfig

### run myapp sample
pip install nltk==3.8.1


### myapp.py

from fam.llm.fast_inference import TTS
import nltk
from pydub import AudioSegment

output_path = "outputs/final.wav"
speaker = "assets/patrick1.mp3"
readtext = """"In a world where mutants with extraordinary abilities are both feared and revered, the X-Men stand as a beacon of hope and unity.
Led by the wise and powerful telepath, Professor Charles Xavier, this diverse team of heroes, including the fierce Wolverine, the weather-controlling Storm, and the telekinetic Jean Grey, fights to protect a world that often misunderstands them.
Their greatest adversary, Magneto, once a friend of Xavier, challenges their ideals with his own vision of mutant supremacy.
Together, the X-Men navigate a landscape of prejudice and conflict, striving to show humanity that their differences can be a source of strength and harmony.
"""

tts = TTS()

def synthesize_chunk(chunk):
    wav_file = tts.synthesise(text=chunk, spk_ref_path=speaker)
    wav_files.append(wav_file)


def concatenate_wav_files(wav_files, output_path):
    combined = AudioSegment.empty()
    for wav_file in wav_files:
        audio = AudioSegment.from_wav(wav_file)
        combined += audio
    combined.export(output_path, format="wav")


nltk.download("popular")
words = nltk.word_tokenize(readtext)
wav_files = []
beginctr = 0
endctr = 0
chunk_size = 20
chunkcnt = 1 + (len(words) // chunk_size)

while chunkcnt > 1:
    endctr += chunk_size
    while not words[beginctr].isalnum:
        beginctr += 1
    words[beginctr].upper()
    chunksegs = words[beginctr:endctr]
    chunksegs.append(".")
    chunk = " ".join(chunksegs)
    synthesize_chunk(chunk)
    beginctr = endctr
    chunkcnt -= 1

if chunkcnt == 1:
    chunk = " ".join(words[beginctr : len(words)])
    synthesize_chunk(chunk)


concatenate_wav_files(wav_files, output_path)



