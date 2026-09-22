# NextSet · 다음세트

A workout rest timer for iPhone, iPad, and Apple Watch, built with SwiftUI.

- Set-rest and countdown modes, presets, pause/resume, and rest adjustment
- Recent workout summaries stored on your device
- Home and Lock Screen widgets, Live Activities, and Control Center controls
- Apple Watch companion with local rest-end notifications
- Korean and English

No account, ads, in-app purchases, or developer-hosted workout storage.

## Build

Open `NextSet/NextSet.xcodeproj` in Xcode 26.5 or later and select the **NextSet** scheme.
The current minimum OS versions are iOS 26.5 and watchOS 26.5.
Install the watchOS simulator runtime because the iOS scheme embeds the Watch app.
For a device build, select your own development team and configure your bundle IDs and shared App Group.

```sh
xcodebuild test -project NextSet/NextSet.xcodeproj -scheme NextSet \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO -only-testing:NextSetTests
```

## Support and privacy

- [한국어 지원](https://unib35.github.io/NextSet/ko/support.html)
- [한국어 개인정보처리방침](https://unib35.github.io/NextSet/ko/privacy.html)
- [English support](https://unib35.github.io/NextSet/en/support.html)
- [Privacy policy](https://unib35.github.io/NextSet/en/privacy.html)

## GitHub Pages

The app source and public page sources live in this repository.
`tools/release-site/build.py` generates `docs/release/site` using the app's localized privacy resources and `docs/release/SUPPORT*.md`.
The Pages workflow publishes only that generated directory, never the app source tree.

```sh
python3 tools/release-site/build.py
```

Push changes to the page sources on `main` to redeploy, or run the **Publish support pages** workflow manually.
