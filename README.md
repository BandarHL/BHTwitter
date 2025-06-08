# NeoFreeBird-BHTwitter
the ultimate way to tweak your Twitter/X experience.

> Forked from [BHTwitter](https://github.com/BandarHL/BHTwitter).

## Warning: 
these builds are considered beta. even though they should work fine. you may run into some issues.
currently we're building it against Twitter/X v10.94. recent versions may have issues that havent been fixed yet.

| | | |
|:-------------------------:|:-------------------------:|:-------------------------:|
|<img width="1604" alt="Screenshot 1" src="1.png">|<img width="1604" alt="Screenshot 2" src="2.png">|<img width="1604" alt="Screenshot 3" src="3.png">|
|<img width="1604" alt="Screenshot 4" src="4.png">|

# How to Build

## Build Locally

1. Install [Theos](https://github.com/theos/theos).
2. Install [cyan](https://github.com/asdfzxcvbn/pyzule-rw) if you want sideload or TrollStore builds.
3. Clone the NeoFreeBird-BHTwitter repository:

```bash
git clone --recursive https://github.com/actuallyaridan/NeoFreeBird-BHTwitter
cd NeoFreeBird-BHTwitter
```

4. Make the build script executable:

```bash
chmod +x ./build.sh
```

5. Run the script with your preferred option:

```bash
./build.sh [OPTIONS]
```

Available options:
```
--sideloaded: For sideloading.
--rootless: For rootless jailbreaks.
--trollstore: For TrollStore users.
(no option): For rootful jailbreaks.
```

## Build via GitHub Actions

1. Fork this repository.
2. Open the "Actions" tab and enable workflows.
3. Choose "Build and Release NeoFreeBird-BHTwitter."
4. Click "Run workflow" and provide:
   - Deployment format: `rootful`, `rootless`, `sideloaded`, or `trollstore`.
   - A decrypted IPA URL for sideloaded/TrollStore builds.
   - Any value for rootful/rootless builds.
5. Check the "Releases" tab once the build completes.

# Build Examples

## Build for Sideloading

1. Get a decrypted IPA for Twitter/X.
2. Rename it to `com.atebits.Tweetie2.ipa` and move it to the `packages` folder.

```bash
./build.sh --sideloaded
```

Result: `NeoFreeBird-BHTwitter-sideloaded.ipa` inside `packages`.

## Build for TrollStore

Follow the same steps as sideloading, then run:

```bash
./build.sh --trollstore
```

Result: `NeoFreeBird-BHTwitter-trollstore.tipa` inside `packages`.

## Build for Rootless Jailbreaks

Simply run:

```bash
./build.sh --rootless
```

Result: `com.bandarhl.bhtwitter_4.2_iphoneos-arm64.deb` inside `packages`.

## Build for Rootful Jailbreaks

Just run the script without any flags:

```bash
./build.sh
```

Result: `com.bandarhl.bhtwitter_4.2_iphoneos-arm.deb` inside `packages`.

