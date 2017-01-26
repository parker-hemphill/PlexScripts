#!/bin/bash
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

print_info(){
 echo -e "$white[NOTICE]: $1$clear"
}

CHECK_PROCESS(){
PROCESS_CHECK=`ps -ax | grep "$1" | egrep -v "find|grep" | gawk '{print $1}' | xargs`
if [ ! -z "$PROCESS_CHECK" ]
then
  print_ok "$2 is running [PID:${blue}$PROCESS_CHECK${green}]"
else
  print_error "$2 is NOT running"
fi
}

PART_CHECK(){ 
PART_INFO=$(df -h | grep $1 | awk '{print $5" "$6}'); PART_SIZE=$(echo $PART_INFO | cut -d"%" -f1); PART_NAME=$(echo $PART_INFO | cut -d" " -f2)
  if [[ "$PART_SIZE" -gt "80" ]]; then print_error "${PART_NAME} is ${PART_SIZE}% full"
  elif [[ "$PART_SIZE" -gt "65" ]]; then print_warning "${PART_NAME} is ${PART_SIZE}% full"
  else print_ok "${PART_NAME} is ${PART_SIZE}% full"
  fi
}

while :;
do
clear
countdown="61" #Set this 1 second higher than the countdown you want for healthcheck
LOAD=$(cat /proc/loadavg | awk '{print $1" "$2" "$3}')
case $(echo $LOAD | cut -d"." -f1) in
0) LOAD=$(echo "${blue}${LOAD}${CLEAR}");;
1) LOAD=$(echo "${green}${LOAD}${CLEAR}");;
2) LOAD=$(echo "${yellow}${LOAD}${CLEAR}");;
*) LOAD=$(echo "${red}${LOAD}${CLEAR}");;
esac

HANDBRAKE=$(ps -ax | grep "HandBrakeCLI" | egrep -v "find|grep" | awk '{print $1}')

print_info "Performing Media Center health checks $(date +%H:%M)"
 echo -e "         \e[1;97m $(perl -e 'print ucfirst(`uptime -p`);') $LOAD"
printf "\n"

CHECK_PROCESS "/Plex Media Server" "Plex Media Server"
CHECK_PROCESS "/opt/sickrage/SickBeard.py" "SickRage"
CHECK_PROCESS "nzbget -D" "nzbget"
#CHECK_PROCESS "/opt/CouchPotatoServer/CouchPotato.py" "Couch Potato"
CHECK_PROCESS "/usr/bin/deluged" "Deluge Daemon"
CHECK_PROCESS "deluge-web" "Deluge-Web"
CHECK_PROCESS "/usr/sbin/dnsmasq" "Pi-hole"

for i in '/dev/sda1' '/dev/sdb1'
do
 PART_CHECK "${i}"
done

 if [ ! -z "$HANDBRAKE" ]
  then
   TV_COUNT=$(find /media/server/torrent/Complete/Convert/TVShows -type f -not -name '*-converted.mp4' -not -name '.*' -name '*.*' | wc -l)
   MOVIE_COUNT=$(find /media/server/torrent/Complete/Convert/Movies -type f -not -name '*-converted.mp4' -not -name '.*' -name '*.*' | wc -l)
   NUM_FILES=$(echo "$TV_COUNT + $MOVIE_COUNT" | bc)
   print_info "Handbrake[PID:${blue}${HANDBRAKE}${white}] is converting: ${blue}`ps -ef | grep "HandBrakeCLI"|sed -n -e 's/^.*--output \/media\/server\/torrent\/Complete\/Convert\///p'`${white}\n${NUM_FILES} file[s] are waiting to be converted${clear}\n"
    while [ "$countdown" -ne "0" ]
    do
     countdown=$(($countdown - 1))
     sleep 1
     FINISH=$(cat /tmp/converted | tail -1 | gawk '{print $NF}' | sed s/.$//)
     printf "\r\e[44m%s\e[0m\e[0;97m " "Healthcheck will run in 00h00m`printf "%02d\n" ${countdown}`s, conversion will complete in $FINISH"
    done
  else
  while [ "$countdown" -ne "0" ]
  do
   countdown=$(($countdown - 1))
   sleep 1
   printf "\r\e[44m%s\e[0m\e[0;97m " "Healthcheck will run in $countdown seconds"
  done
 fi
done
