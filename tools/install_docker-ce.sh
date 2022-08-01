#!/bin/bash

set +x

# Install Docker-ce
curl -sSL https://get.docker.io | bash
sudo usermod -aG docker $(whoami)

# Install Docker-compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose