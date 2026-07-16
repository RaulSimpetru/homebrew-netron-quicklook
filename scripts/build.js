import * as childProcess from 'node:child_process';
import * as fs from 'node:fs/promises';
import * as path from 'node:path';
import * as url from 'node:url';
import * as util from 'node:util';

const execFile = util.promisify(childProcess.execFile);
const root = path.resolve(path.dirname(url.fileURLToPath(import.meta.url)), '..');
const config = JSON.parse(await fs.readFile(path.join(root, 'config.json'), 'utf8'));
const manifest = JSON.parse(await fs.readFile(path.join(root, 'package.json'), 'utf8'));
const formats = JSON.parse(await fs.readFile(path.join(root, 'formats.json'), 'utf8'));
const dist = path.join(root, 'dist');
const app = path.join(dist, `${config.productName}.app`);
const appContents = path.join(app, 'Contents');
const appMacOS = path.join(appContents, 'MacOS');
const appResources = path.join(appContents, 'Resources');
const extension = path.join(appContents, 'PlugIns', 'NetronQuickLook.appex');
const extensionContents = path.join(extension, 'Contents');
const extensionMacOS = path.join(extensionContents, 'MacOS');
const extensionResources = path.join(extensionContents, 'Resources');
const web = path.join(extensionResources, 'Web');
const moduleCache = path.join(dist, 'ModuleCache');

if (process.platform !== 'darwin') {
    throw new Error('netron-quicklook can only be built on macOS.');
}

const run = async (command, args, options = {}) => {
    const result = await execFile(command, args, { cwd: root, ...options });
    return result.stdout.trim();
};

const netronSource = async () => {
    if (process.env.NETRON_SOURCE_DIR) {
        const directory = path.resolve(process.env.NETRON_SOURCE_DIR);
        const upstream = JSON.parse(await fs.readFile(path.join(directory, 'package.json'), 'utf8'));
        if (upstream.version !== config.netron.revision.replace(/^v/, '')) {
            throw new Error(`NETRON_SOURCE_DIR contains Netron ${upstream.version}; expected ${config.netron.revision}.`);
        }
        process.stdout.write(`using local Netron source at ${directory}\n`);
        return directory;
    }
    const directory = path.join(root, 'vendor', 'netron');
    let revision = '';
    try {
        revision = await run('git', ['-C', directory, 'rev-parse', 'HEAD']);
    } catch {
        // Fetch the pinned revision below.
    }
    if (revision !== config.netron.commit) {
        await fs.rm(directory, { recursive: true, force: true });
        await fs.mkdir(directory, { recursive: true });
        await run('git', ['-C', directory, 'init', '--quiet']);
        await run('git', ['-C', directory, 'remote', 'add', 'origin', config.netron.repository]);
        await run('git', ['-C', directory, 'fetch', '--depth=1', 'origin', `refs/tags/${config.netron.revision}`]);
        await run('git', ['-C', directory, 'checkout', '--detach', '--quiet', 'FETCH_HEAD']);
        revision = await run('git', ['-C', directory, 'rev-parse', 'HEAD']);
    }
    if (revision !== config.netron.commit) {
        throw new Error(`Netron revision mismatch: expected ${config.netron.commit}, got ${revision}.`);
    }
    return directory;
};

const replaceOnce = (content, before, after, label) => {
    const index = content.indexOf(before);
    if (index === -1 || content.indexOf(before, index + before.length) !== -1) {
        throw new Error(`Unable to apply the Netron ${label} compatibility patch exactly once.`);
    }
    return `${content.slice(0, index)}${after}${content.slice(index + before.length)}`;
};

const patchBrowser = async () => {
    const file = path.join(web, 'browser.js');
    let content = await fs.readFile(file, 'utf8');
    const dollar = String.fromCharCode(36);
    const environmentBefore = [
        '        this._environment = {',
        '            name: this._document.title,',
        "            type: this._meta.type ? this._meta.type[0] : 'Browser',",
        '            version: this._meta.version ? this._meta.version[0] : null,',
        `            date: Array.isArray(this._meta.date) && this._meta.date.length > 0 && this._meta.date[0] ? new Date(\`${dollar}{this._meta.date[0].split(' ').join('T')}Z\`) : new Date(),`,
        "            packaged: this._meta.version && this._meta.version[0] !== '0.0.0',",
        "            platform: /(Mac|iPhone|iPod|iPad)/i.test(this._navigator.platform) ? 'darwin' : undefined,",
        "            agent: this._navigator.userAgent.toLowerCase().indexOf('safari') !== -1 && this._navigator.userAgent.toLowerCase().indexOf('chrome') === -1 ? 'safari' : '',",
        "            repository: this._element('logo-github').getAttribute('href'),",
        '            menu: true',
        '        };'
    ].join('\n');
    const environmentAfter = [
        '        const params = new this._window.URLSearchParams(this._window.location.search);',
        "        const quicklook = params.get('mode') === 'quicklook';",
        '        this._environment = {',
        '            name: this._document.title,',
        "            type: quicklook ? 'Quick Look' : (this._meta.type ? this._meta.type[0] : 'Browser'),",
        '            version: this._meta.version ? this._meta.version[0] : null,',
        `            date: Array.isArray(this._meta.date) && this._meta.date.length > 0 && this._meta.date[0] ? new Date(\`${dollar}{this._meta.date[0].split(' ').join('T')}Z\`) : new Date(),`,
        "            packaged: !quicklook && this._meta.version && this._meta.version[0] !== '0.0.0',",
        "            platform: /(Mac|iPhone|iPod|iPad)/i.test(this._navigator.platform) ? 'darwin' : undefined,",
        "            agent: this._navigator.userAgent.toLowerCase().indexOf('safari') !== -1 && this._navigator.userAgent.toLowerCase().indexOf('chrome') === -1 ? 'safari' : '',",
        "            repository: this._element('logo-github').getAttribute('href'),",
        '            menu: !quicklook,',
        '            quicklook',
        '        };'
    ].join('\n');
    content = replaceOnce(content, environmentBefore, environmentAfter, 'environment');
    content = replaceOnce(content, `        await age();
        await consent();
        await telemetry();
        await capabilities();`, `        if (!this.environment('quicklook')) {
            await age();
            await consent();
            await telemetry();
            await capabilities();
        }`, 'privacy');
    content = replaceOnce(content, `                if (request.status === 200) {`, `                const customScheme = request.status === 0 && url.startsWith('netron-quicklook:');
                if (request.status === 200 || customScheme) {`, 'URL scheme');
    await fs.writeFile(file, content, 'utf8');
};

const escapeXML = (value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

const renderPlist = async (templateName, output, replacements) => {
    let content = await fs.readFile(path.join(root, 'native', templateName), 'utf8');
    for (const [key, value] of Object.entries(replacements)) {
        if (typeof value === 'object' && value.raw !== undefined) {
            content = content.replaceAll(`<string>__${key}__</string>`, value.raw);
        } else {
            content = content.replaceAll(`__${key}__`, escapeXML(value));
        }
    }
    if (/__[A-Z_]+__/.test(content)) {
        throw new Error(`Unresolved placeholder in ${templateName}.`);
    }
    await fs.writeFile(output, content, 'utf8');
};

const compile = async (source, output, frameworks, extensionTarget = false) => {
    const sdk = await run('xcrun', ['--sdk', 'macosx', '--show-sdk-path']);
    const args = [
        '--sdk', 'macosx', 'clang',
        '-arch', 'arm64',
        '-arch', 'x86_64',
        '-fmodules',
        `-fmodules-cache-path=${moduleCache}`,
        '-fobjc-arc',
        '-isysroot', sdk,
        `-mmacosx-version-min=${config.minimumSystemVersion}`,
        '-Wall',
        '-Wextra',
        '-Werror'
    ];
    if (extensionTarget) {
        args.push('-fapplication-extension', '-Wl,-e,_NSExtensionMain');
    }
    for (const framework of frameworks) {
        args.push('-framework', framework);
    }
    args.push('-o', output, source);
    await run('xcrun', args, { env: { ...process.env, CLANG_MODULE_CACHE_PATH: moduleCache } });
    await fs.chmod(output, 0o755);
};

const sign = async (target, entitlements) => {
    const identity = process.env.SIGNING_IDENTITY || '-';
    const args = ['--force', '--sign', identity];
    if (identity !== '-') {
        args.push('--timestamp', '--options', 'runtime');
    }
    args.push('--entitlements', entitlements, target);
    await run('codesign', args);
};

const upstream = await netronSource();
const upstreamSource = path.join(upstream, 'source');
await fs.rm(dist, { recursive: true, force: true });
await Promise.all([
    fs.mkdir(appMacOS, { recursive: true }),
    fs.mkdir(appResources, { recursive: true }),
    fs.mkdir(extensionMacOS, { recursive: true }),
    fs.mkdir(web, { recursive: true }),
    fs.mkdir(moduleCache, { recursive: true })
]);

const allowedExtensions = new Set(['.css', '.html', '.ico', '.js', '.json', '.png']);
const excludedFiles = new Set(['app.js', 'desktop.mjs', 'node.js']);
await fs.cp(upstreamSource, web, {
    recursive: true,
    filter: (source) => {
        if (source === upstreamSource) {
            return true;
        }
        const name = path.basename(source);
        return !excludedFiles.has(name) && (path.extname(name) === '' || allowedExtensions.has(path.extname(name)));
    }
});
await patchBrowser();

const common = {
    PRODUCT_NAME: config.productName,
    VERSION: manifest.version,
    MINIMUM_SYSTEM_VERSION: config.minimumSystemVersion,
    TYPE_IDENTIFIER: config.typeIdentifier
};
const fileExtensions = formats.map((format) => `                    <string>${escapeXML(format)}</string>`).join('\n');
await renderPlist('App-Info.plist', path.join(appContents, 'Info.plist'), {
    ...common,
    APP_EXECUTABLE: config.executableName,
    APP_BUNDLE_IDENTIFIER: config.bundleIdentifier,
    FILE_EXTENSIONS: { raw: fileExtensions }
});
await renderPlist('Extension-Info.plist', path.join(extensionContents, 'Info.plist'), {
    ...common,
    EXTENSION_EXECUTABLE: config.extensionExecutableName,
    EXTENSION_BUNDLE_IDENTIFIER: `${config.bundleIdentifier}.QuickLookExtension`
});

const notices = path.join(root, 'THIRD_PARTY_NOTICES.md');
const upstreamLicense = path.join(upstream, 'LICENSE');
await Promise.all([
    fs.copyFile(notices, path.join(appResources, 'THIRD_PARTY_NOTICES.txt')),
    fs.copyFile(notices, path.join(extensionResources, 'THIRD_PARTY_NOTICES.txt')),
    fs.copyFile(upstreamLicense, path.join(appResources, 'Netron-LICENSE.txt')),
    fs.copyFile(upstreamLicense, path.join(extensionResources, 'Netron-LICENSE.txt'))
]);

const appExecutable = path.join(appMacOS, config.executableName);
const extensionExecutable = path.join(extensionMacOS, config.extensionExecutableName);
await compile(path.join(root, 'native', 'main.m'), appExecutable, ['AppKit']);
await compile(path.join(root, 'native', 'PreviewViewController.m'), extensionExecutable, ['AppKit', 'QuickLookUI', 'WebKit'], true);
await sign(extension, path.join(root, 'native', 'Extension.entitlements'));
await sign(app, path.join(root, 'native', 'App.entitlements'));
process.stdout.write(`built ${path.relative(root, app)}\n`);
