# NextSet README assets

Orange `#FF9500`, near-black, oversized timer numerals, and bold typography.

| Asset | Size | Use |
| --- | --- | --- |
| [hero-ko.gif](hero-ko.gif) · [hero-en.gif](hero-en.gif) | 1600 × 534 | README banners (`README.md` / `README.en.md`), animated, 3:1 (2026-11) |
| [hero-ko.png](hero-ko.png) · [hero-en.png](hero-en.png) | 3200 × 1068 | Still versions, shown when Reduce Motion is on |
| [hero.png](hero.png) | 2172 × 724 | Previous English banner (unused since 2026-11) |
| [social-preview.png](social-preview.png) | 1774 × 887 | Separate sharing cover, 2:1; not yet configured in repository settings |
| [ko/hero.png](ko/hero.png) | 2172 × 724 | Previous Korean banner (unused since 2026-11) |
| [ko/social-preview.png](ko/social-preview.png) | 1774 × 887 | Korean sharing cover, 2:1 |
| [store/ko/](store/ko/) · [store/en/](store/en/) | iPhone 642 × 1389 · iPad 1032 × 1376 · Watch 410 × 502 | The App Store screenshot set (iPhone 8, iPad 4, Watch 3 per language) shown in both READMEs |

The brand images were made with the built-in image generation tool. Exact prompts are in [PROMPTS.md](PROMPTS.md).
Korean brand copy: **운동 휴식 타이머 · 다음세트 · 잠깐 쉬고, 다시 한 세트.**

`store/` holds downscaled copies of the screenshots submitted to App Store Connect (2026-09-23 set).
They are design mockups rendered from `tools/appstore-screenshots/`, not raw device captures. To refresh them, re-render the
full-size set (`tools/appstore-screenshots/render.sh`, `render-ipad.mjs`) and downscale iPhone to 642 px and iPad to 1032 px wide
(`sips --resampleWidth`); Watch stays at 410 × 502.

Use relative paths in the root README so assets work on branches and forks. Keep meaningful alt text and describe features in Markdown, outside the images.

## App Store 배지

`badges/app-store-ko.svg`, `badges/app-store-en.svg`는 Apple 마케팅 도구에서 받은 공식 "App Store에서 다운로드" 배지다(검정, ko-kr / en-us). 수정하지 않고 그대로 쓴다. 다시 받기:
`https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/black/ko-kr` (영어는 `en-us`).
README 의 스토어 링크는 국가 코드 없는 `https://apps.apple.com/app/id6814582323` — 보는 사람의 나라 스토어로 열린다.

## 앱 아이콘

`icons/app-icon-{light,dark,tinted}.png`(256 × 256, 투명 모서리)는 `NextSet/NextSet/AppIcon.icon`을 Icon Composer 의 `ictool`로 렌더한 것이다. 색조는 `TintedLight` 기본 색. 아이콘을 바꾸면 다시 만든다:
`"/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" NextSet/NextSet/AppIcon.icon --export-image --output-file assets/readme/icons/app-icon-light.png --platform iOS --rendition Default --width 256 --height 256 --scale 1` (다크 `Dark`, 색조 `TintedLight`).
