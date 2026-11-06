"""Real React bridge -> workspace/controller -> mock Hue resources. No physical light access."""
import asyncio,json
from pathlib import Path
from playwright.async_api import async_playwright
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'qa/v5'
async def main():
 checks=[]
 def check(name,condition):assert condition,name;checks.append(name)
 proc=await asyncio.create_subprocess_exec('node',str(ROOT/'tests/everyday_host.cjs'),stdin=asyncio.subprocess.PIPE,stdout=asyncio.subprocess.PIPE)
 async def host(msg):
  proc.stdin.write((json.dumps(msg)+'\n').encode());await proc.stdin.drain();line=await proc.stdout.readline();assert line,'Host terminated';r=json.loads(line);assert 'error' not in r,r;return r
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox']);page=await browser.new_page(viewport={'width':390,'height':844});errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
  await page.set_content((OUT/'everyday-demo.html').read_text());await page.wait_for_function('()=>window.DECK_BOOT.ready');r=await host({});state=r['state'];await page.evaluate('(s)=>window.DECK.report(s)',state)
  async def cycle(extra=None):
   nonlocal state,r
   packet=await page.evaluate('(s)=>JSON.parse(window.DECK.exchange(s))',state);packet.update(extra or {});r=await host(packet);state=r['state'];await page.evaluate('(s)=>window.DECK.report(s)',state);return r
  def bulb(id):return next(l for l in r['bulbs'] if l['id']==id)
  check('opening workspace has no light writes',r['writes']==0)
  await page.get_by_role('button',name='Bright 100% · same color',exact=True).click();await cycle();check('Bright obeys preexisting 85% ceiling and 75% trim',bulb('l1')['dimming']['brightness']==85 and bulb('l2')['dimming']['brightness']==75);check('new uncapped lamps can reach normal 100%',bulb('l3')['dimming']['brightness']==100 and bulb('l5')['dimming']['brightness']==100);check('brightness does not turn on nondimmable switch',bulb('l4')['on']['on'] is False)
  await cycle({'run':2500});check('reported readback comes from subsequent mock GET',state['telemetry']['data']['l1']['brightness']==85 and state['telemetry']['targets']['l1']['kind']=='manual');check('UI displays observed state after readback','85%' in await page.get_by_role('article',name='Sofa glow').inner_text())
  before=r['writes'];await page.get_by_role('button',name='Review 100% ceilings',exact=True).click();await page.get_by_role('button',name='Continue',exact=True).click();await cycle();check('explicit ceiling update does not itself write lights',r['writes']==before and state['layout']['placements']['l1']['ceiling']==100 and state['layout']['placements']['l2']['trim']==.75)
  await page.get_by_role('button',name='Bright 100% · same color',exact=True).click();await cycle();check('Bright now reaches 100% on formerly capped lamp',bulb('l1')['dimming']['brightness']==100)
  await page.get_by_role('button',name='Turn on Accent plug',exact=True).click();await cycle();check('switch-only resource has a usable power control',bulb('l4')['on']['on'] is True)
  await page.get_by_role('button',name='Warm 2700 K · 45%',exact=True).click();await cycle();check('Warm targets white lamps and keeps trims',bulb('l1')['color_temperature']['mirek']==370 and bulb('l2')['dimming']['brightness']==33.75 and bulb('l3')['dimming']['brightness']==100)
  await page.get_by_role('button',name='Restore session',exact=True).click();await cycle();check('manual controls all restore captured static baselines',state['touched']==0 and bulb('l1')['dimming']['brightness']==45 and bulb('l2')['on']['on'] is False and bulb('l3')['dimming']['brightness']==70 and bulb('l4')['on']['on'] is False)
  await page.get_by_text('Your saved Hue scenes',exact=True).click();before=r['writes'];await page.get_by_role('button',name='Read saved scenes',exact=True).click();await cycle({'scenes':True});check('scene enumeration is read-only and scoped',r['writes']==before and len(state['savedScenes']['items'])==1)
  await page.get_by_role('button',name='Evening unwind',exact=True).click();await cycle();check('saved static scene applied with no source-scene mutation',bulb('l1')['dimming']['brightness']==40 and bulb('l3')['on']['on'] is False and all(c['path'].startswith('light/') for c in r['calls'] if c['method'] in ['PUT','POST','DELETE']))
  await page.get_by_role('button',name='Restore session',exact=True).click();await cycle();check('saved scene static copy is restorable',bulb('l1')['dimming']['brightness']==45 and bulb('l3')['on']['on'] is True)
  check('background capability is reflected from actual Hue resource inventory',state['background']['available'] is True and state['background']['count']>=1)
  await page.get_by_role('button',name='Play in background',exact=True).click();await cycle()
  check('one tap hands off a dynamic palette to Hue Bridge',state['mode']=='delegated' and state['native'] is True and any(c['path'].startswith('scene/') and c['method']=='PUT' and c['payload'].get('recall',{}).get('action')=='dynamic_palette' for c in r['calls']))
  old=r['writes'];await cycle({'run':3500});check('native playback issues no further Scriptable live writes',r['writes']==old and state['native'] is True)
  await page.get_by_role('button',name='Stop ambience',exact=True).click();await cycle();check('explicit stop of Bridge playback',state['native'] is False)
  before=r['writes'];await page.get_by_label('Room or zone').select_option('room/office');await cycle();check('area switch creates no lighting change',r['writes']==before and state['meta']['scopeId']=='room/office');check('area switch updates React metadata and visible lamps',await page.get_by_role('article').count()==1 and await page.get_by_role('article',name='Office light').is_visible())
  await page.get_by_role('button',name='Turn off',exact=True).click();await cycle();check('area power does not affect lights elsewhere',bulb('l6')['on']['on'] is False and bulb('l1')['on']['on'] is True)
  await page.get_by_label('Room or zone').select_option('all/all-lights');await cycle();check('All lights includes current Bridge lights once',len(state['meta']['lights'])==6 and await page.get_by_role('article').count()==6);check('explicit limits persist across overlapping room/all scopes',state['layout']['placements']['l1']['ceiling']==100 and state['layout']['placements']['l2']['trim']==.75)
  await page.get_by_role('button',name='Turn off',exact=True).click();await cycle();check('All lights Off includes switch resources',all(l['on']['on'] is False for l in r['bulbs']))
  check('one serialized writer in active scope',state['stats']['maxConcurrentWriters']==1);check('no JavaScript page errors',not errors)
  (OUT/'everyday-controller-e2e.json').write_text(json.dumps({'passed':len(checks),'checks':checks,'pageErrors':errors,'browser':browser.version,'environment':'Production React, real workspace and controller, mocked native exchange and Hue API. No iOS or physical Bridge verification.'},indent=2));print(json.dumps({'passed':len(checks)},indent=2));await browser.close()
 await host({'close':True});proc.stdin.close();await proc.wait()
asyncio.run(main())
