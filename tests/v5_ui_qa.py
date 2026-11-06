"""Production React UI with explicitly synthetic readback. No physical Hue access."""
import asyncio,json,copy
from pathlib import Path
from playwright.async_api import async_playwright
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'qa/v5'
async def main():
 checks=[];errors=[];requests=[]
 def check(name,ok):
  assert ok,name
  checks.append(name)
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox'])
  page=await browser.new_page(viewport={'width':390,'height':844},color_scheme='light');page.on('pageerror',lambda e:errors.append(str(e)));page.on('request',lambda r:requests.append(r.url))
  async def load(theme='light',width=390):
   await page.set_viewport_size({'width':width,'height':844});await page.emulate_media(color_scheme=theme,reduced_motion='no-preference');await page.set_content((OUT/'everyday-demo.html').read_text());await page.wait_for_function('()=>window.DECK_BOOT.ready');await page.evaluate('''()=>{window.__qaState=structuredClone(window.HUE_BOARD_INITIAL);const s=window.__qaState;s.telemetry.lastRead=Date.now();Object.values(s.telemetry.data).forEach(r=>r.fetchedAt=Date.now());window.DECK.report(s);}''')
  async def packet():
   return await page.evaluate('''()=>{const p=JSON.parse(window.DECK.exchange(window.__qaState));if(p.edit)Object.assign(window.__qaState,p.edit);window.DECK.report(window.__qaState);return p;}''')
  async def report(patch):
   await page.evaluate('(p)=>{Object.assign(window.__qaState,p);window.DECK.report(window.__qaState)}',patch)
  async def commit(slider,value):
   await slider.fill(str(value));before=await packet();check('slider does not send while dragging '+str(value),before['command'] is None);await slider.dispatch_event('pointerup');return await packet()
  await load()
  check('default opens Lights, not animation studio',await page.get_by_role('tab',name='Lights',exact=True).get_attribute('aria-selected')=='true')
  check('page title and rendered everyday surface',await page.title()=='Hue Board' and await page.get_by_role('region',name='Everyday lighting').is_visible())
  check('no light command on opening',(await packet())['command'] is None)
  check('room and zone picker includes All lights',await page.get_by_label('Room or zone',exact=True).locator('option').count()==4)
  check('mixed light inventory includes switch',await page.get_by_role('article').count()==5 and await page.get_by_role('article',name='Accent plug').is_visible())
  await page.get_by_role('button',name='Turn on',exact=True).click();v=await packet();check('area on includes every resource',v['command']['name']=='manual' and set(v['command']['payload']['ids'])=={'l1','l2','l3','l4','l5'} and v['command']['payload']['on'] is True)
  await page.get_by_role('button',name='Turn off',exact=True).click();v=await packet();check('area off is explicit power only',set(v['command']['payload'])=={'ids','on'} and v['command']['payload']['on'] is False)
  v=await commit(page.get_by_role('slider',name='Set brightness · 4 dimmable lights'),100);check('100 percent reaches manual intent, skips switch',v['command']['payload']['brightness']==100 and 'l4' not in v['command']['payload']['ids'])
  await page.get_by_role('button',name='Selected · 4',exact=True).click();await page.get_by_role('button',name='Turn off',exact=True).click();v=await packet();check('selection scope is explicit and excludes unselected plug','l4' not in v['command']['payload']['ids'] and len(v['command']['payload']['ids'])==4)
  await page.get_by_role('button',name='This area · 5',exact=True).click()
  await page.get_by_role('button',name='Warm 2700 K · 45%',exact=True).click();v=await packet();check('Warm targets only compatible white lights',set(v['command']['payload']['ids'])=={'l1','l2'} and v['command']['payload']['kelvin']==2700)
  await page.get_by_role('button',name='Focus 4000 K · 80%',exact=True).click();v=await packet();check('Focus white preset requests 80 percent',v['command']['payload']['brightness']==80)
  await page.get_by_role('button',name='Bright 100% · same color',exact=True).click();v=await packet();check('Bright preserves color rather than replacing it',v['command']['payload']['brightness']==100 and 'hex' not in v['command']['payload'] and 'kelvin' not in v['command']['payload'])
  await page.get_by_role('button',name='Play in background',exact=True).click();v=await packet();check('one-tap background button delegates without a live timer',v['command']['name']=='background')
  await page.get_by_role('button',name='Review 100% ceilings',exact=True).click();check('raising old limits requires titled confirmation',await page.get_by_role('dialog',name='Allow these lamps up to 100%?').is_visible());await page.get_by_role('button',name='Cancel',exact=True).click();v=await packet();check('cancel preserves ceiling and sends no writes',v['edit'] is None and v['command'] is None)
  await page.get_by_role('button',name='Review 100% ceilings',exact=True).click();await page.get_by_role('button',name='Continue',exact=True).click();v=await packet();check('raising ceiling is a settings edit not a write',v['edit']['layout']['placements']['l1']['ceiling']==100 and v['command'] is None);check('raising ceiling retains output trim',v['edit']['layout']['placements']['l2']['trim']==.75)
  await page.get_by_role('button',name='Turn on Accent plug',exact=True).click();v=await packet();check('per switch power has correct sole ID',v['command']['payload']=={'ids':['l4'],'on':True})
  plug=page.get_by_role('article',name='Accent plug');await plug.locator('button.light-main').click();check('plug has no fake dimmer color or temperature',await plug.get_by_role('slider').count()==0 and await plug.locator('input[type=color]').count()==0)
  sofa=page.get_by_role('article',name='Sofa glow');await sofa.locator('button.light-main').click();check('lamp detail expansion semantic state',await sofa.locator('button.light-main').get_attribute('aria-expanded')=='true')
  v=await commit(sofa.get_by_role('slider',name='Set brightness · Sofa glow'),100);check('individual brightness only targets that lamp',v['command']['payload']=={'ids':['l1'],'on':True,'brightness':100})
  slider=sofa.get_by_role('slider',name='White temperature · Sofa glow');check('temperature range comes from fixture',await slider.get_attribute('min')=='2000' and await slider.get_attribute('max')=='6535');v=await commit(slider,4000);check('white slider emits Kelvin',v['command']['payload']['kelvin']==4000)
  await sofa.get_by_label('Color for Sofa glow').fill('#00ffbb');check('color draft does not auto-write',(await packet())['command'] is None);await sofa.get_by_role('button',name='Set color').click();v=await packet();check('explicit color apply sends exact color',v['command']['payload']['hex']=='#00ffbb')
  read=page.get_by_role('article',name='Reading lamp');await read.locator('button.light-main').click();check('white lamp omits unsupported color picker',await read.locator('input[type=color]').count()==0 and await read.get_by_role('slider').count()==2)
  check('off bulbs display stored brightness', '35% stored' in await read.inner_text())
  await page.get_by_label('Find a light').fill('sofa');check('search limits light rows',await page.get_by_role('article').count()==1);await page.get_by_label('Find a light').fill('nosuchlamp');check('search empty state is helpful',await page.get_by_text('No lights match. Clear the search or choose All.',exact=True).is_visible());await page.get_by_label('Find a light').fill('');await page.get_by_label('Show',exact=True).select_option('on');check('On filter uses reported state',await page.get_by_role('article').count()==3);await page.get_by_label('Show',exact=True).select_option('all')
  await page.get_by_text('Color for this area',exact=True).click();await page.get_by_label('Area color').fill('#ee6611');await page.get_by_role('button',name='Apply color',exact=True).click();v=await packet();check('area color skips whites and plugs',set(v['command']['payload']['ids'])=={'l1','l5'})
  await page.get_by_text('Your saved Hue scenes',exact=True).click();await page.get_by_role('button',name='Read saved scenes',exact=True).click();v=await packet();check('saved scene read is explicitly requested',v['command']['name']=='refreshScenes');await report({'savedScenes':{'items':[{'id':'saved-cozy','name':'Evening unwind','count':2}],'pending':False,'error':'','readAt':100}});await page.get_by_role('button',name='Evening unwind',exact=True).click();v=await packet();check('scene copy requests the approved ID',v['command']=={'name':'applyScene','payload':'saved-cozy'})
  await page.get_by_role('button',name='Ambient Ion Eclipse',exact=True).click();v=await packet();check('favorite quick scene hands off to the Bridge',v['command']=={'name':'backgroundPreset','payload':'ion-eclipse'})
  # Keyboard commit and no stale command leakage on a new area.
  await load();slider=page.get_by_role('slider',name='Set brightness · 4 dimmable lights');await slider.focus();await page.keyboard.press('End');v=await packet();check('keyboard End commits 100 percent',v['command']['payload']['brightness']==100)
  await page.get_by_label('Room or zone').select_option('room/office');v=await packet();check('area picker sends switch intent',v['command']=={'name':'switchArea','payload':'room/office'})
  await page.get_by_role('button',name='Turn off',exact=True).click();await page.evaluate('''()=>{const s=window.__qaState;s.meta={...s.meta,scopeId:'room/office',name:'Office',lights:s.meta.lights.filter(l=>l.id==='l1')};s.layout.order=['l1'];s.layout.selected=['l1'];s.layout.placements={l1:s.layout.placements.l1};s.navigation.current='room/office';window.DECK.report(s)}''');v=await packet();check('old pending manual command is discarded on scope change',v['command'] is None);check('new area resets visible light list',await page.get_by_role('article').count()==1)
  await report({'navigation':{'current':'room/office','switching':True,'error':'','areas':[{'id':'room/office','name':'Office','type':'room','count':1}]}});check('scope switch disables everyday actions',await page.get_by_role('button',name='Turn on',exact=True).is_disabled() and await page.get_by_label('Room or zone').is_disabled())
  await load();await page.evaluate('''()=>{const s=window.__qaState;s.telemetry.lastRead=Date.now()-20000;for(const r of Object.values(s.telemetry.data))r.fetchedAt=Date.now()-20000;window.DECK.report(s)}''');check('stale states never look current','Not current' in await page.get_by_role('article',name='Sofa glow').inner_text());await report({'error':'Synthetic failed request. No physical lights were contacted.'});check('visible actionable error',await page.get_by_role('alert').filter(has_text='Synthetic failed request').is_visible())
  await load();await page.evaluate('''()=>{const s=window.__qaState;s.telemetry.data.l1.mode='streaming';window.DECK.report(s)}''');check('streaming lamp power is disabled',await page.get_by_role('button',name='Turn off Sofa glow').is_disabled())
  # Viewport, focus, themes, reduced-motion and visual evidence.
  for theme in ['light','dark']:
   for width in [320,390,1024]:
    await load(theme,width);check(f'{theme} {width} home no horizontal overflow',await page.evaluate('document.documentElement.scrollWidth<=innerWidth'));check(f'{theme} {width} system theme applied',await page.evaluate('document.documentElement.dataset.theme')==theme)
    await page.evaluate('scrollTo(0,0)');await page.screenshot(path=str(OUT/f'home-{theme}-{width}.png'),full_page=False)
  await load('light');await page.emulate_media(color_scheme='dark');await page.wait_for_function('()=>document.documentElement.dataset.theme==="dark"');check('live system appearance change retained',(await packet())['command'] is None)
  await page.emulate_media(reduced_motion='reduce');await page.wait_for_function('()=>document.documentElement.dataset.motion==="reduce"');check('system reduced motion retained',True)
  await load();sofa=page.get_by_role('article',name='Sofa glow');await sofa.locator('button.light-main').click();await sofa.scroll_into_view_if_needed();await page.screenshot(path=str(OUT/'lamp-light-390.png'),full_page=False)
  await load('light',320);await page.set_content((OUT/'everyday-demo.html').read_text().replace('Sofa glow','VeryLongUnbrokenFixtureName'*9));await page.wait_for_function('()=>window.DECK_BOOT.ready');check('long fixture names do not overflow',await page.evaluate('document.documentElement.scrollWidth<=innerWidth'))
  await page.get_by_role('tab',name='Lights',exact=True).focus();await page.keyboard.press('ArrowRight');check('main keyboard tab switching reaches Scenes',await page.get_by_role('tab',name='Scenes',exact=True).get_attribute('aria-selected')=='true')
  check('no runtime page errors',not errors);check('no external network or asset requests',not requests)
  result={'passed':len(checks),'checks':checks,'errors':errors,'externalRequests':requests,'browser':browser.version,'method':'Playwright Chromium with production offline bundle and synthetic fixture readback','physicalHardware':False}
  (OUT/'everyday-ui-results.json').write_text(json.dumps(result,indent=2));print(json.dumps({'passed':len(checks),'errors':errors},indent=2));await browser.close()
asyncio.run(main())
