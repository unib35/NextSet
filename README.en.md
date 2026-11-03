<p align="center"><a href="README.md">한국어</a> · <strong>English</strong></p>

<p align="center">
  <picture>
    <source media="(prefers-reduced-motion: reduce)" srcset="assets/readme/hero-en.png">
    <img src="assets/readme/hero-en.gif" width="100%" alt="NextSet — One tap. The rest is lifting. A banner counting down from 5 to 1, then turning orange when rest ends">
  </picture>
</p>

<p align="center">
  <img src="assets/readme/icons/app-icon-light.png" width="100" alt="App icon — Light">
  &nbsp;
  <img src="assets/readme/icons/app-icon-dark.png" width="100" alt="App icon — Dark">
  &nbsp;
  <img src="assets/readme/icons/app-icon-tinted.png" width="100" alt="App icon — Tinted">
  <br>
  <sub>Light · Dark · Tinted</sub>
</p>

<p align="center">
  <a href="https://apps.apple.com/app/id6814582323"><img src="assets/readme/badges/app-store-en.svg" height="54" alt="Download on the App Store"></a>
</p>

<h1 align="center">NextSet · Rest Timer</h1>

<p align="center">
  <strong>Focus on the work. Leave the rest to NextSet.</strong><br>
  A workout rest timer for iPhone, iPad, and Apple Watch.<br>
  Built with SwiftUI · 한국어 / English
</p>

<p align="center">
  <a href="https://apps.apple.com/app/id6814582323">App Store</a> ·
  <a href="#a-look-inside">Screenshots</a> ·
  <a href="#build">Build</a> ·
  <a href="https://unib35.github.io/NextSet/en/support.html">Support</a> ·
  <a href="https://unib35.github.io/NextSet/en/privacy.html">Privacy</a>
</p>

---

## A look inside

Choose your rest. Keep your rhythm. See what you finished.

### iPhone

<table>
  <tr>
    <th width="25%">01 · Resting</th>
    <th width="25%">02 · Pick a time</th>
    <th width="25%">03 · Last 3 seconds</th>
    <th width="25%">04 · Lock Screen</th>
  </tr>
  <tr>
    <td><img src="assets/readme/store/en/iphone-01-resting.png" alt="Between sets. Time to rest. — 42 seconds remaining with −10, +10, +30 and Skip controls"></td>
    <td><img src="assets/readme/store/en/iphone-02-picker.png" alt="Your rest. One tap away. — 60 seconds selected with 30, 45, 60, 90, 120 presets and a Start rest button"></td>
    <td><img src="assets/readme/store/en/iphone-03-last3.png" alt="Feel the final 3 seconds. — a white 3 on an orange background"></td>
    <td><img src="assets/readme/store/en/iphone-04-live-activity.png" alt="Your rest. On the Lock Screen. — Lock Screen circular widget and Live Activity"></td>
  </tr>
  <tr>
    <th>05 · Dynamic Island</th>
    <th>06 · Home Screen widgets</th>
    <th>07 · Apple Watch</th>
    <th>08 · Workout summary</th>
  </tr>
  <tr>
    <td><img src="assets/readme/store/en/iphone-05-dynamic-island.png" alt="Switch apps. Stay on track. — Dynamic Island compact and expanded states"></td>
    <td><img src="assets/readme/store/en/iphone-06-widgets.png" alt="Tap a widget. Start your rest. — small widget and a medium widget with 45, 60, 120 presets"></td>
    <td><img src="assets/readme/store/en/iphone-07-watch.png" alt="NextSet. On your wrist. — Apple Watch resting and rest-over screens"></td>
    <td><img src="assets/readme/store/en/iphone-08-summary.png" alt="Workout done. See your numbers. — 8 sets done, total rest 7:44, average 0:58, 1 skipped"></td>
  </tr>
</table>

### iPad

<table>
  <tr>
    <th width="50%">01 · Resting</th>
    <th width="50%">02 · Pick a time</th>
  </tr>
  <tr>
    <td><img src="assets/readme/store/en/ipad-01-resting.png" alt="iPad landscape rest timer with 42 seconds remaining and adjustment controls"></td>
    <td><img src="assets/readme/store/en/ipad-02-picker.png" alt="iPad landscape time picker with 60 seconds and presets"></td>
  </tr>
  <tr>
    <th>03 · Split View</th>
    <th>04 · Workout summary</th>
  </tr>
  <tr>
    <td><img src="assets/readme/store/en/ipad-03-split-view.png" alt="Keep it beside your video. — the timer in Split View next to a video"></td>
    <td><img src="assets/readme/store/en/ipad-04-summary.png" alt="iPad workout summary with completed sets and total, average and skipped rest"></td>
  </tr>
</table>

### Apple Watch

<table>
  <tr>
    <th width="33%">01 · Idle</th>
    <th width="33%">02 · Resting</th>
    <th width="33%">03 · Rest over</th>
  </tr>
  <tr>
    <td align="center"><img src="assets/readme/store/en/watch-01-idle.png" width="205" alt="Apple Watch idle screen — 60 seconds, tap to start"></td>
    <td align="center"><img src="assets/readme/store/en/watch-02-resting.png" width="205" alt="Apple Watch resting — 42 seconds, +10 and Skip"></td>
    <td align="center"><img src="assets/readme/store/en/watch-03-rest-over.png" width="205" alt="Apple Watch rest over — next set 4, start next rest"></td>
  </tr>
</table>

<sub>English screenshots as submitted to the App Store. Actual screens may vary by device and app version.</sub>

## Made for the time between sets

| | What you can do |
| :--- | :--- |
| **Your pace** | Set-rest and countdown modes, quick presets, pause/resume, and rest adjustment. |
| **A glance away** | Home and Lock Screen widgets, Live Activities, and Control Center controls. |
| **On your wrist** | Apple Watch companion with rest controls and local rest-end notifications. |
| **Your workout history** | Review recent workout summaries stored on your device. |

**No account. No ads. No in-app purchases.** Workout summaries stay on your device, with no developer-hosted workout storage.

## Build

Open `NextSet/NextSet.xcodeproj` in Xcode 26.5 or later and select the **NextSet** scheme.
The minimum OS versions are iOS 18.0 and watchOS 11.0.
Install the watchOS simulator runtime because the iOS scheme embeds the Watch app.
For a device build, select your own development team and configure your bundle IDs and shared App Group.

```sh
xcodebuild test -project NextSet/NextSet.xcodeproj -scheme NextSet \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO -only-testing:NextSetTests
```

## Support and privacy

- [App Store — 다음세트 - 휴식 타이머 (NextSet)](https://apps.apple.com/app/id6814582323)
- [English support](https://unib35.github.io/NextSet/en/support.html)
- [What's New](https://unib35.github.io/NextSet/en/changelog.html)
- [Privacy policy](https://unib35.github.io/NextSet/en/privacy.html)
- [한국어 지원](https://unib35.github.io/NextSet/ko/support.html)
- [한국어 개인정보처리방침](https://unib35.github.io/NextSet/ko/privacy.html)

## GitHub Pages

The app source and public page sources live in this repository.
`tools/release-site/build.py` generates `docs/release/site` using the app's localized privacy resources `docs/release/SUPPORT*.md`, and `docs/release/CHANGELOG*.md`. Styles, scripts, and screenshots live in `tools/release-site/static/`.
The Pages workflow publishes only that generated directory, never the app source tree.

```sh
python3 tools/release-site/build.py
```

Push changes to the page sources on `main` to redeploy, or run the **Publish support pages** workflow manually.
