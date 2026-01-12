# EFB Agent

**Electronic Flight Bag Cybersecurity Telemetry Agent for iPadOS**

Production-oriented cybersecurity telemetry agent aligned with FAA 2024 aviation cybersecurity guidance. Provides continuous monitoring, anomaly detection, encrypted offline-first storage, and secure batch reporting.

## Features

- **Continuous Monitoring**: Periodic collection of system health, network connectivity, and performance metrics
- **Anomaly Detection**: Local rule engine with 5 detection rules (CPU, memory, connectivity, TLS, network allowlist)
- **Offline-First Storage**: Encrypted SQLite database with AES-GCM encryption
- **Secure Reporting**: Batch uploads with optional certificate pinning and HMAC signing
- **Comprehensive Dashboard**: Real-time status, event feeds, diagnostics, and configuration management
- **FAA Aligned**: Designed to support continued-airworthiness procedures and compliance requirements

## Requirements

- iOS 16.0+ (iPadOS)
- Xcode 15.0+
- Swift 5.9+

## Quick Start

1. **Generate Xcode Project:**
   ```bash
   ./setup_project.sh
   ```

2. **Open in Xcode:**
   - Select your development team in Signing & Capabilities
   - Select iPad as the run destination
   - Build and run (Cmd+R)

3. **Use the App:**
   - Tap "Start" to begin agent
   - Tap "Run Diagnostics (Safe)" to verify systems
   - View events, connectivity, and upload status on dashboard

## Documentation

See [EFB_Agent_Documentation.md](EFB_Agent_Documentation.md) for comprehensive documentation covering:
- Overview and user personas
- Complete dashboard walkthrough
- FAA 2024 cybersecurity alignment
- Common scenarios and FAQs
- Glossary

## Architecture

- **Collectors**: MetricKit, Network (NWPathMonitor), System metrics
- **Rule Engine**: Actor-based evaluation with rate limiting and cooldowns
- **Event Store**: Actor-based SQLite with encryption
- **Uploader**: Actor-based batch uploader with exponential backoff
- **UI**: SwiftUI with Combine for reactive updates

## Configuration

Configuration supports three sources (in precedence order):
1. **DEFAULT**: Bundled JSON (`default-config.json`)
2. **MDM**: Apple Managed App Configuration
3. **REMOTE SIGNED**: Signed remote configuration with HMAC verification

## Security

- AES-GCM encryption for data at rest
- Keychain storage for encryption keys
- Optional certificate pinning for upload endpoint
- Optional HMAC signing for request authentication
- Redaction of sensitive data from events

## License

Proprietary - See license terms

