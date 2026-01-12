# EFB Agent

**Electronic Flight Bag Cybersecurity Telemetry Agent for iPadOS**

A production-oriented cybersecurity telemetry agent designed for Electronic Flight Bag (EFB) systems, aligned with FAA 2024 aviation cybersecurity guidance. Provides continuous monitoring, anomaly detection, encrypted offline-first storage, and secure batch reporting.

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Quick Start](#-quick-start)
- [Detailed Setup Guide](#-detailed-setup-guide)
- [Usage Guide](#-usage-guide)
- [Configuration](#-configuration)
- [Architecture](#-architecture)
- [Security](#-security)
- [FAA Compliance](#-faa-compliance)
- [Development](#-development)
- [Testing](#-testing)
- [Troubleshooting](#-troubleshooting)
- [Documentation](#-documentation)
- [Project Structure](#-project-structure)
- [License](#-license)

---

## 🎯 Overview

EFB Agent is a lightweight on-device monitoring and evidence-logging tool designed to observe health and security-relevant signals on an iPad-class EFB environment. It produces defensible, time-stamped events for audit, diagnostics, and reporting.

The application is built around three core principles:

1. **Collect** - Gather device and network telemetry signals continuously
2. **Evaluate** - Apply rule-based detection to transform signals into security-relevant events
3. **Store and Report** - Securely store events (offline-first) and batch upload to reporting endpoints

This aligns with FAA 2024 "aircraft systems information security" objectives—especially around **monitoring, detection, logging, and evidence preservation** for cybersecurity risk management.

### Key Use Cases

- **Continuous Monitoring**: Real-time observation of EFB system health and security indicators
- **Anomaly Detection**: Automated identification of suspicious patterns and security events
- **Evidence Logging**: Tamper-evident, encrypted storage of security-relevant events
- **Compliance Reporting**: Secure batch uploads for regulatory compliance and audit trails
- **Diagnostics**: End-to-end verification of monitoring pipeline functionality

---

## ✨ Features

### Core Capabilities

#### Continuous Monitoring
- **System Metrics**: CPU load, memory usage, thermal state, battery status
- **Network Monitoring**: Connectivity state, interface type (WiFi/Cellular), network constraints
- **Performance Tracking**: Real-time sparkline visualizations (60-second windows)
- **MetricKit Integration**: Device-level performance and crash metrics (iOS 13+)

#### Anomaly Detection
Local rule engine with 5 built-in detection rules:

1. **High CPU Usage Detection**
   - Monitors CPU load percentage
   - Configurable threshold (default: 80%)
   - Rate-limited alerts to prevent noise

2. **Memory Pressure Detection**
   - Tracks memory usage against available memory
   - Configurable threshold (default: 1GB)
   - Alerts on sustained high memory usage

3. **Connectivity Flapping Detection**
   - Detects rapid connectivity state changes
   - Configurable threshold (default: 5 changes per window)
   - Identifies unstable network conditions

4. **Repeated TLS Failure Detection**
   - Monitors TLS/SSL connection failures
   - Configurable threshold (default: 3 failures per 60 seconds)
   - Security-relevant event detection

5. **Network Destination Allowlist Violation**
   - Enforces network destination allowlist policy
   - Alerts on connections to non-allowed hosts
   - Supports security policy enforcement

#### Offline-First Storage
- **SQLite Database**: Local event storage using GRDB.swift
- **AES-GCM Encryption**: All event data encrypted at rest
- **Keychain Integration**: Secure key storage using iOS Keychain
- **Automatic Schema Management**: Database schema created/updated automatically
- **Retention Policies**: Configurable event retention periods

#### Secure Reporting
- **Batch Uploads**: Efficient batch processing of pending events
- **Exponential Backoff**: Automatic retry with exponential backoff
- **Certificate Pinning**: Optional TLS certificate pinning for MITM protection
- **HMAC Signing**: Optional request authentication via HMAC signatures
- **Upload Status Tracking**: Detailed upload attempt and success tracking

#### Comprehensive Dashboard
- **Real-Time Status**: Agent running state, uptime, last snapshot time
- **Event Management**: Event browser with search, filtering, and pagination
- **Connectivity Status**: Network state, interface type, constraints
- **Upload Status**: Endpoint configuration, upload history, manual controls
- **Diagnostics**: End-to-end pipeline verification
- **Configuration View**: Current config source and values

### Security Features

- **Encryption at Rest**: AES-GCM encryption for all stored event data
- **Keychain Storage**: Secure storage of encryption keys in iOS Keychain
- **Certificate Pinning**: Optional TLS certificate pinning for upload endpoints
- **HMAC Signing**: Optional request authentication via HMAC signatures
- **Data Redaction**: Sensitive data removal from events before storage
- **Tamper-Evident Configuration**: Signed remote configuration with HMAC verification
- **Offline-First Operation**: All data stored locally before upload attempts

### FAA Compliance

- Designed to support continued-airworthiness procedures
- Aligned with FAA 2024 Aircraft Systems Information Security Protection (ASISP) requirements
- Supports monitoring, detection, logging, and evidence preservation for cybersecurity risk management
- See [FAA Compliance Crosswalk](Docs/COMPLIANCE_CROSSWALK_FAA_2024.md) for detailed mapping

---

## 📋 Requirements

### System Requirements

- **Operating System**: iOS 16.0 or later (iPadOS)
- **Device**: iPad (optimized for iPadOS)
- **Architecture**: ARM64 (Apple Silicon or A-series processors)

### Development Requirements

- **Xcode**: 15.0 or later
- **Swift**: 5.9 or later
- **macOS**: 13.0 (Ventura) or later (for development)
- **XcodeGen**: Latest version (for project generation)
  - Install via Homebrew: `brew install xcodegen`

### Dependencies

- **GRDB.swift**: 6.0.0+ (SQLite database library)
- **Swift Concurrency**: Modern async/await and actors
- **Combine**: Reactive programming framework
- **SwiftUI**: Declarative UI framework

---

## 🚀 Installation

### Prerequisites

1. **Install Xcode**
   - Download from the Mac App Store or [Apple Developer](https://developer.apple.com/xcode/)
   - Ensure Xcode Command Line Tools are installed:
     ```bash
     xcode-select --install
     ```

2. **Install XcodeGen**
   ```bash
   brew install xcodegen
   ```
   
   Verify installation:
   ```bash
   xcodegen --version
   ```

3. **Install Git** (if not already installed)
   ```bash
   git --version
   ```

### Clone the Repository

```bash
# Clone the repository
git clone <repository-url>
cd EFB-Agent1-Backup-12:16:2025

# Verify project structure
ls -la
```

### Generate Xcode Project

The project uses XcodeGen to generate the Xcode project from `project.yml`. Run the setup script:

```bash
# Make setup script executable (if needed)
chmod +x setup_project.sh

# Run setup script
./setup_project.sh
```

This script will:
1. Check for XcodeGen installation
2. Generate `EFB-Agent.xcodeproj` from `project.yml`
3. Open the project in Xcode

**Alternative Manual Generation:**
```bash
# Generate project manually
xcodegen generate

# Open in Xcode
open EFB-Agent.xcodeproj
```

---

## ⚡ Quick Start

### 1. Open Project in Xcode

```bash
open EFB-Agent.xcodeproj
```

### 2. Configure Signing

1. Select the **EFBAgent** target in Xcode
2. Navigate to **Signing & Capabilities** tab
3. Select your **Development Team** from the dropdown
4. Ensure **Automatically manage signing** is checked
5. Xcode will automatically configure provisioning profiles

### 3. Select Run Destination

1. In Xcode toolbar, click the device selector
2. Choose **iPad** as the run destination:
   - **iPad Pro (12.9-inch)** (recommended for testing)
   - Or any physical iPad connected via USB
   - Or iPad Simulator

### 4. Build and Run

- **Keyboard Shortcut**: Press `⌘R` (Command + R)
- **Menu**: Product → Run
- **Toolbar**: Click the Play button

### 5. First Launch

On first launch, the app will:
1. Initialize the event store (SQLite database)
2. Generate encryption keys and store in Keychain
3. Load default configuration from `default-config.json`
4. Display the dashboard with agent stopped

### 6. Start the Agent

1. Tap the **"Start"** button in the Agent Status card
2. Observe the status change to **"Running"**
3. Watch real-time metrics update
4. Events will begin appearing in the Recent Events section

### 7. Run Diagnostics

1. Tap **"Run Diagnostics (Safe)"** button
2. Wait for diagnostics to complete (typically 5-10 seconds)
3. Review the diagnostics report:
   - Collector checks (MetricKit, Network, System)
   - Storage tests (write/read, encryption)
   - Upload tests (connectivity, endpoint)

---

## 📖 Detailed Setup Guide

### Project Structure Overview

```
EFB-Agent1-Backup-12:16:2025/
├── EFBAgent/                    # Main application source
│   ├── Agent/                   # Agent orchestration
│   ├── Collection/              # Telemetry collectors
│   ├── Configuration/           # Configuration management
│   ├── Detection/               # Rule engine and rules
│   ├── Diagnostics/             # Diagnostic runner
│   ├── Models/                  # Data models
│   ├── Persistence/             # Storage and encryption
│   ├── Telemetry/               # OpenTelemetry exporter
│   ├── UI/                      # SwiftUI views
│   ├── Upload/                  # Upload system
│   ├── Resources/               # Configuration files
│   └── Assets.xcassets/         # App icons and assets
├── EFBAgentTests/               # Unit tests
├── Docs/                        # Documentation
├── project.yml                  # XcodeGen configuration
├── Package.swift                # Swift Package Manager
└── setup_project.sh             # Setup script
```

### Configuration Files

#### Default Configuration

The default configuration is located at:
```
EFBAgent/Resources/default-config.json
```

This file contains:
- Sampling rates
- Upload intervals
- Rule thresholds
- Network allowlists
- Feature flags

#### Project Configuration

The `project.yml` file defines:
- Build settings
- Target configurations
- Dependencies
- Info.plist values

**Important Settings:**
- Bundle Identifier: `com.efbagent.EFBAgent`
- Deployment Target: iOS 16.0
- Device Family: iPad only (`TARGETED_DEVICE_FAMILY: "2"`)

### Build Configuration

#### Debug Build
- Default configuration for development
- Includes debug symbols
- Simulator-friendly (some metrics simulated)

#### Release Build
- Optimized for production
- Stripped debug symbols
- Full metric collection enabled

To switch build configurations:
1. Product → Scheme → Edit Scheme
2. Select Run or Archive
3. Choose Build Configuration: Debug or Release

### Code Signing Setup

#### Automatic Signing (Recommended)

1. Open project in Xcode
2. Select **EFBAgent** target
3. Go to **Signing & Capabilities**
4. Check **Automatically manage signing**
5. Select your **Team** from dropdown
6. Xcode handles provisioning automatically

#### Manual Signing

1. Uncheck **Automatically manage signing**
2. Select **Provisioning Profile** manually
3. Choose **Signing Certificate**
4. Ensure profile matches bundle identifier

### Simulator vs Device

#### Simulator Limitations

- **MetricKit**: Simulated (clearly labeled in UI)
- **Network**: Full functionality
- **System Metrics**: Some limitations (CPU/memory estimates)
- **Keychain**: Simulated Keychain

#### Physical Device

- **Full Functionality**: All collectors operational
- **Real Metrics**: Actual device metrics
- **Keychain**: Real iOS Keychain
- **Network**: Real network conditions

**Recommendation**: Test on physical iPad for production validation.

---

## 📱 Usage Guide

### Dashboard Overview

The main dashboard provides a comprehensive view of agent status and system health:

#### 1. Agent Status Card

**Purpose**: Monitor agent operational state

**Key Information**:
- **Status**: Running / Stopped
- **Uptime**: How long agent has been running
- **Last Snapshot**: Timestamp of last telemetry collection
- **Last Rule Evaluation**: When rules were last evaluated
- **Next Snapshot**: Countdown to next collection
- **Pending Events**: Number of events awaiting upload
- **Pending Bytes**: Estimated bytes pending upload
- **Store Size**: Size of local SQLite database
- **Upload Timestamps**: Last attempt, last success, next attempt
- **Configuration Status**: Config version, signature status

**Actions**:
- **Start**: Begin agent operation
- **Stop**: Pause agent operation

#### 2. Real-Time Metrics Panel

**Purpose**: Visualize current system performance

**Metrics Displayed**:
- **CPU Sparkline**: 60-second CPU usage trend (normalized 0.0-1.0)
- **Memory Sparkline**: 60-second memory usage trend (MB)
- **Live Metrics**: Real-time CPU and memory values

**Note**: CPU and memory metrics are currently estimated. See [Architecture](#architecture) for details.

#### 3. Connectivity Status Card

**Purpose**: Monitor network connectivity state

**Information Displayed**:
- **Status**: Online / Offline
- **Interface**: WiFi / Cellular / Unknown
- **Expensive**: Yes / No (metered connections)
- **Constrained**: Yes / No (Low Data Mode)
- **Last Change**: Timestamp of last connectivity change
- **Reporting Allowed**: Policy-based upload permission

**Use Cases**:
- Verify network connectivity
- Understand network constraints
- Monitor connectivity flapping

#### 4. Upload Status Card

**Purpose**: Monitor and control data uploads

**Information Displayed**:
- **Endpoint**: Upload destination URL
- **Auth Status**: Authentication configuration
- **Cert Pinning**: Certificate pinning status
- **Last Attempt**: Timestamp of last upload attempt
- **Last Success**: Timestamp of last successful upload
- **Next Attempt**: Scheduled next upload time

**Actions**:
- **Force Upload Now**: Manually trigger upload
- **Clear Uploaded**: Remove already-uploaded events
- **Clear Pending**: Remove all pending events (use with caution)

#### 5. Quiet Mode Toggle

**Purpose**: Reduce upload/alert noise in constrained environments

**When Enabled**:
- Rules still evaluate
- Events still log
- Uploads rate-limited
- Alerts suppressed

**Use Cases**:
- Operational constraints
- Network limitations
- Maintenance windows

#### 6. Events Summary Card

**Purpose**: Overview of event statistics

**Counts Displayed**:
- **Total**: All events in database
- **By Severity**: Critical, Error, Warning, Info
- **Acknowledged**: Operator-reviewed events
- **Suppressed**: Policy-suppressed events

#### 7. Recent Events Section

**Purpose**: View most recent events

**Information Per Event**:
- **Name**: Human-readable event name
- **Severity**: Critical / Error / Warning / Info
- **Category**: System / Performance / Network / Connectivity
- **Source**: Collector or rule that generated event
- **Time**: Relative timestamp ("Just now", "2 minutes ago")

**Actions**:
- Tap event to view details
- Scroll to see more events

#### 8. Diagnostics Report Card

**Purpose**: End-to-end system verification

**Test Categories**:
- **Collector Checks**: MetricKit, Network, System collectors
- **Storage Tests**: Write/read, encryption validation
- **Upload Tests**: Connectivity, endpoint reachability

**Actions**:
- **Run Diagnostics (Safe)**: Non-destructive diagnostics
- View detailed test results

### Event Browser

Access via **"Browse Local Events"** or **"DB Browser"** button.

#### Features

1. **Live Updates**
   - Toggle "Live Updates" to see events as they're added
   - Real-time event stream

2. **Pagination**
   - 50 events per page
   - Navigate forward/backward
   - Jump to first/last page

3. **Search**
   - Search by event name
   - Real-time filtering

4. **Filtering**
   - Filter by category
   - Filter by severity
   - Filter by source
   - Filter by time range

5. **Event Details**
   - Tap any event to view details
   - **Metadata View**: ID, timestamps, uploaded flag
   - **Decrypted JSON**: Full event (for debugging)
   - **Redacted JSON**: Safe share view (sensitive keys removed)

6. **Database Export**
   - Export `events.db` file
   - Share via Files app or AirDrop
   - For offline analysis

### Configuration View

Access via **"View Configuration"** or similar button.

#### Configuration Sources

1. **DEFAULT** (Badge: Default)
   - Bundled `default-config.json`
   - Fallback when no other source available

2. **MDM** (Badge: MDM)
   - Apple Managed App Configuration
   - Set via MDM profiles
   - Overrides default values

3. **REMOTE SIGNED** (Badge: Remote Signed)
   - Signed remote configuration
   - HMAC verification required
   - Highest precedence

#### Viewing Configuration

- See current value for each setting
- See source badge for each setting
- See config signature status
- See last update timestamp

---

## ⚙️ Configuration

### Configuration Hierarchy

Configuration is loaded in the following precedence order (highest to lowest):

1. **REMOTE SIGNED**: Signed remote configuration (if enabled)
2. **MDM**: Apple Managed App Configuration
3. **DEFAULT**: Bundled `default-config.json`

### Default Configuration

Located at `EFBAgent/Resources/default-config.json`:

```json
{
  "samplingRate": 30.0,                    // Telemetry collection interval (seconds)
  "uploadInterval": 300.0,                 // Upload batch interval (seconds)
  "allowedHosts": ["example.com"],         // Network destination allowlist
  "quietMode": false,                      // Reduce upload/alert noise
  "debugMode": false,                      // Enable debug logging
  "testMode": false,                       // Enable test mode features
  "enableRemoteConfig": false,             // Enable remote config fetching
  "remoteConfigURL": null,                 // Remote config endpoint URL
  "maxPendingEvents": 10000,               // Maximum pending events before backpressure
  "retentionDays": 7,                      // Event retention period (days)
  "ruleThresholds": {
    "cpuThreshold": 0.8,                   // CPU usage threshold (0.0-1.0)
    "memoryThreshold": 1000000000,        // Memory threshold (bytes)
    "connectivityFlapThreshold": 5,       // Connectivity changes per window
    "tlsFailureThreshold": 3,             // TLS failures per window
    "tlsFailureWindow": 60.0              // TLS failure window (seconds)
  },
  "uploadEndpoint": null,                  // Upload endpoint URL
  "uploadSigningSecret": null             // HMAC signing secret (base64)
}
```

### MDM Configuration

Configure via Apple Managed App Configuration (MDM profiles).

**Supported Keys**:
- `samplingRate` (Double)
- `uploadInterval` (TimeInterval)
- `allowedHosts` (Array of Strings)
- `quietMode` (Boolean)
- `debugMode` (Boolean)
- `testMode` (Boolean)
- `cpuThreshold` (Double)
- `memoryThreshold` (Double)
- `connectivityFlapThreshold` (Integer)
- `tlsFailureThreshold` (Integer)
- `tlsFailureWindow` (Double)
- `uploadEndpoint` (String)
- `uploadSigningSecret` (String, base64)

**Example MDM Profile**:
```xml
<dict>
  <key>com.apple.configuration.managed</key>
  <dict>
    <key>samplingRate</key>
    <real>60.0</real>
    <key>uploadInterval</key>
    <real>600.0</real>
    <key>allowedHosts</key>
    <array>
      <string>api.example.com</string>
      <string>telemetry.example.com</string>
    </array>
  </dict>
</dict>
```

### Remote Signed Configuration

For remote configuration:

1. **Enable Remote Config**:
   ```json
   {
     "enableRemoteConfig": true,
     "remoteConfigURL": "https://config.example.com/efb-agent-config.json"
   }
   ```

2. **Configuration Format**:
   - Same structure as default config
   - Must include HMAC signature
   - Signature verified before application

3. **Security**:
   - HMAC verification required
   - Signature status displayed in UI
   - Invalid signatures rejected

### Configuration Best Practices

1. **Sampling Rate**
   - **Low (30-60s)**: More frequent collection, higher battery usage
   - **Medium (60-120s)**: Balanced approach
   - **High (120s+)**: Lower battery usage, less frequent updates

2. **Upload Interval**
   - **Frequent (300s)**: More timely reporting, higher network usage
   - **Moderate (600-900s)**: Balanced approach
   - **Infrequent (1800s+)**: Lower network usage, delayed reporting

3. **Rule Thresholds**
   - Adjust based on device capabilities
   - Consider operational environment
   - Test thresholds in staging

4. **Network Allowlist**
   - Include all legitimate endpoints
   - Exclude unauthorized destinations
   - Review regularly

---

## 🏗️ Architecture

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        SwiftUI Dashboard                      │
│                    (Reactive UI Layer)                       │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    AgentController                           │
│              (Main Orchestration Layer)                       │
└──────┬──────────────┬──────────────┬──────────────┬─────────┘
       │              │              │              │
       ▼              ▼              ▼              ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│ Collectors  │ │ Rule Engine │ │ Event Store │ │   Uploader  │
│             │ │             │ │             │ │             │
│ • System    │ │ • Rules     │ │ • SQLite    │ │ • Batch     │
│ • Network   │ │ • Rate Limit│ │ • Encryption│ │ • Retry     │
│ • MetricKit │ │ • Cooldowns │ │ • Redaction │ │ • Security  │
└─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘
```

### Component Details

#### Collectors

**SystemCollector**
- Collects CPU load, memory usage, thermal state, battery state
- Runs on configurable interval (samplingRate)
- Note: CPU/memory currently estimated (see limitations)

**NetworkCollector**
- Monitors network connectivity via NWPathMonitor
- Tracks interface type, constraints, expensive connections
- Publishes connectivity changes as events

**MetricKitCollector**
- Subscribes to MetricKit payloads (iOS 13+)
- Device-level performance and crash metrics
- Simulated in simulator, real on device

#### Rule Engine

**RuleEngine** (Actor-based)
- Evaluates telemetry snapshots against rules
- Rate limiting to prevent alert storms
- Cooldown periods for repeated alerts
- Configurable thresholds per rule

**Built-in Rules**:
1. `HighCpuUsageRule`: CPU threshold detection
2. `MemoryPressureRule`: Memory threshold detection
3. `ConnectivityFlapRule`: Connectivity instability detection
4. `RepeatedTLSFailureRule`: TLS failure pattern detection
5. `NetworkDestinationAllowlistRule`: Unauthorized destination detection

#### Event Store

**EventStore** (Actor-based)
- SQLite database via GRDB.swift
- Location: `Documents/events.db`
- Schema auto-created on first run

**Schema**:
```sql
CREATE TABLE events (
    id TEXT PRIMARY KEY,              -- UUID
    device_id TEXT NOT NULL,          -- Device identifier
    created_at REAL NOT NULL,         -- Unix timestamp
    category TEXT NOT NULL,           -- EventCategory
    severity TEXT NOT NULL,          -- EventSeverity
    name TEXT NOT NULL,               -- Event name
    attributes BLOB NOT NULL,        -- Encrypted JSON (AES-GCM)
    source TEXT NOT NULL,             -- EventSource
    sequence_number INTEGER NOT NULL, -- Monotonic sequence
    uploaded INTEGER NOT NULL DEFAULT 0 -- Upload status
);
```

**Encryption**:
- AES-GCM encryption for `attributes` BLOB
- Key stored in iOS Keychain
- Managed by `EventEncryption` actor

#### Uploader

**Uploader** (Actor-based)
- Batch processing of pending events
- Exponential backoff retry logic
- Configurable upload interval
- Upload status tracking

**Upload Flow**:
1. Query pending events (`uploaded = 0`)
2. Batch events into upload payload
3. Optional HMAC signing
4. HTTPS POST to endpoint
5. Optional certificate pinning
6. Mark events as uploaded on success
7. Retry on failure with backoff

### Data Flow

```
1. Collectors → Telemetry Snapshots
   ↓
2. AgentController → Rule Engine
   ↓
3. Rule Engine → Events (if rules trigger)
   ↓
4. EventLogger → Event Store (encrypted)
   ↓
5. Uploader → Batch Upload → Remote Endpoint
```

### Concurrency Model

- **Actors**: Used for thread-safe state management
  - `EventStore`: Database access
  - `EventEncryption`: Key management
  - `RuleEngine`: Rule evaluation
  - `Uploader`: Upload coordination

- **Async/Await**: Modern Swift concurrency
  - Non-blocking I/O
  - Structured concurrency
  - Task cancellation support

- **Combine**: Reactive programming
  - Publisher/Subscriber pattern
  - UI state updates
  - Collector event streams

### Limitations and Notes

1. **CPU/Memory Metrics**
   - Currently estimated/placeholder values
   - SystemCollector uses approximations
   - For production: Implement real process metrics
   - UI clearly labels as "est" (estimated)

2. **Simulator Behavior**
   - MetricKit events simulated
   - Some system metrics limited
   - Keychain simulated
   - Network monitoring fully functional

3. **Redaction Pipeline**
   - Redactor component exists
   - Currently stores original events
   - Future: Wire redaction into storage pipeline

---

## 🔒 Security

### Encryption at Rest

**Algorithm**: AES-GCM (Galois/Counter Mode)
- Authenticated encryption
- Provides confidentiality and integrity
- Industry-standard for data at rest

**Key Management**:
- Keys stored in iOS Keychain
- Keychain access controls enforced
- Key generation on first run
- Key rotation support (future)

**Scope**: All event `attributes` (BLOB field) encrypted

### Network Security

**HTTPS Only**:
- All network communication over HTTPS
- TLS 1.2+ required
- Certificate validation enforced

**Certificate Pinning** (Optional):
- Defends against MITM attacks
- Pinned certificate validation
- Configured per endpoint

**HMAC Signing** (Optional):
- Request authentication
- Shared secret (base64 encoded)
- Signature in request headers

### Data Protection

**Redaction**:
- Sensitive keys removed before storage
- Configurable allowlist/forbidden patterns
- Redacted view available in UI

**Access Control**:
- Keychain-based key storage
- App sandboxing enforced
- No external key exposure

**Offline-First**:
- All data stored locally first
- Uploads are asynchronous
- No data loss on network failure

### Security Best Practices

1. **Certificate Pinning**
   - Enable for production endpoints
   - Manage certificate updates carefully
   - Test pinning configuration

2. **HMAC Signing**
   - Use strong, unique secrets
   - Rotate secrets periodically
   - Store secrets securely (Keychain/MDM)

3. **Network Allowlist**
   - Restrict to known-good endpoints
   - Review allowlist regularly
   - Monitor for violations

4. **Key Management**
   - Document key rotation procedures
   - Backup key recovery process
   - Audit key access

---

## ✈️ FAA Compliance

### Alignment with FAA 2024 ASISP

EFB Agent is designed to support FAA 2024 Aircraft Systems Information Security Protection (ASISP) requirements.

**Key Compliance Areas**:

1. **Monitoring & Detection**
   - Continuous system health monitoring
   - Real-time anomaly detection
   - Security-relevant event identification

2. **Logging & Evidence Preservation**
   - Tamper-evident event storage
   - Time-stamped audit trails
   - Offline-first operation

3. **Secure Data Handling**
   - Encryption at rest (AES-GCM)
   - Secure transmission (HTTPS, pinning)
   - Data minimization (redaction)

4. **Operational Control**
   - Policy-based behavior control
   - Quiet mode for constrained operations
   - Manual override capabilities

5. **Traceability**
   - Event IDs and sequence numbers
   - Device identification
   - Upload status tracking

### Detailed Mapping

See [FAA Compliance Crosswalk](Docs/COMPLIANCE_CROSSWALK_FAA_2024.md) for detailed mapping of UI components and subsystems to FAA requirements.

### Compliance Considerations

1. **Evidence Preservation**
   - Events stored with cryptographic integrity
   - Timestamps from trusted sources
   - Sequence numbers prevent gaps

2. **Operational Resilience**
   - Offline-first operation
   - No data loss during network outages
   - Automatic retry with backoff

3. **Configuration Management**
   - Tamper-evident configuration
   - Signed remote configuration
   - MDM integration for enterprise

---

## 💻 Development

### Development Setup

1. **Clone Repository**
   ```bash
   git clone <repository-url>
   cd EFB-Agent1-Backup-12:16:2025
   ```

2. **Install Dependencies**
   ```bash
   # XcodeGen (if not installed)
   brew install xcodegen
   
   # Swift Package Manager dependencies
   # (Managed automatically by Xcode)
   ```

3. **Generate Project**
   ```bash
   ./setup_project.sh
   ```

4. **Open in Xcode**
   ```bash
   open EFB-Agent.xcodeproj
   ```

### Code Organization

**Module Structure**:
- **Agent**: Core orchestration logic
- **Collection**: Telemetry collection
- **Configuration**: Config management
- **Detection**: Rule engine and rules
- **Diagnostics**: System verification
- **Models**: Data structures
- **Persistence**: Storage and encryption
- **Telemetry**: OpenTelemetry export
- **UI**: SwiftUI views
- **Upload**: Upload system

### Coding Standards

- **Swift Style**: Follow Swift API Design Guidelines
- **Concurrency**: Use async/await and actors
- **Error Handling**: Proper error propagation
- **Documentation**: Code comments for public APIs
- **Testing**: Unit tests for core logic

### Building

#### Debug Build
```bash
xcodebuild build -scheme EFBAgent -configuration Debug -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch)'
```

#### Release Build
```bash
xcodebuild build -scheme EFBAgent -configuration Release -destination 'generic/platform=iOS'
```

### Dependencies

**GRDB.swift** (v6.0.0+)
- SQLite database library
- Swift Package Manager dependency
- Located in `Package.swift`

**System Frameworks**:
- Foundation
- SwiftUI
- Combine
- Network (NWPathMonitor)
- MetricKit (iOS 13+)
- Security (Keychain)

### Project Generation

The project uses **XcodeGen** to generate Xcode projects from YAML.

**Modify Configuration**:
1. Edit `project.yml`
2. Run `xcodegen generate`
3. Xcode project regenerated

**Key Files**:
- `project.yml`: XcodeGen configuration
- `Package.swift`: Swift Package Manager
- `setup_project.sh`: Setup automation

---

## 🧪 Testing

### Running Tests

#### In Xcode
1. Press `⌘U` (Command + U)
2. Or: Product → Test
3. View results in Test Navigator

#### Command Line
```bash
xcodebuild test \
  -scheme EFBAgent \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch)'
```

### Test Structure

**Unit Tests** (`EFBAgentTests/`):
- `MetricsRingBufferTests.swift`: Ring buffer functionality

**Test Coverage**:
- Core data structures
- Business logic
- Utility functions

### Adding Tests

1. Create test file in `EFBAgentTests/`
2. Import XCTest and module
3. Write test methods (prefixed with `test`)
4. Run tests to verify

**Example**:
```swift
import XCTest
@testable import EFBAgent

class MyTests: XCTestCase {
    func testExample() {
        // Test implementation
    }
}
```

### Manual Testing

**Recommended Test Scenarios**:

1. **Agent Lifecycle**
   - Start agent
   - Verify collectors active
   - Stop agent
   - Verify cleanup

2. **Event Generation**
   - Trigger rules manually
   - Verify events created
   - Check event storage

3. **Upload Functionality**
   - Configure endpoint
   - Generate events
   - Trigger upload
   - Verify success

4. **Offline Operation**
   - Disable network
   - Generate events
   - Verify local storage
   - Re-enable network
   - Verify upload

5. **Configuration**
   - Test MDM config
   - Test remote config
   - Verify precedence

---

## 🔧 Troubleshooting

### Common Issues

#### 1. Project Won't Generate

**Problem**: `xcodegen: command not found`

**Solution**:
```bash
brew install xcodegen
```

**Problem**: XcodeGen errors

**Solution**:
- Check `project.yml` syntax
- Verify YAML indentation
- Review error messages

#### 2. Build Errors

**Problem**: Missing dependencies

**Solution**:
- Xcode → File → Packages → Reset Package Caches
- Xcode → File → Packages → Update to Latest Package Versions

**Problem**: Signing errors

**Solution**:
- Select development team in Signing & Capabilities
- Ensure bundle identifier matches profile
- Check provisioning profile validity

#### 3. App Won't Launch

**Problem**: Crashes on launch

**Solution**:
- Check Xcode console for errors
- Verify Keychain access permissions
- Check Info.plist configuration
- Review crash logs

#### 4. No Events Appearing

**Problem**: Events not generating

**Solution**:
- Verify agent is running (Status = Running)
- Check rule thresholds (may be too high)
- Review diagnostics report
- Check collector status

#### 5. Upload Failures

**Problem**: Uploads not succeeding

**Solution**:
- Verify network connectivity
- Check endpoint URL configuration
- Review certificate pinning (if enabled)
- Check HMAC signing (if enabled)
- Review upload status card for errors

#### 6. Database Issues

**Problem**: Database errors

**Solution**:
- Check app Documents directory permissions
- Verify SQLite file accessibility
- Review encryption key status
- Check Keychain access

#### 7. Simulator Limitations

**Problem**: Metrics not accurate in simulator

**Solution**:
- This is expected behavior
- MetricKit simulated in simulator
- Some system metrics estimated
- Test on physical device for accuracy

### Debugging Tips

1. **Enable Debug Mode**
   ```json
   {
     "debugMode": true
   }
   ```
   - More verbose logging
   - Additional diagnostic information

2. **Check Logs**
   - Xcode Console during development
   - Device Console (Window → Devices and Simulators)
   - os.log framework output

3. **Database Inspection**
   - Use DB Browser in app
   - Export `events.db` for analysis
   - Use SQLite tools externally

4. **Network Debugging**
   - Enable network logging
   - Use Charles Proxy or similar
   - Review URLSession metrics

### Getting Help

1. **Check Documentation**
   - User Guide: `Docs/EFB_Agent_User_Guide.md`
   - Compliance Guide: `Docs/COMPLIANCE_CROSSWALK_FAA_2024.md`
   - SQLite Guide: `SQLITE_STORAGE_AND_VIEWING.md`

2. **Review Code**
   - Check component implementations
   - Review error handling
   - Examine configuration

3. **Contact Support**
   - Open issue in repository
   - Contact development team
   - Provide error logs and steps to reproduce

---

## 📚 Documentation

### Included Documentation

1. **[User Guide](Docs/EFB_Agent_User_Guide.md)**
   - Comprehensive user documentation
   - UI tour and field explanations
   - Usage scenarios
   - Troubleshooting

2. **[FAA Compliance Crosswalk](Docs/COMPLIANCE_CROSSWALK_FAA_2024.md)**
   - Detailed mapping to FAA requirements
   - Implementation gaps
   - Compliance considerations

3. **[SQLite Storage Guide](SQLITE_STORAGE_AND_VIEWING.md)**
   - Database schema
   - Storage details
   - Viewing instructions

### Code Documentation

- Inline code comments
- Public API documentation
- Architecture notes in code

### Additional Resources

- [Swift Documentation](https://swift.org/documentation/)
- [SwiftUI Guides](https://developer.apple.com/documentation/swiftui)
- [FAA Cybersecurity Guidance](https://www.faa.gov/)

---

## 📁 Project Structure

```
EFB-Agent1-Backup-12:16:2025/
│
├── EFBAgent/                          # Main application
│   ├── Agent/
│   │   └── AgentController.swift     # Main orchestration
│   │
│   ├── Collection/                    # Telemetry collectors
│   │   ├── MetricKitCollector.swift
│   │   ├── MetricsCollecting.swift
│   │   ├── NetworkCollector.swift
│   │   └── SystemCollector.swift
│   │
│   ├── Configuration/                 # Configuration management
│   │   ├── ConfigManager.swift
│   │   └── SignedConfigVerifier.swift
│   │
│   ├── Detection/                     # Rule engine
│   │   ├── Rule.swift
│   │   ├── RuleEngine.swift
│   │   └── Rules/
│   │       ├── ConnectivityFlapRule.swift
│   │       ├── HighCpuUsageRule.swift
│   │       ├── MemoryPressureRule.swift
│   │       ├── NetworkDestinationAllowlistRule.swift
│   │       └── RepeatedTLSFailureRule.swift
│   │
│   ├── Diagnostics/                   # Diagnostic runner
│   │   └── DiagnosticsRunner.swift
│   │
│   ├── Models/                        # Data models
│   │   ├── AgentEvent.swift
│   │   ├── MetricsSample.swift
│   │   └── TelemetrySnapshot.swift
│   │
│   ├── Persistence/                   # Storage and encryption
│   │   ├── EventEncryption.swift
│   │   ├── EventLogger.swift
│   │   ├── EventStore.swift
│   │   ├── EventStoring.swift
│   │   └── Redactor.swift
│   │
│   ├── Telemetry/                     # OpenTelemetry export
│   │   └── OTelExporter.swift
│   │
│   ├── UI/                            # SwiftUI views
│   │   ├── AgentStatusCard.swift
│   │   ├── ConfigView.swift
│   │   ├── ConnectivityStatusCard.swift
│   │   ├── DashboardView.swift
│   │   ├── DBInspectorView.swift
│   │   ├── DiagnosticsReportCard.swift
│   │   ├── EventBrowserView.swift
│   │   ├── EventDetailView.swift
│   │   ├── EventsSummaryCard.swift
│   │   ├── LaunchScreen.swift
│   │   ├── LocalEventsBrowserView.swift
│   │   ├── QuietModeToggleCard.swift
│   │   ├── RealTimeMetricsPanel.swift
│   │   ├── RecentEventsSection.swift
│   │   ├── SparklineView.swift
│   │   ├── TimeFormatter.swift
│   │   └── UploadStatusCard.swift
│   │
│   ├── Upload/                        # Upload system
│   │   ├── MockUploadEndpoint.swift
│   │   ├── SecureTransport.swift
│   │   ├── Uploader.swift
│   │   └── Uploading.swift
│   │
│   ├── Resources/
│   │   └── default-config.json        # Default configuration
│   │
│   ├── Assets.xcassets/               # App icons and assets
│   │   └── AppIcon.appiconset/
│   │
│   ├── EFBAgentApp.swift              # App entry point
│   ├── Info.plist                     # App configuration
│   └── Info 2.plist                   # Alternative config
│
├── EFBAgentTests/                     # Unit tests
│   └── MetricsRingBufferTests.swift
│
├── Docs/                              # Documentation
│   ├── COMPLIANCE_CROSSWALK_FAA_2024.md
│   └── EFB_Agent_User_Guide.md
│
├── EFB-Agent.xcodeproj/               # Xcode project (generated)
├── EFB-Agent 2.xcodeproj/             # Alternative project
├── EFBAgent.xcodeproj/                # Additional project
│
├── project.yml                        # XcodeGen configuration
├── Package.swift                      # Swift Package Manager
├── setup_project.sh                   # Setup script
├── README.md                          # This file
└── SQLITE_STORAGE_AND_VIEWING.md     # SQLite documentation
```

---

## 📄 License

Proprietary - See license terms

**Note**: This software is proprietary. Unauthorized copying, modification, distribution, or use is prohibited.

---

## 🤝 Contributing

This is a proprietary project. For contributions, please contact the project maintainers.

---

## 📞 Support

For issues, questions, or feature requests:

1. **Check Documentation**: Review included documentation files
2. **Review Troubleshooting**: See [Troubleshooting](#-troubleshooting) section
3. **Open Issue**: Create an issue in the repository (if available)
4. **Contact Team**: Reach out to the development team

---

## 🔮 Future Enhancements

Potential future improvements:

- Real CPU/memory metrics (beyond estimates)
- Redaction pipeline integration
- Database export functionality
- Periodic automated diagnostics
- Enhanced network security indicators
- Operator acknowledgment tracking
- Key rotation procedures
- Config change audit logging

---

**Note**: This agent is designed for production use in aviation environments. Ensure proper configuration and testing before deployment in operational systems. Always follow aviation cybersecurity best practices and regulatory requirements.