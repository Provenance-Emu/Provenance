#!/bin/bash

set -e

# Base directory for Dolphin core components
BASE_DIR="/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/dolphin-ios/Source/Core"

# List of components to convert to OBJECT libraries
COMPONENTS=(
  "AudioCommon/CMakeLists.txt"
  "Common/CMakeLists.txt"
  "Core/CMakeLists.txt"
  "DiscIO/CMakeLists.txt"
  "InputCommon/CMakeLists.txt"
  "UICommon/CMakeLists.txt"
  "VideoCommon/CMakeLists.txt"
  "VideoBackends/Null/CMakeLists.txt"
  "VideoBackends/OGL/CMakeLists.txt"
  "VideoBackends/Software/CMakeLists.txt"
  "VideoBackends/Vulkan/CMakeLists.txt"
  "VideoBackends/Metal/CMakeLists.txt"
)

echo "Converting Dolphin components to OBJECT libraries..."

for component in "${COMPONENTS[@]}"; do
  file_path="$BASE_DIR/$component"
  
  if [ -f "$file_path" ]; then
    echo "Processing $file_path"
    
    # Create a backup
    cp "$file_path" "${file_path}.bak"
    
    # Replace 'add_library(name' with 'add_library(name OBJECT'
    sed -i '' 's/add_library(\([a-zA-Z0-9_]*\)$/add_library(\1 OBJECT/g' "$file_path"
    
    # Add position-independent code flag for object libraries
    if ! grep -q "POSITION_INDEPENDENT_CODE" "$file_path"; then
      sed -i '' '/add_library/a\\
set_target_properties(\1 PROPERTIES POSITION_INDEPENDENT_CODE ON)' "$file_path"
    fi
    
    echo "Converted $file_path to OBJECT library"
  else
    echo "Warning: $file_path not found, skipping"
  fi
done

echo "Conversion complete!"
