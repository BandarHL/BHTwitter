# BHTwitter
- Awesome tweak for Twitter

# Features
- Download Videos (even if account private).
- Custom Tab Bar
- No history feature.
- Hide topics tweet feature.
- Disable video layer caption.
- Padlock.
- Font changer.
- Enable the new UI of DM search.
- Auto load photos in highest quality feature.
- Undo tweet feature.
- Theme (like Twitter Blue).
- App icon changer
- Twitter Circle feature.
- Copying profile information feature.
- Save tweet as an image.
- Hide spaces bar.
- Disable RTL.
- Always open in Safari.
- Translate bio.
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

## Local

- install [Theos](https://github.com/theos/theos)
- install [cyan](https://github.com/asdfzxcvbn/pyzule-rw) if you want to build for sideload or TrollStore

- Clone the BHTwitter project repository:
```bash
git clone --recursive https://github.com/BandarHL/BHTwitter
cd BHTwitter
```
- Make the script executable:
```bash
chmod +x ./build.sh
```
- Run the script with the desired options:
```bash
./build.sh [OPTIONS]
```
- Replace [OPTIONS] with one of the following:

```
--sideloaded: Build BHTwitter project for sideloaded deployment.
--rootless: Build BHTwitter project for rootless deployment.
--trollstore: Build BHTwitter project for TrollStore deployment.
No option: Build BHTwitter project for rootfull deployment.
```

## Using GitHub Actions

- Fork this repository.
- Open "Actions" tab on your fork, and press "I understand my workflows, go ahead and enable them" to proceed.
- Select "Build and Release BHTwitter" workflow.
- Press "Run workflow" menu, and enter parameters in the popup that appears.
  - Don't forget to choose deployment format (`rootfull`, `rootless`, `sideloaded`, `trollstore`).
  - For `sideloaded` and `trollstore` builds, a valid URL of decrypted IPA is required. For `rootfull` and `rootless` builds, enter any value (it won't be used).
  - For other parameters, defaults are usually sufficient.
- Press "Run workflow" button, and after a while you should see build artifacts on "Releases" page.

# Example Usages
## Build for Sideloaded Deployment
- Download an IPA file for X or Twitter from AppDB or decrypt it by your self.
- Then rename the IPA file to `com.atebits.Tweetie2.ipa` and move it to `packages` folder.
```bash
./build.sh --sideloaded
```
- After the build we'll find `BHTwitter-sideloaded.ipa` inside `packages` folder.

## Build for TrollStore Deployment
- Download an IPA file for X or Twitter from AppDB or decrypt it by your self.
- Then rename the IPA file to `com.atebits.Tweetie2.ipa` and move it to `packages` folder.
```bash
./build.sh --trollstore
```
- After the build we'll find `BHTwitter-trollstore.tipa` inside `packages` folder.


## Build for Rootless Deployment
- Just run the build command with rootless flag.
```bash
./build.sh --rootless
```
- After the build we'll find `com.bandarhl.bhtwitter_4.2_iphoneos-arm64.deb` inside `packages` folder.


## Build for Rootfull Deployment
- Just run the build command with rootfull flag.
```bash
./build.sh --rootfull
```
- After the build we'll find `com.bandarhl.bhtwitter_4.2_iphoneos-arm.deb` inside `packages` folder.
