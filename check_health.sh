#!/bin/bash

#Set colors for status message below
red='\e[1;31m'
yellow='\e[1;33m'
blue='\e[1;34m'
green='\e[1;32m'
white='\e[1;97m'
clear='\e[0m'

print_error(){
echo -e "$red[ERROR]: $1$clear"
}

print_warning(){
 echo -e "$yellow[WARNING]: $1$clear"
}

print_ok(){
 echo -e "$green[OK]: $1$clear"
}

print_notice(){
 echo -e "$white[NOTICE]: $1$clear"
}

#Check hostname before we begin while loop since it wont change
case `hostname` in
Media-Server) SERVER_CHECK=media_server ;;
Cloud-Backend) SERVER_CHECK=cloud_server ;;
*) print_error "Unable to determine host, now exiting..."; exit 1 ;;
esac

#Check a process to see if it is running and provide the PID of process
CHECK_PROCESS(){
PID_PROCESS=$(ps -ef | grep "${1}" | egrep -v "grep" | awk '{print $2}')
[ -z "${PID_PROCESS}" ] && print_error "${2} is NOT running" || print_ok "${2} is running PID:[${PID_PROCESS}]"
}

#Check is a share is properly mounted
CHECK_MOUNT(){
if mountpoint -q "${1}"; then print_ok "${1} is mounted"; else print_error "${1} is NOT mounted"; fi
}

#Check free space for a device and provide mount point
CHECK_SPACE(){
df -h | grep "${1}" | awk '{print $(NF-1),"\t",$NF}' | while read OUTPUT; do 
 MOUNT=$(echo $OUTPUT | awk '{ print $2 }'); FULL=$(echo $OUTPUT | awk '{print $1}' | sed 's/[^0-9]*//g')
 if [ $FULL -ge 90 ]; then
   print_error "${MOUNT} is ${FULL}% full"
 elif [ $FULL -ge 70 ]; then
   print_warning "${MOUNT} is ${FULL}% full"
 else
   print_ok "${MOUNT} is ${FULL}% full"
 fi
done
}

#Countdown timer for healthchecks
COUNTDOWN(){
COUNTDOWN=31 #Set to one second longer than you want loop for healthchecks
while [ "$COUNTDOWN" -ne "0" ]
do
COUNTDOWN=$(($COUNTDOWN - 1))
sleep 1
printf "\r\e[44m%s\e[0m\e[0;97m " "Healthcheck will run in $COUNTDOWN seconds"
done
}

#Healthchecks for Media-Server
media_server_check(){
while :; do
clear
LOAD=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
print_notice "Performing Media-Server health checks [`date +%H:%M`]"
echo -e "\n         \e[1;97m $(perl -e 'print ucfirst(`uptime -p`);')"

if [ $(echo $LOAD | cut -d"." -f1) == 0 ]; then
  echo -e "          SYS Load: \e[1;34m${LOAD}\e[0m"
else
  echo -e "          SYS Load: \e[1;31m${LOAD}\e[0m"
fi

CHECK_PROCESS "/bin/sh -c LD_LIBRARY_PATH=/usr/lib/plexmediaserver" "Plex Media Server"
CHECK_PROCESS "su -s /bin/sh -c umask $0; exec "$1" "$@" emby -- 002 env MAGICK_HOME=/usr/lib/emby-server" "Emby Media Server"
CHECK_PROCESS "/opt/plexpy/PlexPy.py" "plexPy"

CHECK_SPACE "/dev/sda1"
CHECK_SPACE "/dev/mapper/fileserver-server"
CHECK_SPACE "/dev/sda6"

CHECK_MOUNT "/server/local"
CHECK_MOUNT "/server/media"

COUNTDOWN
done
}

#Healthchecks for Cloud-Backend
cloud_server_check(){
while :; do
clear
LOAD=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
print_notice "Performing Cloud-Backend health checks [`date +%H:%M`]"
echo -e "\n         \e[1;97m $(perl -e 'print ucfirst(`uptime -p`);')"

if [ $(echo $LOAD | cut -d"." -f1) == 0 ]; then 
  echo -e "          SYS Load: \e[1;34m${LOAD}\e[0m" 
else
  echo -e "          SYS Load: \e[1;31m${LOAD}\e[0m"
fi

CHECK_PROCESS "/opt/sickgear/SickBeard.py" "SickGear"
CHECK_PROCESS "/usr/bin/mono /opt/Radarr/Radarr.exe" "Radarr"
CHECK_PROCESS "/usr/bin/deluged" "Deluge"
CHECK_PROCESS "deluge-web" "Deluge Web"
CHECK_PROCESS "/opt/jackett/JackettConsole.exe" "Jackett"

CHECK_SPACE "/dev/mapper/vg00-lv01"
CHECK_MOUNT "/server"

COUNTDOWN
done
}

#Start loop for server check
[ ${SERVER_CHECK} == "media_server" ] && media_server_check || cloud_server_check
