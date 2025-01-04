#!/bin/bash

playlistName=$1
csvFile="$(dirname "$0")/tmp/albums.csv"
phoneRoot=${2:-"/storage/sdcard0/syncr"}

ts-node export.ts "$playlistName" | sort -u > "$csvFile"

echo "file exported in $csvFile"

read -p "Are you sure you want to delete all files in $phoneRoot? [y/N] " confirm
if [[ $confirm == [yY] ]]; then
  adb rm -rf "$phoneRoot"
else
  echo "Operation cancelled."
  exit 1
fi

adb rm -rf "$phoneRoot"

while IFS=$'\t' read -r -a values; do
  trackDir=${values[0]}
  subDir=${values[1]}

  #echo $trackDir
  #echo $phoneRoot/$subDir

  # exclude hidden MacOS files like ._05 Diaraby.mp3 next to 05 Diaraby.mp3
  adbsync --exclude "._*" push "$trackDir/" "$phoneRoot/$subDir/"
done < "$csvFile"
