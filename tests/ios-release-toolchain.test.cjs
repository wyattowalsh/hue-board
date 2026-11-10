const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');

test('strict TypeScript and aggregate source check are configured',()=>{
  const pkg=require('../package.json');
  const config=JSON.parse(read('tsconfig.json'));
  assert.equal(pkg.scripts.typecheck,'tsc --noEmit');
  assert.match(pkg.scripts.check,/pnpm typecheck/);
  assert.equal(config.compilerOptions.strict,true);
  assert.equal(config.compilerOptions.noUncheckedIndexedAccess,true);
  assert.equal(config.compilerOptions.exactOptionalPropertyTypes,true);
  assert.deepEqual(config.include,['frontend/**/*.ts','frontend/**/*.tsx']);
});

test('native app declares privacy behavior without tracking or collected data',()=>{
  const privacy=read('ios/App/PrivacyInfo.xcprivacy');
  assert.match(privacy,/NSPrivacyTracking/);
  assert.match(privacy,/<false\/>/);
  assert.match(privacy,/NSPrivacyCollectedDataTypes/);
  assert.match(privacy,/NSPrivacyAccessedAPICategoryUserDefaults/);
  assert.match(privacy,/CA92\.1/);
  assert.doesNotMatch(privacy,/NSPrivacyCollectedDataType[A-Z]/);
});

test('XcodeGen project has real app and UI test targets',()=>{
  const project=read('ios/project.yml');
  assert.match(project,/HueBoardAppTests:/);
  assert.match(project,/type: bundle\.unit-test/);
  assert.match(project,/HueBoardUITests:/);
  assert.match(project,/type: bundle\.ui-testing/);
  assert.match(project,/testTargets:\s*\n\s*- HueBoardAppTests\s*\n\s*- HueBoardUITests/);
});

test('hosted native workflow uses pinned Xcode 27.2, tests, archive, privacy check, and evidence upload',()=>{
  const workflow=read('.github/workflows/ios.yml');
  assert.match(workflow,/runs-on: macos-27/);
  assert.match(workflow,/Xcode_27\.2\.app/);
  assert.match(workflow,/pnpm typecheck/);
  assert.match(workflow,/xcodebuild[\s\S]*\stest/);
  assert.match(workflow,/xcodebuild[\s\S]*\sarchive/);
  assert.match(workflow,/PrivacyInfo\.xcprivacy/);
  assert.match(workflow,/actions\/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02/);
});
