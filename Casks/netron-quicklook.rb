cask "netron-quicklook" do
  version "0.1.5"
  sha256 "932c9f8c7d228a591d30e7949c035e7915b52ae366d26196048da158142dfad1"

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
