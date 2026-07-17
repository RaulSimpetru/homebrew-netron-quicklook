# Netron Quick Look

Preview machine-learning models in Finder with Netron's interactive graph
viewer. Select a supported model, press Space, and navigate or inspect the
graph without opening another window.

This is an independent Quick Look extension. It is not maintained, sponsored,
or endorsed by the [Netron](https://github.com/lutzroeder/netron) project.

## Install

Requires macOS 12 or newer.

```sh
brew install --cask RaulSimpetru/netron-quicklook/netron-quicklook
```

Then complete the one-time setup:

1. Launch **Netron Quick Look** from Applications.
2. If macOS blocks it, try launching it first, then choose **Open Anyway** in
   System Settings > Privacy & Security. If it opens normally, no approval is
   needed.
3. If the extension is disabled, click **Open Extensions Settings** in the app
   and enable **Netron Quick Look** under Quick Look extensions.

Do not disable Gatekeeper or remove quarantine attributes.

## Use

Select a [supported model file](formats.json) in Finder and press Space. The
preview provides Netron's graph navigation, inspection, and view controls.
Choose **Open with Netron** when you want to continue in the separate Netron
desktop app.

`Netron.app` is not required for Quick Look previews. Finder's **Open with
Netron** action does require the official
[Netron desktop app](https://github.com/lutzroeder/netron#install), which you
can install separately:

```sh
brew install --cask netron
```

The two casks coexist; `netron-quicklook` does not install, replace, or modify
Netron.

## Update or uninstall

```sh
brew update
brew upgrade --cask RaulSimpetru/netron-quicklook/netron-quicklook
```

```sh
brew uninstall --cask RaulSimpetru/netron-quicklook/netron-quicklook
```

## Troubleshooting

If Finder shows text, raw bytes, or its generic file panel:

1. Launch **Netron Quick Look** once.
2. Click **Open Extensions Settings** in the app and confirm that **Netron
   Quick Look** is enabled.
3. Close the existing preview and press Space again.
4. Run the update command above to install the latest build.

If **Open Anyway** is absent, macOS has not blocked a launch. Open the app
first; no approval is necessary if it starts normally.

If Netron cannot parse the model, the Quick Look extension cannot preview it
either. Try **Open with Netron** to see the complete error.

## Independence, privacy, and signing

The containing app, extension bundle identifiers, and Homebrew cask are
separate from Netron. The app deliberately does not register itself as the
default opener for model files, so it can coexist with `Netron.app` and
Homebrew's `netron` cask.

The renderer is pinned to a verified Netron release. Telemetry, update checks,
and consent prompts are disabled, and previews load model data through a local
private URL scheme. The network-client sandbox entitlement is present only
because current macOS WebKit helper processes require it.

Releases are ad-hoc signed because this project has no Apple signing
credentials. This is suitable for a personal Homebrew tap, but users may need
the one-time Gatekeeper approval described above. The project never uses or
impersonates Netron's signing identity.

Netron's MIT license and the project disclaimer are included in the app and
extension. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Build and release

Local development requires Xcode Command Line Tools and Node.js 20 or newer:

```sh
npm run build
npm run verify
npm run archive
```

The build downloads the pinned Netron source and verifies its commit. To reuse
a matching local checkout:

```sh
NETRON_SOURCE_DIR=/path/to/netron npm run build
```

Copy `dist/Netron Quick Look.app` to `/Applications`, launch it once, and use
the same activation steps described above.

To publish a release, update the version in `package.json`, commit it, tag that
commit as `vX.Y.Z`, and push the branch and tag. GitHub Actions builds the
universal app, publishes the archive, calculates its checksum, and updates
`Casks/netron-quicklook.rb`. Optional Developer ID and notarization secrets can
be added later without changing the user workflow.
