# App Store screenshot renderer

HTML/CSS mockups: `index.html` for iPhone/Watch and `ipad.html` for iPad. Review them against the final app build before release.

Requires Node.js 22+ and Google Chrome on macOS. Run from the repository root:

```sh
tools/appstore-screenshots/render.sh 60
node tools/appstore-screenshots/render-ipad.mjs 60
```

The duration accepts `45`, `60` or `90` seconds. Both renderers generate Korean and English files.

- Working PNGs: `docs/release/screenshots/`
- Layout validation: `docs/validation/T-63/`
- Uploaded originals: `docs/release/app-store-uploaded/<date>/`, copied separately after confirming the portal list. Never regenerate in this directory.

These PNGs are store artwork, not simulator captures. Rendering does not upload or submit the app.
