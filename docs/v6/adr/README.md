# Hue Board 6 architecture decisions

Architecture decision records in this directory are normative for Hue Board 6 implementation and release qualification.

| ADR | Status | Decision |
|---|---|---|
| [0001](0001-native-iphone-ga-scope.md) | Accepted | Native 6.0 is the bounded iPhone GA core; Entertainment and Sound are conditional minor releases |
| [0002](0002-version-and-schema-domains.md) | Accepted | Product, build, persistence, scene, protocol, engine ABI, and catalog versions are independent |
| [0003](0003-supported-platform-and-hardware-matrix.md) | Accepted | Support claims are limited to physically qualified OS, device, Bridge, and fixture tiers |
| [0004](0004-scriptable-lts-and-native-parity.md) | Accepted | Scriptable 5.3 is the LTS fallback; parity means shared semantics, not identical platform capability |
| [0005](0005-physical-light-safety.md) | Accepted | Dynamic physical-light output requires warnings, conservative limits, emergency stop, and a tested safety envelope |

## ADR lifecycle

- **Proposed:** under review and not yet binding.
- **Accepted:** binding on implementation and release work.
- **Superseded:** replaced by a later ADR that links back to the original.
- **Rejected:** retained for historical context but not implemented.

Changing an accepted ADR requires a new ADR. Do not silently rewrite prior decisions after implementation depends on them.
