# PlexScripts
A collection of scripts to assist with running an automated Plex media server based on Linux.  Simply download "batch_encode.sh" and "encode.sh" and make them executable with 

"chmod +x batch_encode.sh; chmod +x encode.sh"

Then use your favorite editor to change the directories in batch_encode.sh

As long as you use different directories for each process and have Sickrage, etc. grab media from the TV_IMPORT directory this script will convert media you send it into a Roku, AppleTV friendly mp4 media file capable of direct-play in Plex.

Run the script manually the first time and when you are satisfied everything works add it to your crontab with the commands included in the script.  
