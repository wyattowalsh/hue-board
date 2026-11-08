'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const iconPath = path.join(
  root,
  'ios/App/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'
);

test('native app icon is a pinned 1024px PNG wired into XcodeGen', () => {
  const png = fs.readFileSync(iconPath);
  assert.deepEqual([...png.subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);
  assert.equal(png.readUInt32BE(16), 1024);
  assert.equal(png.readUInt32BE(20), 1024);
  assert.equal(
    crypto.createHash('sha256').update(png).digest('hex'),
    '050f0f008a84fde162da7d1e51c713516c8174eb36d093eb136792dd5a944430'
  );

  const contents = JSON.parse(
    fs.readFileSync(
      path.join(root, 'ios/App/Assets.xcassets/AppIcon.appiconset/Contents.json'),
      'utf8'
    )
  );
  assert.equal(contents.images.length, 1);
  assert.equal(contents.images[0].filename, 'AppIcon-1024.png');
  assert.equal(contents.images[0].idiom, 'universal');
  assert.equal(contents.images[0].platform, 'ios');
  assert.equal(contents.images[0].size, '1024x1024');

  const project = fs.readFileSync(path.join(root, 'ios/project.yml'), 'utf8');
  assert.match(project, /ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon/);
});
