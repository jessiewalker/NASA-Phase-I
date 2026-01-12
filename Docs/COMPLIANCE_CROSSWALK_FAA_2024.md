# FAA 2024 Compliance Crosswalk: EFB Agent

This document maps EFB Agent UI components and subsystems to FAA 2024 Aircraft Systems Information Security Protection (ASISP) requirements.

## Reference Sources

- FAA NPRM: *Aircraft Systems Information Security Protection* (Federal Register)
- FAA PDF: *Airplane Systems Information Security Protection (ASISP)*
- FAA Rulemaking Reference (Reginfo)

---

## Crosswalk Table

| FAA Requirement Theme | Rulemaking Reference | EFB Agent UI Element(s) | Data Sources | Evidence Produced | Gaps / Next Changes |
|----------------------|---------------------|------------------------|--------------|-------------------|---------------------|
| **Monitoring & Detection** | ASISP §X.X - Continuous monitoring of system health and security indicators | Agent Status Card, Real-Time Metrics (CPU/Memory sparklines), Live Data screen | SystemCollector, NetworkCollector, MetricKitCollector, RuleEngine | Telemetry snapshots, detection events with timestamps, rule evaluation results | SystemCollector uses placeholder CPU; implement real process memory/CPU or clearly label as estimated |
| **Logging & Evidence Preservation** | ASISP §X.X - Maintain auditable logs of security-relevant events | Events Summary, Recent Events, DB Browser, Event Detail View | EventLogger, EventStore | Time-stamped events with category/severity/source, sequence numbers, event IDs | Current implementation preserves full event history; consider retention policy configuration |
| **Offline-First Operation** | ASISP §X.X - Operational resilience during network disruption | Connectivity Status Card, Upload Status Card, Pending Events count | EventStore, Uploader, NetworkCollector | Pending event counts, connectivity state transitions, upload retry history | Implemented; verify backpressure handling for extended offline periods |
| **Encryption at Rest** | ASISP §X.X - Protect stored data from unauthorized access | EventStore encryption implementation (UI shows config signature status) | EventEncryption, EventStore (attributes BLOB), Keychain | Encrypted event payloads, key management status | Document key rotation policy; verify Keychain access controls |
| **Secure Data Transmission** | ASISP §X.X - Secure communication with reporting endpoints | Upload Status Card (endpoint, cert pinning, auth status) | SecureTransport, Uploader | Upload success/failure status, retry counts, error messages | Certificate pinning implemented; document pinning certificate management |
| **Configuration Control & Integrity** | ASISP §X.X - Configuration management with tamper-evidence | Agent Status Card (Config Signature, Config Version), Config View with source badges | ConfigManager, SignedConfigVerifier | Config signature status, source tracking (Default/MDM/Remote Signed), last update timestamp | Implemented; consider config change audit logging |
| **Operational Control & Mitigation** | ASISP §X.X - Policy-based control over system behavior | Quiet Mode Toggle Card, Reporting Allowed (Policy), Upload controls | AgentController, ConfigManager | Quiet mode state, reporting policy status, manual upload triggers | Implemented |
| **Data Minimization & Redaction** | ASISP §X.X - Minimize sensitive data exposure | Redactor component (allowlist/forbidden patterns), Event Detail View (redacted JSON) | Redactor, EventLogger | Redacted event payloads for sharing, full payload for debugging | **GAP**: EventLogger currently stores original event; wire Redactor into storage pipeline |
| **Traceability & Audit Trail** | ASISP §X.X - Maintain event provenance and auditability | Event Detail View (event ID, device ID, sequence number, timestamps, source), DB Browser | EventStore, AgentEvent model | Event IDs (UUID), sequence numbers, device IDs, timestamps, upload status flags | Implemented; consider adding operator acknowledgment tracking |
| **Real-Time Situational Awareness** | ASISP §X.X - Visibility into current system state | Real-Time Metrics sparklines, Live Data screen, Connectivity Status | SystemCollector (CPU/memory), NetworkCollector (path state), RuleEngine (recent events) | Live CPU/memory trends (60s), connectivity state, recent event stream | **GAP**: SystemCollector CPU/memory are placeholders; implement real metrics or label clearly |
| **Diagnostics & Verification** | ASISP §X.X - Ability to verify system functionality | Diagnostics Report Card, Run Diagnostics buttons | DiagnosticsRunner, all collectors, EventStore, Uploader | End-to-end test results, collector availability, storage/encryption/upload verification | Implemented; consider adding periodic automated diagnostics |
| **Data Export & Forensics** | ASISP §X.X - Ability to extract evidence for analysis | DB Browser, Export DB button, Copy DB Path | EventStore, FileManager | SQLite database export, decrypted event JSON views | **GAP**: Export DB button not yet implemented; add UIActivityViewController integration |
| **Network Security Posture** | ASISP §X.X - Monitor network security indicators | Connectivity Status Card (interface type, expensive, constrained), NetworkDestinationAllowlistRule | NetworkCollector, RuleEngine | Connectivity state, interface type, TLS failure counts, destination allowlist violations | TLS failure detection implemented; consider adding more network security indicators |
| **Rate Limiting & Cooldown** | ASISP §X.X - Prevent alert storms and resource exhaustion | RuleEngine (rate limiting, cooldowns), Quiet Mode | RuleEngine, RuleContext | Rate limit status, cooldown state in diagnostics | Implemented |

---

## Key Implementation Gaps to Address

### Critical (Must-Have)

1. **Real CPU/Memory Metrics**
   - **Current**: SystemCollector uses placeholder CPU (0.3) and `memoryUsed` equals total physical memory
   - **Required**: Implement real process memory footprint (task_info/resident_size) and CPU approximation (thread CPU time delta) OR clearly label as "Estimated" in UI
   - **Impact**: FAA compliance requires accurate monitoring evidence

2. **Redaction Pipeline**
   - **Current**: Redactor exists but EventLogger stores original event without redaction
   - **Required**: Wire Redactor into EventLogger so stored events are redacted before encryption
   - **Impact**: Data minimization compliance requirement

3. **DB Export Functionality**
   - **Current**: DB Browser placeholder mentions export but no implementation
   - **Required**: Add "Export events.db" button with UIActivityViewController (Files/AirDrop)
   - **Impact**: Forensics and evidence extraction capability

### Important (Should-Have)

4. **Real DB Browsing**
   - **Current**: Placeholder view with TODO comments
   - **Required**: Implement EventStore query APIs (fetchPage, fetchById, fetchDateRange, fetchCountsBySeverityAndCategory) and full browsing UI
   - **Impact**: Operational visibility and troubleshooting

5. **Live Data Screen**
   - **Current**: Not implemented
   - **Required**: Real-time event stream with auto-refresh, live metrics dashboard, side-by-side decrypted/redacted views
   - **Impact**: Real-time situational awareness

6. **Event Retention Policy**
   - **Current**: Prune function exists but not configurable via UI/config
   - **Required**: Configurable retention policy (days) with UI indication
   - **Impact**: Long-term storage management

### Nice-to-Have

7. **Operator Acknowledgment Tracking**
   - Add acknowledgment state to events (acknowledged/suppressed)
   - **Impact**: Enhanced audit trail

8. **Automated Periodic Diagnostics**
   - Schedule diagnostics runs automatically
   - **Impact**: Proactive health monitoring

---

## Evidence Generation Summary

### For Each Event Stored:

- **Event ID** (UUID) - unique identifier
- **Device ID** - device identifier
- **Timestamp** (created_at) - when event occurred
- **Category** - system/performance/network/security/connectivity
- **Severity** - critical/error/warning/info
- **Source** - which collector/rule generated it
- **Sequence Number** - ordering within device lifetime
- **Full Event JSON** (encrypted in attributes BLOB)
- **Upload Status** (uploaded flag) - whether event was successfully uploaded

### For System State:

- **Connectivity State** - online/offline, interface type, constraints
- **CPU/Memory Trends** - last 60 seconds of metrics
- **Pending Event Counts** - how many events await upload
- **Config Signature Status** - whether configuration is signed/valid
- **Upload History** - last attempt, last success, retry counts

---

## Compliance Verification Checklist

- [x] Events are time-stamped and uniquely identifiable
- [x] Events are encrypted at rest (AES-GCM)
- [x] Encryption keys are stored securely (Keychain)
- [x] Events can be stored offline and uploaded later
- [x] Configuration changes are tracked (source, signature)
- [x] Network security indicators are monitored (TLS failures, connectivity state)
- [x] Rate limiting prevents alert storms
- [x] Diagnostic capability exists to verify end-to-end functionality
- [ ] **GAP**: Real CPU/memory metrics or clear "Estimated" labeling
- [ ] **GAP**: Events are redacted before storage (Redactor wired in)
- [ ] **GAP**: DB export functionality for forensics
- [ ] **GAP**: Full DB browsing with query APIs

