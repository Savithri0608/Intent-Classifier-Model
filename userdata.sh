#!/bin/bash

#craete a directory to clone the repository
#upadte the packages
#git clone to downlaod the source code
#python virtual env and activate
#install python dependencies
#run the model- ctaete .pkl file
#run WSGi-as linux systemd services
#nginx- linux systemd service
#enable the services

set -e

export APP_DIR=/opt/intent-app
mkdir -p $APP_DIR #-p beuse opt/intent is nested directory
cd $APP_DIR

#2
apt update -y
apt install -y git python3 python3-venv python3-pip nginx
 
#3
git clone https://github.com/Savithri0608/Intent-Classifier-Model.git .

#4
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip

#5
python3 -m pip install -r requirements.txt

#6
python3 model/train.py

#7
cat >/etc/systemd/system/intent_gunicorn.service <<'EOF'
[Unit]
Description=Gunicorn instance for Intent Classifier
After=network.target

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory=/opt/intent-app
Environment="PATH=/opt/intent-app/.venv/bin"
ExecStart=/opt/intent-app/.venv/bin/gunicorn --workers 3 --bind 127.0.0.1:6000 wsgi:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# configure nginx reverse proxy (default config will be overwritten), this explains if somebody sending request to localhost/80 server forward to 127 address
cat >/etc/nginx/conf.d/intent_app.conf <<'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:6000/predict;
        proxy_set_header Host $host;              
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 60s;
        proxy_read_timeout 120s;
    }
}
EOF

# Remove default site if present to avoid duplicate default_server collision
if [ -L /etc/nginx/sites-enabled/default ] || [ -f /etc/nginx/sites-enabled/default ]; then
  rm -f /etc/nginx/sites-enabled/default || true
fi

# start & enable services
systemctl daemon-reload
systemctl enable intent_gunicorn
systemctl start intent_gunicorn
systemctl enable nginx
systemctl restart nginx