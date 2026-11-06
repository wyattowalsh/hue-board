// Hue Board installer for Scriptable (iPhone/iPad).
// One-time download of the pinned Hue Board 5.1.0 release.
// Hue Bridge keys and saved room settings are never touched.

const APP = "Hue Board";
const VERSION = "5.1.0";
const COMMIT = "fc7c59d8d64cffac40d62a2450c5bb134ca02bfe";
const SOURCE =
  `https://raw.githubusercontent.com/wyattowalsh/hue-board/${COMMIT}/dist/hue-board.js`;

async function message(title, body) {
  const a = new Alert();
  a.title = title;
  a.message = body;
  a.addAction("OK");
  return await a.presentAlert();
}

async function install() {
  const request = new Request(SOURCE);
  request.timeoutInterval = 30;
  const code = await request.loadString();
  if (
    request.response?.statusCode !== 200 ||
    !code.startsWith("// Hue Board 5.1.0 | Standalone Scriptable controller") ||
    code.length < 300000
  ) {
    throw new Error("Download did not match the expected release.");
  }

  let fm;
  try {
    fm = FileManager.iCloud();
    fm.documentsDirectory();
  } catch (_) {
    fm = FileManager.local();
  }
  const destination = fm.joinPath(fm.documentsDirectory(), `${APP}.js`);

  if (fm.fileExists(destination)) {
    await fm.downloadFileFromiCloud(destination);
    if (fm.readString(destination) === code) {
      await message(APP, `Version ${VERSION} is already installed.`);
      return;
    }

    const a = new Alert();
    a.title = "Update Hue Board?";
    a.message = "Back up the existing script before installing? " +
      "Bridge pairing and saved settings will not be changed.";
    a.addAction("Back up and update");
    a.addCancelAction("Cancel");
    if (await a.presentAlert() !== 0) return;

    const stamp = new Date().toISOString().replace(/[:.]/g, "-");
    const backup = fm.joinPath(
      fm.documentsDirectory(), `Hue Board backup ${stamp}.js`
    );
    fm.copy(destination, backup);
  }

  fm.writeString(destination, code);
  if (fm.readString(destination) !== code) {
    throw new Error("Post-install file verification failed.");
  }
  await message("Hue Board installed", `Version ${VERSION} is ready.\n` +
    "Open your script list and run Hue Board.");
}

try {
  await install();
} catch (e) {
  await message("Install failed", String(e?.message || e) +
    "\nYour previous script and pairing were not intentionally deleted.");
} finally {
  Script.complete();
}