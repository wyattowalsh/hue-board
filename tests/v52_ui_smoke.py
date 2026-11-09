import asyncio,json
from pathlib import Path
from playwright.async_api import async_playwright
ROOT=Path(__file__).resolve().parents[1]
async def run():
 checks=[]; errors=[]
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox'])
  page=await browser.new_page(viewport={'width':390,'height':844},color_scheme='light')
  page.on('pageerror',lambda e:errors.append(str(e)))
  async def check(label,condition):
   if not condition: raise AssertionError(label)
   checks.append(label)
  for theme,width in [('light',390),('dark',390),('light',320),('dark',1024)]:
   await page.set_viewport_size({'width':width,'height':844})
   await page.emulate_media(color_scheme=theme)
   await page.set_content((ROOT/'qa'/'demo.html').read_text())
   await page.wait_for_function('window.DECK_BOOT && window.DECK_BOOT.ready')
   await check(f'{theme} {width} boot',await page.get_by_role('heading',name='Hue Board').is_visible())
   await check(f'{theme} {width} no overflow',await page.evaluate('document.documentElement.scrollWidth<=innerWidth'))
   await check(f'{theme} {width} appearance',await page.evaluate('document.documentElement.dataset.theme')==theme)
   if theme=='light' and width==390: await page.screenshot(path='/mnt/data/Hue_Board_v5_2_0_LIGHT.png',full_page=False)
   if theme=='dark' and width==390: await page.screenshot(path='/mnt/data/Hue_Board_v5_2_0_DARK.png',full_page=False)
  await page.set_viewport_size({'width':390,'height':844})
  await page.emulate_media(color_scheme='light')
  await page.set_content((ROOT/'qa'/'demo.html').read_text())
  await page.wait_for_function('window.DECK_BOOT && window.DECK_BOOT.ready')
  await page.evaluate('window.__testHost = JSON.parse(JSON.stringify(window.HUE_BOARD_INITIAL || {}))')
  for tab in ['Scenes','Studio','Settings']:
   await page.get_by_role('tab',name=tab,exact=True).click()
   await check(f'{tab} renders',await page.get_by_role('tab',name=tab,exact=True).get_attribute('aria-selected')=='true')
  await page.get_by_role('button',name='App & recovery',exact=True).click()
  await check('automatic background guidance in recovery',await page.get_by_text('Automatic playback:',exact=False).count()>0)
  await check('no background switch required',await page.get_by_role('checkbox',name='Keep playing when I leave').count()==0)
  await page.get_by_role('tab',name='Scenes',exact=True).click()
  await check('automatic Bridge explanation in Scenes',await page.get_by_text('Play automatically continues on the Hue Bridge').is_visible())
  await page.get_by_role('button',name='Play · phone-free',exact=True).click()
  packet=await page.evaluate('JSON.parse(window.DECK.exchange(window.__testHost))')
  await check('phone-free Play is explicit, not a startup write',packet['command']['name']=='background')
  await page.get_by_role('button',name='Live Studio · foreground',exact=True).click()
  packet=await page.evaluate('JSON.parse(window.DECK.exchange(window.__testHost))')
  await check('Live Studio has separate foreground intent',packet['command']['name']=='live')
  await check('no JavaScript exceptions',len(errors)==0)
  print(json.dumps({'passed':len(checks),'errors':errors,'checks':checks},indent=2))
  await browser.close()
asyncio.run(run())
