# netron-quicklook

`netron-quicklook` is an independent macOS Quick Look preview extension for
machine-learning model files. It embeds a pinned, lightly patched copy of the
[Netron](https://github.com/lutzroeder/netron) web renderer.

This project is not maintained, sponsored, or endorsed by the Netron project.
It does not replace `Netron.app`, alter a Netron installation, or modify
Homebrew's existing `netron` cask.

## How coexistence works

macOS requires a modern Quick Look extension to live inside a containing app,
so Homebrew installs a small, independent `Netron Quick Look.app`. Its bundle
identifier and cask token are separate from Netron's:

- App: `Netron Quick Look.app`
- Cask: `netron-quicklook`
- Bundle: `io.github.netronquicklook.NetronQuickLook`
- Extension: `io.github.netronquicklook.NetronQuickLook.QuickLookExtension`

The containing app uses `UTImportedTypeDeclarations` and deliberately omits
`CFBundleDocumentTypes`. It therefore describes supported filename extensions
for Quick Look without registering itself as the default application for those
files. Netron and `netron-quicklook` can be installed or removed independently.

Change the provisional bundle identifier in `config.json` to a namespace you
control before the first public release. Do not change it after users install
the extension, because macOS treats a new identifier as a different extension.

## Build locally

Requirements:

- macOS 12 or newer
- Xcode Command Line Tools
- Node.js 20 or newer

The normal build fetches the exact Netron tag and verifies its commit:

```sh
npm run build
npm run verify
npm run archive
```

During development, an existing Netron checkout at the pinned version can be
used without downloading it again:

```sh
NETRON_SOURCE_DIR=/path/to/netron npm run build
```

Local builds are ad-hoc signed. Copy `dist/Netron Quick Look.app` to
`/Applications`, launch it once, then select a supported model in Finder and
press Space. If macOS disables the extension, use the app's **Open Extensions
Settings** button.

## Netron dependency

The renderer is pinned in `config.json`; it is not a fork of the Netron desktop
application. The build copies only browser assets, applies three guarded
compatibility changes, and fails if the pinned source no longer matches:

- turn off Netron telemetry, consent, and update prompts in Quick Look;
- hide application menus in the preview;
- allow model data from the extension's private `netron-quicklook:` URL scheme.

Netron's MIT license and the project disclaimer are embedded in both the host
app and extension. See `THIRD_PARTY_NOTICES.md`.

## Homebrew tap without Apple credentials

Use a GitHub repository named `homebrew-netron-quicklook`. After its first
release, users can install the cask directly with:

```sh
brew install --cask GITHUB_OWNER/netron-quicklook/netron-quicklook
```

The fully qualified command installs this cask from your tap and cannot resolve
to Homebrew's separate `netron` cask.

No paid Apple account is required for a personal tap. When no signing secrets
are configured, the release workflow publishes an ad-hoc-signed universal app,
calculates its SHA-256, and commits `Casks/netron-quicklook.rb` to the default
branch. After installing it, users must launch **Netron Quick Look** once. If
Gatekeeper blocks it, they can approve that specific build with **Open Anyway**
in System Settings > Privacy & Security. The cask repeats this instruction.

Do not tell users to disable Gatekeeper or strip quarantine attributes. An
ad-hoc build is appropriate for a personal tap and informed testers, but it is
not eligible for the official `Homebrew/homebrew-cask` repository.

If Developer ID credentials are added later, the same workflow automatically
signs, notarizes, and staples releases. All of these GitHub Actions secrets are
optional and are only needed for that distribution mode:

- `DEVELOPER_ID_APPLICATION`
- `DEVELOPER_ID_CERTIFICATE_BASE64`
- `DEVELOPER_ID_CERTIFICATE_PASSWORD`
- `KEYCHAIN_PASSWORD`
- `APPLE_API_KEY_BASE64`
- `APPLE_API_KEY_ID`
- `APPLE_API_ISSUER_ID`

Never copy another developer's certificate into this repository. A future
release sponsor should run signing in an environment they control and keep the
certificate in their own protected secrets.

## Release

1. Update `package.json` and commit the version.
2. Tag the same commit, for example `git tag v0.1.0`.
3. Push the branch and tag.
4. Let the release workflow publish the archive and cask.

The independent tap is usable immediately and does not require cooperation
from Netron's maintainer. Submitting to `Homebrew/homebrew-cask` remains an
option only after releases pass Gatekeeper and the project meets Homebrew's
other acceptance criteria.
