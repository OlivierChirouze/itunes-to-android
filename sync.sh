#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <playlistName> [phoneRoot]"
  exit 1
fi

playlistName=$1
csvFile="$(dirname "$0")/tmp/$playlistName.csv"
phoneRoot=${2:-"/storage/sdcard0/syncr"}

ts-node export.ts "$playlistName" | sort -u > "$csvFile"

lineCount=$(wc -l < "$csvFile")
echo "file exported in $csvFile with $lineCount lines"

read -p "Are you sure you want to delete directories in $phoneRoot that are not in $csvFile? [y/N] " confirm
if [[ $confirm != [yY] ]]; then
  echo "Operation cancelled."
  exit 1
fi

# Create an array of directories from the csvFile
csvDirs=()
tempFile=$(mktemp)
cut -f2 "$csvFile" | sort -u > "$tempFile"
while IFS= read -r subDir; do
  csvDirs+=("$subDir")
done < "$tempFile"
rm "$tempFile"

# List all directories in phoneRoot
adb shell find "$phoneRoot" -mindepth 2 -maxdepth 2 -type d | while read -r dir; do
  subDir=${dir#"$phoneRoot"}
  subDir=${subDir#/}  # Remove leading slash if it exists
  found=false
  for csvDir in "${csvDirs[@]}"; do
    if [[ "$subDir" == "$csvDir" ]]; then
      found=true
    fi
  done
  if [[ "$found" == false ]]; then
    adb shell rm -rf "$dir"
  fi
done

while IFS=$'\t' read -r -a values; do
  trackDir=${values[0]}
  subDir=${values[1]}

  #echo $trackDir
  #echo $phoneRoot/$subDir

  # exclude hidden MacOS files like ._05 Diaraby.mp3 next to 05 Diaraby.mp3
  adbsync --exclude "._*" push "$trackDir/" "$phoneRoot/$subDir/"
done < "$csvFile"