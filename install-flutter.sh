#!/bin/bash

# Install Flutter
if [ ! -d "flutter" ]; then
  echo "Downloading Flutter SDK..."
  git clone https://github.com/flutter/flutter.git -b stable
fi

export PATH="$PATH:`pwd`/flutter/bin"

# Upgrade and config
./flutter/bin/flutter doctor
./flutter/bin/flutter config --enable-web

# Get dependencies
echo "Fetching dependencies..."
./flutter/bin/flutter pub get

# Build Web
echo "Building Flutter Web..."
./flutter/bin/flutter build web --release --dart-define=GROQ_API_KEY=$GROQ_API_KEY

echo "Build complete!"
