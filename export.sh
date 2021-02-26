#!/bin/bash
cd /opt/dash

VER_FILE="/opt/dash/version.txt"
VERSION=$(cat $VER_FILE | cut -d '=' -f 2  | xargs | sed 's/ /_/g')

q <<< "\_ permissions.q" &> /dev/null

zip -ru $VERSION.zip \
    data/connections/webserver.json \
    data/dashboards/6be07d93-e60c-cb79-d70d-a5b02b4f209f.json \
    data/dashboards/10ec73be-e822-7e49-1159-037697f15bf1.json \
    dash.q \
    dashboards.csv \
    PERMISSIONS.MD \
    permissions.q_ \
    usergroups.csv \
    users \
    version.txt