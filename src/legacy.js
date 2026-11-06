// Migration-only legacy identifiers from Scriptable releases before Hue Board.
// Do not reuse these identifiers for new data or delete old Keychain entries.
const LEGACY_MIX_APP = 'BOYZ.EXE';
const LEGACY_KEYS = Object.freeze({
  config: 'boyzexe.hue.config.v1',
  authIpPrefix: 'boyzexe.hue.key.',
  authBridgePrefix: 'boyzexe.hue.bridgekey.',
  workspace: 'boyzexe.hue.cyberdeck.v3',
  sessions: 'boyzexe.hue.cyberdeck.sessions.v3',
  scenes: 'boyzexe.hue.cyberdeck.scenes.v3',
  fixtureLimits: 'boyzexe.hue.fixtureLimits.v5',
  olderWorkspace: 'boyzexe.hue.cyberdeck.v2',
  olderRestore: 'boyzexe.hue.cyberdeck.restore.v2'
});
function copyLegacyKey(target, source) {
  if (!Keychain.contains(target) && Keychain.contains(source)) {
    Keychain.set(target, Keychain.get(source));
    return true;
  }
  return false;
}
function migrateLegacyState() {
  // Migrate once per namespace; never overwrite a newer Hue Board value.
  for (const [newKey, oldKey] of [
    [STORAGE, LEGACY_KEYS.config],
    [V3_STORE, LEGACY_KEYS.workspace],
    [V3_SESSION, LEGACY_KEYS.sessions],
    [V3_SCENES, LEGACY_KEYS.scenes],
    [FIXTURE_LIMITS_STORE, LEGACY_KEYS.fixtureLimits]
  ]) copyLegacyKey(newKey, oldKey);
}
function migrateLegacyBridgeKey(config) {
  if (!validIp(config.ip)) return;
  const canonical = authName(config);
  if (Keychain.contains(canonical)) return;
  const sources = [
    config.bridgeId && LEGACY_KEYS.authBridgePrefix + config.bridgeId,
    AUTH_PREFIX + config.ip,
    LEGACY_KEYS.authIpPrefix + config.ip
  ].filter(Boolean);
  for (const oldKey of sources) {
    if (copyLegacyKey(canonical, oldKey)) return;
  }
}
