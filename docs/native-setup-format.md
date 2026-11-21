# Moving a Hue Board setup

In build 8, open **Settings → Export file → Export setup**. In build 7, choose **Export setup** under **Import and export**. Choose which Studio settings, custom colors, cues, saved mixes and scene favorites to include. Select layouts and physical-light preferences only when you intend to share those details. Choose the current room or any other locally saved rooms offered for the connected Bridge. Save the file through Files. A setup contains local creative data. The microphone, local media URLs, files, Bridge connection, pairing key, warning consent, live session and restore journal stay on the device.

On the receiving iPhone, choose **Import file** in Settings (**Import setup or file** in build 7) and select the JSON file. Review the selected changes, skipped fixtures, mix conflicts and old/new brightness limits. Deselect any conflicting section to continue with the others. Confirm while playback is idle. If the destination has changed, review it again. Browsing or confirming a setup never starts the light writer.

## What moves

| Section | Import behavior |
| --- | --- |
| Studio draft | Loads the source look, composition and duration for this Studio session. In **Studio → Saved mixes**, **Save mix** keeps the composition, palette and cue list. To recover the source look, session duration and cue-enabled state after relaunch, reimport the draft and cues from the setup file. |
| Custom palette | Replaces the four custom colors when selected. A draft-only import preserves the receiving palette. |
| Cues | Replaces the cue list, hold time, order and enabled state. The random seed drives both cue order and the engine. The review discloses a change to that shared value. |
| Saved mixes | Adds new document IDs and skips identical copies. Different content with an existing ID blocks that selection. Two distinct IDs can share a display name. |
| Favorites | Replaces local favorite scene IDs with the reviewed list. |
| Room layouts | Requires explicit selection. The new format binds each selected layout to its original Bridge and room or zone. Matching uses exact fixture IDs. Previously excluded fixtures remain excluded. Single-room setups use schema 1 and multi-room setups use schema 2. Check proposed ceiling changes. Other Bridge setups can still receive portable Studio sections. Room and light identifiers in the file may describe your household. |
| Physical-light safety preferences | Replaces the reviewed brightness cap and local Reduce Light Motion setting. Warning consent remains local, and the system Dim Flashing Lights setting is read from the receiver. |

## Compatibility and interruption

The reader accepts the original seven section exports, canonical Hue Board scene schema 2 and supported Scriptable schema 3 mixes. Individual exports remain available. The portable file is limited to 512 KiB, and a saved library can hold 100 mixes. Split a large selection into smaller files. An unsupported schema or invalid section in a setup file stops the whole import before section selection. A valid setup with a layout from a different Bridge skips that layout and can still import its portable sections. For supported legacy Scriptable mixes, review the listed substitutions and clamped values before confirming.

The setup importer validates the file, checks the selected sections against their current durable values, and records a local transaction before writing persistent changes. Recovery rolls an unfinished transaction back or finishes one already marked committed. Only after durable success does the open Studio draft update. Original section formats stay readable. Build 6 compatibility inputs use synthetic data and are pinned to the old codec. [Frozen fixtures and reproduction instructions](../fixtures/native-transfer/build6/README.md)
