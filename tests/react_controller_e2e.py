import asyncio,json
from pathlib import Path
from playwright.async_api import async_playwright
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'qa/v5';OUT.mkdir(parents=True,exist_ok=True)
async def main():
 proc=await asyncio.create_subprocess_exec('node',str(ROOT/'tests/react_host.cjs'),stdin=asyncio.subprocess.PIPE,stdout=asyncio.subprocess.PIPE)
 async def host(msg):
  proc.stdin.write((json.dumps(msg)+'\n').encode());await proc.stdin.drain();r=json.loads(await proc.stdout.readline());assert 'error' not in r,r;return r
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox']);page=await browser.new_page(viewport={'width':390,'height':844})
  await page.set_content((ROOT/'qa/demo.html').read_text());out=await host({});state=out['state'];await page.evaluate('(s)=>window.DECK.report(s)',state)
  async def cycle(run=None):
   nonlocal state
   packet=await page.evaluate('(s)=>JSON.parse(window.DECK.exchange(s))',state)
   if run:packet['run']=run
   result=await host(packet);state=result['state'];await page.evaluate('(s)=>window.DECK.report(s)',state);return result
  assert out['writes']==0
  await page.get_by_role('tab',name='Studio',exact=True).click()
  await page.get_by_role('button',name='Live Studio · foreground',exact=True).click();r=await cycle();r=await cycle(5000);assert r['writes']>=6 and state['mode']=='live'
  await page.get_by_role('button',name='Pause / cancel',exact=True).click();r=await cycle();before=r['writes'];assert state['mode']=='paused'
  await page.get_by_role('tab',name='Settings',exact=True).click();await page.get_by_role('button',name='App & recovery',exact=True).click();await page.get_by_label('Interface theme',exact=True).select_option('light');r=await cycle();assert r['writes']==before and state['ui']['theme']=='light'
  await page.get_by_role('tab',name='Scenes',exact=True).click();await page.get_by_role('button',name='Preview Pacific Swell',exact=True).click();await cycle();assert state['settings']['showA']=='tide' and state['mode']=='paused'
  await page.get_by_text('Build a cue sequence',exact=True).click();await page.get_by_role('slider',name='Hold each cue',exact=True).fill('30');await cycle();await page.get_by_role('button',name='Start sequence and lights',exact=True).click();await cycle();await cycle(31000);assert state['sequence']['enabled'] and state['sequence']['index']==1
  await page.get_by_role('button',name='Restore',exact=True).click();r=await cycle();assert state['mode']=='paused' and state['touched']==0
  assert all(l['dimming']['brightness']==45 and l['on']['on'] for l in r['bulbs'])
  result={'passed':7,'checks':['no writes opening React view','React Start reaches real controller mock writes','React Pause reaches state machine','theme persists without writes when paused','library preset applies without starting','cue sequence advances through real controller','React Restore restores all six mock baselines'],'physicalHardware':False}
  (OUT/'animation-e2e.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2));await browser.close()
 await host({'close':True});proc.stdin.close();await proc.wait()
asyncio.run(main())
