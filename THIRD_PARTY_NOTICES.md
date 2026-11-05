# Third-party sources and notices

## React runtime

React 18.2.0, ReactDOM 18.2.0 and Scheduler 0.23.0 production modules were available in the environment's installed JupyterLab webpack assets. Only those MIT-licensed React/ReactDOM/Scheduler module functions and a small loader were extracted into `vendor/react-runtime.js`. No JupyterLab application code or fonts are included. The installed package license inventory identifies those versions; complete MIT notices are included in `licenses/react.txt`, `react-dom.txt`, and `scheduler.txt`.

ReactDOM's actual exported runtime version is `18.2.0-next-9e3b772b8-20220608`. The delivered runtime was executed in browser tests. No claim is made that this is the latest React release.

## shadcn/ui

Registry source used:
- https://ui.shadcn.com/r/styles/new-york/button.json
- https://ui.shadcn.com/r/styles/new-york/card.json
- https://ui.shadcn.com/r/styles/new-york/input.json
- https://ui.shadcn.com/r/styles/new-york/skeleton.json

MIT, copyright 2023 shadcn. Complete notice: `licenses/shadcn.txt`. Registry-derived source is adapted for this offline interface; Card composition and Input source remain recognizable, Button variants are inlined, unused Slot/cva dependencies removed, and native form controls used for the other primitives. These are source-owned adaptations, not a claim that the shadcn CLI completed installation.


## Tailwind CSS

Actual compiler: 4.1.10. The emitted CSS includes its copyright/license banner. MIT notice in `licenses/tailwindcss.txt`. Build package integrity hashes are in pnpm-lock.yaml, copied from observed installed package metadata.

## Source/API references

- https://reactbits.dev/get-started/installation
- https://reactbits.dev/components/spotlight-card
- https://ui.shadcn.com/docs/dark-mode/vite
- https://tailwindcss.com/docs/dark-mode
- https://docs.scriptable.app/device/
- https://docs.scriptable.app/webview/
- https://docs.scriptable.app/request/

Source URLs may evolve. Pinned compiler versions and the bundled React runtime provide reproducible build provenance; the historical v5 release manifests remain outside this source repository.

## Hue Board scene surface

The decorative scene surface in `frontend/components/SpotlightCard.tsx` is an original MIT-licensed replacement for the older Commons-Clause component. No React Bits source ships in this repository.
