# Project tools

Run commands from the repository root. These tools use local files and do not upload to App Store Connect.

| Folder | Command | Output |
| --- | --- | --- |
| [appstore-screenshots](appstore-screenshots/README.md) | See the renderer guide | Local App Store PNG drafts and layout checks |
| [audio](audio/) | `python3 tools/audio/make_sounds.py` | App CAF resources; macOS `afconvert` required |
| [icons](icons/) | `swift tools/icons/strip_alpha.swift <input.png> <output.png>` | PNG without alpha; macOS Swift required |
| [release-site](release-site/) | `python3 tools/release-site/build.py` | `docs/release/site/`; GitHub Actions publishes this directory |

Original images and audio belong in [assets](../assets/README.md). Build outputs and uploaded screenshot archives have separate locations; regeneration must not overwrite an upload archive.
