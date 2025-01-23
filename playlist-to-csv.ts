/*
This script dumps the list of albums from a particular playlist, reading the entire iTunes library file.
 */

import itunes from "itunes-data";
import * as fs from "fs";
import {ReadStream} from "fs";
import path from "path";

// Get the playlist name from command-line arguments and the library path assumes it's coming from current dir tmp/Library.xml
const playlistName = process.argv[2];
const libraryPath = path.join(__dirname, 'tmp', 'Library.xml');

function init(): { parser: NodeJS.WritableStream, stream: ReadStream } {
  return {
    parser: itunes.parser(),
    stream: fs.createReadStream(libraryPath)
  }
}

/*
parser.on("track", track => {
  console.log("track:", track);
});

parser.on("album", album => {
  console.log("album:", album);
});

 */

interface PlaylistItem {
  "Track ID": number
}

interface Playlist {
  Name: string,
  "Playlist Items": PlaylistItem[]
}

interface Track extends PlaylistItem {
  Location: string,
  'File Folder Count': number
}

function toPath(url: string) {
  return decodeURI(url
    .replace(/^file:\/\//, '')
  )
}

// First run, get the playlist
const firstRun = init();
let musicFolder: string | undefined = undefined;

interface Library {
  "Music Folder": string;
}

firstRun.parser.on("library", (library: Library) => {
  musicFolder = toPath(library["Music Folder"])
})

firstRun.parser.on("playlist", (playlist: Playlist) => {
  if (playlist.Name == playlistName) {
    firstRun.stream.close();

    // Second run, get the tracks
    const tracks = (<Playlist>playlist)["Playlist Items"]
      .map(i => i["Track ID"])
      .reduce((accumulator: { [id: number]: boolean }, current: number) => {
        accumulator[current] = true;
        return accumulator
      }, {});
    let regExp = new RegExp(`^${musicFolder!}`);
    const secondRun = init();
    secondRun.parser.on("track", (t: Track) => {
      if (tracks[t["Track ID"]]) {
        // Is in the playlist
        const trackPath = toPath(t.Location)
        const trackDir = path.dirname(trackPath)
        const subDir = trackDir.replace(regExp, '')
        console.log(`${trackDir}\t${subDir}`)
        // TODO adb-sync
      }
    });
    secondRun.stream.pipe(secondRun.parser);
  }
});
firstRun.stream.pipe(firstRun.parser);
