# PlexScripts
A collection of scripts for Plex Media server.  As I clean up scripts I will add them and try to add plenty of comments.  If anything is unclear send me a message on Facebook.  If you see this project you are most likely in one of the Linux groups I'm a member of.

Parker

PS: Modify $media_root to set your base directory.  The script creates the needed sub directories

####### batch_convert description below ###
I run this script every minute via crontab.  The idea is my download client drops the movie or tv show into respective directory in "$media_root/torrent/Complete/TVShows".   The script then grabs only media files and moves them to "$media_root/torrent/Complete/Convert/TVShows" while also purging the left over files.  Next Handbrake converts and moves to "$media_root/torrent/Complete/Rename".  Finally filebot renames and moves to "$media_root/torrent/Complete/IMPORT/Show/Season/Episode"  At this point Sonnar or Sickrage imports to media directory.  The final step is to limit incorrect shows being imported.  Anything renamed incorrectly simply sits in this directory until you purge it or rename correctly.  Filebot gets it correct about 95% of the time so there is little effort needed.  Options are customizable explained by comments in script.  Once this grabs a file the companion check_health.sh script will see handbrake running during healthchecks and report on the status of movie.
