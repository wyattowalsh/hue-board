// Hue Board 5.2.0 pinned installer for Scriptable on iPhone.
// Installs code only; never removes the Hue Bridge authorization or saved settings.
const APP = 'Hue Board';
const VERSION = '5.2.0';
const REVISION = 'f5c1bd9d3c1a6336d2639d8ef63028b31fa945d6';
const EXPECTED_SHA256 = 'd733ef2af228cddf45ca179e567d0c479e1a802b2689818c0918b57c37a71a7d';
const URL = `https://raw.githubusercontent.com/wyattowalsh/hue-board/${REVISION}/dist/hue-board.js`;


/** SHA-256 of UTF-8 bytes; Scriptable provides Data.fromString().getBytes(). */
function sha256Hex(bytes) {
  const K=[0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2];
  const h=[0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19];
  const n=bytes.length,p=Array.from(bytes);p.push(128);
  while(p.length%64!==56)p.push(0);
  const bits=n*8;
  for(const word of [Math.floor(bits/0x100000000),bits>>>0])for(let i=24;i>=0;i-=8)p.push((word>>>i)&255);
  const R=(x,n)=>(x>>>n)|(x<<(32-n));
  for(let offset=0;offset<p.length;offset+=64){
    const w=new Array(64);
    for(let t=0;t<16;t++){const i=offset+t*4;w[t]=(p[i]<<24|p[i+1]<<16|p[i+2]<<8|p[i+3])>>>0;}
    for(let t=16;t<64;t++){const x=w[t-15],y=w[t-2];w[t]=(w[t-16]+(R(x,7)^R(x,18)^(x>>>3))+w[t-7]+(R(y,17)^R(y,19)^(y>>>10)))>>>0;}
    let [a,b,c,d,e,f,g,q]=h;
    for(let t=0;t<64;t++){
      const t1=(q+(R(e,6)^R(e,11)^R(e,25))+((e&f)^(~e&g))+K[t]+w[t])>>>0;
      const t2=((R(a,2)^R(a,13)^R(a,22))+((a&b)^(a&c)^(b&c)))>>>0;
      q=g;g=f;f=e;e=(d+t1)>>>0;d=c;c=b;b=a;a=(t1+t2)>>>0;
    }
    for(const [i,v] of [a,b,c,d,e,f,g,q].entries())h[i]=(h[i]+v)>>>0;
  }
  return h.map(v=>v.toString(16).padStart(8,'0')).join('');
}

async function notice(title, detail) {
  const a = new Alert();
  a.title = title;
  a.message = detail;
  a.addAction('OK');
  await a.presentAlert();
}

async function install() {
  const r = new Request(URL);
  r.timeoutInterval = 30;
  const script = await r.loadString();
  if (r.response?.statusCode !== 200 ||
      !script.startsWith('// Hue Board 5.2.0 | Standalone Scriptable controller') ||
      sha256Hex(Data.fromString(script).getBytes()) !== EXPECTED_SHA256) {
    throw new Error('The pinned release failed download or SHA-256 verification. No files were changed.');
  }

  let manager = FileManager.iCloud();
  try { manager.documentsDirectory(); }
  catch (_) { manager = FileManager.local(); }
  const destination = manager.joinPath(manager.documentsDirectory(), `${APP}.js`);
  if (manager.fileExists(destination)) {
    await manager.downloadFileFromiCloud(destination);
    if (manager.readString(destination) === script) {
      await notice(APP, `${VERSION} is already installed.`);
      return;
    }
    const a = new Alert();
    a.title = 'Update Hue Board?';
    a.message = `Install ${VERSION}? A dated backup of the existing script will be saved first. Hue credentials and saved settings are untouched.`;
    a.addAction('Back up and update');
    a.addCancelAction('Cancel');
    if (await a.presentAlert() !== 0) return;
    const stamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backup = manager.joinPath(manager.documentsDirectory(), `Hue Board backup ${stamp}.js`);
    manager.copy(destination, backup);
  }
  manager.writeString(destination, script);
  if (manager.readString(destination) !== script) {
    throw new Error('Verification after saving failed. Check the backup before retrying.');
  }
  await notice('Hue Board installed', `Version ${VERSION} is ready. Run the Hue Board script in Scriptable.`);
}

try { await install(); }
catch (error) { await notice('Installation stopped', String(error?.message || error)); }
finally { Script.complete(); }
