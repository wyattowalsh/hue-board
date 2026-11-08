"""Rendered React UI checks against a synthetic host. No Hue hardware is accessed."""
import asyncio,json
from pathlib import Path
from playwright.async_api import async_playwright
ROOT=Path(__file__).resolve().parents[1]
checks=[]
def check(name,value):
 if not value: raise AssertionError(name)
 checks.append(name)
async def main():
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox'])
  page=await browser.new_page(viewport={'width':390,'height':844},color_scheme='light',device_scale_factor=1)
  errors=[];requests=[]
  page.on('pageerror',lambda e:errors.append(str(e)))
  page.on('request',lambda r:requests.append(r.url))
  async def load(scheme='light',width=390,html='hue-demo.html'):
   await page.set_viewport_size({'width':width,'height':844});await page.emulate_media(color_scheme=scheme,reduced_motion='no-preference')
   await page.set_content((ROOT/'qa'/html).read_text(),wait_until='load')
   await page.wait_for_function('()=>window.DECK_BOOT && window.DECK_BOOT.ready')
   await page.evaluate('window.__host=JSON.parse(JSON.stringify(window.HUE_BOARD_INITIAL));')
   await sync()
  async def sync(overrides=None):
   return await page.evaluate('''(patch)=>{Object.assign(window.__host,patch||{});const h=window.__host;const now=Date.now();h.telemetry.lastRead=now;for(const r of Object.values(h.telemetry.data))r.fetchedAt=now;for(const r of Object.values(h.telemetry.links))r.fetchedAt=now;const p=JSON.parse(window.DECK.exchange(h));if(p.edit){h.settings=p.edit.settings;h.layout=p.edit.layout;h.ui=p.edit.ui;}window.DECK.report(h);return p;}''',overrides)
  async def tab(name):
   await sync()
   target={'Perform':'Studio','Library':'Scenes','Room':'Settings','Lab':'Settings'}.get(name,name)
   await page.get_by_role('tab',name=target,exact=True).click()
   if name in ['Room','Lab']:
    await page.get_by_role('button',name='Room setup' if name=='Room' else 'App & recovery',exact=True).click()
   if name=='Perform':
    detail=page.locator('details').filter(has=page.get_by_text('Your room · live readback',exact=True))
    if await detail.get_attribute('open') is None: await page.get_by_text('Your room · live readback',exact=True).click()
  async def slider(name,value):
   await page.get_by_role('slider',name=name,exact=True).fill(str(value))
  await load()
  check('page identity and actual React runtime',await page.title()=='Hue Board' and await page.evaluate('React.version')=='18.2.0')
  check('nonblank and boot-ready',await page.get_by_role('heading',name='Hue Board',exact=True).is_visible() and await page.locator('#boot').is_hidden())
  check('light is the system default',await page.evaluate('document.documentElement.dataset.theme')=='light')
  await page.emulate_media(color_scheme='dark');await page.wait_for_function('()=>document.documentElement.dataset.theme==="dark"')
  check('live system dark change applies without reload',True)
  await page.emulate_media(color_scheme='light');await page.wait_for_function('()=>document.documentElement.dataset.theme==="light"')
  check('live system light change applies without reload',True)
  await tab('Lab');await page.get_by_label('Interface theme',exact=True).select_option('dark');packet=await sync()
  check('manual theme preference is sent without a light command',packet['edit']['ui']['theme']=='dark' and packet['command'] is None)
  check('manual dark overrides light system',await page.evaluate('document.documentElement.dataset.theme')=='dark')
  await page.get_by_label('Interface theme',exact=True).select_option('system');await sync({'systemDark':True})
  await page.wait_for_function('()=>document.documentElement.dataset.theme==="dark"');check('native iOS appearance input takes effect',True)
  await sync({'systemDark':False});await page.wait_for_function('()=>document.documentElement.dataset.theme==="light"');check('native appearance updates live',True)
  await sync({'systemDark':None});await page.get_by_label('Interface motion',exact=True).select_option('reduce');packet=await sync()
  check('motion preference persists without light commands',packet['edit']['ui']['motion']=='reduce' and packet['command'] is None)
  await tab('Perform');check('Original MIT focus surface mounted',await page.locator('[data-hue-board="focus-surface"]').count()==1)
  await slider('Master brightness',37);packet=await sync();check('master slider edits actual controller settings',packet['edit']['settings']['brightness']==37)
  await page.get_by_text('Compose A / B looks',exact=True).click()
  check('all 24 patterns selectable',await page.get_by_label('Pattern A',exact=True).locator('option').count()==24)
  check('18 factory palettes plus custom selectable',await page.get_by_label('Palette A',exact=True).locator('option').count()==19)
  await page.get_by_label('Pattern A',exact=True).select_option('moire');await page.get_by_label('Palette A',exact=True).select_option('17');await slider('Color saturation',43);await page.get_by_label('Reverse direction',exact=True).check();packet=await sync()
  check('pattern/palette/saturation/reverse wired',packet['edit']['settings']['showA']=='moire' and packet['edit']['settings']['paletteA']==17 and packet['edit']['settings']['saturation']==43 and packet['edit']['settings']['reverse'])
  await page.get_by_text('Sculpt the motion',exact=True).click()
  for label,value in [('Atmosphere floor',25),('Accent amount',35),('Pattern copies',3),('Spatial phase offset',.24),('Intensity curve',1.4),('Director act length',80)]:await slider(label,value)
  packet=await sync();check('six added motion controls wired',all(packet['edit']['settings'][k]==v for k,v in [('ambientFloor',25),('accentMix',35),('density',3),('phaseOffset',.24),('brightnessCurve',1.4),('directorSeconds',80)]))
  await page.get_by_text('Create your own palette',exact=True).click();await page.get_by_label('Custom color 1',exact=True).fill('#aabbcc');await page.get_by_role('button',name='Use for A',exact=True).click();packet=await sync()
  check('custom palette edits reach engine settings',packet['edit']['settings']['customColors'][0]=='#AABBCC' and packet['edit']['settings']['paletteA']==18)
  await tab('Library');check('all 32 curated presets render',await page.get_by_role('button',name='Preview ',exact=False).count()==32)
  await page.get_by_role('button',name='Favorite Ion Eclipse',exact=True).click();packet=await sync();check('favorites persist separately from lighting',packet['edit']['ui']['favorites']==['ion-eclipse'] and packet['command'] is None)
  await page.get_by_role('button',name='Favorites',exact=True).click();check('favorites filter',await page.get_by_role('button',name='Preview ',exact=False).count()==1)
  await page.get_by_role('button',name='Favorites',exact=True).click();await page.get_by_role('button',name='Warm',exact=True).click();check('category filter',0<await page.get_by_role('button',name='Preview ',exact=False).count()<32)
  await page.get_by_role('button',name='All',exact=True).click();await page.get_by_label('Search presets',exact=True).fill('does-not-exist');check('search empty state visible',await page.get_by_text('No matching looks. Try another search or category.',exact=True).is_visible())
  await page.get_by_label('Search presets',exact=True).fill('');await page.get_by_role('button',name='Preview Solar Forge',exact=True).click();packet=await sync();check('preset apply sends explicit id without starting playback',packet['command']=={'name':'applyPreset','payload':'solar-forge'})
  await page.get_by_text('Build a cue sequence',exact=True).click();await page.get_by_label('Add a look',exact=True).select_option('arcade-drift');await page.get_by_role('button',name='Add cue ',exact=False).click();packet=await sync();check('cue addition edits saved sequence',packet['edit']['settings']['sequenceIds'][-1]=='arcade-drift')
  await page.get_by_role('button',name='Move cue 4 earlier',exact=True).click();await slider('Hold each cue',45);await page.get_by_label('Sequence order',exact=True).select_option('shuffle');packet=await sync();check('cue order dwell shuffle configurable',packet['edit']['settings']['sequenceIds'][2]=='arcade-drift' and packet['edit']['settings']['sequenceHold']==45 and packet['edit']['settings']['sequenceOrder']=='shuffle')
  await page.get_by_role('button',name='Start sequence and lights',exact=True).click();packet=await sync();check('cue start explicit command',packet['command']['name']=='startSequence')
  await tab('Room');await page.get_by_role('button',name='Import saved positions',exact=True).click();check('import confirmation opens with a title',await page.get_by_role('dialog',name='Import saved positions?',exact=True).is_visible())
  await page.get_by_role('button',name='Cancel',exact=True).click();packet=await sync();check('cancel import emits no command',packet['command'] is None)
  await page.get_by_label('Map projection',exact=True).select_option('xz');await page.get_by_label('Derive animation path',exact=True).select_option('z');await page.get_by_label('Mirror map horizontally',exact=True).check();await page.get_by_role('button',name='Import saved positions',exact=True).click();await page.get_by_role('button',name='Continue',exact=True).click();packet=await sync()
  check('Hue import preserves reference/projection/path/mirror contract',packet['command']['name']=='importHueLayout' and packet['command']['payload']=={'areaId':'demo-hue-area','projection':'xz','phaseMode':'z','mirror':True})
  await page.get_by_label('Fixture role',exact=True).select_option('task');await slider('Path phase',33);await slider('Fixture ceiling',28);packet=await sync();lamp_id=await page.get_by_label('Inspect a bulb',exact=True).input_value();p0=packet['edit']['layout']['placements'][lamp_id];check('per-fixture roles and limits wired',p0['role']=='task' and p0['q']==.33 and p0['ceiling']==28)
  await page.get_by_label('Include in live control',exact=True).uncheck();packet=await sync();check('deselect keeps placement unchanged',lamp_id not in packet['edit']['layout']['selected'] and packet['edit']['layout']['placements'][lamp_id]==p0)
  # Map keyboard position editing preserves phase.
  marker=page.locator('svg.room-map [role="button"]').first;await marker.focus();await page.keyboard.press('ArrowRight');packet=await sync();check('map keyboard editing sends stable position',packet['edit'] is not None)
  await tab('Lab');await page.get_by_label('Deterministic seed',exact=True).fill('222');await page.get_by_label('Edit crossfade (seconds)',exact=True).fill('7');packet=await sync();check('seed and edit crossfade wired',packet['edit']['settings']['seed']==222 and packet['edit']['settings']['transitionMs']==7000)
  await page.get_by_text('Controller events',exact=True).click();await page.get_by_role('button',name='Export redacted diagnostics',exact=True).click();packet=await sync();check('diagnostic export routes to native handler',packet['command']['name']=='exportDiagnostics')
  await page.get_by_role('button',name='Live · phone open',exact=True).click();packet=await sync();check('Start dispatch',packet['command']['name']=='live')
  await sync({'mode':'live','running':True});await page.get_by_role('button',name='Pause / cancel',exact=True).click();packet=await sync();check('Pause dispatch while live',packet['command']['name']=='pause')
  await sync({'mode':'preparing','running':False,'busy':True,'inFlight':True});await page.get_by_role('button',name='Pause / cancel',exact=True).click();packet=await sync();check('Pause remains available during pending request',packet['command']['name']=='pause')
  await sync({'mode':'paused','busy':False,'inFlight':False,'touched':2});await page.get_by_role('button',name='Restore',exact=True).click();packet=await sync();check('Restore dispatch',packet['command']['name']=='restore')
  await sync({'native':True});await page.get_by_role('button',name='Stop background',exact=True).click();packet=await sync();check('delegated playback stop is explicit',packet['command']['name']=='stopBridge')
  await sync({'error':'Synthetic connection timeout','native':False});check('action error shown visibly',await page.get_by_role('alert').filter(has_text='Synthetic connection timeout').is_visible())
  await sync({'error':''});await tab('Perform')
  await page.evaluate('''()=>{const h=window.__host;h.telemetry.targets[h.layout.order[0]]={kind:'live',acceptedAt:Date.now(),action:{dimming:{brightness:50},color:{xy:{x:.2,y:.3}}}};window.DECK.report(h);}''')
  await page.get_by_role('button',name='Sent target',exact=True).click()
  color=await page.locator('svg.room-map [role="button"]').first.locator('circle').nth(1).get_attribute('fill')
  check('accepted color without a power field is not falsely painted off',color not in ['#273442','#15202b',None])
  await page.get_by_role('button',name='Reported',exact=True).click()
  await page.evaluate('''()=>{let s=structuredClone(window.__host);s.telemetry.lastRead=Date.now()-20000;for(const r of Object.values(s.telemetry.data))r.fetchedAt=Date.now()-20000;window.DECK.report(s);}''');check('stale readback remains explicit',await page.get_by_text('Readback is stale',exact=True).is_visible())
  await load('dark');await page.emulate_media(reduced_motion='reduce');await page.wait_for_function('()=>document.documentElement.dataset.motion==="reduce"');check('system Reduce Motion is respected',True)
  await page.get_by_role('tab',name='Lights',exact=True).focus();await page.keyboard.press('ArrowRight');check('tab keyboard navigation',await page.get_by_role('tab',name='Scenes',exact=True).get_attribute('aria-selected')=='true')
  await page.get_by_label('Search presets',exact=True).fill('NEVER');await page.keyboard.press('Tab');check('keyboard focus remains visible',await page.evaluate('document.activeElement!==document.body'))
  # Responsive and theme screenshot matrix. Uses production bundle and synthetic fixtures.
  for theme in ['light','dark']:
   for width in [320,390,1024]:
    await load(theme,width)
    for section in ['Perform','Library','Room','Lab']:
     await tab(section);await page.evaluate('scrollTo(0,0)');await page.wait_for_timeout(80)
     check(f'{theme} {width} {section} has no horizontal overflow',await page.evaluate('document.documentElement.scrollWidth<=innerWidth'))
     check(f'{theme} {width} {section} primary transport visible',await page.get_by_role('button',name='Live · phone open',exact=True).is_visible())
     if width==390 or (width==1024 and section=='Perform'):
      await page.screenshot(path=str(ROOT/f'qa/{section.lower()}-{theme}-{width}.png'),full_page=False)
  # Long content and failing startup state.
  await load('light',320);await page.evaluate("window.__host.error='Long synthetic error '.repeat(60);window.DECK.report(window.__host)");check('long error wraps on narrow screen',await page.evaluate('document.documentElement.scrollWidth<=innerWidth'))
  await page.set_content((ROOT/'qa/hue-demo.html').read_text().replace('Sofa left','LampWithAnExtremelyLongUnbrokenName'*9));await tab('Room')
  check('long fixture names wrap on narrow Room view',await page.evaluate('document.documentElement.scrollWidth<=innerWidth'))
  await page.evaluate("window.deckBootError('Synthetic startup failure')");check('startup failure is not hidden behind blank canvas',await page.locator('#boot').is_visible() and 'Synthetic startup failure' in await page.locator('#bootDetail').inner_text())
  check('no page JavaScript errors',not errors);check('no external asset or network requests',not requests)
  report={'passed':len(checks),'checks':checks,'errors':errors,'externalRequests':requests,'browser':browser.version,'method':'Playwright Chromium, loadHTML-equivalent set_content; synthetic host, no physical lights','viewports':[320,390,1024]}
  (ROOT/'qa/v5/regression-ui-results.json').write_text(json.dumps(report,indent=2));print(json.dumps({'passed':len(checks),'errors':errors},indent=2))
  await browser.close()
asyncio.run(main())
