#!/bin/bash
PIDFILE=~/convert.pid
if [ -f $PIDFILE ]
then
  PID=$(cat $PIDFILE)
  ps -p $PID > /dev/null 2>&1
  if [ $? -eq 0 ]
  then
    echo "Process already running"
    exit 1
  else
    ## Process not found assume not running
    echo $$ > $PIDFILE
    if [ $? -ne 0 ]
    then
      echo "Could not create PID file"
      exit 1
    fi
  fi
else
  echo $$ > $PIDFILE
  if [ $? -ne 0 ]
  then
    echo "Could not create PID file"
    exit 1
  fi
fi

### The directories below are required so that files can be moved along as they are converted.  Best if $media_root points to a mounted disk for Plex Server
media_root="/media/server" #this is the base directory where media files are imported from torrent/nzb client.  Also serves as holder for converted files awaiting import into Plex
# Create folder inside /media manually and chown it to the user you run Plex and torrent client with

MAKE_DIR(){ if [ ! -d "$2" ]; then mkdir "$2"; chmod "$1" "$2"; fi } # $1 sets mode for DIR 770 by default; $2 is name to check/create if it doesn't exist

CHECK_BIN(){ hash $1 2>/dev/null || { echo >&2 "$1 required but it's not installed.  Aborting."; exit 1; }; } #Checks if required binaries are installed

# Required binaries check
for i in "mediainfo" "HandBrakeCLI" "filebot"
do
CHECK_BIN "$i"
done

# Loop to check for directories needed to process files.  Will create if they don't exist
if [ ! -d "$media_root" ]
then
MAKE_DIR 770 "$media_root/torrent"
MAKE_DIR 770 "$media_root/torrent/Complete"
for j in "Rename" "IMPORT" "Convert"
do
  MAKE_DIR 770 "$media_root/torrent/Complete/$j"
 for i in "TVShows" "Movies"
 do
   MAKE_DIR 770 "$media_root/torrent/Complete/$j/$i"
 done
done
fi

# The encode function is adapted from the bash script located at https://gist.githubusercontent.com/donmelton/5734177/raw/79532cf60c90c40485cc4e546783fcb312ea4be3/encode.sh
ENCODE(){
handbrake_options="--markers --large-file --encoder x264 --encopts vbv-maxrate=25000:vbv-bufsize=31250:ratetol=inf --crop 0:0:0:0 --strict-anamorphic"
width="$(mediainfo --Inform='Video;%Width%' "$media_root/torrent/Complete/Convert/${1}/${2}")"
height="$(mediainfo --Inform='Video;%Height%' "$media_root/torrent/Complete/Convert/${1}/${2}")"

if (($width > 1280)) || (($height > 720)); then
    max_bitrate="1400"
elif (($width > 720)) || (($height > 576)); then
    max_bitrate="1200"
else
    max_bitrate="1000"
fi

min_bitrate="$((max_bitrate / 2))"
bitrate="$(mediainfo --Inform='Video;%BitRate%' "$media_root/torrent/Complete/Convert/${1}/${2}")"

if [ ! "$bitrate" ]; then
    bitrate="$(mediainfo --Inform='General;%OverallBitRate%' "$media_root/torrent/Complete/Convert/${1}/${2}")"
    bitrate="$(((bitrate / 10) * 9))"
fi

if [ "$bitrate" ]; then
    bitrate="$(((bitrate / 5) * 4))"
    bitrate="$((bitrate / 1000))"
    bitrate="$(((bitrate / 100) * 100))"

    if (($bitrate > $max_bitrate)); then
        bitrate="$max_bitrate"
    elif (($bitrate < $min_bitrate)); then
        bitrate="$min_bitrate"
    fi
else
    bitrate="$min_bitrate"
fi

handbrake_options="$handbrake_options --vb $bitrate"
frame_rate="$(mediainfo --Inform='Video;%FrameRate_Original%' "$media_root/torrent/Complete/Convert/${1}/${2}")"

if [ ! "$frame_rate" ]; then
    frame_rate="$(mediainfo --Inform='Video;%FrameRate%' "$media_root/torrent/Complete/Convert/${1}/${2}")"
fi

if [ "$frame_rate" == '29.970' ]; then
    handbrake_options="$handbrake_options --rate 23.976"
else
    handbrake_options="$handbrake_options --rate 30 --pfr"
fi

channels="$(mediainfo --Inform='Audio;%Channels%' "$media_root/torrent/Complete/Convert/${1}/${2}" | sed 's/[^0-9].*$//')"

if (($channels > 2)); then
    handbrake_options="$handbrake_options --aencoder ca_aac,copy:ac3"
elif [ "$(mediainfo --Inform='General;%Audio_Format_List%' "$media_root/torrent/Complete/Convert/${1}/${2}" | sed 's| /.*||')" == 'AAC' ]; then
    handbrake_options="$handbrake_options --aencoder copy:aac"
fi

if [ "$frame_rate" == '29.970' ]; then
    handbrake_options="$handbrake_options --detelecine"
fi

HandBrakeCLI " $handbrake_options" --input="$media_root/torrent/Complete/Convert/${1}/${2}" --output="$media_root/torrent/Complete/Convert/${1}/${2%\.*}-converted.mp4" 2>&1 | tee -a "/tmp/converted"
}

# Find command to move only media files into the convert directory
find $media_root/torrent/Complete/TVShows/ -not -name '*sample*' -regex '.*\.\(avi\|mkv\|mod\|mp4\|m4v\)' -exec mv "{}" $media_root/torrent/Complete/Convert/TVShows \;
find $media_root/torrent/Complete/Movies/ -not -name '*sample*' -regex '.*\.\(avi\|mkv\|mod\|mp4\|m4v\)' -exec mv "{}" $media_root/torrent/Complete/Convert/Movies \;
find $media_root/torrent/Complete/TVShows/ -iname "*sample*" -delete 
find $media_root/torrent/Complete/Movies/ -iname "*sample*" -delete
find $media_root/torrent/Complete/Rename/ -iname "*sample*" -delete
find $media_root/torrent/Complete/TVShows/ -name "*.*" -size -10M -delete
find $media_root/torrent/Complete/Movies/ -name "*.*" -size -10M -delete
find $media_root/torrent/Complete/TVShows/ -type d -not -name 'TVShows' -empty -delete 
find $media_root/torrent/Complete/Movies/ -type d -not -name 'Movies' -empty -delete
find $media_root/torrent/Complete/Rename/ -type d -not -name 'Movies' -not -name 'TVShows' -empty -delete 
find $media_root/torrent/Complete/IMPORT/ -type d -not -name 'TV Shows' -empty -delete

# IFS set to new line to handle spaces in filenames
IFS=$'\n'

# Check if there are any files to convert in TV directory and then check Movies directory
if [ -n "$(ls -A $media_root/torrent/Complete/Convert/TVShows/)" ]
then
 for i in $(ls -ltr $media_root/torrent/Complete/Convert/TVShows/ | tail -1 | awk '{$1=$2=$3=$4=$5=$6=$7=$8=""; print $0}' | cut -c 9-)
 do
 ENCODE "TVShows" "${i}"
cat /dev/null > /tmp/converted
  mv "$media_root/torrent/Complete/Convert/TVShows/${i%\.*}-converted.mp4" "/media/server/torrent/Complete/Rename/TVShows/" &&  rm -f "$media_root/torrent/Complete/Convert/TVShows/${i}" || rm "$media_root/torrent/Complete/Convert/TVShows/${i%\.*}-converted.mp4"
  filebot -script fn:amc --output "/media/server/torrent/Complete/IMPORT" --action move -non-strict "/media/server/torrent/Complete/Rename/TVShows" --log-file ~/amc.log --def excludeList=amc.txt --def clean=yes
   cat ~/amc.txt | sed '${s/$/'" \[$(date)\]"'/;}' > ~/amc.txt
 done
elif [ -n "$(ls -A $media_root/torrent/Complete/Convert/Movies/)" ]
then
 for i in $(ls -ltr $media_root/torrent/Complete/Convert/Movies/ | tail -1 | awk '{$1=$2=$3=$4=$5=$6=$7=$8=""; print $0}' | cut -c 9-)
 do
 ENCODE "Movies" "${i}"
cat /dev/null > /tmp/converted
  mv "$media_root/torrent/Complete/Convert/Movies/${i%\.*}-converted.mp4" "$media_root/torrent/Complete/Rename/Movies/" &&  rm -f "$media_root/torrent/Complete/Convert/Movies/${i}" || rm "$media_root/torrent/Complete/Convert/Movies/${i%\.*}-converted.mp4"
  cat ~/amc.txt | sed '${s/$/'" \[$(date)\]"'/;}' > ~/amc.txt
  filebot -script fn:amc --output "/media/server" --action move -non-strict "/media/server/torrent/Complete/Rename/Movies" --log-file ~/amc.log --def excludeList=~/amc.txt --def clean=yes
done
else
echo "No files to encode"
fi
rm $PIDFILE
parker@media-server:/torrent$ cat /var/tmp/check_health.sh 
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
   print_info "Handbrake[PID:${blue}${HANDBRAKE}${white}] is converting: ${blue}`ps -ef | grep "HandBrakeCLI" | sed -n -e 's/^.*Movies\///p' -e 's/^.*TVShows\///p'`${white}\n${NUM_FILES} file[s] are waiting to be converted${clear}\n"
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
