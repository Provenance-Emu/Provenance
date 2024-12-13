#!/bin/bash

# Check if ImageMagick is installed
if ! command -v magick &> /dev/null
then
    echo "ImageMagick is not installed. Please install it and try again."
    exit 1
fi

# Function to compress image
compress_image() {
    local input_file="$1"
    local temp_file="${input_file}.temp"

    # Convert filename to lowercase for comparison using tr command
    local lowercase_file=$(echo "$input_file" | tr '[:upper:]' '[:lower:]')

    # Compress based on file type
    case "$lowercase_file" in
        *.jpg|*.jpeg)
            magick "$input_file" -sampling-factor 4:2:0 -strip -quality 85 -interlace JPEG -colorspace sRGB "$temp_file"
            ;;
        *.png)
            magick "$input_file" -strip -quality 85 "$temp_file"
            ;;
        *)
            echo "Unsupported file type: $input_file"
            return
            ;;
    esac

    # Compare file sizes
    original_size=$(wc -c < "$input_file")
    compressed_size=$(wc -c < "$temp_file")

    if [ $compressed_size -lt $original_size ]; then
        mv "$temp_file" "$input_file"
        echo "Compressed: $input_file (${original_size} -> ${compressed_size} bytes)"
    else
        rm "$temp_file"
        echo "Skipped: $input_file (compressed size not smaller)"
    fi
}

# Check if any arguments are provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <pattern1> [pattern2 ...]"
    echo "Examples:"
    echo "  $0 '*.jpg'"
    echo "  $0 '*.png' '*.jpg'"
    echo "  $0 '*@2x.png'"
    exit 1
fi

# Process each pattern provided as argument
for pattern in "$@"; do
    # Find matching files and compress
    while IFS= read -r -d '' file; do
        compress_image "$file"
    done < <(find . -type f -name "$pattern" -print0 2>/dev/null)
done

echo "Compression process completed."
