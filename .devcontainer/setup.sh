#!/bin/bash
set -e

echo "🚀 Setting up Flutter development environment..."

# ---- Install Flutter SDK ----
if [ ! -d "$HOME/flutter" ]; then
  echo "📦 Installing Flutter SDK..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
fi
export PATH="$HOME/flutter/bin:$PATH"
{
  echo ''
  echo '# Flutter'
  echo 'export PATH="$HOME/flutter/bin:$PATH"'
} >> ~/.bashrc

# ---- Install Android SDK ----
ANDROID_HOME="$HOME/android-sdk"
mkdir -p "$ANDROID_HOME/cmdline-tools"

if [ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]; then
  echo "📦 Installing Android command-line tools..."
  cd /tmp
  curl -fsSL https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -o cmdtools.zip
  unzip -q cmdtools.zip
  mv cmdline-tools "$ANDROID_HOME/cmdline-tools/latest"
  rm cmdtools.zip
fi

export ANDROID_HOME
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
{
  echo ''
  echo '# Android SDK'
  echo "export ANDROID_HOME=$ANDROID_HOME"
  echo 'export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"'
} >> ~/.bashrc

# ---- Accept licenses & install SDK components ----
echo "📦 Installing Android SDK components..."
yes | sdkmanager --licenses > /dev/null 2>&1 || true
sdkmanager "platforms;android-36" "build-tools;36.0.0" "platform-tools"

# ---- Flutter setup ----
flutter config --no-analytics
flutter precache --android

# ---- Generate platform files if not present ----
WORKSPACE_DIR="$(pwd)"
if [ ! -d "$WORKSPACE_DIR/android" ]; then
  echo "📦 Generating Android project files..."
  flutter create --project-name book_speaker --org com.bookspeaker .
fi

# ---- Patch Android config for plugin compatibility ----
echo "🔧 Patching Android config..."
if [ -f "android/settings.gradle.kts" ]; then
  SETTINGS="android/settings.gradle.kts"
else
  SETTINGS="android/settings.gradle"
fi
if [ -f "android/app/build.gradle.kts" ]; then
  BUILD="android/app/build.gradle.kts"
else
  BUILD="android/app/build.gradle"
fi

sed -i -E 's/(org\.jetbrains\.kotlin\.android.* version ")([^"]*)/\12.1.0/' "$SETTINGS"
sed -i -E 's/compileSdk\s*=\s*(flutter\.compileSdkVersion|[0-9]+)/compileSdk = 36/' "$BUILD"

flutter pub get

echo ""
echo "✅ Development environment ready!"
echo "   Run 'flutter build apk --release' to build the APK."
echo "   Run 'flutter run' if a device is connected."
