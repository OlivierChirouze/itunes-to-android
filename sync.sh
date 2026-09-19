#!/bin/bash
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <playlistName> [phoneRoot]"
  exit 1
fi

playlistName=$1
csvFile="$(dirname "$0")/tmp/$playlistName.csv"
tsFile="$(dirname "$0")/playlist-to-csv.ts"
phoneRoot=${2:-"/storage/sdcard0/syncr"}

# Quote a string for remote shell usage: wrap in single quotes and escape any single quotes inside
sh_quote() {
  # replace each ' with '\'' and wrap whole result in single quotes
  printf "%s" "'$'" >/dev/null 2>&1 || true
  printf "'%s'" "$(printf "%s" "$1" | sed "s/'/'\\''/g")"
}


# Create the albums csv file. Write to a tmp file first so a failure in
# ts-node does not leave behind an empty/partial csv that would later be
# interpreted as "every phone directory must be deleted".
csvTmp="$csvFile.partial"
trap 'rm -f "$csvTmp"' EXIT
ts-node "$tsFile" "$playlistName" | sort -u > "$csvTmp"
mv "$csvTmp" "$csvFile"

lineCount=$(wc -l < "$csvFile")
echo "file exported in $csvFile with $lineCount albums found"

if [ "$lineCount" -eq 0 ]; then
  echo "Aborting: no albums were exported for playlist '$playlistName'." >&2
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

# Create an array of directories in phoneRoot
phoneDirs=()
tempFile=$(mktemp)
cmd=$(printf "find %s -mindepth 2 -maxdepth 2 -type d" "$(sh_quote "$phoneRoot")")
adb shell "$cmd" > "$tempFile"
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
    cmd=$(printf "rm -rf %s" "$(sh_quote "$dir")")
    adb shell "$cmd"
  done
else
  echo "No directories to delete."
fi

while IFS=$'\t' read -r -a values; do
  trackDir=${values[0]}
  subDir=${values[1]}
  
  echo "$subDir"

  # exclude hidden MacOS files like ._05 Diaraby.mp3 next to 05 Diaraby.mp3
  adbsync -q --show-progress --del --exclude "._*" push "$trackDir/" "$phoneRoot/$subDir/"
done < "$csvFile"