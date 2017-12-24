#!/bin/bash

PIDFILE=/var/tmp/encode_movie.pid
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

if [ -f "$HOME/.bashrc" ]; then
 . "$HOME/.profile"
fi

#Set variables to point to directories for file locations
MOVIE_ADD="/torrent/Complete/Movies" #This is where your download client should place COMPLETED downloads of movies
TV_ADD="/torrent/Complete/TVShows" #This is where your download client should place COMPLETED downloads of TV shows

MOVIE_CONVERT="/torrent/Complete/Convert/Movies" #This is where media files are stripped from completed directory and encoded by this script
TV_CONVERT="/torrent/Complete/Convert/TVShows" 
MOVIE_CONVERT_TEMP="/torrent/Complete/Convert/Temp/Movies" #This is where mkv files are sent to be re-encoded so handbrake can convert them 
TV_CONVERT_TEMP="/torrent/Complete/Convert/Temp/TVShows"

MOVIE_IMPORT="/torrent/Complete/IMPORT/Movies" #This is where filebot imports Movies from
TV_IMPORT="/torrent/Complete/IMPORT/TVShows" #This is the directory to point Sonarr, Sickrage, etc to as the post-processing directory or "completed downloads"
MOVIE_PLEX="/server/media" #Filebot appends "Movies" directory to this path so it is omited 

#Set location for log file
LOG="/home/parker/converted.log"

#Set location where you downloaded encode.sh
ENCODE_SCRIPT="/var/tmp/encode.sh"

#Set colors for status message 
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

CHECK_MOUNT(){
! mountpoint -q "$1" && print_error "$1 is NOT mounted" && exit 3 || print_ok "$1 is mounted"
}

#Simply point to mountpoint you wish to check or comment out.  You can also add additional CHECK_MOUNT commands
CHECK_MOUNT "/server"

#IFS set to new line to handle spaces in filenames
OLD_IFS=$IFS
IFS=$'\n'

# Check if there are any files to convert in MOVIE directory
if [ "$(ls -A "$MOVIE_CONVERT")" ]; then
 rm "$MOVIE_CONVERT/*-converted.mp4" > /dev/null 2>&1
 FILE=$(ls -tr "$MOVIE_CONVERT" | tail -1)
 { time $ENCODE_SCRIPT "$MOVIE_CONVERT/$FILE" "MOVIE"; } 2> /tmp/time_movie.txt
 mv "$MOVIE_CONVERT/${FILE%\.*}-converted.mp4" "${MOVIE_IMPORT}/" && rm -f "$MOVIE_CONVERT/${FILE}" && echo "[MOVIE] ${FILE} [$(date "+%a %D %H:%M")] `cat /tmp/time_movie.txt | grep sys | awk '{print $2}'`" >> "${LOG}" || touch -d "2000-01-01 00:00:00" "$MOVIE_CONVERT/${FILE}"
 if [ "$(ls -A "$MOVIE_IMPORT")" ]; then
  /usr/local/bin/filebot -script fn:amc --output "$MOVIE_PLEX" --action move -non-strict "$MOVIE_IMPORT" --log-file=/dev/null --def clean=yes --def "exec=chmod -R 755 \"{folder}/\" ; chown -R parker:vpn \"{folder}/\" ; chown -R parker:vpn \"{file}/\""
 fi
fi
rm "$PIDFILE"
