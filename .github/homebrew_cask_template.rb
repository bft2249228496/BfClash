cask "flclash" do
  version "VERSION"

  on_macos do
    arch arm: "arm64", intel: "amd64"

    sha256 arm:   "ARM_SHA256",
           intel: "AMD_SHA256"

    url "https://github.com/bft2249228496/clash-self/releases/download/v#{version}/BfClash-#{version}-macos-#{arch}.dmg"
  end

  name "BfClash"
  desc "Multi-platform proxy client based on ClashMeta"
  homepage "https://github.com/bft2249228496/clash-self"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on :macos

  app "BfClash.app"

  postflight do
    system_command "xattr",
                   args: ["-rd", "com.apple.quarantine", "#{appdir}/BfClash.app"]
  end

  uninstall quit: "com.follow.clash"

  zap trash: [
    "~/Library/Application Support/com.follow.clash",
    "~/Library/Caches/com.follow.clash",
    "~/Library/Preferences/com.follow.clash.plist",
    "~/Library/Saved Application State/com.follow.clash.savedState",
  ]
end
