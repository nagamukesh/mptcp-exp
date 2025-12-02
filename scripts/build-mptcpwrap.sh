#!/bin/bash

# Build script for libmptcpwrap.so for Android ARM64
set -e

# NDK Configuration
export NDK_ROOT=/home/tanay_pc/Downloads/android-ndk-r27d-linux/android-ndk-r27d
export TOOLCHAIN_ROOT=$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64
export PATH=$TOOLCHAIN_ROOT/bin:$PATH

# Target Configuration
export TARGET_API=28
export TARGET_TRIPLE=aarch64-linux-android$TARGET_API
export CC=$TARGET_TRIPLE-clang

# Build flags for shared library
export CFLAGS="-fPIC -O2 -DANDROID -D__ANDROID_API__=$TARGET_API -fvisibility=hidden"
export LDFLAGS="-shared -fPIC"

# Output directory
export OUTPUT_DIR=/home/tanay_pc/android-builds/mptcpize-android-arm64
mkdir -p $OUTPUT_DIR

echo "=== Building libmptcpwrap.so for Android ARM64 ==="
echo "Compiler: $CC"
echo "Target API: $TARGET_API"
echo "Output: $OUTPUT_DIR/libmptcpwrap.so.0.0.1"

# Build the wrapper library
echo "Compiling libmptcpwrap.so..."

$CC $CFLAGS $LDFLAGS \
    src/mptcpwrap.c \
    -o $OUTPUT_DIR/libmptcpwrap.so.0.0.1

if [ $? -eq 0 ]; then
    echo "✓ Build successful!"
    echo "Library location: $OUTPUT_DIR/libmptcpwrap.so.0.0.1"
    
    # Verify the library
    echo "Verifying library..."
    file $OUTPUT_DIR/libmptcpwrap.so.0.0.1
    ls -la $OUTPUT_DIR/libmptcpwrap.so.0.0.1
    
    # Check library dependencies
    echo "Library dependencies:"
    llvm-readelf -d $OUTPUT_DIR/libmptcpwrap.so.0.0.1
    
    # Check exported symbols
    echo "Exported symbols:"
    llvm-nm -D $OUTPUT_DIR/libmptcpwrap.so.0.0.1 | grep -v " U "
    
    echo ""
    echo "=== Installation Instructions ==="
    echo "1. Push the library to device:"
    echo "   /home/tanay_pc/Android/Sdk/platform-tools/adb push $OUTPUT_DIR/libmptcpwrap.so.0.0.1 /data/local/tmp/"
    echo "2. Set permissions:"
    echo "   /home/tanay_pc/Android/Sdk/platform-tools/adb shell chmod 755 /data/local/tmp/libmptcpwrap.so.0.0.1"
    echo "3. Test mptcpize:"
    echo "   /home/tanay_pc/Android/Sdk/platform-tools/adb shell '/data/local/tmp/mptcpize run -d /system/bin/ping -c 1 8.8.8.8'"
else
    echo "✗ Build failed!"
    exit 1
fi
