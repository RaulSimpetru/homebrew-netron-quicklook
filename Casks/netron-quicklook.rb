cask "netron-quicklook" do
  version "0.1.0"
  sha256 "19e34e4c8c37f3b94fd1db3af9c40603b14d96d1f8b1b25f05b0595c1d480d69"

  url "https://github.com/RaulSimpetru/homebrew-netron-quicklook/releases/download/v#{version}/NetronQuickLook-#{version}.zip"
  name "Netron Quick Look"
  desc "Quick Look previews for machine-learning models using the Netron renderer"
  homepage "https://github.com/RaulSimpetru/homebrew-netron-quicklook"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :monterey"

  app "Netron Quick Look.app"

  caveats <<~EOS
    Releases may be ad-hoc signed. After installation, launch "Netron Quick Look"
    once. If macOS blocks it, use System Settings > Privacy & Security > Open
    Anyway. Do not disable Gatekeeper or remove quarantine attributes.
  EOS
end
