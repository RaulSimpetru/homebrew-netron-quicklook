cask "netron-quicklook" do
  version "0.1.7"
  sha256 "ab6c596ac1a045428ff48c4cef1487fe937b9b9f2863259b83311469ec95b1d3"

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
    Launch "Netron Quick Look" once to finish enabling the full interactive
    Netron preview. Releases may be ad-hoc signed. If macOS blocks the first
    launch, use System Settings > Privacy & Security > Open Anyway. Do not
    disable Gatekeeper or remove quarantine attributes.
  EOS
end
