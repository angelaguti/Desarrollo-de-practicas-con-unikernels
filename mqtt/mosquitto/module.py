from osv.modules import api

default = api.run("/mosquitto -c /etc/mosquitto/mosquitto.conf -v")
