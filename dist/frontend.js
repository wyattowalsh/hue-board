(function(){'use strict';const modules={"App":function(module,exports,require){
"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = App;
const React = __importStar(require("react"));
const bridge_1 = require("./lib/bridge");
const ui_1 = require("./components/ui");
const MapPreview_1 = require("./components/MapPreview");
const LightsPanel_1 = require("./components/LightsPanel");
const PerformPanel_1 = require("./components/PerformPanel");
const LibraryPanel_1 = require("./components/LibraryPanel");
const RoomPanel_1 = require("./components/RoomPanel");
const LabPanel_1 = require("./components/LabPanel");
const tabs = [['lights', 'Lights'], ['library', 'Looks'], ['perform', 'Studio'], ['settings', 'Settings']];
function App() {
    const { status: state, settings, layout, ui, heartbeat } = (0, bridge_1.useDeck)(), now = (0, bridge_1.useNow)();
    const [tab, setTab] = React.useState('lights'), [settingsTab, setSettingsTab] = React.useState('room'), [focusId, setFocus] = React.useState(bridge_1.META.lights[0]?.id || ''), [newBaseline, setNewBaseline] = React.useState(false);
    const { theme, reduced } = (0, bridge_1.useAppearance)(ui, state.systemDark), scopeId = state.meta?.scopeId || bridge_1.META.name;
    const idle = now - heartbeat > 7000, switching = !!state.navigation?.switching, stopping = ['live', 'preparing', 'adjusting', 'restoring', 'stopping'].includes(state.mode) || state.busy;
    React.useLayoutEffect(() => { window.DECK_BOOT.ready = true; const boot = document.getElementById('boot'); if (boot)
        boot.hidden = true; }, []);
    React.useEffect(() => { setFocus(bridge_1.META.lights[0]?.id || ''); }, [scopeId]);
    function selectTab(id) { setTab(id); window.scrollTo({ top: 0, behavior: 'auto' }); }
    function tabKeys(event, i) { let n = i; if (event.key === 'ArrowRight')
        n = (i + 1) % tabs.length;
    else if (event.key === 'ArrowLeft')
        n = (i + tabs.length - 1) % tabs.length;
    else if (event.key === 'Home')
        n = 0;
    else if (event.key === 'End')
        n = tabs.length - 1;
    else
        return; event.preventDefault(); selectTab(tabs[n][0]); document.getElementById('tab-' + tabs[n][0])?.focus(); }
    const summary = state.mode === 'live' ? 'Animation running' : state.native ? 'Bridge playback' : state.mode === 'adjusting' ? 'Applying lighting' : state.busy ? 'Working' : idle ? 'Controller idle' : 'Ready';
    return React.createElement(React.Fragment, null,
        React.createElement("main", { className: "app", "data-surface": tab },
            React.createElement("header", { className: "app-header" },
                React.createElement("div", null,
                    React.createElement("h1", { className: "wordmark" },
                        "Hue",
                        React.createElement("span", null, " Board")),
                    React.createElement("p", { className: "app-subtitle" }, "Everyday light. Extraordinary nights.")),
                React.createElement("div", { className: "topbar-status" },
                    React.createElement("div", null, summary),
                    React.createElement("p", { className: "mt-1 text-muted-foreground" },
                        ui.theme === 'system' ? 'System · ' : '',
                        theme))),
            state.navigation ? React.createElement("div", { className: "area-picker" },
                React.createElement(ui_1.Select, { id: "areaPicker", label: "Room or zone", disabled: switching, value: state.navigation.current, options: state.navigation.areas.map(a => [a.id, `${a.name} · ${a.count} ${a.type === 'all' ? 'lights on this Bridge' : a.type === 'zone' ? 'lights / zone' : 'lights'}`]), onChange: id => bridge_1.deck.send({ name: 'switchArea', payload: id }) }),
                switching ? React.createElement("p", { className: "muted-note", role: "status" }, "Finishing the current request before switching. No overlapping controller is started.") : null) : React.createElement("p", { className: "mb-5 text-sm text-muted-foreground" }, bridge_1.META.name),
            React.createElement("nav", { className: "tabs", role: "tablist", "aria-label": "Control surfaces" }, tabs.map(([id, label], i) => React.createElement("button", { id: 'tab-' + id, key: id, type: "button", role: "tab", "aria-selected": tab === id, "aria-controls": 'panel-' + id, tabIndex: tab === id ? 0 : -1, onClick: () => selectTab(id), onKeyDown: e => tabKeys(e, i) }, label))),
            state.navigation?.error ? React.createElement("div", { className: "mb-5" },
                React.createElement(ui_1.Alert, { title: "Could not change area", destructive: true }, state.navigation.error)) : null,
            state.error ? React.createElement("div", { className: "mb-5" },
                React.createElement(ui_1.Alert, { title: "Needs attention", destructive: true }, state.error)) : null,
            idle ? React.createElement("div", { className: "mb-5" },
                React.createElement(ui_1.Alert, { title: "Controller is not responding" }, "Keep Scriptable open. Values below retain their last read time; commands are not confirmed until acknowledged.")) : null,
            state.session.recoveryRequired ? React.createElement("div", { className: "mb-5" },
                React.createElement(ui_1.Alert, { title: "Keep your previous restore point?" },
                    React.createElement("p", null,
                        "It was captured ",
                        state.session.createdAt ? new Date(state.session.createdAt).toLocaleString() : 'at an unknown time in an older version',
                        ". Keep it to continue, or start a fresh baseline. Neither choice turns lights on."),
                    React.createElement("div", { className: "mt-3 flex flex-wrap gap-2" },
                        React.createElement(ui_1.Button, { size: "sm", onClick: () => bridge_1.deck.send({ name: 'resumeSession' }) }, "Keep restore point"),
                        React.createElement(ui_1.Button, { size: "sm", variant: "outline", onClick: () => setNewBaseline(true) }, "Start fresh")))) : null,
            state.sequence?.enabled ? React.createElement("div", { className: "sequence-banner" },
                React.createElement("span", null,
                    "Cue ",
                    state.sequence.index + 1,
                    "/",
                    settings.sequenceIds.length,
                    " \u00B7 next in ",
                    Math.ceil(state.sequence.remaining),
                    "s"),
                React.createElement(ui_1.Button, { variant: "ghost", size: "sm", onClick: () => bridge_1.deck.send({ name: 'stopSequence' }) }, "Keep this look")) : null,
            React.createElement("section", { role: "tabpanel", id: 'panel-' + tab, "aria-labelledby": 'tab-' + tab, tabIndex: 0, key: scopeId },
                tab === 'lights' ? React.createElement(LightsPanel_1.LightsPanel, { state: state, layout: layout, ui: ui, onLooks: () => selectTab('library') }) : null,
                tab === 'library' ? React.createElement(LibraryPanel_1.LibraryPanel, { state: state, settings: settings, ui: ui }) : null,
                tab === 'perform' ? React.createElement("div", { className: "work-area" },
                    React.createElement("aside", { className: "preview-column" },
                        React.createElement(ui_1.Fold, { title: "Your room \u00B7 live readback" },
                            React.createElement(MapPreview_1.MapPreview, { state: state, settings: settings, layout: layout, roomMode: false, focusId: focusId, onFocus: setFocus }))),
                    React.createElement("div", { className: "control-column" },
                        React.createElement("div", { className: "studio-heading" },
                            React.createElement("h2", { className: "panel-heading" }, "Make it move."),
                            React.createElement("p", { className: "muted-note mt-2" }, "Compose without starting. Press Play when you\u2019re ready.")),
                        React.createElement(PerformPanel_1.PerformPanel, { state: state, settings: settings, theme: theme, reduced: reduced }))) : null,
                tab === 'settings' ? React.createElement("div", { className: "flex flex-col gap-6" },
                    React.createElement(ui_1.ToggleGroup, { label: "Settings section", value: settingsTab, options: [["room", "Room setup"], ["lab", "App & recovery"]], onChange: setSettingsTab }),
                    settingsTab === 'room' ? React.createElement("div", { className: "work-area" },
                        React.createElement("aside", { className: "preview-column" },
                            React.createElement(MapPreview_1.MapPreview, { state: state, settings: settings, layout: layout, roomMode: true, focusId: focusId, onFocus: setFocus })),
                        React.createElement("div", { className: "control-column" },
                            React.createElement(RoomPanel_1.RoomPanel, { state: state, settings: settings, layout: layout, focusId: focusId, onFocus: setFocus }))) : React.createElement(LabPanel_1.LabPanel, { state: state, settings: settings, ui: ui, theme: theme })) : null),
            React.createElement("p", { className: "mt-6 muted-note", role: "status", "aria-live": "polite" }, state.note)),
        React.createElement("footer", { className: "transport" },
            React.createElement("div", null, tab === 'lights' ? React.createElement("div", { className: "daily-transport" },
                React.createElement("span", { className: "muted-note" }, switching ? 'Changing area…' : stopping ? 'Local control active' : state.native ? 'Bridge playback may continue' : 'Local to your Hue Bridge'),
                React.createElement("div", { className: "flex gap-2" },
                    stopping ? React.createElement(ui_1.Button, { size: "sm", variant: "outline", onClick: () => bridge_1.deck.send({ name: 'pause' }) }, "Pause / cancel") : null,
                    state.native ? React.createElement(ui_1.Button, { size: "sm", variant: "outline", onClick: () => bridge_1.deck.send({ name: 'stopBridge' }) }, "Stop Bridge") : null,
                    React.createElement(ui_1.Button, { size: "sm", variant: "outline", disabled: !state.touched || switching, onClick: () => bridge_1.deck.send({ name: 'restore' }) }, "Restore session"))) : React.createElement(React.Fragment, null,
                React.createElement("div", { className: "transport-grid" },
                    React.createElement(ui_1.Button, { disabled: switching || (!stopping && !layout.selected.length), onClick: () => bridge_1.deck.send({ name: stopping ? 'pause' : 'live' }) }, stopping ? 'Pause / cancel' : 'Play animation'),
                    React.createElement(ui_1.Button, { variant: "outline", disabled: switching || (!state.native && !layout.selected.length), onClick: () => bridge_1.deck.send({ name: state.native ? 'stopBridge' : 'bridge' }) }, state.native ? 'Stop Bridge' : 'Run on Bridge'),
                    React.createElement(ui_1.Button, { variant: "outline", disabled: !state.touched || switching, onClick: () => bridge_1.deck.send({ name: 'restore' }) }, "Restore session")),
                React.createElement("p", { className: "mt-2 text-center text-[10px] leading-relaxed text-muted-foreground" },
                    state.native ? 'Bridge playback can continue independently.' : state.mode === 'live' ? 'Keep Scriptable open and your phone awake.' : 'Previewing and editing do not start playback.',
                    " ",
                    state.inFlight ? 'An already-sent request can still finish.' : '')))),
        newBaseline ? React.createElement(ui_1.Confirm, { title: "Start a new restore baseline?", description: "Archive the earlier point and capture fresh light states on your next action. Live playback will pause. Stop Bridge playback first if it is active.", onClose: () => setNewBaseline(false), onAccept: () => bridge_1.deck.send({ name: 'newSession' }) }) : null);
}

},
"components/LabPanel":function(module,exports,require){
"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.LabPanel = LabPanel;
const React = __importStar(require("react"));
const bridge_1 = require("../lib/bridge");
const ui_1 = require("./ui");
function LabPanel({ state, settings, ui, theme }) {
    const now = (0, bridge_1.useNow)(), [archive, setArchive] = React.useState(''), [confirm, setConfirm] = React.useState(null);
    return React.createElement("div", { className: "flex flex-col gap-5" },
        React.createElement("div", null,
            React.createElement("h2", { className: "panel-heading" }, "Fine control."),
            React.createElement("p", { className: "mt-2 muted-note" }, "Appearance, recovery, and honest diagnostics. Nothing here changes the request-rate safety budget.")),
        React.createElement(ui_1.Select, { label: "Interface theme", value: ui.theme, options: [["system", "Follow my system"], ["light", "Light"], ["dark", "Dark"]], onChange: v => bridge_1.deck.ui({ theme: v }) }),
        React.createElement("p", { className: "muted-note" },
            "Currently ",
            theme,
            ". System mode follows iOS appearance while this screen is open. Theme changes never change your lights."),
        React.createElement(ui_1.Select, { label: "Interface motion", value: ui.motion, options: [["system", "Respect system Reduce Motion"], ["reduce", "Always reduce interface motion"]], onChange: v => bridge_1.deck.ui({ motion: v }) }),
        React.createElement("div", { className: "two-fields" },
            React.createElement(ui_1.Field, null,
                React.createElement("label", { className: "text-sm font-medium", htmlFor: "seed" }, "Deterministic seed"),
                React.createElement(ui_1.Input, { id: "seed", type: "number", min: 0, max: 999999, value: settings.seed, onChange: e => { if (e.currentTarget.value !== '')
                        bridge_1.deck.settings({ seed: Number(e.currentTarget.value) }); } })),
            React.createElement(ui_1.Field, null,
                React.createElement("label", { className: "text-sm font-medium", htmlFor: "crossfade" }, "Edit crossfade (seconds)"),
                React.createElement(ui_1.Input, { id: "crossfade", type: "number", min: 2.5, max: 15, step: .5, value: settings.transitionMs / 1000, onChange: e => { if (e.currentTarget.value !== '')
                        bridge_1.deck.settings({ transitionMs: Number(e.currentTarget.value) * 1000 }); } }))),
        React.createElement(ui_1.Select, { label: "External control policy", value: settings.ownership, options: [["yield_off", "Yield to an external off"], ["hold", "Keep enforcing on"]], onChange: v => bridge_1.deck.settings({ ownership: v }) }),
        React.createElement("p", { className: "muted-note" }, "Yield stops updating a lamp reported off. Color changes from another app cannot always be identified. Entertainment ownership blocks REST writes."),
        React.createElement(ui_1.Button, { variant: "outline", onClick: () => bridge_1.deck.send({ name: 'clearYield' }) }, "Clear yield flags"),
        React.createElement(ui_1.Fold, { title: "Request budget" },
            React.createElement("dl", { className: "grid grid-cols-2 gap-4 text-sm" },
                React.createElement("div", null,
                    React.createElement("dt", { className: "text-muted-foreground" }, "Smoothed request"),
                    React.createElement("dd", { className: "mt-1 font-mono" },
                        state.stats?.latencyMs || 0,
                        " ms")),
                React.createElement("div", null,
                    React.createElement("dt", { className: "text-muted-foreground" }, "Fade horizon"),
                    React.createElement("dd", { className: "mt-1 font-mono" },
                        ((state.stats?.horizonMs || 0) / 1000).toFixed(2),
                        " s")),
                React.createElement("div", null,
                    React.createElement("dt", { className: "text-muted-foreground" }, "Accepted writes"),
                    React.createElement("dd", { className: "mt-1 font-mono" }, state.stats?.writes || 0)),
                React.createElement("div", null,
                    React.createElement("dt", { className: "text-muted-foreground" }, "Failures"),
                    React.createElement("dd", { className: "mt-1 font-mono" }, state.stats?.failures || 0))),
            React.createElement("p", { className: "muted-note" }, "Multi-second REST transitions, not Entertainment streaming. A request already sent may finish after Pause.")),
        React.createElement(ui_1.Fold, { title: "Restore session", open: state.session?.recoveryRequired },
            React.createElement("p", { className: "muted-note" },
                "Captured: ",
                state.session?.createdAt ? new Date(state.session.createdAt).toLocaleString() : 'legacy date unknown',
                ". Restoration returns static states, not the previous animation."),
            state.session?.recoveryRequired ? React.createElement(ui_1.Alert, { title: "Choose how to continue" }, "Keep this saved baseline, or archive it before capturing new values.") : null,
            React.createElement("div", { className: "flex flex-wrap gap-2" },
                React.createElement(ui_1.Button, { variant: "outline", disabled: !state.session?.recoveryRequired, onClick: () => bridge_1.deck.send({ name: 'resumeSession' }) }, "Resume saved point"),
                React.createElement(ui_1.Button, { variant: "outline", disabled: state.busy || state.native, onClick: () => setConfirm({ title: 'Archive and start a new baseline?', description: 'Archive the existing restore point. A fresh baseline is captured on the next explicit Start or Bridge playback. No lights change now.', accept: () => bridge_1.deck.send({ name: 'newSession' }) }) }, "Archive / new baseline")),
            React.createElement(ui_1.Select, { label: "Archived baseline", value: archive, options: [["", "Choose an archive"], ...(state.session?.archives || []).map(a => [a.id, a.createdAt ? new Date(a.createdAt).toLocaleString() : 'Unknown capture date'])], onChange: setArchive }),
            React.createElement(ui_1.Button, { variant: "outline", disabled: !archive || state.busy || state.native, onClick: () => setConfirm({ title: 'Select this archived baseline?', description: 'Keep the current baseline in history, then select this saved one. Review its timestamp before pressing Restore.', accept: () => bridge_1.deck.send({ name: 'restoreArchive', payload: archive }) }) }, "Select archived baseline")),
        React.createElement(ui_1.Fold, { title: "Detailed bulb telemetry" },
            React.createElement("p", { className: "muted-note" }, "Read time is when the Bridge replied. It can return cached or target properties, not every physical transition frame. No optical measurements are implied."),
            bridge_1.META.lights.map(l => { const r = state.telemetry?.data?.[l.id], stale = !r?.fetchedAt || now - r.fetchedAt > 6000; return React.createElement("div", { key: l.id, className: "flex flex-col gap-1 border-b pb-4" },
                React.createElement("p", { className: "text-sm font-semibold" }, l.name),
                React.createElement("p", { className: "muted-note" }, bridge_1.T.stateText(r)),
                React.createElement("p", { className: "muted-note" },
                    stale ? 'STALE / UNAVAILABLE · ' : '',
                    bridge_1.T.ageText(r?.fetchedAt, now),
                    " \u00B7 ",
                    bridge_1.T.connection(state.telemetry?.links?.[r?.owner || ''], now)),
                React.createElement("p", { className: "muted-note" }, bridge_1.T.targetText(state.telemetry?.targets?.[l.id], now)),
                r?.gradient?.length ? React.createElement("div", { className: "gradient-points", "aria-label": "Reported gradient points" }, r.gradient.map((p, i) => React.createElement("span", { key: i, style: { background: bridge_1.T.xyCSS(p) } }))) : null,
                React.createElement("p", { className: "muted-note" },
                    state.ownership?.[l.id] || 'uncontrolled',
                    state.failures?.[l.id] ? ` · ${state.failures[l.id].count} failures: ${state.failures[l.id].error}` : '')); })),
        React.createElement(ui_1.Fold, { title: "Controller events" },
            React.createElement("pre", { className: "trace" }, state.logs?.length ? state.logs.slice(-30).map(l => `${new Date(l.at).toLocaleTimeString()} ${l.kind}: ${l.message}`).join('\n') : 'No controller events yet.'),
            React.createElement(ui_1.Button, { variant: "outline", onClick: () => bridge_1.deck.send({ name: 'exportDiagnostics' }) }, "Export redacted diagnostics"),
            React.createElement("p", { className: "muted-note" }, "The export omits keys, IPs, light names, resource IDs, and raw request bodies. Export/import pauses live updates.")),
        React.createElement("p", { className: "muted-note" }, "React + Tailwind, with shadcn-derived controls and an original MIT-licensed scene surface. All runtime assets are bundled locally. Trusted Wi-Fi only: this Scriptable transport disables local Bridge certificate checking."),
        confirm ? React.createElement(ui_1.Confirm, { ...confirm, onAccept: confirm.accept, onClose: () => setConfirm(null) }) : null);
}

},
"components/LibraryPanel":function(module,exports,require){
"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.LibraryPanel = LibraryPanel;
const React = __importStar(require("react"));
const bridge_1 = require("../lib/bridge");
const ui_1 = require("./ui");
const utils_1 = require("../lib/utils");
const PresetThumb = React.memo(function PresetThumb({ id, brightness }) { const p = bridge_1.PRESETS.find(p => p.id === id); const s = bridge_1.E.clean({ ...bridge_1.E.defaults, ...p.settings, brightness }); return React.createElement("div", { className: "preset-thumb", "aria-hidden": "true" }, Array.from({ length: 8 }, (_, i) => { const f = bridge_1.E.sample(19, i / 8, s); return React.createElement("span", { key: i, style: { background: bridge_1.E.css(f.rgb), height: 10 + f.b * .25, opacity: .85 } }); })); });
function LibraryPanel({ settings, ui, state }) {
    const [query, setQuery] = React.useState(''), [category, setCategory] = React.useState('All'), [favoriteOnly, setFavoriteOnly] = React.useState(false), [append, setAppend] = React.useState(bridge_1.PRESETS[0].id);
    const matches = bridge_1.PRESETS.filter(p => (category === 'All' || p.category === category) && (!favoriteOnly || ui.favorites.includes(p.id)) && `${p.name} ${p.description} ${p.category}`.toLowerCase().includes(query.toLowerCase()));
    const favorite = (id) => bridge_1.deck.ui({ favorites: ui.favorites.includes(id) ? ui.favorites.filter(v => v !== id) : ui.favorites.concat(id) });
    return React.createElement("div", { className: "flex flex-col gap-5" },
        React.createElement("div", null,
            React.createElement("h2", { className: "panel-heading" }, "Find your next look."),
            React.createElement("p", { className: "mt-2 text-sm text-muted-foreground" }, "Preview a look without starting it, or press Play. Your room and brightness limits stay unchanged.")),
        React.createElement(ui_1.Input, { "aria-label": "Search presets", placeholder: "Search by mood, color, or motion", value: query, onChange: e => setQuery(e.currentTarget.value) }),
        React.createElement(ui_1.ToggleGroup, { label: "Preset category", value: category, options: ['All', 'Chill', 'Energy', 'Space', 'Warm', 'Organic'].map(c => [c, c]), onChange: setCategory, wrap: true }),
        React.createElement("div", { className: "flex flex-wrap gap-2" },
            React.createElement(ui_1.Button, { variant: favoriteOnly ? 'secondary' : 'ghost', size: "sm", "aria-pressed": favoriteOnly, onClick: () => setFavoriteOnly(!favoriteOnly) }, "Favorites")),
        React.createElement(ui_1.Fold, { title: "Build a cue sequence" },
            React.createElement("p", { className: "muted-note" }, "Runs in the foreground. Holds use active wall time, not the speed dial. Pattern, palette, or room edits stop the sequence; the current look continues. Master brightness and interface theme can change without stopping it."),
            React.createElement("div", { className: "flex flex-col gap-2" }, settings.sequenceIds.map((id, index) => React.createElement("div", { key: `${id}-${index}`, className: "flex items-center gap-2 rounded-xl bg-muted px-3 py-1" },
                React.createElement("span", { className: "min-w-0 flex-1 text-sm" },
                    index + 1,
                    ". ",
                    bridge_1.PRESETS.find(p => p.id === id)?.name || id),
                React.createElement(ui_1.Button, { size: "icon", variant: "ghost", "aria-label": `Move cue ${index + 1} earlier`, disabled: index === 0, onClick: () => { const ids = settings.sequenceIds.slice(); [ids[index - 1], ids[index]] = [ids[index], ids[index - 1]]; bridge_1.deck.settings({ sequenceIds: ids }); } }, "\u2191"),
                React.createElement(ui_1.Button, { size: "icon", variant: "ghost", "aria-label": `Remove cue ${index + 1}`, onClick: () => bridge_1.deck.settings({ sequenceIds: settings.sequenceIds.filter((_, i) => i !== index) }) }, "\u00D7")))),
            React.createElement(ui_1.Select, { label: "Add a look", value: append, options: bridge_1.PRESETS.map(p => [p.id, p.name]), onChange: setAppend }),
            React.createElement(ui_1.Button, { variant: "outline", disabled: settings.sequenceIds.length >= 12, onClick: () => bridge_1.deck.settings({ sequenceIds: settings.sequenceIds.concat(append) }) },
                "Add cue (",
                settings.sequenceIds.length,
                "/12)"),
            React.createElement(ui_1.Range, { label: "Hold each cue", value: settings.sequenceHold, min: 30, max: 600, step: 5, unit: "s", onChange: v => bridge_1.deck.settings({ sequenceHold: v }) }),
            React.createElement(ui_1.Select, { label: "Sequence order", value: settings.sequenceOrder, options: [["forward", "In order"], ["shuffle", "Seeded shuffle; no immediate repeats"]], onChange: v => bridge_1.deck.settings({ sequenceOrder: v }) }),
            React.createElement(ui_1.Button, { disabled: !settings.sequenceIds.length || !state.layout.selected.length, onClick: () => bridge_1.deck.send({ name: state.sequence?.enabled ? 'stopSequence' : 'startSequence' }) }, state.sequence?.enabled ? 'Stop sequence, keep this look' : 'Start sequence and lights'),
            state.sequence?.enabled ? React.createElement("p", { className: "text-sm text-primary" },
                "Cue ",
                state.sequence.index + 1,
                " \u00B7 next in ",
                Math.ceil(state.sequence.remaining),
                "s") : null),
        React.createElement("p", { className: "text-xs text-muted-foreground" },
            matches.length,
            " looks \u00B7 thumbnails are design illustrations"),
        React.createElement("div", { className: "preset-grid" }, matches.map(p => React.createElement(ui_1.Card, { key: p.id, className: (0, utils_1.cn)('flex min-w-0 flex-col', settings.showA === p.settings.showA && settings.paletteA === p.settings.paletteA && settings.morph === 0 ? 'active-preset' : undefined) },
            React.createElement(ui_1.CardHeader, { className: "p-4 pb-0" },
                React.createElement("div", { className: "flex items-start justify-between gap-1" },
                    React.createElement(ui_1.CardTitle, { className: "text-sm" }, p.name),
                    React.createElement("button", { type: "button", "aria-label": `${ui.favorites.includes(p.id) ? 'Unfavorite' : 'Favorite'} ${p.name}`, "aria-pressed": ui.favorites.includes(p.id), onClick: () => favorite(p.id), className: "-mt-2 -mr-2 flex size-11 shrink-0 items-center justify-center rounded-lg text-primary" },
                        React.createElement("svg", { width: "17", height: "17", viewBox: "0 0 24 24", fill: ui.favorites.includes(p.id) ? 'currentColor' : 'none', stroke: "currentColor", strokeWidth: "1.7" },
                            React.createElement("path", { d: "m12 3 2.8 5.8 6.4.9-4.6 4.5 1.1 6.4-5.7-3-5.7 3 1.1-6.4L2.8 9.7l6.4-.9Z" }))))),
            React.createElement(ui_1.CardContent, { className: "flex flex-1 flex-col gap-3 p-4" },
                React.createElement(PresetThumb, { id: p.id, brightness: settings.brightness }),
                React.createElement(ui_1.CardDescription, { className: "text-xs" }, p.description)),
            React.createElement(ui_1.CardFooter, { className: "flex flex-col gap-2 p-4 pt-0" },
                React.createElement(ui_1.Button, { variant: "outline", size: "sm", onClick: () => bridge_1.deck.send({ name: 'applyPreset', payload: p.id }) },
                    "Preview ",
                    p.name),
                React.createElement(ui_1.Button, { size: "sm", disabled: !state.layout.selected.length, onClick: () => bridge_1.deck.send({ name: 'playPreset', payload: p.id }) },
                    "Play ",
                    p.name))))),
        !matches.length ? React.createElement(ui_1.Empty, null, "No matching looks. Try another search or category.") : null);
}

},
"components/LightsPanel":function(module,exports,require){
"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.LightsPanel = LightsPanel;
const React = __importStar(require("react"));
const bridge_1 = require("../lib/bridge");
const ui_1 = require("./ui");
const utils_1 = require("../lib/utils");
/** This is an edit target, never a fabricated readback. Commit at release, key-up or blur, not every frame. */
function CommitRange({ label, value, min = 1, max = 100, unit = '%', disabled = false, onCommit }) {
    const [draft, setDraft] = React.useState(value), dirty = React.useRef(false), id = React.useId();
    React.useEffect(() => { if (!dirty.current)
        setDraft(Math.min(max, Math.max(min, value))); }, [value, min, max]);
    const commit = () => { if (disabled || !dirty.current)
        return; dirty.current = false; onCommit(draft); };
    return React.createElement(ui_1.Field, null,
        React.createElement("label", { htmlFor: id, className: "flex items-center justify-between gap-3 text-sm font-medium" },
            React.createElement("span", null, label),
            React.createElement("output", { htmlFor: id, className: "tabular-nums text-primary" },
                Math.round(draft),
                unit)),
        React.createElement("input", { id: id, type: "range", value: draft, min: min, max: max, step: unit === ' K' ? 50 : 1, disabled: disabled, onChange: e => { dirty.current = true; setDraft(Number(e.currentTarget.value)); }, onPointerUp: commit, onKeyUp: e => { if (['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Home', 'End', 'PageUp', 'PageDown'].includes(e.key))
                commit(); }, onBlur: commit, className: "h-11 w-full cursor-pointer accent-primary disabled:opacity-45" }));
}
const PowerIcon = () => React.createElement("svg", { "data-icon": "inline-start", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: "1.8", "aria-hidden": "true" },
    React.createElement("path", { d: "M12 3v9M7.2 5.8a8 8 0 1 0 9.6 0", strokeLinecap: "round" }));
function LightCard({ id, state, layout, locked }) {
    const light = bridge_1.META.lights.find(l => l.id === id), c = state.capabilities?.[id] || light.capabilities, p = layout.placements[id], r = state.telemetry?.data?.[id];
    const [expanded, setExpanded] = React.useState(false), [color, setColor] = React.useState('#00bddd');
    const age = r?.fetchedAt == null ? null : bridge_1.T.age(r.fetchedAt, Date.now()), stale = age == null || age > 6;
    const streaming = c.streaming || r?.mode === 'streaming', disabled = locked || streaming;
    const link = r && state.telemetry.links?.[r.owner], linkBad = link && Date.now() - link.fetchedAt < 30000 && ['disconnected', 'connectivity_issue'].includes(link.status);
    const name = light.name, send = (change) => bridge_1.deck.send({ name: 'manual', payload: { ids: [id], ...change } });
    const type = c.color ? 'Color' : c.temperature ? 'Adjustable white' : c.dimming ? 'Dimmable' : 'On / off';
    const power = r?.on === true ? 'On' : r?.on === false ? 'Off' : 'Not read yet';
    return React.createElement("article", { className: (0, utils_1.cn)('light-card', r?.on === true ? 'is-on' : undefined), "aria-label": name },
        React.createElement("div", { className: "light-row" },
            React.createElement("button", { type: "button", className: "light-main", "aria-expanded": expanded, "aria-controls": 'light-details-' + id, onClick: () => setExpanded(!expanded) },
                React.createElement("span", { className: "light-orb", style: { '--lamp': bridge_1.T.color(r) }, "aria-hidden": "true" },
                    React.createElement("svg", { viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: "1.5" },
                        React.createElement("path", { d: "M8 16c0-3-3-3.5-3-7a7 7 0 0 1 14 0c0 3.5-3 4-3 7M8 17h8M9 20h6M10 22h4", strokeLinecap: "round" }))),
                React.createElement("span", { className: "min-w-0" },
                    React.createElement("strong", null, name),
                    React.createElement("span", { className: "light-description" },
                        power,
                        r?.brightness != null ? ` · ${Math.round(r.brightness)}%${r.on === false ? ' stored' : ''}` : '',
                        streaming ? ' · Streaming' : linkBad ? ' · Link issue' : stale ? ' · Not current' : ''))),
            React.createElement(ui_1.Button, { variant: r?.on === true ? 'default' : 'outline', size: "icon", disabled: disabled, "aria-label": `${r?.on === true ? 'Turn off' : 'Turn on'} ${name}`, onClick: () => send({ on: r?.on !== true }) },
                React.createElement(PowerIcon, null))),
        expanded ? React.createElement("div", { className: "light-details", id: 'light-details-' + id },
            React.createElement("div", { className: "flex flex-wrap items-center justify-between gap-2" },
                React.createElement(ui_1.Badge, { variant: "outline" }, type),
                React.createElement("span", { className: "text-xs text-muted-foreground" }, r?.fetchedAt == null ? 'Waiting for readback' : `Bridge read ${Math.floor(age || 0)}s ago`)),
            streaming ? React.createElement(ui_1.Alert, { title: "Controlled by a streaming app" }, "Stop its Entertainment stream before using these controls.") : null,
            c.dimming ? React.createElement(CommitRange, { label: 'Set brightness · ' + name, value: r?.brightness || 50, min: Math.max(1, Math.ceil(c.minBrightness || 1)), disabled: disabled, onCommit: v => send({ on: true, brightness: v }) }) : null,
            c.temperature && c.temperatureRange ? React.createElement(React.Fragment, null,
                React.createElement("div", { className: "flex flex-wrap gap-2" }, [[2700, 'Warm'], [4000, 'Neutral'], [6000, 'Cool']].map(([k, label]) => React.createElement(ui_1.Button, { key: k, variant: "outline", size: "sm", disabled: disabled, onClick: () => send({ on: true, kelvin: k }) }, label))),
                React.createElement(CommitRange, { label: 'White temperature · ' + name, value: r?.kelvin || 4000, min: c.temperatureRange.min, max: c.temperatureRange.max, unit: " K", disabled: disabled, onCommit: v => send({ on: true, kelvin: v }) })) : null,
            c.color ? React.createElement(ui_1.Field, null,
                React.createElement("label", { className: "text-sm font-medium", htmlFor: 'color-' + id }, "Choose a color"),
                React.createElement("div", { className: "color-apply" },
                    React.createElement("input", { type: "color", id: 'color-' + id, "aria-label": 'Color for ' + name, value: color, disabled: disabled, onChange: e => setColor(e.currentTarget.value) }),
                    React.createElement(ui_1.Button, { variant: "outline", disabled: disabled, onClick: () => send({ on: true, hex: color }) }, "Set color"))) : null,
            React.createElement("p", { className: "muted-note" },
                c.dimming ? `Ceiling ${Math.round(p.ceiling)}% · trim ${Math.round(p.trim * 100)}%. ` : '',
                "Changing a value turns this light on and pauses the local show. Reported values above update after a Bridge read.")) : null);
}
function LightsPanel({ state, layout, ui, onLooks }) {
    const [scope, setScope] = React.useState('area'), [search, setSearch] = React.useState(''), [filter, setFilter] = React.useState('all'), [confirmLimits, setConfirmLimits] = React.useState(false), [groupColor, setGroupColor] = React.useState('#00bddd');
    const ids = scope === 'selected' ? layout.selected : layout.order, locked = !!state.navigation?.switching;
    const lights = bridge_1.META.lights, targets = lights.filter(l => ids.includes(l.id)), dimmers = targets.filter(l => l.capabilities.dimming), whites = targets.filter(l => l.capabilities.temperature), colors = targets.filter(l => l.capabilities.color);
    const read = state.telemetry?.data || {}, on = lights.filter(l => read[l.id]?.on === true).length, unknown = lights.filter(l => read[l.id]?.on == null).length;
    const capped = dimmers.filter(l => layout.placements[l.id].ceiling < 100 || layout.placements[l.id].trim < 1);
    const values = dimmers.map(l => read[l.id]?.brightness).filter((v) => typeof v === 'number');
    const average = values.length ? Math.round(values.reduce((a, b) => a + b, 0) / values.length) : 50;
    const send = (change, subset = ids) => bridge_1.deck.send({ name: 'manual', payload: { ids: subset, ...change } });
    const visible = lights.filter(l => l.name.toLowerCase().includes(search.toLowerCase()) && (filter === 'all' || filter === 'on' && read[l.id]?.on === true || filter === 'selected' && layout.selected.includes(l.id)));
    const favorites = bridge_1.PRESETS.filter(p => ui.favorites.includes(p.id)).slice(0, 4);
    const fresh = state.telemetry?.lastRead != null && Date.now() - state.telemetry.lastRead <= 6000;
    return React.createElement("div", { className: "lights-home" },
        React.createElement("section", { className: "everyday", "aria-label": "Everyday lighting" },
            React.createElement("div", { className: "everyday-heading" },
                React.createElement("div", null,
                    React.createElement("h2", { className: "panel-heading" }, "Your lights, your way."),
                    React.createElement("p", { className: "muted-note mt-2" },
                        on,
                        " on \u00B7 ",
                        lights.length,
                        " lights",
                        unknown ? ` · ${unknown} not read yet` : '',
                        !fresh ? ' · Waiting for current state' : '')),
                React.createElement(ui_1.Badge, { variant: "outline" }, state.mode === 'live' ? 'Animating' : 'Everyday')),
            React.createElement(ui_1.ToggleGroup, { label: "Control scope", value: scope, options: [["area", `This area · ${layout.order.length}`], ["selected", `Selected · ${layout.selected.length}`]], onChange: setScope }),
            React.createElement("div", { className: "power-pair" },
                React.createElement(ui_1.Button, { disabled: locked || !ids.length, onClick: () => send({ on: true }) },
                    React.createElement(PowerIcon, null),
                    "Turn on"),
                React.createElement(ui_1.Button, { variant: "outline", disabled: locked || !ids.length, onClick: () => send({ on: false }) },
                    React.createElement(PowerIcon, null),
                    "Turn off")),
            dimmers.length ? React.createElement(CommitRange, { label: `Set brightness · ${dimmers.length} dimmable lights`, value: average, disabled: locked, onCommit: v => send({ on: true, brightness: v }, dimmers.map(l => l.id)) }) : null,
            React.createElement("div", { className: "quick-looks", "aria-label": "Everyday presets" },
                React.createElement(ui_1.Button, { variant: "secondary", disabled: locked || !whites.length, onClick: () => send({ on: true, kelvin: 2700, brightness: 45 }, whites.map(l => l.id)) },
                    React.createElement("span", null,
                        "Warm",
                        React.createElement("small", null, "2700 K \u00B7 45%"))),
                React.createElement(ui_1.Button, { variant: "secondary", disabled: locked || !whites.length, onClick: () => send({ on: true, kelvin: 4000, brightness: 80 }, whites.map(l => l.id)) },
                    React.createElement("span", null,
                        "Focus",
                        React.createElement("small", null, "4000 K \u00B7 80%"))),
                React.createElement(ui_1.Button, { variant: "secondary", disabled: locked || !dimmers.length, onClick: () => send({ on: true, brightness: 100 }, dimmers.map(l => l.id)) },
                    React.createElement("span", null,
                        "Bright",
                        React.createElement("small", null, "100% \u00B7 same color")))),
            React.createElement("details", { className: "control-help" },
                React.createElement("summary", null, "How these controls work"),
                React.createElement("p", { className: "muted-note mt-2" }, "Sliders apply on release and turn addressed lights on. Manual controls pause the local animation. White presets only affect adjustable-white lights. 100% is the device\u2019s normal maximum setting, not a brightness boost beyond its specifications.")),
            capped.length ? React.createElement("div", { className: "limit-callout" },
                React.createElement("p", null,
                    capped.length,
                    " saved limit",
                    capped.length === 1 ? '' : 's',
                    " / trim",
                    capped.length === 1 ? '' : 's',
                    " active"),
                React.createElement(ui_1.Button, { size: "sm", variant: "outline", onClick: () => setConfirmLimits(true) }, "Review 100% ceilings")) : null),
        React.createElement("section", { "aria-label": "Individual lights" },
            React.createElement("div", { className: "section-heading" },
                React.createElement("h2", null, "Individual lights"),
                React.createElement("span", { className: "text-xs text-muted-foreground" }, "Tap a name for color & white")),
            React.createElement("div", { className: "light-filters" },
                React.createElement(ui_1.Input, { "aria-label": "Find a light", placeholder: "Find a light\u2026", value: search, onChange: e => setSearch(e.currentTarget.value) }),
                React.createElement(ui_1.Select, { label: "Show", value: filter, options: [["all", "All"], ["on", "On"], ["selected", "Show selection"]], onChange: setFilter })),
            React.createElement("div", { className: "light-list" }, visible.map(l => React.createElement(LightCard, { key: l.id, id: l.id, state: state, layout: layout, locked: locked }))),
            !visible.length ? React.createElement(ui_1.Empty, null, "No lights match. Clear the search or choose All.") : null),
        React.createElement(ui_1.Fold, { title: "Color for this area" },
            React.createElement("p", { className: "muted-note" },
                "Affects ",
                colors.length,
                " color-capable lights in the current control scope."),
            React.createElement(ui_1.Field, null,
                React.createElement("label", { htmlFor: "areaColor", className: "text-sm font-medium" }, "Choose a color"),
                React.createElement("div", { className: "color-apply" },
                    React.createElement("input", { id: "areaColor", "aria-label": "Area color", type: "color", value: groupColor, onChange: e => setGroupColor(e.currentTarget.value) }),
                    React.createElement(ui_1.Button, { variant: "outline", disabled: locked || !colors.length, onClick: () => send({ on: true, hex: groupColor }, colors.map(l => l.id)) }, "Apply color")))),
        React.createElement(ui_1.Fold, { title: "Your saved Hue scenes" },
            React.createElement("p", { className: "muted-note" }, "Applies the scene\u2019s static light settings within this area, respecting your ceilings and trims. Dynamic effects are not copied. Your saved Hue scene is never edited."),
            React.createElement(ui_1.Button, { variant: "outline", disabled: state.savedScenes?.pending, onClick: () => bridge_1.deck.send({ name: 'refreshScenes' }) }, state.savedScenes?.pending ? 'Reading…' : 'Read saved scenes'),
            state.savedScenes?.error ? React.createElement(ui_1.Alert, { title: "Scene list unavailable", destructive: true }, state.savedScenes.error) : null,
            React.createElement("div", { className: "saved-scenes" }, state.savedScenes?.items?.map(s => React.createElement(ui_1.Button, { key: s.id, variant: "outline", disabled: locked, onClick: () => bridge_1.deck.send({ name: 'applyScene', payload: s.id }) }, s.name))),
            state.savedScenes?.readAt && !state.savedScenes.items.length ? React.createElement(ui_1.Empty, null, "No applicable saved Hue scenes in this area.") : null),
        React.createElement("section", { className: "favorites-shortcut" },
            React.createElement("div", { className: "section-heading" },
                React.createElement("h2", null, "Put on a light show"),
                React.createElement(ui_1.Button, { variant: "ghost", size: "sm", onClick: onLooks }, "Browse looks")),
            React.createElement("p", { className: "muted-note" }, "Play starts the current animation selection. Master brightness and lamp limits stay as you set them."),
            React.createElement("div", { className: "saved-scenes" }, (favorites.length ? favorites : bridge_1.PRESETS.filter(p => ['ion-eclipse', 'deep-orbit'].includes(p.id))).map(p => React.createElement(ui_1.Button, { key: p.id, variant: "outline", disabled: locked || !layout.selected.length, onClick: () => bridge_1.deck.send({ name: 'playPreset', payload: p.id }) },
                "Play ",
                p.name)))),
        state.manualResult && (state.manualResult.skipped.length || state.manualResult.failed.length) ? React.createElement(ui_1.Alert, { title: "Some lights were not changed" }, [...state.manualResult.skipped, ...state.manualResult.failed].map(x => React.createElement("p", { key: x.id },
            lights.find(l => l.id === x.id)?.name || 'Light',
            ": ",
            x.reason))) : null,
        confirmLimits ? React.createElement(ui_1.Confirm, { title: "Allow these lamps up to 100%?", description: `This raises the ceiling of ${dimmers.length} dimmable lights in the chosen scope. It does not change their current brightness. Output trims are preserved. If a live show is running, its subsequent targets can use the new limit.`, onClose: () => setConfirmLimits(false), onAccept: () => { const next = JSON.parse(JSON.stringify(layout)); for (const l of dimmers)
                next.placements[l.id].ceiling = 100; bridge_1.deck.layout(next); } }) : null);
}

},
"components/MapPreview":function(module,exports,require){
"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.MapPreview = MapPreview;
const React = __importStar(require("react"));
const bridge_1 = require("../lib/bridge");
const ui_1 = require("./ui");
function MapPreview({ state, layout, settings, roomMode, focusId, onFocus }) {
    const [source, setSource] = React.useState('reported'), now = (0, bridge_1.useNow)(), svg = React.useRef(null);
    const moving = React.useRef(null);
    const lamp = bridge_1.META.lights.find(l => l.id === focusId), reported = state.telemetry?.data?.[focusId];
    function move(id, x, y) { bridge_1.deck.layout({ ...layout, placements: { ...layout.placements, [id]: { ...layout.placements[id], x: Math.min(.96, Math.max(.04, x)), y: Math.min(.94, Math.max(.06, y)) } } }); }
    function drag(e) { if (!moving.current || !svg.current)
        return; const r = svg.current.getBoundingClientRect(), x = (e.clientX - r.left) / r.width * 360, y = (e.clientY - r.top) / r.height * 230; move(moving.current, (x - 24) / 312, (y - 16) / 198); }
    const fresh = state.telemetry?.lastRead != null && now - state.telemetry.lastRead <= 6000;
    return React.createElement("div", { className: "flex flex-col gap-3" },
        React.createElement("div", { className: "flex items-center justify-between gap-3" },
            React.createElement("h2", { className: "text-sm font-semibold" }, "Your room"),
            React.createElement(ui_1.Badge, { variant: "outline" },
                layout.selected.length,
                " / ",
                bridge_1.META.lights.length,
                " selected")),
        React.createElement(ui_1.ToggleGroup, { label: "Preview data source", value: source, options: [["reported", "Reported"], ["target", "Sent target"], ["design", "Design"]], onChange: setSource }),
        React.createElement("p", { className: "min-h-4 text-xs text-muted-foreground", "data-testid": "telemetry-summary" }, bridge_1.T.summary(state.telemetry, now)),
        React.createElement("svg", { ref: svg, className: roomMode ? "room-map" : "room-map compact-map", viewBox: "0 0 360 230", role: "group", "aria-label": "Bulb placement and state", onPointerMove: drag, onPointerUp: () => moving.current = null, onPointerCancel: () => moving.current = null },
            React.createElement("path", { className: "map-grid", d: "M24 54H336M24 94H336M24 134H336M24 174H336M76 16V214M128 16V214M180 16V214M232 16V214M284 16V214" }),
            React.createElement("rect", { x: "24", y: "16", width: "312", height: "198", rx: "16", fill: "none", stroke: "var(--grid)" }),
            layout.order.map((id, index) => {
                const p = layout.placements[id], light = bridge_1.META.lights.find(l => l.id === id);
                let row = state.telemetry?.data?.[id];
                const target = state.telemetry?.targets?.[id];
                if (source === 'target')
                    row = target && target.kind !== 'native' && target.action ? bridge_1.T.normalize({ id, ...target.action }, target.acceptedAt) : null;
                // A color target without an on/off field leaves power unchanged. Render its requested color, not a fabricated off state.
                const targetRow = row;
                const displayRow = source === 'target' && targetRow && targetRow.on == null ? { ...targetRow, on: true } : row;
                const color = source === 'design' ? bridge_1.E.css((state.design?.[id] || bridge_1.E.sample(state.t, p.q, settings)).rgb) : bridge_1.T.color(displayRow);
                const r = row;
                const stale = source === 'reported' && (!r || r.fetchedAt == null || now - r.fetchedAt > 6000 || r.missing);
                const on = source === 'design' ? layout.selected.includes(id) : source === 'target' ? !!r && r.on !== false : r?.on === true;
                const level = source === 'design' ? (state.design?.[id]?.b || 0) / 100 : Math.max(0, (r?.brightness || 0) / 100);
                const x = 24 + p.x * 312, y = 16 + p.y * 198, selected = id === focusId;
                const h = p.hue, edited = h?.applied && (Math.abs(h.applied.x - p.x) > .0001 || Math.abs(h.applied.y - p.y) > .0001);
                const geometry = h && !edited ? h.positions.map(v => bridge_1.H.project(v, h.projection, h.mirror)) : [];
                return React.createElement("g", { key: id },
                    geometry.length > 1 ? React.createElement("polyline", { points: geometry.map(v => `${24 + v.x * 312},${16 + v.y * 198}`).join(' '), fill: "none", stroke: "var(--muted-foreground)", opacity: ".35", strokeWidth: "2" }) : null,
                    React.createElement("g", { className: "map-bulb", role: "button", tabIndex: 0, "aria-label": `${light?.name}. ${source === 'reported' ? bridge_1.T.stateText(row) : source === 'target' ? bridge_1.T.targetText(target, now) : 'Design simulation'}`, "aria-pressed": selected, onClick: () => onFocus(id), onPointerDown: e => { onFocus(id); if (roomMode) {
                            e.preventDefault();
                            moving.current = id;
                            svg.current?.setPointerCapture(e.pointerId);
                        } }, onKeyDown: e => { if (e.key === 'Enter' || e.key === ' ') {
                            e.preventDefault();
                            onFocus(id);
                        } if (roomMode && ['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(e.key)) {
                            e.preventDefault();
                            move(id, p.x + (e.key === 'ArrowRight' ? .02 : e.key === 'ArrowLeft' ? -.02 : 0), p.y + (e.key === 'ArrowDown' ? .02 : e.key === 'ArrowUp' ? -.02 : 0));
                        } } },
                        React.createElement("circle", { className: "hit", cx: x, cy: y, r: "22", fill: "transparent", stroke: selected ? 'var(--primary)' : 'transparent', strokeWidth: "1.5" }),
                        React.createElement("circle", { cx: x, cy: y, r: on ? 13 + level * 3 : 12, fill: color, opacity: stale ? .35 : on ? .45 + .55 * level : .5, stroke: "var(--lamp-edge)", strokeDasharray: stale ? '3 3' : undefined }),
                        React.createElement("text", { x: x, y: y + 4, textAnchor: "middle", style: { fill: on ? '#fff' : 'var(--muted-foreground)', paintOrder: 'stroke', stroke: on ? '#0007' : 'transparent', strokeWidth: 2 } }, index + 1)));
            })),
        React.createElement("p", { className: "text-center text-[10px] font-medium tracking-wide text-muted-foreground" }, source === 'reported' ? 'BRIDGE STATE · APPROXIMATE SCREEN COLORS' : source === 'target' ? 'LAST ACCEPTED TARGET · NOT OPTICAL OUTPUT' : 'DESIGN SIMULATION · NOT REPORTED STATE'),
        React.createElement(ui_1.Fold, { title: roomMode ? 'Inspect and position a bulb' : 'Bulb inspector', open: roomMode },
            " ",
            React.createElement(ui_1.Select, { label: "Inspect a bulb", value: focusId, options: bridge_1.META.lights.map(l => [l.id, l.name]), onChange: onFocus }),
            lamp ? React.createElement("div", { className: "flex flex-col gap-1 rounded-xl bg-muted p-3" },
                React.createElement("p", { className: "text-sm font-semibold" }, lamp.name),
                React.createElement("p", { className: "text-xs leading-relaxed text-muted-foreground" }, bridge_1.T.stateText(reported)),
                React.createElement("p", { className: "text-xs text-muted-foreground" },
                    bridge_1.T.ageText(reported?.fetchedAt, now),
                    " \u00B7 ",
                    bridge_1.T.connection(state.telemetry?.links?.[reported?.owner || ''], now)),
                React.createElement("p", { className: "text-xs text-muted-foreground" }, state.ownership?.[focusId] || 'uncontrolled')) : null),
        roomMode ? React.createElement(React.Fragment, null,
            " ",
            state.hueLayouts?.areas?.some(a => a.matched) && !layout.hue ? React.createElement("p", { className: "muted-note" }, "Saved Hue positions are available in Room. Importing preserves lamp selection and limits.") : null,
            React.createElement("p", { className: "muted-note" },
                layout.hue ? `Placement: ${layout.hue.areaName}. Relative coordinates, not measured metres.` : 'Local placement. Import saved Hue positions in Room.',
                " ",
                roomMode ? 'Drag a bulb or use arrow keys; map edits do not change path phase.' : '')) : null,
        !fresh && state.telemetry?.lastRead != null ? React.createElement(ui_1.Alert, { title: "Readback is stale" }, "Last-known values are retained. They are not current optical measurements.") : null);
}

},
"components/PerformPanel":function(module,exports,require){
"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.SavedMixes = SavedMixes;
exports.BridgePlayback = BridgePlayback;
exports.PerformPanel = PerformPanel;
const React = __importStar(require("react"));
const bridge_1 = require("../lib/bridge");
const ui_1 = require("./ui");
const SpotlightCard_1 = __importDefault(require("./SpotlightCard"));
function SavedMixes({ state }) { const [name, setName] = React.useState(''), [selected, setSelected] = React.useState(''); return React.createElement(ui_1.Fold, { title: "Your saved mixes" },
    React.createElement(ui_1.Input, { "aria-label": "Mix name", placeholder: "Name this mix", maxLength: 48, value: name, onChange: e => setName(e.currentTarget.value) }),
    React.createElement(ui_1.Button, { variant: "outline", disabled: !name.trim(), onClick: () => bridge_1.deck.send({ name: 'savePreset', payload: name }) }, "Save mix"),
    React.createElement(ui_1.Select, { label: "Load a saved mix", value: selected, options: [["", "Choose a saved mix"], ...state.presets.map(p => [p.name, p.name])], onChange: setSelected }),
    React.createElement(ui_1.Button, { variant: "outline", disabled: !selected, onClick: () => bridge_1.deck.send({ name: 'loadPreset', payload: selected }) }, "Load mix"),
    React.createElement("div", { className: "flex gap-2" },
        React.createElement(ui_1.Button, { variant: "ghost", onClick: () => bridge_1.deck.send({ name: 'exportMix' }) }, "Export JSON"),
        React.createElement(ui_1.Button, { variant: "ghost", onClick: () => bridge_1.deck.send({ name: 'importMix' }) }, "Import JSON"))); }
function BridgePlayback({ state, settings }) { const match = Object.values(state.effectParams || {}).filter(p => p.effect === settings.effect); return React.createElement(ui_1.Fold, { title: "Let the Bridge take over" },
    React.createElement(ui_1.Select, { label: "Playback type", value: settings.nativeKind, options: [["palette", "Dynamic palette"], ["effect", "Advertised fixture effect"]], onChange: v => bridge_1.deck.settings({ nativeKind: v }) }),
    settings.nativeKind === 'effect' ? React.createElement(React.Fragment, null,
        React.createElement(ui_1.Select, { label: "Available effect", value: settings.effect, options: [["", "Select an advertised effect"], ...state.effects.map(e => [e.name, `${e.name} · ${e.supported}/${e.total} eligible`])], onChange: v => bridge_1.deck.settings({ effect: v }) }),
        match.some(v => v.speed) ? React.createElement(ui_1.Range, { label: "Native effect speed", value: settings.effectSpeed, min: 0, max: 1, step: .05, onChange: v => bridge_1.deck.settings({ effectSpeed: v }) }) : null,
        match.some(v => v.color) ? React.createElement(ui_1.Toggle, { label: "Tint with the selected palette", checked: settings.effectTint, onChange: v => bridge_1.deck.settings({ effectTint: v }) }) : null) : React.createElement("p", { className: "muted-note" }, "Runs a palette, not the spatial show. The lowest selected trim caps shared brightness. Task and anchor lamps remain static."),
    React.createElement(ui_1.Button, { variant: "outline", disabled: !state.layout.selected.length || (settings.nativeKind === 'effect' && !settings.effect), onClick: () => bridge_1.deck.send({ name: 'bridge' }) }, "Apply Bridge playback"),
    React.createElement("p", { className: "muted-note" }, "Can continue without this screen on compatible fixtures. Stop Bridge or Restore to end delegated playback.")); }
function PerformPanel({ settings, state, theme, reduced }) {
    const active = bridge_1.E.shows.find(v => v[0] === settings.showA)?.[1] || settings.showA;
    return React.createElement("div", { className: "flex flex-col gap-5" },
        " ",
        React.createElement(ui_1.Range, { id: "brightness", label: "Master brightness", value: settings.brightness, min: 5, max: 100, unit: "%", onChange: v => bridge_1.deck.settings({ brightness: v }) }),
        React.createElement(SpotlightCard_1.default, { theme: theme, disabled: reduced, className: "p-5" },
            React.createElement("div", { className: "flex items-center justify-between gap-3" },
                React.createElement("span", { className: "text-xs font-medium text-muted-foreground" }, "Now composing"),
                React.createElement(ui_1.Badge, { variant: "outline" }, state.mode === 'live' ? 'Live' : state.native ? 'Bridge playback' : 'Stopped')),
            React.createElement("h2", { className: "mt-3 text-3xl font-semibold tracking-tight" }, active),
            React.createElement("p", { className: "mt-2 text-sm text-muted-foreground" },
                bridge_1.E.palettes[settings.paletteA].name,
                settings.morph > 0 ? ` → ${bridge_1.E.shows.find(v => v[0] === settings.showB)?.[1]} · ${settings.morph}%` : ''),
            React.createElement("div", { className: "swatch mt-5", "aria-hidden": "true" }, (settings.paletteA === 18 ? settings.customColors : bridge_1.E.palettes[settings.paletteA].colors).map((c, i) => React.createElement("span", { key: i, style: { background: c } })))),
        React.createElement("div", { className: "grid grid-cols-2 gap-2" }, ['ion-eclipse', 'plasma-turbine', 'afterburner', 'deep-orbit'].map(id => { const p = bridge_1.PRESETS.find(p => p.id === id); return React.createElement(ui_1.Button, { key: id, variant: "outline", onClick: () => bridge_1.deck.send({ name: 'applyPreset', payload: id }) }, p.name); })),
        React.createElement(ui_1.FieldGroup, null,
            React.createElement(ui_1.Range, { label: "Energy", value: settings.energy, min: 0, max: 100, unit: "%", onChange: v => bridge_1.deck.settings({ energy: v }) }),
            React.createElement(ui_1.Range, { label: "Motion speed", value: settings.speed, min: .25, max: 1.6, step: .05, unit: "\u00D7", onChange: v => bridge_1.deck.settings({ speed: v }) }),
            React.createElement(ui_1.Range, { label: "A / B morph", value: settings.morph, min: 0, max: 100, unit: "%", onChange: v => bridge_1.deck.settings({ morph: v }) })),
        React.createElement("div", { className: "flex gap-2" },
            React.createElement(ui_1.Button, { variant: "secondary", disabled: state.mode !== 'live', onClick: () => bridge_1.deck.send({ name: 'surge' }) }, "12-second lift"),
            React.createElement(ui_1.Button, { variant: "ghost", onClick: () => bridge_1.deck.settings({ ...bridge_1.E.defaults, brightness: settings.brightness, sequenceIds: settings.sequenceIds }) }, "Reset mix")),
        React.createElement(ui_1.Fold, { title: "Compose A / B looks" },
            React.createElement("div", { className: "two-fields" },
                React.createElement(ui_1.Select, { label: "Pattern A", value: settings.showA, options: bridge_1.E.shows, onChange: v => bridge_1.deck.settings({ showA: v }) }),
                React.createElement(ui_1.Select, { label: "Pattern B", value: settings.showB, options: bridge_1.E.shows, onChange: v => bridge_1.deck.settings({ showB: v }) }),
                React.createElement(ui_1.Select, { label: "Palette A", value: settings.paletteA, options: bridge_1.E.palettes.map((p, i) => [i, p.name]), onChange: v => bridge_1.deck.settings({ paletteA: Number(v) }) }),
                React.createElement(ui_1.Select, { label: "Palette B", value: settings.paletteB, options: bridge_1.E.palettes.map((p, i) => [i, p.name]), onChange: v => bridge_1.deck.settings({ paletteB: Number(v) }) })),
            React.createElement(ui_1.Toggle, { label: "Reverse direction", checked: settings.reverse, onChange: v => bridge_1.deck.settings({ reverse: v }) }),
            React.createElement(ui_1.Range, { label: "Color tension", value: settings.tension, min: 0, max: 100, unit: "%", onChange: v => bridge_1.deck.settings({ tension: v }) }),
            React.createElement(ui_1.Range, { label: "Color saturation", value: settings.saturation, min: 0, max: 100, unit: "%", onChange: v => bridge_1.deck.settings({ saturation: v }) })),
        React.createElement(ui_1.Fold, { title: "Sculpt the motion" },
            React.createElement(ui_1.FieldGroup, null,
                [['depth', 'Contrast / depth', 0, 100, 1, '%'], ['focus', 'Focus', 0, 100, 1, '%'], ['spread', 'Motif width', .5, 2, .05, '×'], ['ambientFloor', 'Atmosphere floor', 0, 65, 1, '%'], ['accentMix', 'Accent amount', 0, 100, 1, '%'], ['density', 'Pattern copies', 1, 4, 1, ''], ['phaseOffset', 'Spatial phase offset', -1, 1, .01, ''], ['brightnessCurve', 'Intensity curve', .5, 2, .05, '×'], ['directorSeconds', 'Director act length', 30, 180, 5, 's']].map(([key, label, min, max, step, unit]) => React.createElement(ui_1.Range, { key: key, label: label, value: settings[key], min: min, max: max, step: step, unit: unit, onChange: v => bridge_1.deck.settings({ [key]: v }) })),
                React.createElement("p", { className: "muted-note" }, "Pattern copies tile closed rings; open paths retain their continuous coordinate. None of these controls increase the HTTP request rate or exceed master/fixture brightness limits."))),
        React.createElement(ui_1.Fold, { title: "Create your own palette" },
            React.createElement("p", { className: "muted-note" }, "Base, motion, secondary, and accent. Select Custom four-color for A or B to use these colors."),
            React.createElement("div", { className: "grid grid-cols-4 gap-3" }, settings.customColors.map((c, i) => React.createElement("label", { key: i, className: "flex flex-col gap-2 text-xs text-muted-foreground" },
                ['Base', 'Motion', 'Secondary', 'Accent'][i],
                React.createElement("input", { type: "color", "aria-label": `Custom color ${i + 1}`, value: c, onChange: e => { const colors = settings.customColors.slice(); colors[i] = e.currentTarget.value; bridge_1.deck.settings({ customColors: colors }); }, className: "h-12 w-full cursor-pointer rounded-lg border bg-card" })))),
            React.createElement("div", { className: "flex gap-2" },
                React.createElement(ui_1.Button, { variant: "outline", onClick: () => bridge_1.deck.settings({ paletteA: 18 }) }, "Use for A"),
                React.createElement(ui_1.Button, { variant: "outline", onClick: () => bridge_1.deck.settings({ paletteB: 18 }) }, "Use for B"))),
        React.createElement(BridgePlayback, { state: state, settings: settings }),
        React.createElement(SavedMixes, { state: state }));
}

},
"components/RoomPanel":function(module,exports,require){
"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.RoomPanel = RoomPanel;
const React = __importStar(require("react"));
const bridge_1 = require("../lib/bridge");
const ui_1 = require("./ui");
function RoomPanel({ state, layout, settings, focusId, onFocus }) {
    const [areaId, setArea] = React.useState(layout.hue?.areaId || ''), [projection, setProjection] = React.useState(layout.hue?.projection || 'xy'), [phase, setPhase] = React.useState(layout.hue?.phaseMode || 'clockwise'), [mirror, setMirror] = React.useState(layout.hue?.mirror || false), [confirm, setConfirm] = React.useState(null), [roomName, setRoomName] = React.useState(''), [savedRoom, setSavedRoom] = React.useState('');
    const catalog = state.hueLayouts, areas = (catalog?.areas || []).filter(a => a.matched > 0), selectedArea = areas.find(a => a.id === areaId) || (areas.length === 1 ? areas[0] : undefined);
    const light = bridge_1.META.lights.find(l => l.id === focusId), p = layout.placements[focusId];
    function placement(patch) { bridge_1.deck.layout({ ...layout, placements: { ...layout.placements, [focusId]: { ...p, ...patch } } }); }
    function selection(id, checked) { bridge_1.deck.layout({ ...layout, selected: checked ? [...new Set([...layout.selected, id])] : layout.selected.filter(x => x !== id) }); }
    function reorder(delta) { const order = layout.order.slice(), i = order.indexOf(focusId); if (i + delta < 0 || i + delta >= order.length)
        return; [order[i], order[i + delta]] = [order[i + delta], order[i]]; bridge_1.deck.layout({ ...layout, order }); }
    return React.createElement("div", { className: "flex flex-col gap-5" },
        React.createElement("div", null,
            React.createElement("h2", { className: "panel-heading" }, "Room, not a list."),
            React.createElement("p", { className: "mt-2 muted-note" }, "Selection never moves another lamp. Placement, animation phase, and output limits stay independent.")),
        React.createElement(ui_1.Fold, { title: "Reuse your Hue layout", open: !layout.hue },
            catalog?.pending ? React.createElement(ui_1.Alert, { title: "Reading saved Hue positions" }, "Read-only discovery is in progress. Your current layout is unchanged.") : null,
            catalog?.error ? React.createElement(ui_1.Alert, { title: "Hue layout read failed", destructive: true }, catalog.error) : null,
            !catalog?.pending && !catalog?.error && !areas.length ? React.createElement(ui_1.Empty, null, "No matching saved Entertainment positions were returned. Local placement remains available.") : null,
            React.createElement(ui_1.Select, { label: "Saved Entertainment area", value: selectedArea?.id || '', options: [["", "Choose an area"], ...areas.map(a => [a.id, `${a.name} · ${a.matched}/${a.total} matched`])], onChange: setArea }),
            selectedArea ? React.createElement("p", { className: "muted-note" },
                selectedArea.matched,
                "/",
                selectedArea.total,
                " lamps can be mapped. ",
                selectedArea.unmatched?.length ? `${selectedArea.unmatched.length} unmatched lamps retain their local positions. ` : '',
                selectedArea.warnings?.join(' ')) : null,
            React.createElement("div", { className: "two-fields" },
                React.createElement(ui_1.Select, { label: "Map projection", value: projection, options: [["xy", "Top · X / Y"], ["xz", "Front · X / Z"], ["yz", "Side · Y / Z"]], onChange: setProjection }),
                React.createElement(ui_1.Select, { label: "Derive animation path", value: phase, options: [["clockwise", "Clockwise"], ["x", "Left / right · X"], ["y", "Depth · Y"], ["z", "Height · Z"], ["keep", "Keep current phases"]], onChange: setPhase })),
            React.createElement(ui_1.Toggle, { label: "Mirror map horizontally", checked: mirror, onChange: setMirror }),
            React.createElement(ui_1.Button, { disabled: !selectedArea || catalog.pending || !!catalog.error, onClick: () => { if (!selectedArea)
                    return; const id = selectedArea.id; setConfirm({ title: 'Import saved positions?', description: `Map ${selectedArea.matched} matching lamps from ${selectedArea.name}. Live updates pause. Selection, roles, limits, and unmatched lamps are preserved. No Hue layout or light writes are sent by this import.`, accept: () => bridge_1.deck.send({ name: 'importHueLayout', payload: { areaId: id, projection, phaseMode: phase, mirror } }) }); } }, "Import saved positions"),
            React.createElement("div", { className: "flex flex-wrap gap-2" },
                React.createElement(ui_1.Button, { variant: "outline", disabled: catalog.pending, onClick: () => bridge_1.deck.send({ name: 'refreshHueLayout' }) }, "Read Hue again"),
                React.createElement(ui_1.Button, { variant: "ghost", disabled: !catalog.canUndo, onClick: () => setConfirm({ title: 'Undo layout import?', description: 'Restore the previous local layout and path topology. Live updates pause. Existing Bridge playback is not stopped.', accept: () => bridge_1.deck.send({ name: 'undoHueLayout' }) }) }, "Undo import")),
            React.createElement("p", { className: "muted-note" }, "Hue positions are relative, not measured distances. All XYZ and segment metadata remain stored. Rescanning never silently replaces local edits.")),
        React.createElement(ui_1.Select, { label: "Path topology", value: settings.topology, options: [["ring", "Closed ring"], ["path", "Open path"]], onChange: v => bridge_1.deck.settings({ topology: v }) }),
        React.createElement(ui_1.Toggle, { label: "Use supported gradient strips", checked: settings.gradient, onChange: v => bridge_1.deck.settings({ gradient: v }) }),
        React.createElement(ui_1.Fold, { title: `Light selection · ${layout.selected.length} enabled` },
            React.createElement(ui_1.FieldGroup, null, layout.order.map((id, i) => { const l = bridge_1.META.lights.find(x => x.id === id); return React.createElement("div", { key: id, className: "flex items-center justify-between gap-3" },
                React.createElement(ui_1.Toggle, { label: `${i + 1}. ${l.name}`, checked: layout.selected.includes(id), onChange: v => selection(id, v) }),
                React.createElement(ui_1.Button, { variant: "ghost", size: "sm", onClick: () => onFocus(id), "aria-label": `Configure ${l.name}` }, "Edit")); }))),
        p && light ? React.createElement(ui_1.Fold, { title: `Configure ${light.name}`, open: true },
            React.createElement(ui_1.Toggle, { label: "Include in live control", checked: layout.selected.includes(focusId), onChange: v => selection(focusId, v) }),
            React.createElement(ui_1.Select, { label: "Fixture role", value: p.role, options: [["wash", "Architectural wash"], ["accent", "Moving accent"], ["task", "Steady task / face"], ["anchor", "Steady background"]], onChange: v => placement({ role: v }) }),
            React.createElement(ui_1.Range, { label: "Path phase", value: p.q * 100, min: 0, max: 100, step: 1, unit: "%", onChange: v => placement({ q: v / 100 }) }),
            React.createElement("div", { className: "two-fields" },
                React.createElement(ui_1.Range, { label: "Map X", value: p.x * 100, min: 4, max: 96, unit: "%", onChange: v => placement({ x: v / 100 }) }),
                React.createElement(ui_1.Range, { label: "Map Y", value: p.y * 100, min: 6, max: 94, unit: "%", onChange: v => placement({ y: v / 100 }) })),
            React.createElement(ui_1.Range, { label: "Output trim", value: p.trim * 100, min: 10, max: 100, unit: "%", onChange: v => placement({ trim: v / 100 }) }),
            React.createElement(ui_1.Range, { label: "Fixture ceiling", value: p.ceiling, min: 5, max: 100, unit: "%", onChange: v => placement({ ceiling: v }) }),
            light.capabilities.gradient >= 2 ? React.createElement(React.Fragment, null,
                React.createElement(ui_1.Range, { label: "Strip extent", value: p.extent * 100, min: 2, max: 50, unit: "%", onChange: v => placement({ extent: v / 100 }) }),
                React.createElement(ui_1.Range, { label: "Strip map angle", value: p.angle, min: -180, max: 180, unit: "\u00B0", onChange: v => placement({ angle: v }) }),
                React.createElement(ui_1.Toggle, { label: "Reverse gradient points", checked: p.stripReverse, onChange: v => placement({ stripReverse: v }) })) : null,
            React.createElement("div", { className: "flex gap-2" },
                React.createElement(ui_1.Button, { variant: "outline", disabled: layout.order.indexOf(focusId) === 0, onClick: () => reorder(-1) }, "Earlier"),
                React.createElement(ui_1.Button, { variant: "outline", disabled: layout.order.indexOf(focusId) === layout.order.length - 1, onClick: () => reorder(1) }, "Later")),
            React.createElement("p", { className: "muted-note" }, "Reordering this list does not recalculate lamp positions or phase."),
            React.createElement("p", { className: "muted-note break-words" }, bridge_1.H.text(p))) : null,
        React.createElement(ui_1.Fold, { title: "Saved room layouts" },
            React.createElement(ui_1.Input, { "aria-label": "Layout name", placeholder: "Name this room layout", maxLength: 48, value: roomName, onChange: e => setRoomName(e.currentTarget.value) }),
            React.createElement(ui_1.Button, { variant: "outline", disabled: !roomName.trim(), onClick: () => bridge_1.deck.send({ name: 'saveRoom', payload: roomName }) }, "Save layout"),
            React.createElement(ui_1.Select, { label: "Stored room layout", value: savedRoom, options: [["", "Choose a layout"], ...state.rooms.map(r => [r.name, r.name])], onChange: setSavedRoom }),
            React.createElement(ui_1.Button, { variant: "outline", disabled: !savedRoom, onClick: () => setConfirm({ title: 'Load room layout?', description: 'Replace local placement, selection, and fixture settings with this saved layout. Playback is not started.', accept: () => bridge_1.deck.send({ name: 'loadRoom', payload: savedRoom }) }) }, "Load layout"),
            React.createElement(ui_1.Button, { variant: "ghost", onClick: () => setConfirm({ title: 'Redistribute clockwise?', description: 'Explicitly replace all map positions and animation phases with an evenly spaced ring. Imported source coordinates remain available in metadata.', accept: () => { const placements = { ...layout.placements }; layout.order.forEach((id, i) => { const q = i / Math.max(1, layout.order.length); placements[id] = { ...placements[id], q, x: .5 + .4 * Math.sin(q * Math.PI * 2), y: .5 - .4 * Math.cos(q * Math.PI * 2) }; }); bridge_1.deck.layout({ ...layout, placements }); } }) }, "Redistribute clockwise explicitly")),
        confirm ? React.createElement(ui_1.Confirm, { ...confirm, onAccept: confirm.accept, onClose: () => setConfirm(null) }) : null);
}

},
"components/SpotlightCard":function(module,exports,require){
"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = SpotlightCard;
/** MIT-licensed original scene surface for Hue Board.
 * Decorative gradients visualize a design theme, never Bridge telemetry.
 */
const React = __importStar(require("react"));
/** A quiet visual highlight without continuous animation or pointer tracking. */
function SpotlightCard({ children, className = '', style, spotlightColor = 'var(--primary)', intensity = 0.12, spotlightSize = 240, theme = 'dark', disabled = false, 
// Retain the old caller's optional props without forwarding them to the DOM.
softness: _softness, borderGlow: _borderGlow, smoothing: _smoothing, ...rest }) {
    const opacity = disabled ? 0 : Math.min(0.13, Math.max(0, intensity)) * (theme === 'light' ? 0.6 : 1);
    return (React.createElement("div", { "data-hue-board-surface": "scene", className: 'relative isolate overflow-hidden rounded-2xl border bg-card text-card-foreground ' + className, style: style, ...rest },
        !disabled && React.createElement("div", { "aria-hidden": "true", className: "pointer-events-none absolute inset-0 -z-10 rounded-[inherit]", style: {
                background: `radial-gradient(circle ${Math.max(40, spotlightSize)}px at 25% 5%, ${spotlightColor}, transparent 95%)`,
                opacity,
            } }),
        children));
}

},
"components/ui":function(module,exports,require){
"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.Input = void 0;
exports.Button = Button;
exports.Card = Card;
exports.CardHeader = CardHeader;
exports.CardTitle = CardTitle;
exports.CardDescription = CardDescription;
exports.CardContent = CardContent;
exports.CardFooter = CardFooter;
exports.FieldGroup = FieldGroup;
exports.Field = Field;
exports.Badge = Badge;
exports.Separator = Separator;
exports.Alert = Alert;
exports.Skeleton = Skeleton;
exports.Empty = Empty;
exports.Select = Select;
exports.Range = Range;
exports.Toggle = Toggle;
exports.ToggleGroup = ToggleGroup;
exports.Fold = Fold;
exports.Confirm = Confirm;
/** shadcn/ui registry-derived primitives (MIT). Locally owned source for an offline React 18 WebView.
 * Card/Input/Skeleton retain the upstream composition. Button variants are inlined, unused Slot removed.
 * Accessible native range/select/tab controls avoid extra runtime dependencies. See THIRD_PARTY_NOTICES.
 */
const React = __importStar(require("react"));
const utils_1 = require("../lib/utils");
function Button({ variant = 'default', size = 'default', className, ...props }) { const variants = { default: 'bg-primary text-primary-foreground shadow-sm hover:bg-primary/90', outline: 'border border-input bg-background hover:bg-accent hover:text-accent-foreground', secondary: 'bg-secondary text-secondary-foreground hover:bg-secondary/80', ghost: 'hover:bg-accent hover:text-accent-foreground', destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90' }; return React.createElement("button", { type: "button", className: (0, utils_1.cn)('inline-flex min-h-11 items-center justify-center gap-2 rounded-xl text-sm font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-45 [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0', variants[variant], size === 'sm' ? 'px-3 py-2' : size === 'icon' ? 'size-11' : 'px-4 py-2.5', className), ...props }); }
exports.Input = React.forwardRef(({ className, ...props }, ref) => React.createElement("input", { ref: ref, className: (0, utils_1.cn)('flex h-11 w-full min-w-0 rounded-xl border border-input bg-transparent px-3 py-2 text-base shadow-sm placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50', className), ...props }));
exports.Input.displayName = 'Input';
function Card({ className, ...props }) { return React.createElement("div", { className: (0, utils_1.cn)('rounded-2xl border bg-card text-card-foreground shadow-sm', className), ...props }); }
function CardHeader({ className, ...props }) { return React.createElement("div", { className: (0, utils_1.cn)('flex flex-col gap-1.5 p-5', className), ...props }); }
function CardTitle({ className, ...props }) { return React.createElement("h2", { className: (0, utils_1.cn)('text-lg font-semibold leading-tight tracking-tight', className), ...props }); }
function CardDescription({ className, ...props }) { return React.createElement("p", { className: (0, utils_1.cn)('text-sm text-muted-foreground', className), ...props }); }
function CardContent({ className, ...props }) { return React.createElement("div", { className: (0, utils_1.cn)('p-5 pt-0', className), ...props }); }
function CardFooter({ className, ...props }) { return React.createElement("div", { className: (0, utils_1.cn)('flex items-center p-5 pt-0', className), ...props }); }
function FieldGroup({ children }) { return React.createElement("div", { className: "flex flex-col gap-5" }, children); }
function Field({ children }) { return React.createElement("div", { className: "flex min-w-0 flex-col gap-2" }, children); }
function Badge({ children, variant = 'secondary' }) { return React.createElement("span", { className: (0, utils_1.cn)('inline-flex items-center rounded-lg px-2 py-1 text-xs font-medium', variant === 'outline' ? 'border text-muted-foreground' : 'bg-secondary text-secondary-foreground') }, children); }
function Separator() { return React.createElement("div", { role: "separator", className: "my-5 h-px bg-border" }); }
function Alert({ title, children, destructive = false }) { return React.createElement("div", { role: destructive ? 'alert' : 'status', className: (0, utils_1.cn)('rounded-xl border p-4', destructive ? 'border-destructive/40 bg-destructive/10 text-destructive' : 'border-border bg-muted text-foreground') },
    React.createElement("p", { className: "text-sm font-semibold" }, title),
    children ? React.createElement("div", { className: "mt-1 text-sm leading-relaxed" }, children) : null); }
function Skeleton({ className }) { return React.createElement("div", { className: (0, utils_1.cn)('animate-pulse rounded-md bg-primary/10', className) }); }
function Empty({ children }) { return React.createElement("div", { className: "rounded-xl border border-dashed p-6 text-center text-sm text-muted-foreground" }, children); }
function Select({ label, value, options, onChange, disabled = false, id }) { const uid = React.useId(), name = id || uid; return React.createElement(Field, null,
    React.createElement("label", { htmlFor: name, className: "text-sm font-medium" }, label),
    React.createElement("select", { id: name, value: value, disabled: disabled, onChange: e => onChange(e.currentTarget.value), className: "min-h-11 w-full min-w-0 rounded-xl border border-input bg-background px-3 py-2 text-base text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:opacity-50" }, options.map(([v, n]) => React.createElement("option", { key: v, value: v }, n)))); }
function Range({ label, value, min, max, step = 1, onChange, unit = '', id, help }) { const uid = React.useId(), name = id || uid; return React.createElement(Field, null,
    React.createElement("label", { htmlFor: name, className: "flex items-baseline justify-between gap-4 text-sm font-medium" },
        React.createElement("span", null, label),
        React.createElement("output", { htmlFor: name, className: "font-mono text-base font-semibold tabular-nums text-primary" },
            step < 1 ? value.toFixed(2) : Math.round(value),
            unit)),
    React.createElement("input", { id: name, type: "range", min: min, max: max, step: step, value: value, onChange: e => onChange(Number(e.currentTarget.value)), className: "h-8 w-full cursor-pointer accent-primary" }),
    help ? React.createElement("p", { className: "text-xs leading-relaxed text-muted-foreground" }, help) : null); }
function Toggle({ label, checked, onChange, disabled = false }) { return React.createElement("label", { className: "flex min-h-11 cursor-pointer items-center gap-3 text-sm" },
    React.createElement("input", { type: "checkbox", checked: checked, disabled: disabled, onChange: e => onChange(e.currentTarget.checked), className: "size-5 accent-primary" }),
    label); }
function ToggleGroup({ label, value, options, onChange, wrap = false }) { return React.createElement("div", { className: (0, utils_1.cn)('flex rounded-xl border bg-muted p-1', wrap ? 'flex-wrap' : undefined), role: "group", "aria-label": label }, options.map(([id, text]) => React.createElement("button", { key: id, type: "button", "aria-pressed": value === id, onClick: () => onChange(id), className: (0, utils_1.cn)('min-h-10 min-w-0 flex-1 rounded-lg px-2 text-xs font-semibold focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring', value === id ? 'bg-background text-foreground shadow-sm' : 'text-muted-foreground', wrap ? 'basis-1/3' : undefined) }, text))); }
function Fold({ title, children, open = false }) { return React.createElement("details", { open: open || undefined, className: "rounded-2xl border bg-card" },
    React.createElement("summary", { className: "cursor-pointer rounded-2xl p-4 text-sm font-semibold focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring" }, title),
    React.createElement("div", { className: "flex flex-col gap-5 px-4 pb-5" }, children)); }
function Confirm({ title, description, onAccept, onClose }) { const ref = React.useRef(null); React.useEffect(() => { const el = ref.current; if (!el)
    return; el.showModal(); return () => el.close(); }, []); return React.createElement("dialog", { ref: ref, onCancel: e => { e.preventDefault(); onClose(); }, className: "w-[min(90vw,420px)] rounded-2xl border bg-card p-6 text-card-foreground shadow-xl backdrop:bg-black/60", "aria-labelledby": "confirm-title" },
    React.createElement("h2", { id: "confirm-title", className: "text-lg font-semibold" }, title),
    React.createElement("p", { className: "mt-3 text-sm leading-relaxed text-muted-foreground" }, description),
    React.createElement("div", { className: "mt-6 flex gap-3" },
        React.createElement(Button, { autoFocus: true, variant: "outline", onClick: onClose }, "Cancel"),
        React.createElement(Button, { onClick: () => { onClose(); onAccept(); } }, "Continue"))); }

},
"lib/bridge":function(module,exports,require){
"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.deck = exports.META = exports.PRESETS = exports.H = exports.T = exports.E = void 0;
exports.useDeck = useDeck;
exports.useNow = useNow;
exports.useAppearance = useAppearance;
const React = __importStar(require("react"));
exports.E = window.HUE_BOARD_ENGINE();
exports.T = window.HUE_BOARD_TELEMETRY();
exports.H = window.HUE_BOARD_LAYOUT;
exports.PRESETS = window.HUE_BOARD_PRESETS;
exports.META = window.HUE_BOARD_META;
const copy = (v) => JSON.parse(JSON.stringify(v));
let state = window.HUE_BOARD_INITIAL;
let snapshot = { status: state, settings: copy(state.settings), layout: copy(state.layout), ui: state.ui || { theme: 'system', motion: 'system', favorites: [] }, heartbeat: Date.now() };
let dirty = false, pending = null;
const listeners = new Set();
const emit = () => { for (const fn of listeners)
    fn(); };
exports.deck = {
    subscribe(fn) { listeners.add(fn); return () => { listeners.delete(fn); }; }, getSnapshot: () => snapshot,
    settings(p) { snapshot = { ...snapshot, settings: exports.E.clean({ ...snapshot.settings, ...p }) }; dirty = true; emit(); },
    layout(next) { snapshot = { ...snapshot, layout: copy(next) }; dirty = true; emit(); },
    ui(p) { snapshot = { ...snapshot, ui: { ...snapshot.ui, ...p } }; dirty = true; emit(); },
    send(command) { const urgent = ['pause', 'restore', 'stopBridge', 'stopSequence']; if (pending && urgent.includes(pending.name) && !urgent.includes(command.name))
        return; pending = command; emit(); },
    report(next) { if (next.meta && next.meta.scopeId !== exports.META.scopeId) {
        exports.META = next.meta;
        dirty = false;
        pending = null;
    } state = next; snapshot = { ...snapshot, status: next, heartbeat: Date.now(), ...(!dirty ? { settings: copy(next.settings), layout: copy(next.layout), ui: copy(next.ui || snapshot.ui) } : {}) }; emit(); },
    exchange(next) { exports.deck.report(next); const packet = { edit: dirty ? { settings: snapshot.settings, layout: snapshot.layout, ui: snapshot.ui } : null, command: pending, hidden: document.hidden }; dirty = false; pending = null; return JSON.stringify(packet); }
};
window.DECK = { exchange: exports.deck.exchange, report: exports.deck.report };
function useDeck() { return React.useSyncExternalStore(exports.deck.subscribe, exports.deck.getSnapshot, exports.deck.getSnapshot); }
function useNow() { const [now, setNow] = React.useState(Date.now()); React.useEffect(() => { const id = setInterval(() => setNow(Date.now()), 1000); return () => clearInterval(id); }, []); return now; }
function useAppearance(ui, nativeDark) {
    const [media, setMedia] = React.useState(() => matchMedia('(prefers-color-scheme: dark)').matches);
    const [reduce, setReduce] = React.useState(() => matchMedia('(prefers-reduced-motion: reduce)').matches);
    React.useEffect(() => { const m = matchMedia('(prefers-color-scheme: dark)'), r = matchMedia('(prefers-reduced-motion: reduce)'); const a = () => setMedia(m.matches), b = () => setReduce(r.matches); m.addEventListener('change', a); r.addEventListener('change', b); return () => { m.removeEventListener('change', a); r.removeEventListener('change', b); }; }, []);
    const theme = ui.theme === 'system' ? ((nativeDark ?? media) ? 'dark' : 'light') : ui.theme;
    const reduced = reduce || ui.motion === 'reduce';
    React.useLayoutEffect(() => { document.documentElement.dataset.theme = theme; document.documentElement.classList.toggle('dark', theme === 'dark'); document.documentElement.style.colorScheme = theme; document.documentElement.dataset.motion = reduced ? 'reduce' : 'normal'; }, [theme, reduced]);
    return { theme, reduced };
}

},
"lib/utils":function(module,exports,require){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.cn = cn;
/** Source-owned shadcn cn helper. Static variants are mutually exclusive; no twMerge runtime needed. */
function cn(...values) { return values.filter(Boolean).join(' '); }

},
"main":function(module,exports,require){
"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const React = __importStar(require("react"));
const ReactDOM = __importStar(require("react-dom"));
const client_1 = require("react-dom/client");
const App_1 = __importDefault(require("./App"));
class ErrorBoundary extends React.Component {
    constructor() {
        super(...arguments);
        this.state = { message: '' };
    }
    static getDerivedStateFromError(error) { return { message: error.message || String(error) }; }
    componentDidCatch(error) { window.deckBootError(error.message || String(error)); }
    render() { return this.state.message ? React.createElement("div", { role: "alert", className: "boot error" },
        React.createElement("h1", null, "Interface error"),
        React.createElement("p", null, this.state.message),
        React.createElement("p", null, "Close with Done and choose Compatibility controls. Your pairing is unchanged.")) : this.props.children; }
}
const root = document.getElementById('root');
if (!root)
    throw new Error('Interface root missing');
// A synchronous initial commit satisfies Scriptable's existing readiness handshake.
ReactDOM.flushSync(() => (0, client_1.createRoot)(root).render(React.createElement(ErrorBoundary, null,
    React.createElement(App_1.default, null))));

},
"types":function(module,exports,require){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });

}};const cache={};function resolve(id,from){if(id[0]!=='.')return id;const parts=from.split('/');parts.pop();for(const p of id.split('/')){if(p==='..')parts.pop();else if(p!=='.')parts.push(p);}return parts.join('/');}function req(id,from=''){id=resolve(id,from);if(id==='react')return window.React;if(id==='react-dom')return window.ReactDOM;if(id==='react-dom/client')return {createRoot:window.ReactDOM.createRoot};if(!modules[id])throw Error('Missing bundled module '+id);if(cache[id])return cache[id].exports;const m={exports:{}};cache[id]=m;modules[id](m,m.exports,n=>req(n,id));return m.exports;}req('main');})();