#!/bin/bash
SRC=/opt/dash
DEST=/home/david/repos/dash-direct-perms

cd $SRC

cp -ru --parents \
    data/connections/webserver.json \
    data/dashboards/6be07d93-e60c-cb79-d70d-a5b02b4f209f.json \
    data/dashboards/10ec73be-e822-7e49-1159-037697f15bf1.json \
    dash.q \
    dashboards.csv \
    PERMISSIONS.MD \
    permissions.q \
    usergroups.csv \
    users \
    version.txt \
    export.sh \
    $DEST/