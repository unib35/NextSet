<p align="center"><strong>English</strong> · <a href="README.ko.md">한국어</a></p>

<p align="center">
  <img src="assets/readme/hero.png" width="100%" alt="NextSet — Rest. Reset. Go again. 주황색 30을 모티프로 한 운동 휴식 타이머 배너">
</p>

<h1 align="center">NextSet · 다음세트</h1>

<p align="center">
  <strong>운동에 집중하고, 휴식은 다음세트에 맡기세요.</strong><br>
  A workout rest timer for iPhone, iPad, and Apple Watch.<br>
  Built with SwiftUI · 한국어 / English
</p>

<p align="center">
  <a href="#a-look-inside">Screenshots</a> ·
  <a href="#build">Build</a> ·
  <a href="https://unib35.github.io/NextSet/ko/support.html">지원</a> ·
  <a href="https://unib35.github.io/NextSet/en/support.html">Support</a> ·
  <a href="https://unib35.github.io/NextSet/en/privacy.html">Privacy</a>
</p>

---

## A look inside

Choose your rest. Keep your rhythm. See what you finished.

<table>
  <tr>
    <th width="33%">01 · Set your rest</th>
    <th width="33%">02 · Stay focused</th>
    <th width="33%">03 · Wrap it up</th>
  </tr>
  <tr>
    <td><img src="assets/readme/setup.png" width="280" alt="Rest setup with a 60-second preset and Set done → Rest button"></td>
    <td><img src="assets/readme/rest.png" width="280" alt="Active rest timer with 59 seconds remaining and rest adjustment controls"></td>
    <td><img src="assets/readme/summary.png" width="280" alt="Workout summary showing completed sets, total rest, and skipped rests"></td>
  </tr>
</table>

<sub>Actual simulator captures with sample workout data. Screens may vary by device and app version.</sub>

## Made for the time between sets

| | What you can do |
| :--- | :--- |
| **Your pace** | Set-rest and countdown modes, quick presets, pause/resume, and rest adjustment. |
| **A glance away** | Home and Lock Screen widgets, Live Activities, and Control Center controls. |
| **On your wrist** | Apple Watch companion with rest controls and local rest-end notifications. |
| **Your workout history** | Review recent workout summaries stored on your device. |

<p align="center">
  <img src="assets/readme/watch.png" width="180" alt="Apple Watch rest timer with 97 seconds remaining, add 10 seconds, and skip controls"><br>
  <sub>A quick check between sets, right on your wrist.</sub>
</p>

**No account. No ads. No in-app purchases.** Workout summaries stay on your device, with no developer-hosted workout storage.

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
