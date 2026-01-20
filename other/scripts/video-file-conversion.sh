#!/bin/zsh

# Check if folder argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <input_folder>"
    echo "Example: $0 /path/to/videos"
    exit 1
fi

INPUT_FOLDER="$1"

# Check if input folder exists and is a directory
if [ ! -d "$INPUT_FOLDER" ]; then
    echo "Error: '$INPUT_FOLDER' is not a valid directory."
    exit 1
fi

# Count total files to process
total_files=$(find "$INPUT_FOLDER" -maxdepth 1 -type f ! -name "._*" \( -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.wmv" -o -iname "*.flv" -o -iname "*.webm" \) | wc -l)

if [ "$total_files" -eq 0 ]; then
    echo "⚠️  No video files found in '$INPUT_FOLDER'"
    exit 0
fi

echo "🎬 Found $total_files video file(s) to process in '$INPUT_FOLDER'"
processed=0
failed=0

# Build array of all video files (compatible with bash 3.2+)
video_files=()
while IFS= read -r -d '' file; do
    video_files+=("$file")
done < <(find "$INPUT_FOLDER" -maxdepth 1 -type f ! -name "._*" \( -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.wmv" -o -iname "*.flv" -o -iname "*.webm" \) -print0)

# Process each video file in the folder
for input_file in "${video_files[@]}"; do
    # Get filename without extension and create output filename
    filename=$(basename -- "$input_file")
    name_without_ext="${filename%.*}"
    output_file="$(dirname -- "$input_file")/${name_without_ext}_converted.mp4"

    echo "⚙️  Processing: $filename"

    # Check if file is already in target format
    video_codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>/dev/null)
    audio_codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>/dev/null)
    format_name=$(ffprobe -v error -show_entries format=format_name -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>/dev/null)

    if [ "$video_codec" = "hevc" ] && [ "$audio_codec" = "aac" ] && echo "$format_name" | grep -q "mp4"; then
        echo "⏭️  Skipping (already in target format): $filename"
        echo ""
        continue
    fi

    # Run ffmpeg conversion
    if ffmpeg -i "$input_file" -c:v hevc_videotoolbox -pix_fmt p010le -c:a aac -b:a 384k -ac 6 -sn -map 0:v -map 0:a:0 -movflags +faststart "$output_file" -y; then
        # Check if output file was created and has reasonable size
        if [ -f "$output_file" ] && [ -s "$output_file" ]; then
            output_size=$(stat -f%z "$output_file" 2>/dev/null || echo "0")
            if [ "$output_size" -gt 1000 ]; then  # At least 1KB
                echo "✓ Successfully converted: $filename"
                echo "  Deleting original file: $input_file"
                rm "$input_file"
                echo "  Renaming converted file to original name"
                mv "$output_file" "$input_file"
                processed=$((processed + 1))
            else
                echo "✗ Output file too small, keeping original: $filename"
                rm -f "$output_file"  # Remove the bad output file
                failed=$((failed + 1))
            fi
        else
            echo "✗ Output file not created properly, keeping original: $filename"
            failed=$((failed + 1))
        fi
    else
        echo "✗ FFmpeg failed for: $filename"
        rm -f "$output_file"  # Remove any partial output file
        failed=$((failed + 1))
    fi
    echo ""
done

# Clean up MacOS system files
echo "🧹 Cleaning up system files..."
find "$INPUT_FOLDER" -maxdepth 1 -type f -name "._*" -delete

echo "🎉 Conversion complete!"
echo "✅ Successfully processed: $processed files"
echo "❌ Failed: $failed files"
