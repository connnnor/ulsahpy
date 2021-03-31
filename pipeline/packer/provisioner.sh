#!/usr/bin/env bash 
app=ulsahpy

# Update OS and install python deps
sudo apt-get update && sudo apt-get -y upgrade
sudo apt-get -y install python3-pip python3-venv
# make sure virtualenv is in path
PATH=$PATH:$HOME/.local/bin
# add a user and create home dir
#sudo /usr/sbin/useradd -m -s /usr/sbin/nologin $app

# Set up the working directory and app
mkdir -p "$HOME"/"$app"
cp -R /tmp/"$app" "$HOME"/"$app"
cp /tmp/requirements.txt "$HOME"/"$app"
# Create virtualenv and install app deps
cd $HOME/"$app"
python3 -m venv venv
. venv/bin/activate
pip install -r requirements.txt

# Enable the systemd unit 
sudo cp /tmp/"$app".service /etc/systemd/system/
sudo systemctl enable $app
