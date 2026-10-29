# Icon originals

`icon-light-src.png`, `icon-dark-src.png` and `icon-tinted-src.png` are editable source assets. The app uses the copies in its asset catalog under `NextSet/NextSet/Assets.xcassets/`.

To export a PNG without alpha, run from the repository root:

```sh
swift tools/icons/strip_alpha.swift assets/icons/icon-light-src.png /tmp/nextset-icon-light.png
```

Review the result before replacing an app asset.
