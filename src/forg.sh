#!/usr/bin/env bash

src_directory="$1"
output_directory="$2"
config="$HOME/.local/share/forg.conf" # Sources filenames and extensions
logs="$HOME/.cache/forg.logs"
KILLDUPLICATE=false
DRYMODE=false

readonly config_ext
readonly config_dir

function help() {
  cat <<EOF
File Organizer
Usage: $0 [source-directory] [dest-directory] [options]
Available Options:
- dry                - Give a preview of the command
- rmdup              - Remove duplicate files
- help               - Display this message and exits
EOF
}

move() {
  find "$src_directory" -type f -print0 | while IFS= read -r -d $'\0' file; do
    filename=$(basename "$file")
    file_tag="${filename%%\%*}"
    extension="${filename##*.}"
    destination_subpath=""

    case "$method" in
    ftp)
      destination_subpath="${ftp[$extension]}"
      ;;
    *)
      map="${method}"
      eval "destination_subpath=\${$map[\$file_tag]}"
      ;;
    esac

    # Ensure destination_dir is valid
    if [[ -n "$destination_subpath" ]]; then
      destination_dir="$output_directory/$destination_subpath"
    else
      destination_dir="$output_directory/others"
    fi

    if [ ! -d "$destination_dir" ]; then
      mkdir -p "$destination_dir"
    fi

    # Check if the file already exists in the destination
    if [[ -e "$destination_dir/$filename" ]]; then
      if [ "$KILLDUPLICATE" = "true" ]; then
        rm "$file"
        echo "Duplicate file: '$filename' removed"
      else
        echo "File '$filename' already exists in '$destination_dir'! Possible duplicate?"
      fi
      continue
    fi

    # Move the file
    if [ "$DRYMODE" = "true" ]; then
      echo "Move file: $file ==> $destination_dir"
    else
      if mv -n "$file" "$destination_dir" 2>"$logs"; then
        echo "Moved '$filename' to '$destination_dir'"
      else
        echo "Error moving '$filename' to '$destination_dir'.  Check '$logs' for details." >&2
      fi
    fi
  done
  echo "Complete!"
}

function main() {
  echo "Choose an organize method:"
  echo "ftp - Apply changes based on filetype"
  echo "* - Apply filename rules from config"
  echo ""
  read method

  if [ "$DRYMODE" = "true" ]; then
    echo "Dry Mode:"
  fi

  move
}

# Check for optional arguments
case "$3" in
dry)
  DRYMODE=true
  ;;
rmdup)
  KILLDUPLICATE=true
  ;;
help)
  help
  exit 0
  ;;
esac

# Check required arguments
if [ -z "$src_directory" ] || [ -z "$output_directory" ]; then
  echo "Error: Missing required arguments"
  help
  exit 1
fi

# Same directory warning
if [ "$src_directory" == "$output_directory" ]; then
  echo "Be careful! You are running this script in the same directory!"
  echo "If this directory is overpopulated, it may take longer"
  select choice_continue in "Yes" "No"; do
    case $choice_continue in
    Yes) break ;;
    No) exit 0 ;;
    esac
  done
fi

# Check for config files and source them
if [[ ! -f "$config" ]]; then
  echo "Error: forg.conf not found.  Exiting." >&2
  exit 1
else
  # shellcheck disable=SC1090
  source "$config"
  val=$?
  if [ "$val" -ne 0 ]; then
    echo "Failed to source configuration files"
    exit 1
  fi
fi

main
