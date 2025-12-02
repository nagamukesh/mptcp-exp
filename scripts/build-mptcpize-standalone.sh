#!/bin/bash

# Standalone build script for mptcpize for Android ARM64
set -e

# NDK Configuration
export NDK_ROOT=/home/tanay_pc/Downloads/android-ndk-r27d-linux/android-ndk-r27d
export TOOLCHAIN_ROOT=$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64
export PATH=$TOOLCHAIN_ROOT/bin:$PATH

# Target Configuration
export TARGET_API=28
export TARGET_TRIPLE=aarch64-linux-android$TARGET_API
export CC=$TARGET_TRIPLE-clang

# Build flags
export CFLAGS="-fPIE -fPIC -O2 -DANDROID -D__ANDROID_API__=$TARGET_API"
export LDFLAGS="-fPIE -pie"

# Output directory
export OUTPUT_DIR=/home/tanay_pc/android-builds/mptcpize-android-arm64
mkdir -p $OUTPUT_DIR

echo "=== Building mptcpize for Android ARM64 ==="
echo "Compiler: $CC"
echo "Target API: $TARGET_API"
echo "Output: $OUTPUT_DIR/mptcpize"

# Get version from configure.ac
VERSION=$(grep "AC_INIT" configure.ac | sed 's/.*\[\([0-9.]*\)\].*/\1/')
echo "Version: $VERSION"

# Create a minimal config header for standalone build
cat > mptcpize_config.h << 'EOF'
#ifndef MPTCPIZE_CONFIG_H
#define MPTCPIZE_CONFIG_H

#define VERSION "0.13"
#define PACKAGE_BUGREPORT "mptcp@lists.linux.dev"
#define PKGLIBDIR "/data/local/tmp"
#define LIBREVISION "1"

// Android doesn't have error.h, so we'll define our own
#ifndef HAVE_ERROR_H
#define HAVE_ERROR_H 0
#endif

#endif
EOF

# Build mptcpize with minimal dependencies
echo "Compiling mptcpize (Android version)..."

$CC $CFLAGS $LDFLAGS \
    -DVERSION="\"$VERSION\"" \
    -DPACKAGE_BUGREPORT="\"mptcp@lists.linux.dev\"" \
    -DPKGLIBDIR="\"/data/local/tmp\"" \
    -DLIBREVISION="\"1\"" \
    mptcpize_android.c \
    -o $OUTPUT_DIR/mptcpize

if [ $? -eq 0 ]; then
    echo "✓ Build successful!"
    echo "Binary location: $OUTPUT_DIR/mptcpize"
    
    # Verify the binary
    echo "Verifying binary..."
    file $OUTPUT_DIR/mptcpize
    ls -la $OUTPUT_DIR/mptcpize
    
    echo ""
    echo "=== Installation Instructions ==="
    echo "1. Connect your rooted Android device via USB"
    echo "2. Enable USB debugging"
    echo "3. Push the binary to device:"
    echo "   adb push $OUTPUT_DIR/mptcpize /data/local/tmp/"
    echo "4. Set execute permissions:"
    echo "   adb shell chmod +x /data/local/tmp/mptcpize"
    echo "5. Use it:"
    echo "   adb shell su -c '/data/local/tmp/mptcpize run <your_command>'"
else
    echo "✗ Build failed!"
    exit 1
fi
