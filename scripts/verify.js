import * as childProcess from 'node:child_process';
import * as fs from 'node:fs/promises';
import * as path from 'node:path';
import * as url from 'node:url';
import * as util from 'node:util';

const execFile = util.promisify(childProcess.execFile);
const root = path.resolve(path.dirname(url.fileURLToPath(import.meta.url)), '..');
const config = JSON.parse(await fs.readFile(path.join(root, 'config.json'), 'utf8'));
const formats = JSON.parse(await fs.readFile(path.join(root, 'formats.json'), 'utf8'));
const contentTypeAliases = JSON.parse(await fs.readFile(path.join(root, 'content-type-aliases.json'), 'utf8'));
const app = path.join(root, 'dist', `${config.productName}.app`);
const extension = path.join(app, 'Contents', 'PlugIns', 'NetronQuickLook.appex');
const appInfo = path.join(app, 'Contents', 'Info.plist');
const extensionInfo = path.join(extension, 'Contents', 'Info.plist');
const appExecutable = path.join(app, 'Contents', 'MacOS', config.executableName);
const extensionExecutable = path.join(extension, 'Contents', 'MacOS', config.extensionExecutableName);
const contentTypeManifest = path.join(root, 'dist', 'supported-content-types.json');

const run = async (command, args) => (await execFile(command, args)).stdout.trim();
const assert = (condition, message) => {
    if (!condition) {
        throw new Error(message);
    }
};
const plist = (file, key) => run('plutil', ['-extract', key, 'raw', '-o', '-', file]);
const plistJSON = (file, key) => run('plutil', ['-extract', key, 'json', '-o', '-', file]).then((value) => JSON.parse(value));

await run('plutil', ['-lint', appInfo, extensionInfo]);
const appIdentifier = await plist(appInfo, 'CFBundleIdentifier');
const extensionIdentifier = await plist(extensionInfo, 'CFBundleIdentifier');
assert(appIdentifier === config.bundleIdentifier, 'The app bundle identifier does not match config.json.');
assert(extensionIdentifier === `${appIdentifier}.QuickLookExtension`, 'The extension is not namespaced below the containing app.');
assert(await plist(extensionInfo, 'NSExtension.NSExtensionPointIdentifier') === 'com.apple.quicklook.preview', 'The embedded extension is not a Quick Look preview extension.');

const contentTypes = await plistJSON(extensionInfo, 'NSExtension.NSExtensionAttributes.QLSupportedContentTypes');
const routing = JSON.parse(await fs.readFile(contentTypeManifest, 'utf8'));
assert(contentTypes.includes(config.typeIdentifier), 'The Quick Look extension is missing its imported model type.');
assert(JSON.stringify(contentTypes) === JSON.stringify(routing.supportedContentTypes), 'The Quick Look content types do not match the generated routing manifest.');
for (const format of formats) {
    const identifiers = routing.formatIdentifiers[format];
    assert(Array.isArray(identifiers) && identifiers.length > 0, `Missing resolved content type for .${format}.`);
    assert(identifiers.some((identifier) => contentTypes.includes(identifier)), `Quick Look cannot route .${format} files to the extension.`);
}
for (const [format, identifiers] of Object.entries(contentTypeAliases)) {
    assert(identifiers.every((identifier) => routing.formatIdentifiers[format].includes(identifier)), `Missing configured content-type alias for .${format}.`);
}
assert(routing.formatIdentifiers.pkl.some((identifier) => identifier !== config.typeIdentifier), 'The .pkl regression check did not resolve a routable macOS content type.');
assert(routing.formatIdentifiers.pkl.includes('public.pkl-source'), 'The .pkl routing does not cover Xcode\'s public.pkl-source declaration.');

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
assert(entitlements.includes('com.apple.security.network.client'), 'The Quick Look extension cannot launch WebKit networking helpers.');

const browser = await fs.readFile(path.join(extension, 'Contents', 'Resources', 'Web', 'browser.js'), 'utf8');
assert(browser.includes("url.startsWith('netron-quicklook:')"), 'The bundled renderer does not support the private URL scheme.');
assert(browser.includes("if (!this.environment('quicklook'))"), 'The bundled renderer does not disable telemetry in Quick Look mode.');
assert(browser.includes("menu: true,\n            quicklook"), 'The bundled renderer does not retain Netron controls in Quick Look mode.');
const caskFiles = [path.join(root, 'Casks', 'netron-quicklook.rb'), path.join(root, 'scripts', 'update-cask.js')];
const caskContents = await Promise.all(caskFiles.map((file) => fs.readFile(file, 'utf8')));
for (const [index, content] of caskContents.entries()) {
    const file = caskFiles[index];
    assert(content.includes('depends_on macos: :monterey'), `${path.basename(file)} does not use the current Homebrew macOS dependency format.`);
    assert(!/depends_on macos:\s*["']/.test(content), `${path.basename(file)} uses Homebrew's deprecated string comparison format.`);
    assert(content.includes('LaunchServices.framework/Support/lsregister'), `${path.basename(file)} does not register the installed app with Launch Services.`);
}
await fs.access(path.join(extension, 'Contents', 'Resources', 'Netron-LICENSE.txt'));
process.stdout.write('verified independent app identity, universal binaries, signatures, renderer patch, and notices\n');
