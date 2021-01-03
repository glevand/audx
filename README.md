# AUDX - Audio Exchange

Digital audio utilities.

## rip-c - Rip audio cassettes.

Record, split, and re-encode analog audio from cassette or vinyl.

### rip-c

```
rip-c.sh (audx) - Rip audio cassettes.
Usage: rip-c.sh [flags]
Option flags:
  -h --help         - Show this help and exit.
  -v --verbose      - Verbose execution.
  --base-name       - Output file base name. Default: ''.
  --start-duration  - Silence start duration. Default: '0.2'.
  --start-threshold - Silence start threshold. Default: '0.6%'.
  --end-duration    - Silence end duration. Default: '2.0'.
  --end-threshold   - Silence end threshold. Default: '0.6%'.
  -f --force        - Force overwrite if exisitng output file.
  -c --config-file  - Configuration file. Default: ''.
Option steps:
  -1 --rip-sox      - Rip to sox file.
  -2 --split-sox    - Split sox file.
  -3 --encode-flac  - Encode to flac.
```

### rip-c-to-flac
```
rip-c-to-flac.sh (audx) - Encode SOX files as FLAC.
Usage: rip-c-to-flac.sh [flags] top-dir
Option flags:
  -h --help        - Show this help and exit.
  -v --verbose     - Verbose execution.
  -g --debug       - Extra verbose execution.
Send bug reports to: Geoff Levand <geoff@infradead.org>.
```

### rip-c-flac-tags
```
rip-c-flac-tags.sh (audx) - Add FLAC metadata tags to rip-c files.
Usage: rip-c-flac-tags.sh [flags] top-dir
Option flags:
  -h --help        - Show this help and exit.
  -v --verbose     - Verbose execution.
  -g --debug       - Extra verbose execution.
Send bug reports to: Geoff Levand <geoff@infradead.org>.
```

### rip-c Equipment

![Music Station](images/music-station-sm.jpg)

* [Sony VGN-SZ330P VAIO Notebook](https://www.newegg.com/sony-vaio-sz-series-vgn-sz330p-b/p/N82E16834117394).
* [ART USB Phono Plus Audio Interface](https://artproaudio.com/product/usb-phono-plus-project-series).
* [Sony TC-WE305 Dual Cassette Deck](https://www.sony.com/electronics/support/audio-components-cassette-decks).
* [Sony MDR-DS6000 Wireless Headphones](https://www.crutchfield.com/S-qvDLUN72Ckb/p_158MDR6000/Sony-MDR-DS6000.html).

## FLAC File Ulilities

### flac-add-tracktotal - Add FLAC tracktotal metadata tags.

```
flac-add-tracktotal.sh - Add FLAC tracktotal metadata tags.
Usage: flac-add-tracktotal.sh [flags] top-dir
Option flags:
  -h --help        - Show this help and exit.
  -v --verbose     - Verbose execution.
  -d --dry-run     - Dry run, don't modify files.
  -g --debug       - Extra verbose execution.
```

### flac-clean-tags - Clean FLAC metadata tags using standard rules.

```
flac-clean-tags.sh - Clean FLAC metadata tags using standard rules.
Usage: flac-clean-tags.sh [flags] top-dir
Option flags:
  -h --help        - Show this help and exit.
  -v --verbose     - Verbose execution.
  -d --dry-run     - Dry run, don't modify files.
  -g --debug       - Extra verbose execution.
```

### flac-meta-rename - Rename files based on FLAC metadata tags.

```
flac-meta-rename.sh - Rename files based on FLAC metadata tags.
Usage: flac-meta-rename.sh [flags] top-dir
Option flags:
  -r --various - Use 'Various Artists' logic.
  -h --help    - Show this help and exit.
  -v --verbose - Verbose execution.
  -d --dry-run - Dry run, don't rename files.
  -g --debug   - Extra verbose execution.
```

### flac-print-paths - Print file paths generated from FLAC metadata tags.

```
flac-print-paths.sh - Print file paths generated from FLAC metadata tags.
Usage: flac-print-paths.sh [flags] top-dir
Option flags:
  -h --help        - Show this help and exit.
  -v --verbose     - Verbose execution.
  -g --debug       - Extra verbose execution.
```

### flac-print-tags - Recursively print FLAC metadata tags.

```
flac-print-tags.sh - Recursively print FLAC metadata tags.
Usage: flac-print-tags.sh [flags] top-dir
Option flags:
  -h --help        - Show this help and exit.
  -v --verbose     - Verbose execution.
  -g --debug       - Extra verbose execution.
```

### flac-write-tags - Write new FLAC metadata tags.

```
flac-write-tags.sh - Write new FLAC metadata tags using --tag or --tag-name, --tag-value.
Usage: flac-write-tags.sh [flags] top-dir
Option flags:
  -t --tag         - Full tag 'NAME=VALUE'. Default=''.
  -n --tag-name    - Tag Name. Default=''.
  -l --tag-value   - Tag data. Default=''.'
  -h --help        - Show this help and exit.
  -v --verbose     - Verbose execution.
  -d --dry-run     - Dry run, don't modify files.
  -g --debug       - Extra verbose execution.
```

## Music Collection Utilities

### check-vfat-names - Check vfat file names.

Recursively check for valid vfat file names.

```
check-vfat-names.sh (audx) - Check vfat file names.
Usage: check-vfat-names.sh [flags] top-dir
Option flags:
  -o --output-dir  - Output directory. Default: ''.
  -c --clean-names - Clean file names using standard rules. Default: ''.
  -h --help        - Show this help and exit.
  -v --verbose     - Verbose execution.
  -g --debug       - Extra verbose execution.
```

### m4a-converter - Convert FLAC files to m4a AAC encoded files.

```
m4a-converter.sh - Convert FLAC files to m4a AAC encoded files suitable for download to Walkman type devices.
Usage: m4a-converter.sh [flags] top-dir
Option flags:
  -b --bitrate     - Encoding bitrate. Default: '328k'.
  -o --output-dir  - Output directory. Default: ''.
  -h --help        - Show this help and exit.
  -v --verbose     - Verbose execution.
  -g --debug       - Extra verbose execution.
```

### make-inventory - Make inventory lists of an album collection.

```
make-inventory.sh (audx) - Make inventory lists of an album collection.
Usage: make-inventory.sh [flags] src-directory [src-directory]...
Option flags:
  -o --output-dir  - Output directory. Default: '/tmp/inventory.out'.
  -c --canonical   - Output full canonical paths to lists.
  -t --use-tags    - Use metadata tags to generate lists. Default: ''.
  -h --help        - Show this help and exit.
  -v --verbose     - Verbose execution.
  -g --debug       - Extra verbose execution.
```


### make-playlists - Recursively search for audio files and create m3u playlists.

```
make-playlists.sh - Recursively create m3u album playlists.
Usage: make-playlists.sh [flags] top-dir
Option flags:
  -c --canonical   - Output full canonical paths to playlist.
  -t --file-types  - File extension types {flac mp3 m4a sox wav}. Default: 'flac'.
  -h --help        - Show this help and exit.
  -v --verbose     - Verbose execution.
  -g --debug       - Extra verbose execution.
```

### make-shufflelist.sh - Create an m3u playlist of random albums.

```
make-shufflelist.sh - Create an m3u playlist of random albums.
Usage: make-shufflelist.sh [flags] top-dir
Option flags:
  -c --count       - Number of albums in playlist. Default: '6'.
  -o --output-file - Playlist output file. Default: ''.
  -h --help        - Show this help and exit.
  -v --verbose     - Verbose execution.
  -g --debug       - Extra verbose execution.
```

## Licence & Usage

All files in the [audx project](https://github.com/glevand/audx), unless otherwise noted, are covered by an [MIT Plus License](https://github.com/glevand/audx/blob/master/mit-plus-license.txt).  The text of the license describes what usage is allowed.
