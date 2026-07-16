import * as childProcess from 'node:child_process';
import * as fs from 'node:fs/promises';
import * as path from 'node:path';
import * as url from 'node:url';
import * as util from 'node:util';

const execFile = util.promisify(childProcess.execFile);
const root = path.resolve(path.dirname(url.fileURLToPath(import.meta.url)), '..');
const config = JSON.parse(await fs.readFile(path.join(root, 'config.json'), 'utf8'));
const formats = JSON.parse(await fs.readFile(path.join(root, 'formats.json'), 'utf8'));
const app = path.join(root, 'dist', `${config.productName}.app`);
const extension = path.join(app, 'Contents', 'PlugIns', 'NetronQuickLook.appex');
const appInfo = path.join(app, 'Contents', 'Info.plist');
const extensionInfo = path.join(extension, 'Contents', 'Info.plist');
const appExecutable = path.join(app, 'Contents', 'MacOS', config.executableName);
const extensionExecutable = path.join(extension, 'Contents', 'MacOS', config.extensionExecutableName);

const run = async (command, args) => (await execFile(command, args)).stdout.trim();
const assert = (condition, message) => {
    if (!condition) {
        throw new Error(message);
    }
};
const plist = (file, key) => run('plutil', ['-extract', key, 'raw', '-o', '-', file]);

await run('plutil', ['-lint', appInfo, extensionInfo]);
const appIdentifier = await plist(appInfo, 'CFBundleIdentifier');
const extensionIdentifier = await plist(extensionInfo, 'CFBundleIdentifier');
assert(appIdentifier === config.bundleIdentifier, 'The app bundle identifier does not match config.json.');
assert(extensionIdentifier === `${appIdentifier}.QuickLookExtension`, 'The extension is not namespaced below the containing app.');
assert(await plist(extensionInfo, 'NSExtension.NSExtensionPointIdentifier') === 'com.apple.quicklook.preview', 'The embedded extension is not a Quick Look preview extension.');

const appPlist = await fs.readFile(appInfo, 'utf8');
assert(appPlist.includes('<key>UTImportedTypeDeclarations</key>'), 'File types must be imported, not claimed as project-owned exports.');
assert(!appPlist.includes('UTExportedTypeDeclarations'), 'The app must not export Netron file types.');
assert(!appPlist.includes('CFBundleDocumentTypes'), 'The app must not register itself as a model-file opener.');
for (const format of formats) {
    assert(appPlist.includes(`<string>${format}</string>`), `Missing file extension: ${format}`);
}

const binaries = [appExecutable, extensionExecutable];
const binaryArchitectures = await Promise.all(binaries.map((executable) => run('lipo', ['-archs', executable])));
for (const [index, value] of binaryArchitectures.entries()) {
    const executable = binaries[index];
    const architectures = value.split(/\s+/).sort();
    assert(JSON.stringify(architectures) === JSON.stringify(['arm64', 'x86_64']), `${path.basename(executable)} is not universal.`);
}
await run('codesign', ['--verify', '--deep', '--strict', app]);
const entitlements = await run('codesign', ['-d', '--entitlements', ':-', extension]);
assert(entitlements.includes('com.apple.security.app-sandbox'), 'The Quick Look extension is not sandboxed.');

const browser = await fs.readFile(path.join(extension, 'Contents', 'Resources', 'Web', 'browser.js'), 'utf8');
assert(browser.includes("url.startsWith('netron-quicklook:')"), 'The bundled renderer does not support the private URL scheme.');
assert(browser.includes("if (!this.environment('quicklook'))"), 'The bundled renderer does not disable telemetry in Quick Look mode.');
const caskFiles = [path.join(root, 'Casks', 'netron-quicklook.rb'), path.join(root, 'scripts', 'update-cask.js')];
const caskContents = await Promise.all(caskFiles.map((file) => fs.readFile(file, 'utf8')));
for (const [index, content] of caskContents.entries()) {
    const file = caskFiles[index];
    assert(content.includes('depends_on macos: :monterey'), `${path.basename(file)} does not use the current Homebrew macOS dependency format.`);
    assert(!/depends_on macos:\s*["']/.test(content), `${path.basename(file)} uses Homebrew's deprecated string comparison format.`);
}
await fs.access(path.join(extension, 'Contents', 'Resources', 'Netron-LICENSE.txt'));
process.stdout.write('verified independent app identity, universal binaries, signatures, renderer patch, and notices\n');
