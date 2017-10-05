#!/bin/bash

#Check if script is running already.  This prevents multiple encode jobs from running since this script is designed to run manually or invoked from crontab.
PIDFILE=/var/tmp/encode.pid
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

#Set variables to point to directories for file locations
MOVIE_ADD="/torrent/Complete/Movies" #This is where your download client should place COMPLETED downloads of movies
TV_ADD="/torrent/Complete/TVShows" #This is where your download client should place COMPLETED downloads of TV shows

MOVIE_CONVERT="/torrent/Complete/Convert/Movies" #This is where media files are stripped from completed directory and encoded by this script
TV_CONVERT="/torrent/Complete/Convert/TVShows" 

MOVIE_IMPORT="/torrent/Complete/IMPORT/Movies" #This is where filebot imports Movies from
TV_IMPORT="/torrent/Complete/IMPORT/TVShows" #This is the directory to point Sonarr, Sickrage, etc to as the post-processing directory or "completed downloads"
MOVIE_PLEX="/server/plex" #Filebot appends "Movies" directory to this path so it is omited 

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

if [ -z "$PS1" ]; then
    manual=true;clear; print_notice "$0 is being ran manually.  You can invoke automatically by running \"${green}crontab -e${white}\" and adding the following line:\n"
    echo -e "* * * * * `[[ $0 = /* ]] && echo "$0" || echo "$PWD/${0#./}"` > /dev/null 2>&1\n"
fi

# check if binary exist and exit if not
CHECK_BIN(){
unset BIN; BIN=$(which $1 2>/dev/null)
[ -z $BIN ] && print_error "$1 either doesn't exist or isn't in the PATH statement, now exiting" && exit 1 || print_ok "Found $1"
}

CHECK_MOUNT(){
! mountpoint -q "$1" && print_error "$1 is NOT mounted" && exit 3 || print_ok "$1 is mounted"
}

#This step is optional and can be used to check if a NFS share or filesystem mount point is present. 
#Simply point to mountpoint you wish to check or comment out.  You can also add additional CHECK_MOUNT commands
CHECK_MOUNT "/server"

#This checks for binaries and needed directories.  When ran from cron these checks are skipped.
if [ $manual == true ]; then
 CHECK_BIN HandBrakeCLI; CHECK_BIN mediainfo; CHECK_BIN filebot; CHECK_BIN ffmpeg
 for check in "$TV_ADD" "$MOVIE_ADD" "$TV_CONVERT" "$MOVIE_CONVERT" "$TV_IMPORT" "$MOVIE_IMPORT"; do 
  [ ! -d "$check" ] && print_error "$check does NOT exist.  Please create directory" && exit 4; done
fi

#IFS set to new line to handle spaces in filenames
OLD_IFS=$IFS
IFS=$'\n'

#This clears any files that might be sample media files
find "$TV_ADD" -type f -not -name '*sample*' -size +70M -regex '.*\.\(avi\|mkv\|mod\|mpg\|mp4\|m4v\)' -exec mv "{}" "$TV_CONVERT/" \;
find "$MOVIE_ADD" -type f -not -name '*sample*' -size +600M -regex '.*\.\(avi\|mkv\|mod\|mpg\|mp4\|m4v\)' -exec mv "{}" "$MOVIE_CONVERT/" \;

#Safe to run this command as the previous find command will always grab valid media before the containing folder is removed
find "$TV_ADD" -type d -mmin +1440 -exec rm -rf {} \;
find "$MOVIE_ADD" -type d -mmin +1440 -exec rm -rf {} \;

# Check if there are any files to convert in TV directory
if [ -n "$(ls "$TV_CONVERT")" ]
then
 for i in $(ls -tr "$TV_CONVERT" | tail -1)
 do
 if [ ${i: -4} == ".mkv" ]
 then
 ffmpeg -i "$TV_CONVERT/$i" -c:v copy -c:a copy "$TV_CONVERT/${i%%.mkv}.mp4"
  if [ $? -eq 0 ]
  then
   rm "$TV_CONVERT/$i" 
   i="${i%%.mkv}.mp4"
  fi
 fi
 `$ENCODE_SCRIPT "$TV_CONVERT/${i}"` 
  mv "$TV_CONVERT/${i%\.*}-converted.mp4" "${TV_IMPORT}/" &&  rm -f "$TV_CONVERT/${i}" || rm "$TV_CONVERT/${i%\.*}-converted.mp4"
  if [ $? -eq 0 ]
  then
    echo "[TV Show] ${i} [$(date "+%a %D %H:%M")]" >> "${LOG}"
  fi
 done
fi

# Check if there are any files to convert in MOVIE directory
if [ -n "$(ls "$MOVIE_CONVERT")" ]
then
 for i in $(ls -tr "$MOVIE_CONVERT" | tail -1)
 do
 if [ ${i: -4} == ".mkv" ]
 then
 ffmpeg -i "$MOVIE_CONVERT/$i" -c:v copy -c:a copy "$MOVIE_CONVERT/${i%%.mkv}.mp4"
  if [ $? -eq 0 ]
  then
   rm "$MOVIE_CONVERT/$i"
   i="${i%%.mkv}.mp4"
  fi
 fi
 `$ENCODE_SCRIPT "$MOVIE_CONVERT/${i}"`
  mv "$MOVIE_CONVERT/${i%\.*}-converted.mp4" "${MOVIE_IMPORT}/" &&  rm -f "$MOVIE_CONVERT/${i}" || rm "$MOVIE_CONVERT/${i%\.*}-converted.mp4"
  if [ $? -eq 0 ]
  then
    echo "[MOVIE] ${i} [$(date "+%a %D %H:%M")]" >> "${LOG}"
  fi
 done
fi
[ $(ls "$MOVIE_IMPORT" | wc -l) == 0 ] || /opt/filebot/filebot.sh -script fn:amc --output "$MOVIE_PLEX" --action move -non-strict "$MOVIE_IMPORT" --log-file=/dev/null --def excludeList=/tmp/amc.txt --def clean=yes
IFS=$OLD_IFS
rm $PIDFILE
