#!/bin/bash
PIDFILE=~/encode.pid
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

MOVIE="/media/server" #this is the folder where movies are renamed to.  This is the base directory.  FileBot adds movie folders to a folder named "Movies" above this directory

media_root="/media/server" #this is the base directory where media files are imported from torrent/nzb client.  Also serves as holder for converted files awaiting import into Plex

# Create folder inside /media manually and chown it to the user you run Plex and torrent client with

MAKE_DIR(){ if [ ! -d "$2" ]; then mkdir "$2"; chmod "$1" "$2"; fi } # $1 sets mode for DIR 770 by default; $2 is name to check/create if it doesn't exist

CHECK_BIN(){ hash $1 2>/dev/null || { echo >&2 "$1 required but it's not installed.  Aborting."; exit 1; }; } #Checks if required binaries are installed

# Required binaries check
for i in "mediainfo" "HandBrakeCLI" "filebot" "ffmpeg"
do
CHECK_BIN "$i"
done

# IFS set to new line to handle spaces in filenames
IFS=$'\n'

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
handbrake_options=" --markers --large-file --encoder x264 --encopts vbv-maxrate=1400:vbv-bufsize=31250:ratetol=inf --crop 0:0:0:0 --strict-anamorphic"
width="$(mediainfo --Inform='Video;%Width%' "$media_root/torrent/Complete/Convert/${1}/${2}")"
height="$(mediainfo --Inform='Video;%Height%' "$media_root/torrent/Complete/Convert/${1}/${2}")"

if (($width > 1280)) || (($height > 720)); then
    max_bitrate="1400"
elif (($width > 720)) || (($height > 576)); then
    max_bitrate="1400"
else
    max_bitrate="1200"
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
    handbrake_options=" $handbrake_options --aencoder ca_aac,copy:ac3"
elif [ "$(mediainfo --Inform='General;%Audio_Format_List%' "$media_root/torrent/Complete/Convert/${1}/${2}" | sed 's| /.*||')" == 'AAC' ]; then
    handbrake_options=" $handbrake_options --aencoder copy:aac"
fi

if [ "$frame_rate" == '29.970' ]; then
    handbrake_options=" $handbrake_options --detelecine"
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

# Check if there are any files to convert in TV directory and then check Movies directory
if [ -n "$(ls -A $media_root/torrent/Complete/Convert/TVShows/)" ]
then
 for i in $(ls -tr $media_root/torrent/Complete/Convert/TVShows/ | tail -1)
 do
 if [ "$i" == "*.mkv" ]
 then
 ffmpeg -i "$media_root/torrent/Complete/Convert/TVShows/$i" -c:v copy -c:a copy "$media_root/torrent/Complete/Convert/TVShows/${i%%.mkv}.mp4"
  if [ $? -eq 0 ]
  then
   rm "$media_root/torrent/Complete/Convert/TVShows/$i"
   i="${i%%.mkv}.mp4"
  fi
 fi
 ENCODE "TVShows" "${i}"
cat /dev/null > /tmp/converted
  mv "$media_root/torrent/Complete/Convert/TVShows/${i%\.*}-converted.mp4" "$media_root/torrent/Complete/Rename/TVShows/" &&  rm -f "$media_root/torrent/Complete/Convert/TVShows/${i}" || rm "$media_root/torrent/Complete/Convert/TVShows/${i%\.*}-converted.mp4"
  filebot -script fn:amc --output "$media_root/torrent/Complete/IMPORT" --action move -non-strict "$media_root/torrent/Complete/Rename/TVShows" --log-file=/dev/null --def excludeList=/tmp/amc.txt --def clean=yes
  if [ $? -eq 0 ]
  then
    echo "[TV Show] ${i} [$(date "+%a %D %H:%M")]" >> ~/converted.log
  fi
 done
fi
if [ -n "$(ls -A $media_root/torrent/Complete/Convert/Movies/)" ]
then
 for i in $(ls -tr $media_root/torrent/Complete/Convert/Movies/ | tail -1)
 do
 if [ "$i" == "*.mkv" ]
 then
 ffmpeg -i "$media_root/torrent/Complete/Convert/Movies/$i" -c:v copy -c:a copy "$media_root/torrent/Complete/Convert/Movies/${i%%.mkv}.mp4"
  if [ $? -eq 0 ]
  then
   rm "$media_root/torrent/Complete/Convert/Movies/$i"
   i="${i%%.mkv}.mp4"
  fi
 fi
 ENCODE "Movies" "${i}"
cat /dev/null > /tmp/converted
  mv "$media_root/torrent/Complete/Convert/Movies/${i%\.*}-converted.mp4" "/media/server/torrent/Complete/Rename/Movies/" &&  rm -f "$media_root/torrent/Complete/Convert/Movies/${i}" || rm "$media_root/torrent/Complete/Convert/Movies/${i%\.*}-converted.mp4"
  filebot -script fn:amc --output "$MOVIE" --action move -non-strict "$media_root/torrent/Complete/Rename/Movies" --log-file=/dev/null --def excludeList=/tmp/amc.txt --def clean=yes
  if [ $? -eq 0 ]
  then
    echo "[Movie] ${i} [$(date "+%a %D %H:%M")]" >> ~/converted.log
  fi
 done
fi
rm $PIDFILE
