#!/bin/bash

set -eu # stop on error
set -x  # print commands

# install/update depot-tools
if [ ! -d "depot_tools" ]; then
  git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
else
  cd depot_tools
  git pull
  cd ..
fi

BASE_PATH=`pwd`
export PATH=$PATH:${BASE_PATH}/depot_tools

# fix for problem of `tar` command on some docker platform "Cannot change ownership"
# happens on sysroot installation `src/build/linux/sysroot_scripts/install-sysroot.py` while `gclient sync`
TAR_PROXY_DIR="${BASE_PATH}/tar-bin"
if [ ! -d ${TAR_PROXY_DIR} ]; then
  mkdir ${TAR_PROXY_DIR}
fi
echo '#!/bin/sh -x' > ${TAR_PROXY_DIR}/tar
echo '/bin/tar $1 $2 $3 $4 $5 $6 $7 $8 $9 --no-same-owner' >> ${TAR_PROXY_DIR}/tar
chmod 755 ${TAR_PROXY_DIR}/tar
export PATH=${TAR_PROXY_DIR}:$PATH

# fetch BIG source code
mkdir webrtc
cd webrtc
fetch --nohooks webrtc

# ..... wait .....

# get source code of specific commit
cd src
git checkout 2770c3df91861693ecb2ae805db84c7edbb1fc1a # applied unity plugin fix
cd ..

# prepare dependent libraries
export CHROME_HEADLESS=1 # a magic to skip interactive license agreement
echo "target_os = [ 'windows' ]" >> .gclient
gclient sync
unset CHROME_HEADLESS

# ... wait ...

# export targets
cd src
#echo '{ global: *; };' >  build/android/android_only_jni_exports.lst
#echo '{ global: *; };' >  build/android/android_only_explicit_jni_exports.lst

# generate ninja build files
gn gen out/Windows --args='target_os="win" target_cpu="x64"'

# build library .so file
ninja -C out/Windows webrtc_unity_plugin

# .... wait ....

# copy and rename .so file to ~/webrtc
cp out/Windows/libwebrtc_unity_plugin.so ../libjingle_peerconnection_so.so

# build java library
ninja -C out/Windows libwebrtc_unity

# .. wait ..

# copy jar file to ~/webrtc
cp out/Windows/lib.java/examples/libwebrtc_unity.jar ../.

cd ..
