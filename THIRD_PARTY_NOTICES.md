# Third-party sources and notices

## React runtime

React 18.2.0, ReactDOM 18.2.0 and Scheduler 0.23.0 production modules were available in the environment's installed JupyterLab webpack assets. Only those React/ReactDOM/Scheduler module functions and a small loader were extracted into `vendor/react-runtime.js`. No JupyterLab application code or fonts are included. The installed package license inventory identifies those versions; complete MIT notices are included in `licenses/react.txt`, `react-dom.txt`, and `scheduler.txt`.

ReactDOM's actual exported runtime version is `18.2.0-next-9e3b772b8-20220608`. The delivered runtime was executed in browser tests. No claim is made that this is the latest React release.

## shadcn/ui

Registry source used:
- https://ui.shadcn.com/r/styles/new-york/button.json
- https://ui.shadcn.com/r/styles/new-york/card.json
- https://ui.shadcn.com/r/styles/new-york/input.json
- https://ui.shadcn.com/r/styles/new-york/skeleton.json

MIT, copyright 2023 shadcn. Complete notice: `licenses/shadcn.txt`. Registry-derived source is adapted for this offline interface; Card composition and Input source remain recognizable, Button variants are inlined, unused Slot/cva dependencies removed, and native form controls used for the other primitives. These are source-owned adaptations, not a claim that the shadcn CLI completed installation.

## Hue Board interactive highlight

The decorative scene surface in `frontend/components/SpotlightCard.tsx` is original
Hue Board application code under the repository's MIT license. The earlier
React Bits component is not included in this build.

## Tailwind CSS

Actual compiler: 4.1.10. The emitted CSS includes its copyright/license banner. MIT notice in `licenses/tailwindcss.txt`. Build package integrity hashes are in pnpm-lock.yaml, copied from observed installed package metadata.

## Takumi README renderer

The optional README-art workflow pins `takumi-js` 2.19.0 in `scripts/readme-art/package.json`. Takumi is dual-licensed under MIT or Apache-2.0; Hue Board uses it under the MIT option. The complete MIT notice is included in `licenses/takumi-js.txt`. Takumi is a development-only renderer and is not bundled into either the Scriptable controller or the native iOS application.

## Source/API references

- https://reactbits.dev/get-started/installation
- https://reactbits.dev/components/spotlight-card
- https://ui.shadcn.com/docs/dark-mode/vite
- https://tailwindcss.com/docs/dark-mode
- https://docs.scriptable.app/device/
- https://docs.scriptable.app/webview/
- https://docs.scriptable.app/request/
- https://github.com/kane50613/takumi

Source URLs may evolve. Pinned compiler versions and the bundled runtime are documented in the build metadata.
