import * as fs from 'node:fs/promises';
import * as path from 'node:path';
import * as url from 'node:url';

const root = path.resolve(path.dirname(url.fileURLToPath(import.meta.url)), '..');
const config = JSON.parse(await fs.readFile(path.join(root, 'config.json'), 'utf8'));
const manifest = JSON.parse(await fs.readFile(path.join(root, 'package.json'), 'utf8'));
const args = new Map();
for (let index = 2; index < process.argv.length; index += 2) {
    args.set(process.argv[index], process.argv[index + 1]);
}
const repository = args.get('--repository') || process.env.GITHUB_REPOSITORY;
const sha256 = args.get('--sha256');
const version = args.get('--version') || manifest.version;
if (!repository || !/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repository)) {
    throw new Error('Pass --repository owner/homebrew-netron-quicklook.');
}
if (!sha256 || !/^[a-fA-F0-9]{64}$/.test(sha256)) {
    throw new Error('Pass the release archive checksum as --sha256.');
}
if (!/^\d+\.\d+\.\d+$/.test(version)) {
    throw new Error('The cask version must use semantic versioning.');
}

const content = `cask "netron-quicklook" do
  version "${version}"
  sha256 "${sha256.toLowerCase()}"

  url "https://github.com/${repository}/releases/download/v#{version}/NetronQuickLook-#{version}.zip"
  name "${config.productName}"
  desc "Quick Look previews for machine-learning models using the Netron renderer"
  homepage "https://github.com/${repository}"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :monterey

  app "${config.productName}.app"

  caveats <<~EOS
    Releases may be ad-hoc signed. After installation, launch "${config.productName}"
    once. If macOS blocks it, use System Settings > Privacy & Security > Open
    Anyway. Do not disable Gatekeeper or remove quarantine attributes.
  EOS
end
`;
const directory = path.join(root, 'Casks');
const file = path.join(directory, 'netron-quicklook.rb');
await fs.mkdir(directory, { recursive: true });
await fs.writeFile(file, content, 'utf8');
process.stdout.write(`${file}\n`);
