cp -pR ../RetroArch/pkg/apple/* .
rm WebServer/GCDWebUploader/GCDWebUploader.h
python3 xcode_absolute_path_to_relative.py
