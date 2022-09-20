# BHTwitter
- Awesome tweak for Twitter

# Features
- Download Videos (even if account private).
- Custom Tab Bar
- Video zoom feature.
- No history feature.
- Hide topics tweet feature.
- Disable video layer caption.
- Padlock.
- Font changer.
- Enable the new UI of DM search.
- Auto load photos in highest quality feature.
- Undo tweet feature.
- Theme (like Twitter Bule).
- Twitter Circle feature.
- Copying profile information feature.
- Save tweet as an image.
- Hide spaces bar.
- Disable RTL.
- Always open in Safari.
- Translate bio.
- Reader mode feature.
- Disable new tweet style (A.K.A edge to edge tweet)
- Enable voice tweet and voice message in DM.
- Hide promoted tweet from the timeline.
- Confirm alert when hit the tweet button.
- Confirm alert when hit like button.
- Confirm alert when hit follow button.
- FLEX for debugging.

| | | |
|:-------------------------:|:-------------------------:|:-------------------------:|
|<img width="1604" alt="screen shot 2017-08-07 at 12 18 15 pm" src="1.png"> |  <img width="1604" alt="screen shot 2017-08-07 at 12 18 15 pm" src="2.png">|<img width="1604" alt="screen shot 2017-08-07 at 12 18 15 pm" src="3.png">|
|<img width="1604" alt="screen shot 2017-08-07 at 12 18 15 pm" src="4.png">  |

# How to build the project
- install [Theos](https://github.com/theos/theos)
- install [MonkeyDev](https://github.com/AloneMonkey/MonkeyDev)
- Open BHTwitter.xcodeproj
- Make sure you're selecting (Any iOS Device)
 > If you get Code sign error, add an developer account to xcode and then Go to Build settings and select "All" tab then search for "Sign", you should find "Code Signing Identity" chnage it to iOS developer and chnage "Developer Team" to match you're developer account
### for jailbreak devices
- Just press Run button of the project or command+b from you're keyboard
- Wait until the build finished
- You should find deb file in Packages folder of the project
### for non-jailbreak devices
- Go to the Build settings and scroll down to 'user-Defined' section and change "MonkeyDevInstallOnAnyBuild" value to NO
- Select BHTwitter.xm and scoll down to 1237 line or 'Fix login keychain in non-JB (IPA).' section and enable the code below it
- Press Run button of the project or command+b from you're keyboard
- Wait until the build finished
- You should find the BHTwitter.dylib in LatestBuild dir of the project
- To inject the tweak with IPA correctly, you need:
    - BHTwitter.dylib
    - [libcephei SDK](https://1drv.ms/u/s!AkvDoVwju6c4gTL7_d-H3nmegFop?e=OqFpok)
    - BHTwitter.bundle (You can find it in BHTwitter project 'BHTwitter/Package/Library/Application Support/BHT/BHTwitter.bundle'
    - Twitter.ipa
    - Use [Azule](https://github.com/Al4ise/Azule) to inject all these.
      > exmaple command: azule -n BHTwitter -i /Users/bandarhelal/Desktop/Twitter.ipa -o /Users/bandarhelal/Desktop/ -r -f /Users/bandarhelal/Library/Developer/Xcode/DerivedData/BHTwitter-axvjvuqbopwuevhafqossnmzlzcm/Build/Products/Debug-iphoneos/BHTwitter.dylib /Users/bandarhelal/Desktop/libcephei/Cephei.framework /Users/bandarhelal/Desktop/libcephei/CepheiPrefs.framework /Users/bandarhelal/Desktop/libcephei/CepheiUI.framework /Users/bandarhelal/Documents/GitHub/BHTwitter/BHTwitter/Package/Library/Application\ Support/BHT/BHTwitter.bundle
