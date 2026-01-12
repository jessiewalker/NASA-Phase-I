# SQLite Data Storage and User Viewing in EFB Agent

## How Data is Stored in SQLite

### Database Location
- **File Path**: `events.db` in the app's Documents directory
- **Full Path**: `/var/mobile/Containers/Data/Application/[UUID]/Documents/events.db` (on device)
- **Library**: GRDB.swift for SQLite access

### Database Schema

The `events` table structure:

```sql
CREATE TABLE events (
    id TEXT PRIMARY KEY,              -- UUID string of the event
    device_id TEXT NOT NULL,          -- Device identifier
    created_at REAL NOT NULL,         -- Unix timestamp (TimeInterval since 1970)
    category TEXT NOT NULL,           -- EventCategory.rawValue (performance, security, etc.)
    severity TEXT NOT NULL,           -- EventSeverity.rawValue (critical, error, warning, info)
    name TEXT NOT NULL,               -- Event name/description
    attributes BLOB NOT NULL,         -- Encrypted full event JSON (AES-GCM)
    source TEXT NOT NULL,             -- EventSource.rawValue (metricKit, networkCollector, etc.)
    sequence_number INTEGER NOT NULL, -- Monotonically increasing sequence number
    uploaded INTEGER NOT NULL DEFAULT 0 -- Boolean flag: 0 = pending, 1 = uploaded
)
```

### Indexes
- `idx_uploaded` on `uploaded` column (for fast pending event queries)
- `idx_created_at` on `created_at` column (for time-based queries)

### Storage Details

1. **Encryption**: 
   - The full `AgentEvent` JSON is encrypted using AES-GCM before storage
   - Encryption keys are stored in the iOS Keychain (via `EventEncryption` actor)
   - Only the `attributes` BLOB field contains encrypted data; metadata fields are stored in plain text for querying

2. **Event Persistence Flow**:
   ```
   AgentEvent → JSON encoding → AES-GCM encryption → SQLite INSERT
   ```

3. **Retrieval Flow**:
   ```
   SQLite SELECT → Decrypt attributes BLOB → JSON decoding → AgentEvent
   ```

4. **Upload Tracking**:
   - Events start with `uploaded = 0` (pending)
   - After successful upload, `uploaded = 1`
   - Old uploaded events can be pruned via `prune(retentionDays:)`

### Key Methods in EventStore

- `append(_ event: AgentEvent)` - Stores a new event (encrypted)
- `fetchBatch(limit: Int)` - Retrieves pending events (decrypted)
- `markUploaded(ids: [UUID])` - Marks events as uploaded
- `countPending()` - Returns count of pending events
- `prune(retentionDays: Int)` - Deletes old uploaded events
- `deleteUploadedEvents()` - Deletes all uploaded events (DEBUG)
- `deleteAllEvents()` - Deletes all events (DEBUG)

## How End Users Can View Data

### Current Implementation

**In-Memory Recent Events (Primary View)**:
- Location: `AgentController.recentEvents` (in-memory array, max 200 items)
- UI Component: `RecentEventsSection` in `DashboardView`
- Features:
  - Shows events in reverse chronological order (newest first)
  - Filter by severity (critical, error, warning, info)
  - Filter by category (performance, security, connectivity, system)
  - Capped at 200 visible events
  - Shows "X more events..." if truncated

**Event Detail View**:
- Accessed by tapping any event in the Recent Events feed
- UI Component: `EventDetailView`
- Displays:
  - Event ID (UUID)
  - Device ID
  - Timestamp (formatted)
  - Category, Severity, Source
  - Sequence Number
  - Event Name
  - Full event JSON (pretty-printed, sortable keys)
  - "Copy JSON" button to clipboard

### Limitations

⚠️ **Important**: The current implementation does NOT query all events from SQLite for display. Only events that pass through the app's event logging pipeline are shown in the Recent Events feed (limited to the last 200 in memory).

### Viewing Options Summary

| Feature | Location | Source | Limit |
|---------|----------|--------|-------|
| Recent Events Feed | Dashboard → Recent Events Section | In-memory array | 200 items |
| Event Details | Tap event → EventDetailView | In-memory array | Full JSON |
| Pending Count | Dashboard → Agent Status Card | SQLite query | All pending |
| Store Size | Dashboard → Agent Status Card | File system | Total DB size |

## Direct SQLite Access (Not Currently Exposed)

To view the raw SQLite database directly, users would need:

1. **Via Xcode/Device Console**:
   - Connect iPad to Mac
   - Use Xcode → Window → Devices and Simulators
   - Download container
   - Access `Documents/events.db`

2. **Via SQLite CLI**:
   ```bash
   sqlite3 events.db
   SELECT * FROM events ORDER BY created_at DESC LIMIT 50;
   ```
   ⚠️ Note: `attributes` column will show encrypted binary data (not human-readable)

3. **Via Third-Party Apps**:
   - Apps like iMazing, iExplorer can browse app containers
   - Extract `events.db` file
   - Open with SQLite browser (requires decryption key from Keychain)

## Potential Enhancement: Database Query View

Currently missing: A UI feature to query and view ALL events from SQLite (not just recent in-memory). This could include:

- Paginated event list from database
- Filter by date range
- Filter by uploaded status
- Export events to JSON/CSV
- Search by event name or attributes

Such a feature would require adding methods to `EventStore` like:
- `fetchAll(limit:offset:)` - Fetch all events with pagination
- `fetchByDateRange(start:end:)` - Query by timestamp
- `fetchBySeverity(_ severity: EventSeverity)` - Filter by severity
- `fetchByCategory(_ category: EventCategory)` - Filter by category

