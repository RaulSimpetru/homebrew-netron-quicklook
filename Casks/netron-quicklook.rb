cask "netron-quicklook" do
  version "0.1.6"
  sha256 "bb29a4588210f23796bce928b287bc9b4a08caf63a3fa9fc04bdd0e8963d010c"

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
