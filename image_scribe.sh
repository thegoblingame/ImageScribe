#!/bin/bash

echo_output=false
exec &> output.txt

conditional_echo() {
  local input=$1
  if [ "$echo_output" = true ]; then
      echo $input
  fi
}

output_execution_status() {
  if ! [ $? -eq 0 ]; then
    echo "Error processing image: $image"
  fi
}

rename_duplicates() {
  declare -A filenames
  for image in input_images/*; do
      base_name="${image%.*}"
      extension="${image##*.}"
      if [[ -z "${filenames["$base_name"]}" ]]; then
          filenames["$base_name"]=0
      else
          ((filenames["$base_name"]++))
          new_name="${base_name}_${filenames["$base_name"]}.$extension"
          mv "$image" "$new_name"
          conditional_echo "Renamed $image to $new_name"
      fi
  done
}

detect_jpegs() {
  for image in input_images/*.{png,PNG}; do
    filetype=$(file --brief --mime-type "$image")
    if [[ "$filetype" == "image/jpeg" ]]; then
        conditional_echo "mislabeled JPG detected, renaming from PNG to JPG"
        exiftool "-filename=%f.jpg" "$image"
    fi
  done
}

while getopts "edj" opt; do
  case ${opt} in 
    e )
      echo_output=true
      ;;
    d )
      rename_duplicates
      ;;
    j )
      detect_jpegs
      ;;
    \? )
      echo "Usage: cmd [-d] [-j] [-e]"
      exit 1
      ;;
  esac
done


for image in ./input_images/*; do
  filetype=$(file --brief --mime-type "$image")
  conditional_echo $image
    if [[ $filetype == "image/png" ]]; then
      new_image="${image%.*}.jpg"
      magick convert "$image" "$new_image"
      image="$new_image"
      text=$(tesseract "$image" stdout)
      output_execution_status
      exiftool -charset FileName=UTF8 -overwrite_original -Title="$text" "$image" -o ./output_images/"$(basename "$image")"
    else 
      text=$(tesseract "$image" stdout)
      output_execution_status
      exiftool -charset FileName=UTF8 -Title="$text" "$image" -o ./output_images/"$(basename "$image")"
    fi
done

exit