# Hue Board V6 Defect Register

| ID | Severity | Finding | Required correction | Tasks |
|---|---:|---|---|---|
| `D-001` | P0 | Hosted CI blocked before job execution | Resolve account/billing lock; observe runner-backed green jobs; protect main. | BASE-001/002 |
| `D-002` | P0 | Exact Xcode app build and physical install unobserved | Run deterministic device workflow and fix Apple SDK/signing defects. | BASE-004/005, CI-001 |
| `D-003` | P0 | Scriptable source is 5.3 while public installer remains 5.2 | Complete immutable 5.3 artifact, manifest, installer, and rollback. | BASE-003 |
| `D-004` | P0 | Persistence has no atomic envelope, registry, backup, or quarantine | Implement schema 2 and migration safety. | MIG-001..005 |
| `D-005` | P0 | Physical write ownership is distributed across orchestration | Introduce PlaybackCoordinator, writer epochs, and transport contracts. | ARC-001..007 |
| `D-006` | P0 | Preview safety is convention rather than capability isolation | Use NullPreviewTransport and no-write tests. | ARC-004, APP-001, TST-003 |
| `D-007` | P0 | App scheme has no application/UI test targets | Add test targets, FakeHueBridge, xcodebuild test, and xcresults. | CI-002, TST-001..006 |
| `D-008` | P0 | Recovery durability is coupled to ordinary preference persistence | Persist recovery independently and test crashes/partial failures. | MIG-005, TST-004 |
| `D-009` | P0 | Physical-light health policy is absent | Add warning, emergency stop, Reduce Light Motion, and safety envelope. | ADR-006, SEC-004/005 |
| `D-010` | P0 | Privacy manifest and full App Store privacy evidence are absent | Add manifest, privacy report, data inventory, policy, and disclosures. | SEC-002/006, REL-002 |
| `D-011` | P1 | Product/app/schema/engine versions are conflated | Adopt independent version domains and compatibility rules. | ADR-002, ARC-009 |
| `D-012` | P1 | REST Live is coupled directly to HueBridgeClient | Extract RestAmbientTransport and rename the UI mode. | ARC-003/006, APP-005 |
| `D-013` | P1 | Settings consumes a permanent primary tab | Move settings behind a consistent destination; add conditional status surface. | APP-002..004 |
| `D-014` | P1 | iPad and landscape are enabled but not qualified | Qualify or disable/not advertise. | ADR-003, APP-010, TST-007/008 |
| `D-015` | P1 | No strict semantic TypeScript gate | Add strict tsconfig, typecheck, lint, and format checks. | CI-003/004 |
| `D-016` | P1 | No durable redacted diagnostics packet | Add unified logging, bounded ring buffer, export, and redaction tests. | MIG-008, SEC-003 |
| `D-017` | P1 | EDK licensing and redistribution are unresolved | Complete legal/technical ADR before implementation. | ADR-005, ENT-001 |
| `D-018` | P1 | Historical v6 plan has stale baseline and wrong dependencies | Supersede with this execution program and conditional release tracks. | BASE-007, ADR-001 |
