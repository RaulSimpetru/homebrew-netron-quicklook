cask "netron-quicklook" do
  version "0.1.2"
  sha256 "4189b92822ca93e5d61771219026871350bee1634f9cbcf267a87e70e6a6c838"

  url "https://github.com/RaulSimpetru/homebrew-netron-quicklook/releases/download/v#{version}/NetronQuickLook-#{version}.zip"
  name "Netron Quick Look"
  desc "Quick Look previews for machine-learning models using the Netron renderer"
  homepage "https://github.com/RaulSimpetru/homebrew-netron-quicklook"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :monterey

  app "Netron Quick Look.app"

  caveats <<~EOS
    Releases may be ad-hoc signed. After installation, launch "Netron Quick Look"
    once. If macOS blocks it, use System Settings > Privacy & Security > Open
    Anyway. Do not disable Gatekeeper or remove quarantine attributes.
  EOS
end
