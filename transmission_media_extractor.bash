#!/bin/bash

#####################################################################################################################################
#########################################################Manual DIR and NAME#########################################################
#####################################################################################################################################
# Variables can be manually populated for testing or use with another program other than Transmission.
#TR_TORRENT_DIR="media/mediashare/downloads/complete/sonarr"
#TR_TORRENT_NAME="Sample.TV.Show.S01E01.1080p.BluRay.x264"
#####################################################################################################################################

# Gets current directory for the script.
# This works for aliases, source, bash-c, symbolic links, etc.
source="${bash_source[0]}"
# Loops source
while [ -h "$source" ]; do
    # Gets DIR and hides output
    dir="$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )"
    # Gets source
    source="$(readlink "$source")"
    # If the source is a symlink, this will set the path to where the symlink file is located
    [[ $source != /* ]] && source="$dir/$source"
done
# Sets script directory
scriptDIR="$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )"

# Sets log path
# Script dir is used by default
# This is needing when using bind mounts with docker
logFile="$scriptDIR/transmission_media_extractor.log"

# Log cleanup in case it gets too big
# Sets the minimum log size in bytes
# Setting to 1 Megabyte
minimumLogSize=1000000
# Checks if the log file exists
if test -f "$logFile"; then
    # Gets actual log file size
    actualLogSize=$(wc -c <"$logFile")
    if [ $actualLogSize -ge $minimumLogSize ]; then
        # Clears log file
        truncate -s 0 $logFile
    fi
fi


printf "#######################################################################################" |  (tee -a ${logFile} )
printf "%s\n##############################Starting Media Extractor#################################" |  (tee -a ${logFile} )
printf "%s\n#######################################################################################" |  (tee -a ${logFile} )

# Sets media_RAR_FullPathName & Sets media_MKV_FullPathName
# Parameters are filled with information passed in from Transmission.
media_RAR_Directory="/$TR_TORRENT_DIR/$TR_TORRENT_NAME"
media_RAR_FullPathName=$(find /$TR_TORRENT_DIR/$TR_TORRENT_NAME -name *".rar")
media_MKV_FullPathName=$(find /$TR_TORRENT_DIR/$TR_TORRENT_NAME -name *".mkv")


# Checks which file types are in the media downloaded folder.
# This is used to determine if a RAR file needs to be extracted.
if [[ -n "$media_RAR_FullPathName" ]] && [[ -z "$media_MKV_FullPathName" ]]; then

    # RAR file found in the media folder
    printf "%s\n$(date)|Info|RAR file found in $TR_TORRENT_NAME. Continuing with processing" |  (tee -a ${logFile} )

elif [[ -n "$media_MKV_FullPathName" ]] && [[ -z "$media_RAR_FullPathName" ]]; then
    
    # MKV file found in the media folder
    printf "%s\n$(date)|Info|MKV file found in $TR_TORRENT_NAME. No extraction required" |  (tee -a ${logFile} )

    # Blank line
    printf "%s\n" |  (tee -a ${logFile} )

    exit

elif [[ -n "$media_MKV_FullPathName" ]] && [[ -n "$media_RAR_FullPathName" ]]; then

    # Skipping because RAR and MKV both exist
    printf "%s\n$(date)|Info|RAR and MKV file found in $TR_TORRENT_NAME. No extraction required" |  (tee -a ${logFile} )

    # Blank line
    printf "%s\n" |  (tee -a ${logFile} )

    exit

else

    # Error because no RAR and MKV found
    printf "%s\n$(date)|Error|RAR or MKV file not found in $TR_TORRENT_NAME. Manual intervention is required" |  (tee -a ${logFile} )

    # Blank line
    printf "%s\n" |  (tee -a ${logFile} )

    exit

fi


printf "%s\n$(date)|Info|Media Directory = /$TR_TORRENT_DIR" |  (tee -a ${logFile} )
printf "%s\n$(date)|Info|Media RAR Name = $TR_TORRENT_NAME" |  (tee -a ${logFile} )
printf "%s\n$(date)|Info|Media RAR Directory = $media_RAR_Directory" |  (tee -a ${logFile} )
printf "%s\n$(date)|Info|Media RAR Full Path Name = $media_RAR_FullPathName" |  (tee -a ${logFile} )
printf "%s\n$(date)|Info|Compressed Media Details Below" |  (tee -a ${logFile} )

# Blank line before bulk output
printf "%s\n" |  (tee -a ${logFile} )

# Logs console and log
printf "%s\n------------------------------------------------------------------------------------------------------------------------------" |  (tee -a ${logFile} )

# Blank line
echo ""

#######################################################################################################################################################
# FIFO is needed for unrar console/log file pipe. Needs defined peruse.
# Some shells do not support process substitution with 'tee,' making sure the output gets put into the output stream.
# FIFO is a special file that allows multiple read/writes and passes data internally without writing to the filesystem, which will allow piped output to be shown.
# Use Case: The transmission docker created by linux.io will not work with 'tee,' but this allows the output to work correctly.
###################################################################################################
fifo=$(mktemp -u); mkfifo $fifo;
cat "$fifo" &

# Gets rar file details
# Two different 'tee' commands
#   - 1st: tee $fifo allows output to the console when storing to a variable.
#   - 2nd: tee -a ${logFile} appends data to the log file.
compressedFileDetails=$(unrar l $media_RAR_FullPathName | tee "$fifo" | (tee -a ${logFile}))

# Blank line
echo ""

# Logs console and log
printf "%s\n------------------------------------------------------------------------------------------------------------------------------" |  (tee -a ${logFile} )

# Blank line
printf "%s\n" |  (tee -a ${logFile} )

# FIFO is needed for unrar console/log file pipe. Needs defined peruse.
fifo=$(mktemp -u); mkfifo $fifo;
cat "$fifo" &

# This section of code uses unrar to pull details about the media file.
: <<'##############################################################Return-Example##############################################################'
UNRAR 5.61 beta 1 freeware      Copyright (c) 1993-2018 Alexander Roshal

Archive: /media/mediashare/downloads/complete/sonarr/Sample.TV.Show.S01E01.1080p.BluRay.x264/Sample.TV.Show.S01E01.1080p.BluRay.x264.rar
Details: RAR 4, volume

Attributes      Size     Date    Time   Name
----------- ---------  ---------- -----  ----
..A.... 9997780478  2017-11-30 02:58  Sample.TV.Show.S01E01.1080p.BluRay.x264.mkv
----------- ---------  ---------- -----  ----
9997780478  volume 1          1
##############################################################Return-Example##############################################################
# This greps with a space, so it only pulls the returned media file name instead of the archive path.
# grep, by default, is case-sensitive. Using the -i will match upper or lower. The folder and filename may be opposite insensitive.
# sed Options:
#   -e = script
#   's/\('$TR_TORRENT_NAME' = sets substitution match search string
#   \) = ends the named block
#   .* = match everything
#   $ = stop matching at the end of the line
#   / = ends the substitute search section
#   \NewBlock = replaces with the search string
#   & = adds anything after the search string
#   / = ends the replacement
#   I = allows insensitive search
#   -e = script
#   s/.* = match everything
#   \NewBlock/ = replace everything with replacement name block
compressedFileName=$(unrar l $media_RAR_FullPathName | grep -i " $TR_TORRENT_NAME" | sed -e 's/\('$TR_TORRENT_NAME'\).*$/\NewBlock&/I' -e 's/.*\NewBlock//')


# Logs console and log
printf "%s\n$(date)|Info|Compressed File Name = $compressedFileName" |  (tee -a ${logFile} )
printf "%s\n$(date)|Info|Starting Media Extraction For $TR_TORRENT_NAME" |  (tee -a ${logFile} )
printf "%s\n$(date)|Info|Please wait....." |  (tee -a ${logFile} )

# Blank line before bulk output
printf "%s\n" |  (tee -a ${logFile} )

# Logs console and log
printf "%s\n------------------------------------------------------------------------------------------------------------------------------" |  (tee -a ${logFile} )

# Blank line
printf "%s\n" |  (tee -a ${logFile} )

# This section of code uses unrar to extract the media file.
# Extracts file into root media file folder.
# Two different 'tee' commands
#   - 1st: tee $fifo allows output to the console when storing to a variable
#   - 2nd: tee -a ${logFile} appends data to the log file
: <<'##############################################################Return-Example##############################################################'
Extracting from /media/mediashare/downloads/complete/sonarr/Sample.TV.Show.S01E01.1080p.BluRay.x264/Sample.TV.Show.S01E01.1080p.BluRay.x264.r83

...         Sample.TV.Show.S01E01.1080p.BluRay.x264.mkv       99%

Extracting from /media/mediashare/downloads/complete/sonarr/Sample.TV.Show.S01E01.1080p.BluRay.x264/Sample.TV.Show.S01E01.1080p.BluRay.x264.r84

...         Sample.TV.Show.S01E01.1080p.BluRay.x264.mkv       OK 
All OK
##############################################################Return-Example##############################################################
compressedFileDetails=$(unrar e -r -o- $media_RAR_FullPathName $media_RAR_Directory | tee "$fifo" | (tee -a ${logFile}))

# Blank line
echo ""

# Log and append file
printf "%s\n------------------------------------------------------------------------------------------------------------------------------" |  (tee -a ${logFile} )

# Blank line
echo ""

# Log and append file
printf "%s\n$(date)|Info|Validating file extracted" |  (tee -a ${logFile} )


# This section of code makes sure the extraction returns 'All OK" at the end.
if [[ "$compressedFileDetails" == *"All OK"* ]]; then
   printf "%s\n$(date)|Success|$compressedFileName extract validation passed" |  (tee -a ${logFile} )
else
   printf "%s\n$(date)|Error|$compressedFileName extract validation failed" |  (tee -a ${logFile} )
fi

# Log and append file
printf "%s\n$(date)|Info|Validating if /$TR_TORRENT_DIR/$TR_TORRENT_NAME/$compressedFileName exists" |  (tee -a ${logFile} )

# Checks if the extracted file exists.
# This check is dependent on the scene packaging the RAR having the same Media file name as the medias root folder.
# Failure could result in a failed test, but the contents could still exist.
if test -f "/$TR_TORRENT_DIR/$TR_TORRENT_NAME/$compressedFileName"; then
    printf "%s\n$(date)|Success|$compressedFileName destination validation passed" |  (tee -a ${logFile} )
else
    printf "%s\n$(date)|Error|$compressedFileName destination validation failed" |  (tee -a ${logFile} )
fi

#Blank line at end
printf "%s\n" |  (tee -a ${logFile} )
