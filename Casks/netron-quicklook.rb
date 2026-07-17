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

  postflight do
    launch_services = "/System/Library/Frameworks/CoreServices.framework" \
                      "/Frameworks/LaunchServices.framework/Support/lsregister"
    system_command launch_services,
                   args:         ["-f", "#{appdir}/Netron Quick Look.app"],
                   must_succeed: false
  end

  caveats <<~EOS
    Launch "Netron Quick Look" once to finish enabling the full interactive
    Netron preview. Releases may be ad-hoc signed. If macOS blocks the first
    launch, use System Settings > Privacy & Security > Open Anyway. Do not
    disable Gatekeeper or remove quarantine attributes.
  EOS
end
