import * as childProcess from 'node:child_process';
import * as fs from 'node:fs/promises';
import * as path from 'node:path';
import * as url from 'node:url';
import * as util from 'node:util';

const execFile = util.promisify(childProcess.execFile);
const root = path.resolve(path.dirname(url.fileURLToPath(import.meta.url)), '..');
const config = JSON.parse(await fs.readFile(path.join(root, 'config.json'), 'utf8'));
const manifest = JSON.parse(await fs.readFile(path.join(root, 'package.json'), 'utf8'));
const app = path.join(root, 'dist', `${config.productName}.app`);
const archive = path.join(root, 'dist', `NetronQuickLook-${manifest.version}.zip`);

await fs.access(app);
await fs.rm(archive, { force: true });
await execFile('ditto', ['-c', '-k', '--sequesterRsrc', '--keepParent', app, archive]);
process.stdout.write(`${archive}\n`);
