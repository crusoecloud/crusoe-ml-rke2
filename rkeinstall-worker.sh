#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
sudo apt update && sudo apt install jq curl wget -y

curl -s -L https://nvidia.github.io/nvidia-container-runtime/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-archive.gpg
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L "https://nvidia.github.io/nvidia-container-runtime/$distribution/nvidia-container-runtime.list" | \
    sed 's|deb |deb [signed-by=/usr/share/keyrings/nvidia-archive.gpg] |g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-runtime.list
sudo apt update && sudo apt install -y nvidia-container-runtime

while [ ! -e "/root/rke-0-main.json" ]; do echo "Waiting for lb metadata file to be present..."; sleep 2; done;
host=$(jq -r ".network_interfaces[0].private_ipv4.address" /root/rke-0-main.json)

desired_status_code=200
url="http://$host:5500/rke-agent-token"
timeout=60

while ! curl -s --output /dev/null --head --fail --max-time $timeout $url; do :; done

rke_token=$(curl -s $url)

while [ ! -e "/root/rke-lb-main.json" ]; do echo "Waiting for metadata file to be present..."; sleep 2; done;
lb_host=$(jq -r ".network_interfaces[0].private_ipv4.address" /root/rke-lb-main.json)

#Creating directory for RKE2 config file
mkdir -p /etc/rancher/rke2

#Creating RKE2 agent config file
cat << EOF > /etc/rancher/rke2/config.yaml
server: https://$lb_host:9345
token: $rke_token
EOF