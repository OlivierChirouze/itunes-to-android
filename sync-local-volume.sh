#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <playlistName> [volumePath]"
  exit 1
fi

playlistName=$1
csvFile="$(dirname "$0")/tmp/$playlistName.csv"
tsFile="$(dirname "$0")/playlist-to-csv.ts"
volumePath=${2:-"/Volumes/MP3/"}

# Create the albums csv file
ts-node "$tsFile" "$playlistName" | sort -u > "$csvFile"

lineCount=$(wc -l < "$csvFile")
echo "file exported in $csvFile with $lineCount albums found"

# Create an array of directories from the csvFile
csvDirs=()
tempFile=$(mktemp)
cut -f2 "$csvFile" | sort -u > "$tempFile"
while IFS= read -r subDir; do
  csvDirs+=("$subDir")
done < "$tempFile"
rm "$tempFile"

# Create an array of directories in volumePath
volumeDirs=()
if [ -d "$volumePath" ]; then
  tempFile=$(mktemp)
  find "$volumePath" -mindepth 2 -maxdepth 2 -type d > "$tempFile"
  while IFS= read -r dir; do
    volumeDirs+=("$dir")
  done < "$tempFile"
  rm "$tempFile"
fi

# List all directories in volumePath and find those not in csvDirs
dirsToDelete=()
for volumeDir in "${volumeDirs[@]}"; do
  found=false
  for csvDir in "${csvDirs[@]}"; do
    if [[ "$volumeDir" == *"$csvDir" ]]; then
      found=true
      break
    fi
  done
  if [ "$found" = false ]; then
    dirsToDelete+=("$volumeDir")
  fi
done

# Display the list of directories to be deleted
if [ ${#dirsToDelete[@]} -gt 0 ]; then
  echo "Directories to be deleted:"
  for dir in "${dirsToDelete[@]}"; do
    echo "$dir"
  done

  read -p "Are you sure you want to delete these directories in $volumePath? [y/N] " confirm
  if [[ $confirm != [yY] ]]; then
    echo "Operation cancelled."
    exit 1
  fi

  # Delete the directories
  for dir in "${dirsToDelete[@]}"; do
    echo "Deleting $dir"
    rm -rf "$dir"
  done
else
  echo "No directories to delete."
fi

while IFS=$'\t' read -r -a values; do
  trackDir=${values[0]}
  subDir=${values[1]}
  
  echo $subDir

  # Create destination directory if it doesn't exist
  mkdir -p "$volumePath/$subDir"

  # exclude hidden MacOS files like ._05 Diaraby.mp3 next to 05 Diaraby.mp3
  rsync --progress --archive --exclude "._*" "$trackDir/" "$volumePath/$subDir/"
done < "$csvFile"