#!/bin/bash

LONG=sideloaded:,rootless:,trollstore
OPTS=$(getopt -a weather --longoptions "$LONG" -- "$@")
libcephei_URL="https://web.archive.org/web/20240222081324/https://cdn.discordapp.com/attachments/755439561454256132/1184388888475738243/libcephei.zip"
PROJECT_PATH=$PWD

while :; do
  case "$1" in
    --sideloaded)
      echo -e '\033[1m\033[32mBuilding BHTwitter project for sideloaded.\033[0m'

      make clean
      rm -rf .theos
      make SIDELOADED=1

      if [ $? -eq 0 ]; then
        echo -e '\033[1m\033[32mMake command succeeded.\033[0m'
      else
        echo -e '\033[1m\033[31mMake command failed.\033[0m'
        exit 1
      fi

      if [ -e ./packages/com.atebits.Tweetie2.ipa ]; then

        echo -e '\033[1m\033[32mDownloading libcephei SDK.\033[0m'
        temp_dir=$(mktemp -d)
        curl -L -o "$temp_dir/libcephei.zip" "$libcephei_URL"
        unzip -o "$temp_dir/libcephei.zip" -d ./packages
        rm -rf "$temp_dir"
        rm -rf ./packages/__MACOSX

        echo -e '\033[1m\033[32mBuilding the IPA.\033[0m'
        azule -i "$PROJECT_PATH/packages/com.atebits.Tweetie2.ipa" -o "$PROJECT_PATH/packages" -n BHTwitter-sideloaded -r -f "$PROJECT_PATH/.theos/obj/debug/keychainfix.dylib" "$PROJECT_PATH/.theos/obj/debug/libbhFLEX.dylib" "$PROJECT_PATH/.theos/obj/debug/BHTwitter.dylib" "$PROJECT_PATH/packages/Cephei.framework" "$PROJECT_PATH/packages/CepheiUI.framework" "$PROJECT_PATH/packages/CepheiPrefs.framework" "$PROJECT_PATH/layout/Library/Application Support/BHT/BHTwitter.bundle"

        echo -e '\033[1m\033[32mDone, thanks for using BHTwitter.\033[0m'
      else
        echo -e '\033[1m\033[0;31mpackages/com.atebits.Tweetie2.ipa not found.\033[0m'
      fi
      break
      ;;
    --rootless)
      echo -e '\033[1m\033[32mBuilding BHTwitter project for Rootless.\033[0m'

      make clean
      rm -rf .theos
      export THEOS_PACKAGE_SCHEME=rootless
      make package

      echo -e '\033[1m\033[32mDone, thanks for using BHTwitter.\033[0m'
      break
      ;;
    --trollstore)
      echo -e '\033[1m\033[32mBuilding BHTwitter project for TrollStore.\033[0m'

      make clean
      rm -rf .theos
      make

      if [ $? -eq 0 ]; then
        echo -e '\033[1m\033[32mMake command succeeded.\033[0m'
      else
        echo -e '\033[1m\033[31mMake command failed.\033[0m'
        exit 1
      fi

      if [ -e ./packages/com.atebits.Tweetie2.ipa ]; then

        echo -e '\033[1m\033[32mDownloading libcephei SDK.\033[0m'
        temp_dir=$(mktemp -d)
        curl -L -o "$temp_dir/libcephei.zip" "$libcephei_URL"
        unzip -o "$temp_dir/libcephei.zip" -d ./packages
        rm -rf "$temp_dir"
        rm -rf ./packages/__MACOSX

        echo -e '\033[1m\033[32mBuilding the IPA.\033[0m'

        azule -i "$PROJECT_PATH/packages/com.atebits.Tweetie2.ipa" -o "$PROJECT_PATH/packages" -n BHTwitter-trollstore -r -f "$PROJECT_PATH/.theos/obj/debug/BHTwitter.dylib" "$PROJECT_PATH/.theos/obj/debug/libbhFLEX.dylib" "$PROJECT_PATH/packages/Cephei.framework" "$PROJECT_PATH/packages/CepheiUI.framework" "$PROJECT_PATH/packages/CepheiPrefs.framework" "$PROJECT_PATH/layout/Library/Application Support/BHT/BHTwitter.bundle"
        mv "$PROJECT_PATH/packages/BHTwitter-trollstore.ipa" "$PROJECT_PATH/packages/BHTwitter-trollstore.tipa"

        echo -e '\033[1m\033[32mDone, thanks for using BHTwitter.\033[0m'
      else
        echo -e '\033[1m\033[0;31mpackages/com.atebits.Tweetie2.ipa not found.\033[0m'
      fi
      break
      ;;
    *)
      echo -e '\033[1m\033[32mBuilding BHTwitter project for Rootfull.\033[0m'

      make clean
      rm -rf .theos
      unset THEOS_PACKAGE_SCHEME
      make package

      echo -e '\033[1m\033[32mDone, thanks for using BHTwitter.\033[0m'
      break
      ;;
  esac
done
