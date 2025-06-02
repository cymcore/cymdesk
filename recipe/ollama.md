# ensure .ollama is at /mnt/c/Users/ptimme01/podman_data/ollama/.ollama

podman network create ollama

podman run -itd --device $(nvidia-ctk cdi list|grep nvidia) --network ollama -e OLLAMA_HOST=0.0.0.0:11434 -v /mnt/c/Users/ptimme01/podman_data/ollama/.ollama:/root/.ollama -v /mnt/c/xfer:/xfer --hostname ollama --name ollama nvidia/cuda:12.6.3-cudnn-devel-ubuntu24.04 /bin/bash

podman exec -it ollama /bin/bash

apt update

apt install -y build-essential wget curl nano tmux

curl -fsSL https://ollama.com/install.sh | sh

ollama serve

ollama run <model>

ollam list # will show models already installed