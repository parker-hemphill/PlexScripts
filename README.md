# PlexScripts
A collection of scripts to assist with running an automated Plex media server based on Linux.

Simply change the variables at the top of the files to set the directories to use.  You also need to have ffmpeg, HandBrakeCLI, and filebot installed and in your users path (you can simply type each of those names verbatim into your terminal and recieve output) and add the following to your crontab:

Type "crontab -e" and paste all between the hashes into your terminal window:
#####
* * * * * /var/tmp/batch_move.sh >> /dev/null 2>&1
* * * * * /var/tmp/convert_tv.sh >> /dev/null 2>&1
*/5 * * * * /var/tmp/convert_movie.sh >> /dev/null 2>&1
#####
This will check every minute for newly downloaded files and move them to be encoded.  It will also encode movies every 5 minutes and tv shows every minute.
