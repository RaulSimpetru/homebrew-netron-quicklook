cask "netron-quicklook" do
  version "0.1.3"
  sha256 "67e5433a39bd556a064c1f0d951aca3b0956919fab1ca83b5e36dc622ad0fcf7"

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
