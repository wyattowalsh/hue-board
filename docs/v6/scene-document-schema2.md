# Hue Board scene document schema 2

## Purpose

`hue-board.scene` schema 2 is the cross-runtime document format for portable Hue Board looks. It contains deterministic lighting intent and source provenance, but no physical target or credential.

```json
{
  "format": "hue-board.scene",
  "schema": 2,
  "kind": "look",
  "documentId": "scene-example",
  "name": "Evening test",
  "createdAt": "2026-11-10T21:00:00.000Z",
  "modifiedAt": "2026-11-10T21:00:00.000Z",
  "scope": "user-selected",
  "source": {
    "productVersion": "6.0.0",
    "engineABI": 1,
    "catalogRevision": null,
    "implementation": "native"
  },
  "settings": {
    "showA": "eclipse",
    "showB": "turbine",
    "paletteA": 0,
    "paletteB": 1,
    "morph": 0,
    "brightness": 60,
    "speed": 1,
    "depth": 75,
    "spread": 1.2,
    "energy": 65,
    "tension": 65,
    "focus": 55,
    "reverse": false,
    "gradient": false,
    "seed": 731,
    "topology": "ring",
    "transitionMs": 4500,
    "ownership": "yield_off",
    "nativeKind": "palette",
    "effect": "",
    "effectSpeed": 0.4,
    "effectTint": false,
    "saturation": 100,
    "ambientFloor": 0,
    "accentMix": 100,
    "density": 1,
    "phaseOffset": 0,
    "brightnessCurve": 1,
    "directorSeconds": 52,
    "customColors": ["#102CBA", "#00B9F2", "#36E5D1", "#A4ED51"],
    "sequenceIds": ["ion-eclipse", "plasma-turbine", "deep-orbit"],
    "sequenceHold": 90,
    "sequenceOrder": "forward"
  }
}
```

## Security boundary

The only valid scope is `user-selected`. A document cannot select the Bridge, room, zone, fixture, credential, host, or application key. The importing application chooses a target after validation through a separate explicit Apply or Play action.

Schema 2 uses a closed field set. Unknown root, source, or setting keys are rejected rather than retained as hidden behavior. This prevents target, credential, or future command data from being smuggled into a portable look.

## Compatibility

- Format identifier: `hue-board.scene`
- Schema: `2`
- Supported kind: `look`
- Supported engine ABI: `1`
- Scope policy: `user-selected`

The product version is provenance, not a compatibility decision. Engine ABI, catalog revision, scene schema, persistence schema, and product version are independent domains.

## Legacy Scriptable migration

Hue Board accepts legacy mix objects with:

```json
{
  "app": "hue-board",
  "schema": 3,
  "settings": {}
}
```

The migration also accepts the historical `BOYZ.EXE` app identifier. Legacy partial settings are normalized through current deterministic bounds. Unsupported metadata is ignored with an explicit warning. The same normalized logical settings produce the same deterministic migration identifier.

Legacy import never transfers Keychain values, Bridge addresses, room IDs, fixture IDs, recovery journals, or other home-specific state.

## Validation

Schema 2 validation requires:

- all documented settings fields;
- known pattern and palette identifiers;
- finite numeric values within engine bounds;
- supported enum values;
- four valid hexadecimal custom colors;
- bounded sequence identifiers;
- valid ISO-8601 timestamps with `modifiedAt >= createdAt`;
- a valid source identifier and engine ABI;
- a 64-character hexadecimal catalog revision when supplied.

Invalid documents do not modify persisted state or issue physical lighting commands.

## Runtime behavior

Scriptable exports schema 2 while retaining legacy schema-3 import support. Native iOS decodes and validates the same schema in `HueBoardKit`. Settings that are not yet used by the native execution surface remain preserved in the document model for cross-runtime round-trip compatibility.
