#chromebrew directories
OWNER="skycocker"
REPO="chromebrew"
BRANCH="master"
URL="https://raw.githubusercontent.com/$OWNER/$REPO/$BRANCH"
CREW_PREFIX=${CREW_PREFIX:-/usr/local}
CREW_LIB_PATH=$CREW_PREFIX/lib/crew/
CREW_CONFIG_PATH=$CREW_PREFIX/etc/crew/
CREW_BREW_DIR=$CREW_PREFIX/tmp/crew/
CREW_DEST_DIR=$CREW_BREW_DIR/dest
CREW_PACKAGES_PATH=$CREW_LIB_PATH/packages

architecture=$(uname -m)

if [ $EUID -eq 0 ]; then
  echo 'Chromebrew should not be run as root.'
  exit 1;
fi

case "$architecture" in
"i686"|"x86_64"|"armv7l"|"aarch64")
  ;;
*)
  echo 'Your device is not supported by Chromebrew yet.'
  exit 1;;
esac

#This will allow things to work without sudo
sudo chown -R `id -u`:`id -g` "${CREW_PREFIX}"

#prepare directories
for dir in $CREW_LIB_PATH $CREW_CONFIG_PATH $CREW_CONFIG_PATH/meta $CREW_BREW_DIR $CREW_DEST_DIR $CREW_PACKAGES_PATH; do
  mkdir -p $dir
done

#prepare url and sha256
#  install only ruby, git and libssh2
urls=()
sha256s=()
case "$architecture" in
"aarch64")
  urls+=('https://dl.bintray.com/chromebrew/chromebrew/ruby-2.5.1-chromeos-armv7l.tar.xz')
  sha256s+=('b03154f57e2599f71b0bdd42ba3a126397eca451ccb99485615b5b0429955152')
  urls+=('https://dl.bintray.com/chromebrew/chromebrew/git-2.18.0-chromeos-armv7l.tar.xz')
  sha256s+=('4a0b4979ff300fe5562ace00e293139853104c9769a47c32ea895593f0cfe3d8')
  urls+=('https://dl.bintray.com/chromebrew/chromebrew/libssh2-1.8.0-chromeos-armv7l.tar.xz')
  sha256s+=('6fa84296583273dd9e749a2c54cb1cf688a7dab032e2528de5944a4d9777f037')
  ;;
"armv7l")
  if ! type "xz" > /dev/null; then
    urls+=('https://github.com/snailium/chrome-cross/releases/download/v1.8.1/xz-5.2.3-chromeos-armv7l.tar.gz')
    sha256s+=('4dc9f086ee7613ab0145ec0ed5ac804c80c620c92f515cb62bae8d3c508cbfe7')
  fi
  urls+=('https://dl.bintray.com/chromebrew/chromebrew/ruby-2.5.1-chromeos-armv7l.tar.xz')
  sha256s+=('b03154f57e2599f71b0bdd42ba3a126397eca451ccb99485615b5b0429955152')
  urls+=('https://dl.bintray.com/chromebrew/chromebrew/git-2.18.0-chromeos-armv7l.tar.xz')
  sha256s+=('4a0b4979ff300fe5562ace00e293139853104c9769a47c32ea895593f0cfe3d8')
  urls+=('https://dl.bintray.com/chromebrew/chromebrew/libssh2-1.8.0-chromeos-armv7l.tar.xz')
  sha256s+=('6fa84296583273dd9e749a2c54cb1cf688a7dab032e2528de5944a4d9777f037')
  ;;
"i686")
  urls+=('https://dl.bintray.com/chromebrew/chromebrew/ruby-2.5.1-chromeos-i686.tar.xz')
  sha256s+=('de1d30b89fd09b6e544fe537cbbc4cdc76f4f1610b0f801ab82ce90c1dc04999')
  urls+=('https://dl.bintray.com/chromebrew/chromebrew/git-2.18.0-chromeos-i686.tar.xz')
  sha256s+=('51f5058681c87810bd25c2471e4d98353fecf54f1eefa6c172eaa0879e1a12bf')
  urls+=('https://dl.bintray.com/chromebrew/chromebrew/libssh2-1.8.0-chromeos-i686.tar.xz')
  sha256s+=('771b2d30a49dd691db8456f773da404753d368f3c31d03c682c552ea0b5eb65e')
  ;;
"x86_64")
  urls+=('https://dl.bintray.com/chromebrew/chromebrew/ruby-2.5.1-chromeos-x86_64.tar.xz')
  sha256s+=('2e60c9b84968f17ac796e92992a5e32b4c39291d5a0b1bb0183f43d1c784303f')
  urls+=('https://dl.bintray.com/chromebrew/chromebrew/git-2.18.0-chromeos-x86_64.tar.xz')
  sha256s+=('a3dc5bf0bde8f3093f73a2f0413e1ad507cdb568d4f108258fb518ce7088831a')
  urls+=('https://dl.bintray.com/chromebrew/chromebrew/libssh2-1.8.0-chromeos-x86_64.tar.xz')
  sha256s+=('6e026450389021c6267a9cc79b8722d15f48e2f8d812d5212501f686b4368e3c')
  ;;
esac

#functions to maintain packages
function download_check () {
    cd $CREW_BREW_DIR

    #download
    echo "Downloading $1..."
    curl -C - -# -L --ssl $2 -o "$3"

    #verify
    echo "Verifying $1..."
    echo $4 $3 | sha256sum -c -
    case $? in
    0) ;;
    *)
      echo "Verification failed, something may be wrong with the $1 download."
      exit 1;;
    esac
}

function extract_install () {
    cd $CREW_BREW_DIR

    #extract and install
    echo "Extracting $1 (this may take a while)..."
    rm -rf ./usr
    tar -xf $2
    echo "Installing $1 (this may take a while)..."
    tar cf - ./usr/* | (cd /; tar xp --keep-directory-symlink -f -)
    mv ./dlist $CREW_CONFIG_PATH/meta/$1.directorylist
    mv ./filelist $CREW_CONFIG_PATH/meta/$1.filelist
}

function update_device_json () {
  cd $CREW_CONFIG_PATH

  if grep '"name": "'$1'"' device.json > /dev/null; then
    echo "Updating version number of existing $1 information in device.json..."
    sed -i device.json -e '/"name": "'$1'"/N;//s/"version": ".*"/"version": "'$2'"/'
  elif grep '^    }$' device.json > /dev/null; then
    echo "Adding new $1 information to device.json..."
    sed -i device.json -e '/^    }$/s/$/,\
    {\
      "name": "'$1'",\
      "version": "'$2'"\
    }/'
  else
    echo "Adding new $1 information to device.json..."
    sed -i device.json -e '/^  "installed_packages": \[$/s/$/\
    {\
      "name": "'$1'",\
      "version": "'$2'"\
    }/'
  fi
}

#create the device.json file if it doesn't exist
cd $CREW_CONFIG_PATH
if [ ! -f device.json ]; then
  echo "Creating new device.json..."
  echo '{' > device.json
  echo '  "architecture": "'$architecture'",' >> device.json
  echo '  "installed_packages": [' >> device.json
  echo '  ]' >> device.json
  echo '}' >> device.json
fi

#extract, install and register packages
for i in `seq 0 $((${#urls[@]} - 1))`; do
  url=${urls[$i]}
  sha256=${sha256s[$i]}
  tarfile=`basename $url`
  name=${tarfile%%-*}   # extract string before first '-'
  rest=${tarfile#*-}    # extract string after first '-'
  version=`echo $rest | sed -e 's/-chromeos.*$//'`
                        # extract string between first '-' and "-chromeos"

  download_check $name $url $tarfile $sha256
  extract_install $name $tarfile
  update_device_json $name $version
done

#download, prepare and install chromebrew
cd $CREW_LIB_PATH
rm -rf crew lib packages
curl -# -o crew $URL/crew
chmod +x crew
rm -f $CREW_PREFIX/bin/crew
ln -s `pwd`/crew $CREW_PREFIX/bin
#install crew library
mkdir -p $CREW_LIB_PATH/lib
cd $CREW_LIB_PATH/lib
curl -# -o package.rb $URL/lib/package.rb
curl -# -o package_helpers.rb $URL/lib/package_helpers.rb

#Making GCC act like CC (For some npm packages out there, only required for gcc)
#rm -f $CREW_PREFIX/bin/cc
#ln -s $CREW_PREFIX/bin/gcc $CREW_PREFIX/bin/cc

#package gcc7 has already made symbolic links for cc and gcc, no action required here


#prepare sparse checkout .rb packages directory and do it
cd $CREW_LIB_PATH
rm -rf .git
git init
git remote add -f origin https://github.com/$OWNER/$REPO.git
git config core.sparsecheckout true
echo packages >> .git/info/sparse-checkout
echo lib >> .git/info/sparse-checkout
echo crew >> .git/info/sparse-checkout
git fetch origin master
git reset --hard origin/master
yes | crew install buildessential less most
echo
echo "To set the default PAGER environment variable to be able to use less:"
echo "echo \"export PAGER=$CREW_PREFIX/bin/less\" >> ~/.bashrc && . ~/.bashrc"
echo
echo "Alternatively, you could use most.  Why settle for less, right?"
echo "echo \"export PAGER=$CREW_PREFIX/bin/most\" >> ~/.bashrc && . ~/.bashrc"
echo
echo "Chromebrew installed successfully and package lists updated."
