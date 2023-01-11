import os
import pathlib
import re

# This should be the absolute path to the Core / Vulkan directory
CORE_DIR = '../../'
CORE_DEST_DIR = '../RetroArch/'

CORE_SRCBASE = '\$\(SRCBASE\)'
CORE_SRCDEST_DIR = '../RetroArch'

HEADER_SEARCH_PATH = 'HEADER_SEARCH_PATHS = \('
HEADER_SEARCH_PATH_DEST = '''HEADER_SEARCH_PATHS  =  (
					../RetroArch/pkg/apple,
                                        ../RetroArch/pkg, 
                                        ../RetroArch/ui/drivers/cocoa,
                                        ../RetroArch/pkg/apple/iOS, 
                                        ../RetroArch/pkg/apple/WebServer/GCDWebUploader,
'''
# Path to CMake XCode project files to process
# (This will do recursive processing of all pbxproj files inside )
DIRECTORY_TO_READ = os.getcwd() # Process current directory

# Paths to convert to relative path in XCode
SRCROOT_PATH_TO_FIND = CORE_DIR
SRCROOT_PATH_TO_REPLACE_WITH = CORE_DEST_DIR
SRCBASE_PATH_TO_FIND = CORE_SRCBASE
SRCBASE_PATH_TO_REPLACE_WITH = CORE_SRCDEST_DIR
HEADER_SEARCH_PATH_TO_FIND = HEADER_SEARCH_PATH
HEADER_SEARCH_PATH_TO_REPLACE_WITH = HEADER_SEARCH_PATH_DEST

# Replacements will be processed in this order
replacements = []
replacements.append([SRCROOT_PATH_TO_FIND,SRCROOT_PATH_TO_REPLACE_WITH])
replacements.append([SRCBASE_PATH_TO_FIND,SRCBASE_PATH_TO_REPLACE_WITH])
replacements.append([HEADER_SEARCH_PATH_TO_FIND, HEADER_SEARCH_PATH_TO_REPLACE_WITH])

# Extensions of files to process
extensions = ['.pbxproj', '.xcscheme']
print(f'$(SRCROOT) to find/replace:', replacements)
print(f'Extensions to find:', extensions)

# Does Find / Replace (regex works)
def find_and_replace(content):
  has_match=False
  for (find_string, replace_string) in replacements:
    if re.search(find_string, content):
      content=re.sub(find_string, replace_string, content)
      has_match=True
  return content if has_match else ''

# Find Files to Replace
def process_file(file):
  process = False
  for extension in extensions:
    if extension in file:
      process = True
  if process:
    try:
      with open(file, "r") as fh:
        content=find_and_replace(fh.read())
        fh.close()
      if content:
        print(f"Replacing absolute paths in {file}")
        with open(file, "w") as fh:
          fh.write(content)
          fh.close()
    except Exception as e:
      print('Exception: ', file, e)

# Recurse Get all files under current dir
def get_files(path):
  files = os.listdir(path)
  for file in files:
    if path != '.':
      file=f'{path}/{file}'
    if os.path.isdir(file):  
      get_files(file)
    elif os.path.isfile(file):
      process_file(file)

get_files(DIRECTORY_TO_READ)
