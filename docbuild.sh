#!/bin/bash

current_folder=$(basename "$PWD")
current_folder_lower=$(echo "$current_folder" | tr '[:upper:]' '[:lower:]')
read -p "Enter version: " version

xcodebuild docbuild -scheme "$current_folder" \
  -derivedDataPath ./docbuild \
  -destination 'generic/platform=iOS'

$(xcrun --find docc) process-archive \
  transform-for-static-hosting ./docbuild/Build/Products/Debug-iphoneos/"$current_folder".doccarchive \
  --output-path ./docs/"$version" \
  --hosting-base-path "$current_folder/$version"

echo "Documentation has been generated at ./docs/$version"

readme_file="README.md"
new_version_entry="* [$version](https://yabby1997.github.io/$current_folder/$version/documentation/$current_folder_lower/)"

if [[ -f "$readme_file" ]]; then
  awk -v new_entry="$new_version_entry" '/## Documents/ {print; print new_entry; next}1' "$readme_file" > temp && mv temp "$readme_file"
  echo "Added $version to README.md under ## Documents section."

  git add "$readme_file" docs
  git commit -m "Add document for $current_folder $version"
  echo "Changes committed to Git with message: 'Add document for $version'"

else
  echo "README.md file not found!"
fi
