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
#     ├── movies
#     ├── music
#     └── tv

# Parse Arguments
set -l root $argv[1]

function create_subdirs
  set -l root_dir $argv[1]
  set -l sub_dir $argv[2]

  mkdir -p "$root_dir/$sub_dir/books" "$root_dir/$sub_dir/movies" "$root_dir/$sub_dir/music" "$root_dir/$sub_dir/tv"
end

# Generate 'torrents' directories
create_subdirs $root "torrents"

# Generate 'media' directories
create_subdirs $root "media"

# Generate 'usenet' directories
mkdir -p "$root/usenet/incomplete"
create_subdirs $root "usenet/complete"
