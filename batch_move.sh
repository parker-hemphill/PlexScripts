#!/bin/bash
IFS=$'\n'
#Check if script is running already.  This prevents multiple encode jobs from running since this script is designed to run manually or invoked from crontab.
PIDFILE=/var/tmp/encode_move.pid
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

#This clears any files that might be sample media files
find "$TV_ADD" -type f -not -name '*sample*' -size +30M -regex '.*\.\(avi\|mod\|mpg\|mp4\|m4v\)' -exec mv "{}" "$TV_CONVERT/" \;
find "$MOVIE_ADD" -type f -not -name '*sample*' -size +600M -regex '.*\.\(avi\|mod\|mpg\|mp4\|m4v\)' -exec mv "{}" "$MOVIE_CONVERT/" \;

find "$TV_ADD" -type f -not -name '*sample*' -size +30M -regex '.*\.mkv' -exec mv "{}" "$TV_CONVERT/" \;
find "$MOVIE_ADD" -type f -not -name '*sample*' -size +30M -regex '.*\.mkv' -exec mv "{}" "$MOVIE_CONVERT/" \;

find "$TV_ADD" -mindepth 1 -delete
find "$MOVIE_ADD" -mindepth 1 -delete
rm "$PIDFILE"
