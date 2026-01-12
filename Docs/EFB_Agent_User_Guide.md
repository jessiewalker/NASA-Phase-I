# EFB Agent User Guide

*(Electronic Flight Bag Agent – Local Monitoring, Evidence Logging, and Secure Reporting)*

## What this app is

EFB Agent is a lightweight on-device monitoring and evidence-logging tool designed to observe health and security-relevant signals on an iPad-class EFB environment and produce defensible, time-stamped events for audit, diagnostics, and reporting.

It is built around three ideas:

1. **Collect** a small set of device + network signals
2. **Evaluate** rules that turn signals into events
3. **Store and report** events securely (including offline-first operation)

This aligns with FAA 2024 "aircraft systems information security" objectives—especially around **monitoring, detection, logging, and evidence preservation** for cybersecurity risk management.

---

## Quick start (novice)

1. Open **EFB Agent**
2. Confirm **Agent Status = Running**
3. Watch:

   * **Connectivity** shows Online/Offline
   * **Events Summary** counts update as events occur
4. Tap **Run Diagnostics (Safe)** to validate the pipeline end-to-end
5. Tap **Browse Local Events / DB Browser** to inspect what's stored on the device

If you are in a simulator build, some telemetry may be **simulated** (e.g., MetricKit events) and clearly labeled.

---

## Quick start (experienced)

* Confirm collectors are active:

  * NetworkCollector path updates + URLSession metrics
  * MetricKitCollector payload subscription (device) or simulation (sim)
  * SystemCollector snapshot calls are being triggered by the controller
* Validate persistence:

  * New events appear in the event browser
  * DB file exists as **`events.db`** in app Documents 
* Validate security:

  * Stored payload is encrypted at rest (AES-GCM) 
  * Key is stored in Keychain 

---

## UI tour and meaning of every field

### 1) Agent Status

This section answers: **Is the agent running, and is it producing evidence on a schedule?**

**Status**

* **Running**: the agent is active and collectors/rules are operating.
* **Stopped**: the agent is paused; collection/evaluation is halted.

**Uptime**

* How long the agent has been continuously running.

**Last Snapshot**

* The timestamp of the most recent telemetry snapshot captured.

**Last Rule Evaluation**

* The timestamp of the most recent rule evaluation pass.

**Next Snapshot**

* Countdown or readiness indicator for the next scheduled snapshot.

**Pending Events**

* How many events exist locally that have not been uploaded yet.
* Internally, EventStore tracks this with `uploaded = 0`. 

**Pending Bytes**

* Estimated bytes awaiting upload (helpful for constrained links).
* Current implementation may use an estimate (~2KB/event). 

**Store Size**

* File size of the local database on disk.

**Upload timestamps**

* **Last Upload Attempt**: last time an upload was tried
* **Last Successful Upload**: last time an upload succeeded
* **Next Upload Attempt**: next scheduled upload time

**Ruleset Version / Config Version / Config Signature**

* Version identifiers for the policy/rules configuration.
* **Config Signature** indicates whether the config is signed/present (tamper-evidence posture).

---

### 2) Real-Time Metrics (last 60 seconds)

This section answers: **What is the device doing right now, and what's the trend?**

**CPU Sparkline (60s)**

* A small chart of CPU estimates for the last 60 seconds.
* Use this for "spikes" and trend direction, not precision forensic attribution.
* **Labeled as "est" (estimated)**: SystemCollector uses placeholder CPU values since iOS doesn't provide direct CPU usage. Consider implementing real process CPU monitoring with thread CPU time deltas for production.

**Memory Sparkline (60s)**

* A small chart of memory footprint for the last 60 seconds.
* **Labeled as "est" (estimated)**: SystemCollector currently reports total physical memory, not actual used RAM. For real memory monitoring, consider using task_info/resident_size (requires entitlements).

---

### 3) Connectivity

This section answers: **Can the agent communicate, and what kind of network conditions are present?**

**Status**

* **Online**: `NWPath.status == satisfied`
* **Offline**: no satisfied path

**Interface**

* WiFi / Cellular / Unknown
  NetworkCollector infers interface via `path.usesInterfaceType`. 

**Expensive**

* "Yes" means metered/costly network conditions (e.g., cellular).
* Derived from `path.isExpensive`. 

**Constrained**

* "Yes" indicates Low Data Mode or constrained networking.
* Derived from `path.isConstrained`. 

**Last Change**

* Timestamp of the last connectivity state transition.

**Reporting Allowed (Policy)**

* Policy control: whether the agent is permitted to upload/report at this moment.
* (This is where safety modes and operational constraints are enforced.)

---

### 4) Upload Status

This section answers: **Where would data go, and did uploads succeed?**

**Endpoint**

* Destination configuration (e.g., Mock/Testing or a real backend).

**Auth Status**

* Whether authentication is required for upload.

**Cert Pinning**

* Indicates whether certificate pinning is enabled (defends against MITM in many threat models).

**Last Attempt / Last Success**

* Timestamps for upload telemetry.

**Force Upload Now**

* Manual upload trigger—useful for test and verification.

**Clear Uploaded / Clear Pending**

* Maintenance actions:

  * Clear Uploaded removes already-uploaded events (storage hygiene).
  * Clear Pending removes all locally pending events (test-only / extreme operations).

---

### 5) Quiet Mode

Quiet Mode answers: **Should we keep collecting but reduce "noise" (uploads/alerts)?**

When enabled:

* Rules still evaluate and events still log,
* But **uploads and alerts are rate-limited** (behavior depends on policy).

Use Quiet Mode in constrained operational contexts where you still need evidence continuity but want reduced network activity.

---

### 6) Events Summary

This section answers: **How many events exist, by severity and state?**

Typical counters:

* **Total**
* **Critical / Errors / Warnings / Info**
* **Acknowledged** (operator reviewed)
* **Suppressed** (policy suppressed/noised down)

---

### 7) Recent Events

This section answers: **What just happened?**

Events include:

* **Name** (human readable)
* **Severity** (Info/Warning/Error/Critical)
* **Category** (System/Performance/Network/Connectivity)
* **Source** (which collector/rule produced it)
* **Time** ("Just now", etc.)

Example: Connectivity Lost/Restored is generated by NetworkCollector when path state changes. 

---

### 8) Diagnostics Report

Diagnostics answers: **Does the full pipeline work end-to-end (collect → rule → event → store → upload)?**

**Summary**

* Elapsed Time
* Events Generated
* Rules Passed (e.g., 3/5)

**Collector Checks**

* MetricKit payloads received / simulated
* Network updates observed
* URLSession metrics observed

**Storage Tests**

* Store write/read
* Encryption validation
* Pending before/after counts

**Upload Tests**

* Upload success + status code
* Retry counts
* If error occurs, the diagnostic should capture the failing component clearly.

---

## The data model (what's actually stored)

### Local database

Events are stored in **SQLite** (via GRDB) in:

* **Documents/events.db** 

### Table: `events`

Columns (simplified):

* `id` (UUID string)
* `device_id`
* `created_at` (timestamp)
* `category`
* `severity`
* `name`
* `attributes` (BLOB) **encrypted**
* `source`
* `sequence_number`
* `uploaded` (0/1)

Schema is created if missing on startup. 

### Encryption at rest (important)

When an event is appended:

* The full event JSON is **redacted** (sensitive keys removed via Redactor allowlist/forbidden patterns)
* The redacted event JSON is encoded and then **encrypted**
* The encrypted bytes are stored in the `attributes` BLOB field. 

Encryption mechanism:

* AES-GCM with a symmetric key stored in Keychain.  

---

## Using the DB Browser (what you asked for)

The DB Browser is for answering: **"Show me exactly what the agent is collecting right now, and what's in SQLite."**

### What you can do

* **Live View:** watch events as they are appended (toggle "Live Updates")
* **Browse:** page through stored events (pagination: 50 events per page)
* **Search:** by event name (text search)
* **Filter:** by category, severity, source, time range
* **Inspect:** tap an event to see:

  * metadata (ID, timestamps, uploaded flag)
  * decrypted JSON (internal view - full event)
  * redacted JSON (safe share view - sensitive keys removed)
* **Export DB:** share `events.db` to Files/AirDrop for offline analysis
* **Copy DB path** (dev/testing)

### Why decrypted vs redacted views exist

* **Decrypted JSON** helps engineering/debugging - shows the full event as stored.
* **Redacted JSON** supports operational sharing while minimizing sensitive leakage - shows only allowed keys per Redactor policy.

---

## FAA 2024 mapping (how the UI supports the intent of the rule)

FAA 2024 aircraft information security rulemaking emphasizes designing systems to be resilient to security threats and to support evidence-driven cybersecurity risk management across aircraft systems and networks.

Here's how the EFB Agent UI aligns at a "capability" level:

* **Monitoring & Detection:** Real-time metrics + rule evaluation transform telemetry into security-relevant events.
* **Logging & Evidence:** Events are time-stamped, categorized, and preserved locally (including offline operation).
* **Secure Data Handling:** Events are **redacted** before storage, then **encrypted at rest**; uploading can enforce certificate pinning and policy-based reporting.
* **Operational Control:** Quiet Mode and Reporting Allowed (Policy) support controlled behavior in constrained or sensitive contexts.
* **Traceability:** Event IDs + sequence numbers + upload status support audit trails and investigation workflows.

The detailed crosswalk lives in `docs/COMPLIANCE_CROSSWALK_FAA_2024.md` (created from the @workspace tasks).

---

## Troubleshooting (common)

**I see "Mock (Testing)" endpoint**

* You're running a test configuration; uploads will not go to a real backend.

**Events appear but uploads don't**

* Check Connectivity + Reporting Allowed (Policy)
* Use "Force Upload Now"
* Review Upload Status error details

**I'm on simulator and want real device metrics**

* Some collectors are simulated in the simulator (MetricKit simulation is expected). 

**I want to validate what's stored**

* Open DB Browser → filter → tap an event → view decrypted JSON
* Export `events.db` for external inspection

**CPU/Memory metrics show "est" (estimated)**

* Current implementation uses placeholder values. For production, implement real process memory (task_info/resident_size) and CPU approximation (thread CPU time delta).

---

## Glossary

* **Collector:** a component that gathers telemetry (system/network/MetricKit).
* **Rule:** a condition that turns telemetry into an event (e.g., connectivity flapping).
* **Event:** a structured, time-stamped record with category/severity/source.
* **Pending:** stored locally but not uploaded yet (`uploaded = 0`). 
* **Encryption at rest:** data stored on disk is encrypted (AES-GCM).
* **Redaction:** removal of sensitive keys from event attributes before storage (via Redactor allowlist/forbidden patterns).

