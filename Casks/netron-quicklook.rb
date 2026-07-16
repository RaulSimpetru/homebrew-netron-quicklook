cask "netron-quicklook" do
  version "0.1.1"
  sha256 "709cf535e348ce05ca7dfb1bbe41accbf1530e519767a87dfcdf877f0175da04"

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
