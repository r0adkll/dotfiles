#!/usr/bin/env fish

#
# Helper script to generate the necessary media folder structure for the 
# Servarr application 
#
# ---
#
# Folder Structure:
#
# <root>
# ├── torrents
# │   ├── books
# │   ├── movies
# │   ├── music
# │   └── tv
# ├── usenet
# │   ├── incomplete
# │   └── complete
# │       ├── books
# │       ├── movies
# │       ├── music
# │       └── tv
# └── media
#     ├── books
#     ├── movies-hd
#     ├── movies-uhd
#     ├── music
#     ├── tv-hd
#     └── tv-uhd

# Parse Arguments
set -l root $argv[1]

function create_subdirs
  set -l root_dir $argv[1]
  set -l sub_dir $argv[2]
  set -l is_multiple $argv[3]

  if $is_multiple; then
    mkdir -p "$root_dir/$sub_dir/books" "$root_dir/$sub_dir/music"
    mkdir -p "$root_dir/$sub_dir/movies-hd" "$root_dir/$sub_dir/tv-hd"
    mkdir -p "$root_dir/$sub_dir/movies-uhd" "$root_dir/$sub_dir/tv-uhd"
  else
    mkdir -p "$root_dir/$sub_dir/books" "$root_dir/$sub_dir/movies" "$root_dir/$sub_dir/music" "$root_dir/$sub_dir/tv"
  fi
end

# Generate 'torrents' directories
create_subdirs $root "torrents" false

# Generate 'media' directories
create_subdirs $root "media" true

# Generate 'usenet' directories
mkdir -p "$root/usenet/incomplete"
create_subdirs $root "usenet/complete" false
