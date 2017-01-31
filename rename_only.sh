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
for i in "filebot"
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

# IFS set to new line to handle spaces in filenames
IFS=$'\n'

# Check if there are any files to rename in TV directory and then check Movies directory
if [ -n "$(ls -A $media_root/torrent/Complete/Convert/TVShows/)" ]
then
 for i in $(ls -tr $media_root/torrent/Complete/Convert/TVShows/ | tail -1)
 do
  mv "$media_root/torrent/Complete/Convert/TVShows/${i}" "/media/server/torrent/Complete/Rename/TVShows/"
  filebot -script fn:amc --output "/media/server/torrent/Complete/IMPORT" --action move -non-strict "/media/server/torrent/Complete/Rename/TVShows" --log-file=/dev/null --def excludeList=/tmp/amc.txt --def clean=yes
  echo "[TV Show] ${i} [$(date "+%a %D %H:%M")]" >> ~/converted.log
 done
fi
if [ -n "$(ls -A $media_root/torrent/Complete/Convert/Movies/)" ]
then
 for i in $(ls -tr $media_root/torrent/Complete/Convert/Movies/ | tail -1)
 do
  mv "$media_root/torrent/Complete/Convert/Movies/${i}" "$media_root/torrent/Complete/Rename/Movies/"
  filebot -script fn:amc --output "/media/server" --action move -non-strict "/media/server/torrent/Complete/Rename/Movies" --log-file=/dev/null --def excludeList=/tmp/amc.txt --def clean=yes
  echo "[Movie] ${i} [$(date "+%a %D %H:%M")]" >> ~/converted.log
  done
fi
rm $PIDFILE
