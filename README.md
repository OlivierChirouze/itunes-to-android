# Purpose

Synchronize a playlist from iTunes to an Android device.

Warning: this will consider only full albums are selected in the playlist.

# Prerequisites
- install adb
  - see https://www.xda-developers.com/install-adb-windows-macos-linux/
  - and add `adb` to path
- install adbsync
```shell
pip install BetterADBSync
```
- npm install here
```shell
npm install
```

# Usage

First export the entire library in Music.app, to this directory under `tmp/Library.xml`

`File > Library > Export library...`

![iTunes-export.png](iTunes-export.png)

```shell
# cd to this directory and start sync
sh sync.sh "YourPlaylistName"
```