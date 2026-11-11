# Hue Board 6 architecture decisions

These records are the accepted product and engineering boundaries for Hue Board 6. They supersede conflicting assumptions in older planning documents and are release gates for the v6 implementation program.

| ADR | Decision | Status |
|---|---|---|
| [0001](0001-native-ga-scope.md) | Native iPhone GA scope and release train | Accepted |
| [0002](0002-version-and-schema-model.md) | Independent product, build, schema, ABI, protocol, and catalog versions | Accepted |
| [0003](0003-supported-platform-and-hardware-matrix.md) | Initial supported platform, Bridge, and fixture matrix | Accepted |
| [0004](0004-scriptable-lts-and-parity.md) | Scriptable 5.3 LTS and semantic parity policy | Accepted |
| [0005](0005-physical-light-safety.md) | Physical-light health and motion-safety policy | Accepted |

A decision may be revised only by a later ADR that states the compatibility, migration, qualification, and release consequences. Runtime code must not silently widen a support, ownership, privacy, or safety boundary documented here.
