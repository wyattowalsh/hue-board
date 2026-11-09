/**
 * Public controller adapter.
 *
 * `controller-core.js` owns the state machine. This boundary keeps preset
 * selection side-effect free until Bridge-owned playback eligibility has
 * passed. Unsupported phone-free Play must not persist a different
 * composition or alter a foreground Live session.
 */
const makeControllerCore = makeController;
makeController = function makeSafeController(cfg, group, options = {}) {
  const controller = makeControllerCore(cfg, group, options);
  const dispatchCore = controller.dispatch;

  controller.dispatch = function dispatch(command, payload = null) {
    if (command !== 'playPreset' && command !== 'backgroundPreset') {
      return dispatchCore(command, payload);
    }

    // Validate the preset without changing state. Invalid identifiers follow
    // the core path so its normal user-facing validation error is preserved.
    let nextSettings;
    try {
      nextSettings = applyLibraryPreset(controller.state().settings, payload);
    } catch {
      return dispatchCore(command, payload);
    }

    // The payload-free action performs all scope and fixture eligibility
    // checks first. It only queues the network writer when delegation is safe.
    dispatchCore('background');
    if (controller.state().error) return;

    // A successful validation has queued Bridge playback but no network work
    // starts until the next tick, so the selected preset can now be persisted
    // without an unsupported action ever mutating saved state.
    controller.update({settings: nextSettings});
  };

  return controller;
};
