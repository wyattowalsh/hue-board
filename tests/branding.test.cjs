const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');

test('active application, repository docs, and iPhone distribution use Hue Board', () => {
  const userFiles = [
    'README.md', 'AGENTS.md', 'build.cjs',
    ...fs.readdirSync(path.join(root, 'src')).filter(x => x !== 'legacy.js').map(x => 'src/' + x),
    ...['App.tsx','main.tsx','lib/bridge.ts'].map(x => 'frontend/' + x),
    ...['migration.md','v6-plan.md','validation-v5.md'].map(x => 'docs/' + x),
  ];
  const obsolete = /BOYZ[._ -]?EXE|Cyberdeck/i;
  for (const name of userFiles) assert.doesNotMatch(read(name), obsolete, name);
  assert.match(read('README.md'), /dist\/hue-board\.js/);
  assert.match(read('dist/hue-board.js').slice(0, 200), /Hue Board/);
  assert.equal(read('dist/hue-board.js'), read('dist/hue-board.txt'));
  assert.equal(fs.existsSync(path.join(root, 'dist/BOYZ_EXE_CYBERDECK_v5.js')), false);
});

test('legacy storage constants remain isolated for backward compatibility', () => {
  const { LEGACY_KEYS, migrateLegacyState, VERSION } = require('../dist/testable.cjs');
  assert.equal(VERSION, '5.1.0');
  assert.equal(typeof migrateLegacyState, 'function');
  assert.equal(LEGACY_KEYS.config, 'boyzexe.hue.config.v1');
});
