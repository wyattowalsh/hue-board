// Hue Board 5.2.0 pinned installer for Scriptable on iPhone.
// Installs code only; never removes the Hue Bridge authorization or saved settings.
const APP = 'Hue Board';
const VERSION = '5.2.0';
const REVISION = '50ba9ecdc445731912ff963ada9c361fc46bba45';
const URL = `https://raw.githubusercontent.com/wyattowalsh/hue-board/${REVISION}/dist/hue-board.js`;

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
      script.length < 300000) {
    throw new Error('The expected pinned release was not received. No files were changed.');
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
