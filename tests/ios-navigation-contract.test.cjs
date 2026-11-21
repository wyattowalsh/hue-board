const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');

test('native primary navigation has four product destinations and modal settings',()=>{
  const model=read('ios/App/AppModel.swift');
  const rootView=read('ios/App/Views/RootView.swift');
  const settings=read('ios/App/Views/SettingsView.swift');

  assert.match(model,/enum Tab: Hashable \{ case lights, scenes, live, room \}/);
  assert.doesNotMatch(model,/case settings/);
  assert.match(model,/isSettingsPresented/);
  assert.equal((rootView.match(/\.tabItem/g)||[]).length,4);
  assert.doesNotMatch(rootView,/\.tag\(AppModel\.Tab\.settings\)/);
  for (const destination of ['LightsView', 'ScenesView', 'LiveView', 'RoomLayoutView']) {
    assert.ok(rootView.includes(destination + '().hueBoardSettingsToolbar()'), destination);
  }
  assert.match(rootView,/Button\("Settings", systemImage: "[^"]+"\)\s*\{\s*model\.isSettingsPresented = true\s*\}/);
  assert.match(rootView,/sheet\(isPresented: \$model\.isSettingsPresented\)\s*\{\s*NavigationStack\s*\{\s*SettingsView\(\)/);
  assert.match(settings,/Button\("Done"\)\s*\{\s*model\.isSettingsPresented = false\s*\}/);
});
