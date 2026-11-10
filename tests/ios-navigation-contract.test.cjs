const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');

test('native primary navigation has three product destinations and modal settings',()=>{
  const model=read('ios/App/AppModel.swift');
  const rootView=read('ios/App/Views/RootView.swift');
  const lights=read('ios/App/Views/LightsView.swift');
  const scenes=read('ios/App/Views/ScenesView.swift');
  const live=read('ios/App/Views/LiveView.swift');
  const settings=read('ios/App/Views/SettingsView.swift');

  assert.match(model,/enum Tab: Hashable \{ case lights, scenes, live \}/);
  assert.doesNotMatch(model,/case settings/);
  assert.match(model,/isSettingsPresented/);
  assert.equal((rootView.match(/\.tabItem/g)||[]).length,3);
  assert.doesNotMatch(rootView,/\.tag\(AppModel\.Tab\.settings\)/);
  assert.match(rootView,/sheet\(isPresented: \$model\.isSettingsPresented\)/);
  for(const source of [lights,scenes,live]) assert.match(source,/accessibilityLabel\("Settings"\)/);
  assert.match(settings,/Button\("Done"\)/);
});
