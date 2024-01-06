#!/bin/bash

# elegoo_install.sh by James Forwood (uberoptix)
# Designed to install the Elegoo 3.5" RPi display per https://github.com/MrYacha/LCD-show
# Last updated 6 Jan 2024

cd ~/
sudo rm -rf LCD-show
git clone https://github.com/goodtft/LCD-show.git
chmod -R 755 LCD-show
cd LCD-show
sudo ./LCD35-show
