#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <playlistName> [phoneRoot]"
  exit 1
fi

playlistName=$1
csvFile="$(dirname "$0")/tmp/$playlistName.csv"
phoneRoot=${2:-"/storage/sdcard0/syncr"}

# Create the albums csv file
ts-node export.ts "$playlistName" | sort -u > "$csvFile"

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

# Create an array of directories in phoneRoot
phoneDirs=()
tempFile=$(mktemp)
adb shell find "$phoneRoot" -mindepth 2 -maxdepth 2 -type d > "$tempFile"
while IFS= read -r dir; do
  phoneDirs+=("$dir")
done < "$tempFile"
rm "$tempFile"

# List all directories in phoneRoot and find those not in csvDirs
dirsToDelete=()
for phoneDir in "${phoneDirs[@]}"; do
  found=false
  for csvDir in "${csvDirs[@]}"; do
    if [[ "$phoneDir" == *"$csvDir" ]]; then
      found=true
      break
    fi
  done
  if [ "$found" = false ]; then
    dirsToDelete+=("$phoneDir")
  fi
done

# Display the list of directories to be deleted
if [ ${#dirsToDelete[@]} -gt 0 ]; then
  echo "Directories to be deleted:"
  for dir in "${dirsToDelete[@]}"; do
    echo "$dir"
  done

  read -p "Are you sure you want to delete these directories in $phoneRoot? [y/N] " confirm
  if [[ $confirm != [yY] ]]; then
    echo "Operation cancelled."
    exit 1
  fi

  # Delete the directories
  for dir in "${dirsToDelete[@]}"; do
    echo "Deleting $dir"
    adb shell rm -rf $(printf %q "$dir")
  done
else
  echo "No directories to delete."
fi

while IFS=$'\t' read -r -a values; do
  trackDir=${values[0]}
  subDir=${values[1]}
  
  echo $subDir

  # exclude hidden MacOS files like ._05 Diaraby.mp3 next to 05 Diaraby.mp3
  adbsync -q --show-progress --exclude "._*" push "$trackDir/" "$phoneRoot/$subDir/"
done < "$csvFile"