// Hue Board 5.2.0
// Bundled offline Scriptable application. Source modules and tests are in the source ZIP.
// Local certificate checking is disabled ONLY for private IPv4 Hue endpoints.
// Bridge readback is resource state, not a measurement of emitted light.
const VERSION = '5.2.0';
const STORAGE = 'hue-board.config.v1';
const AUTH_PREFIX = 'hue-board.key.';
const V3_STORE = 'hue-board.workspace.v3';
const V3_SESSION = 'hue-board.sessions.v3';
const V3_SCENES = 'hue-board.scenes.v3';
const FIXTURE_LIMITS_STORE = 'hue-board.fixtureLimits.v5';
const clamp = (v,a,b) => Math.max(a,Math.min(b,v));
const finite = v => typeof v === 'number' && Number.isFinite(v);
const clone = v => JSON.parse(JSON.stringify(v));
const sleep = ms => new Promise(resolve => Timer.schedule(Math.max(1,ms),false,resolve));
const safeJSON = v => JSON.stringify(v).replace(/</g,'\\u003c').replace(/\u2028/g,'\\u2028').replace(/\u2029/g,'\\u2029');
function readObject(key, fallback={}) {
  try { if(!Keychain.contains(key)) return clone(fallback); const v=JSON.parse(Keychain.get(key));
    return v && typeof v==='object' && !Array.isArray(v) ? v : clone(fallback);
  } catch (_) {return clone(fallback);}
}
function writeObject(key,v) {Keychain.set(key,JSON.stringify(v));}
function validIp(ip) {
  if(typeof ip!=='string'||!/^\d{1,3}(\.\d{1,3}){3}$/.test(ip))return false;
  const p=ip.split('.').map(Number); if(!p.every(n=>n>=0&&n<=255))return false;
  return p[0]===10||(p[0]===172&&p[1]>=16&&p[1]<=31)||(p[0]===192&&p[1]===168);
}
function uid() {return typeof UUID!=='undefined'?UUID.string():Date.now().toString(36)+'-'+Math.random().toString(36).slice(2);}
class HueError extends Error {
  constructor(kind,message,status=0,details=[]) {super(message);this.name='HueError';this.kind=kind;this.status=status;this.details=details;}
}
function errorKind(e) {return e && e.kind || 'unknown';}
function shortError(e) {return String(e&&e.message||e).replace(/[A-Za-z0-9_-]{32,}/g,'[redacted]').slice(0,300);}
function resourceAck(reply,rid) {return !!(reply&&Array.isArray(reply.data)&&reply.data.some(r=>r&&r.rid===rid));}
function assertAck(reply,rid) {if(!resourceAck(reply,rid))throw new HueError('protocol','Bridge response did not acknowledge the expected resource. Check readback before retrying.');}
async function choose(title,message,labels,cancel='Back') {
  const a=new Alert();a.title=title;a.message=message;for(const label of labels)a.addAction(label);a.addCancelAction(cancel);return await a.presentSheet();
}
async function inform(title,message) {const a=new Alert();a.title=title;a.message=message;a.addAction('OK');await a.presentAlert();}
async function input(title,message,value='') {
  const a=new Alert();a.title=title;a.message=message;a.addTextField('Value',String(value));a.addAction('Save');a.addCancelAction('Cancel');return await a.presentAlert()<0?null:a.textFieldValue(0).trim();
}
async function confirm(title,message) {return await choose(title,message,['Continue'],'Cancel')===0;}
