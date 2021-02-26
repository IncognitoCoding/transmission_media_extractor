# transmission_media_extractor

transmission_media_extractor is a post-processing script used for extracting compressed RAR media upon torrent completion. Using software like Sonarr/Radarr, you have the ability to move/rename automatically. Sonarr/Radarr will not extract compressed files, so this script will prepare the media file to allow Sonarr/Radarr to do its magic.

IncognitoCoding will always provide additional comments in the code to help anyone understand the script's flow/functionality.

This script was designed with detailed logging in mind. Extracting files with a single line is possible with post-processing, but any failures would be unknown. This script does two different checks at the end of the script to verify the compressed media file extracted successfully, and the media file exists in the destination.

The extracted media file will remain in the extracted folder directory. The media file needs to exist until moved to the file's final destination (ex: media files) using Sonarr/Radarr or another program. Once the torrent is deleted, the extracted media file will be deleted as well.

## Script Info:
* Extracted media file will extract into the media files root folder. Allows easy import of .nfo files from Sonarr/Radarr.
* The log file auto clears at 1 Megabyte.
* Lots of additional comments.
* No script edits required to use this script.

## Tested On:
* Ubuntu 20.04
* linuxserver/transmission container

## Software Prerequistes:
* Host Install: Requires unrar to be installed on the Linux server
* linuxserver/transmission container: no action required

## How To Use:
Transmission allows you to edit a file called settings.json to enable post-processing upon torrent completion. The directory can vary, so I will not specify a path for host-installed Transmission instances, but I will give some details around the linuxserver/transmission container deployment.

##### settings.json edits
* "script-torrent-done-enabled": true, 
* "script-torrent-done-filename": "/your/script path/transmission_media_extractor.bash",

### Docker Setup:
All steps are completed on the docker host. These steps add the script to the bind mount directory linked between the host and docker container. The script will live on the docker host but execute from the Transmission container. 

* Step 1: Copy the transmission_media_extractor.bash into the directory you used for the bind mount. (/path to data:/config)
* Step 2: Set the correct permissions on the script, or you will get an access denied error during execution. Run: chmod +x transmission_media_extractor.bash
* Step 3: Edit your new settings.json file and update the "script-torrent-done-*" options.
* Step 3.1: "script-torrent-done-enabled": true,
* Step 3.2:  "script-torrent-done-filename": "/config/transmission_media_extractor.bash",
* Step 4: Restart Transmission if it is running.
* Step 5 (Sonarr/Radarr): Enable Completed Download Handling

### Viewing Logs:
The script is designed to output logs to a file and console. 
* Log File: You can find the log file in the script root named transmission_media_extractor.log
* linuxserver/transmission container: You can view the output in the main transmission log output. Having console output enabled on the script allows Transmission to redirect the script's output into the transmission log. If you are using something like Portainer, this makes it easy to view the output.

### Manual Testing:
Transmission provides the "Torrent_DIR" and "Torrent_NAME" during post-processing, so nothing has to be modified in the script to know what media file needs to be processed. If you choose to test the script manually, a section at the top of the script has been comment blocked out to allow manual testing. Also, the script has the ability to be used with other applications as long as the "TR_TORRENT_DIR" and "TR_TORRENT_NAME" variables are populated with information.

Testing the script can be time-consuming when waiting on new torrents to download. When needing to test the post-processing process, delete the .nfo file on a torrent that's already downloaded. Go into Transmission and click "VERIFY LOCAL DATA". This, in return, will have Tranmssion re-download the .nfo file and trigger post-processing on that media file.

#### Non-Media RAR:
Any non-media RAR files will process, but errors may occur because the validation process is based on media files.
