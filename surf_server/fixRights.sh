#!/bin/sh
chown -R surf:surf .
chown -R surf:www-data csgo
chmod -R 0755 csgo
chown -R surf:ruby csgo/addons/sourcemod/data/sqlite
