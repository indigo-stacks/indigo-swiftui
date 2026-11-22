# Local Caching Guide

## Introduction

This guide covers how to implement local data persistence and caching using GRDB and SQLiteData, integrated with The Composable Architecture (TCA). The patterns described here provide type-safe and testable data persistence.

The template reads through a dependency client (`NotesClient`) and refetches after writes. `@FetchAll` reactive queries are an alternative that the shipped example does not use; this guide keeps them marked as such.

```swift
let notes = try await notesClient.fetchAll()
```

Key advantages:

- **Type Safety**: `@Table` macro eliminates schema/model mismatches
- **TCA Integration**: Dependency injection for testability
- **Concurrent Access**: `DatabasePool` for efficient read/write operations
- **Explicit Data Flow**: every read and write goes through a testable client

## Dependencies

Add this package to your project:

```swift
.package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.12.0"),
```

GRDB is included as a transitive dependency through sqlite-data.

Import them in your files:

```swift
import GRDB
import SQLiteData
```

## Model Definition

Define your models using the `@Table` macro from SQLiteData:

```swift
import SQLiteData

@Table
public struct Note: Identifiable, Codable, Hashable, Sendable {
  public let id: UUID
  public var title: String
  public var body: String
  public let createdAt: Date
  public var updatedAt: Date?

  public init(
    id: UUID = UUID(),
    title: String,
    body: String = "",
    createdAt: Date = Date(),
    updatedAt: Date? = nil
  ) {
    self.id = id
    self.title = title
    self.body = body
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}
```

The `@Table` macro automatically generates:

- GRDB `Record` conformance for database operations
- A `Draft` type for insertions and updates
- Type-safe query builders

**Best Practices:**

- Always conform to `Identifiable`, `Codable`, `Hashable`, and `Sendable`
- Use `UUID` for primary keys
- Include `createdAt` and `updatedAt` timestamps
- Make mutable properties `var`, immutable ones `let`

## Database Schema

### Migrations

Define your schema using versioned migrations:

The shipped implementation lives in `Core/Sources/Database/Migrations.swift` and `Core/Sources/Database/Connection.swift`. The migrator is a `DatabaseMigrator` extension, and each migration is a plain function:

```swift
import GRDB
import SQLiteData

extension DatabaseMigrator {
  /// The migrator the template applies to every database it opens.
  static var baseMigrator: Self {
    var migrator = DatabaseMigrator()

    #if DEBUG
      migrator.eraseDatabaseOnSchemaChange = true
    #endif

    migrator.registerV1Migration()
    return migrator
  }

  mutating func registerV1Migration() {
    registerMigration("v1") { database in
      try v1(on: database)
    }
  }
}

func v1(on database: Database) throws {
  try #sql(
    """
    CREATE TABLE "notes" (
      "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
      "title" TEXT NOT NULL,
      "body" TEXT NOT NULL DEFAULT '',
      "createdAt" TEXT NOT NULL,
      "updatedAt" TEXT
    ) STRICT
    """
  )
  .execute(database)
}
```

Future migrations get their own version string and a new `registerMigration` call.

**Schema Guidelines:**

- Use `STRICT` mode for type enforcement
- Store UUIDs as `TEXT`
- Store dates as `TEXT` (ISO8601 format)
- Use `ON CONFLICT REPLACE` for upsert support
- Define sensible defaults where appropriate

### Database Connection

Set up the database connection with appropriate configuration:

The shipped implementation lives in `Core/Sources/Database/Connection.swift`:

```swift
import Dependencies
import Foundation
import Logging
import OSLog
import SQLiteData

private let logger = Logger(subsystem: "Core", category: "Database")

public func appDatabase() throws -> any DatabaseWriter {
  @Dependency(\.context) var context

  let database: any DatabaseWriter
  var configuration = Configuration()

  configuration.foreignKeysEnabled = true

  configuration.prepareDatabase { db in
    #if DEBUG
      db.trace(options: .profile) {
        if context == .live {
          logger.debug("\($0.expandedDescription)")
        } else {
          print("\($0.expandedDescription)")
        }
      }
    #endif
  }

  if context == .preview {
    database = try DatabaseQueue(configuration: configuration)
  } else {
    let path: String
    if context == .live {
      let folder = URL.applicationSupportDirectory
        .appending(component: "Database", directoryHint: .isDirectory)
      try FileManager.default.createDirectory(
        at: folder,
        withIntermediateDirectories: true
      )
      try (folder as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
      #if DEBUG
        let file = folder.appending(component: "cache-debug.sqlite")
      #else
        let file = folder.appending(component: "cache.sqlite")
      #endif
      path = file.path()
    } else {
      path = URL.temporaryDirectory
        .appending(component: "\(UUID().uuidString).sqlite").path()
    }
    logger.info("Open \(path)")
    database = try DatabasePool(path: path, configuration: configuration)
  }

  try DatabaseMigrator.baseMigrator.migrate(database)
  return database
}
```

**Connection Types:**

| Context | Type            | Use Case                                          |
| ------- | --------------- | ------------------------------------------------- |
| Live    | `DatabasePool`  | Production - Application Support, backup-excluded |
| Preview | `DatabaseQueue` | SwiftUI previews - in-memory                      |
| Test    | `DatabasePool`  | Unit tests - temporary files                      |

### Dependency Registration

SQLiteData already provides the `defaultDatabase` dependency, so no custom `DependencyKey` is required. Assign it once in your app entry point:

```swift
@main
struct MyApp: App {
  init() {
    prepareDependencies {
      $0.defaultDatabase = try! appDatabase()
    }
  }
}
```

Clients then read it with `@Dependency(\.defaultDatabase) var database`.

## Data Access Patterns

### Option 1: Client Pattern (What the Template Ships)

The shipped example reads and writes through one dedicated client, `Core/Sources/Clients/NotesClient.swift`, and features refetch after every write. Create the client like this:

```swift
import Dependencies
import DependenciesMacros
import GRDB
import SQLiteData

@DependencyClient
public struct NotesClient: Sendable {
  public var fetchAll: @Sendable () async throws -> [Note]
  public var fetch: @Sendable (_ id: UUID) async throws -> Note?
  public var create: @Sendable (_ title: String, _ body: String) async throws -> Note
  public var update: @Sendable (_ note: Note) async throws -> Void
  public var delete: @Sendable (_ id: UUID) async throws -> Void
}

extension NotesClient: DependencyKey {
  public static var liveValue: NotesClient {
    @Dependency(\.defaultDatabase) var database

    return NotesClient(
      fetchAll: {
        try await database.read { db in
          try Note.fetchAll(db)
        }
      },
      fetch: { id in
        try await database.read { db in
          try Note.where { $0.id.eq(id) }.fetchOne(db)
        }
      },
      create: { title, body in
        let note = Note(title: title, body: body)
        try await database.write { db in
          try Note.insert { Note.Draft(note) }.execute(db)
        }
        return note
      },
      update: { note in
        var updated = note
        updated.updatedAt = Date()

        try await database.write { [updated] db in
          try Note.upsert { Note.Draft(updated) }.execute(db)
        }
      },
      delete: { id in
        try await database.write { db in
          try Note.where { $0.id.eq(id) }.delete().execute(db)
        }
      }
    )
  }
}

extension DependencyValues {
  public var notesClient: NotesClient {
    get { self[NotesClient.self] }
    set { self[NotesClient.self] = newValue }
  }
}
```

**Usage in Reducers:**

```swift
@Reducer
struct NotesListFeature {
  @Dependency(\.notesClient) var notesClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        return .run { send in
          let notes = try await notesClient.fetchAll()
          await send(.notesLoaded(notes))
        }

      case .deleteNote(let id):
        return .run { send in
          try await notesClient.delete(id)
          // Refetch after the write so the list mirrors the database.
          let notes = try await notesClient.fetchAll()
          await send(.notesLoaded(notes))
        }
      }
    }
  }
}
```

### Option 2: Reactive Queries with @FetchAll (Alternative — Not Used by the Template)

The shipped features do not use `@FetchAll`: they hold plain arrays in state and refetch through the client after every write, which keeps the data flow explicit and easy to test. If your app prefers live queries instead, SQLiteData supports them with the `@FetchAll` property wrapper:

```swift
import SQLiteData

@Reducer
struct NotesListFeature {
  @ObservableState
  struct State: Equatable {
    @ObservationStateIgnored
    @FetchAll var notes: [Note] = []

    init() {
      _notes = FetchAll(Note.order(by: \.createdAt, .desc))
    }
  }
}
```

**Key Points:**

- Use `@ObservationStateIgnored` to exclude from equatability checks
- The query re-executes automatically when the database changes
- No manual refresh needed - SwiftUI updates automatically

**With Filtering:**

```swift
@ObservableState
struct State: Equatable {
  var searchQuery: String = ""

  @ObservationStateIgnored
  @FetchAll var notes: [Note] = []

  init() {
    _notes = FetchAll(
      Note.where { note in
        note.title.contains(searchQuery) || note.body.contains(searchQuery)
      }
      .order(by: \.createdAt, .desc)
    )
  }
}
```

**With Relationships:**

```swift
struct StackDetailsFeature {
  @ObservableState
  struct State: Equatable {
    var stack: Stack

    @ObservationStateIgnored
    @FetchAll var tiles: [Tile] = []

    init(stack: Stack) {
      self.stack = stack
      _tiles = FetchAll(
        Tile.where { $0.stackId == stack.id }
            .order(by: \.createdAt)
      )
    }
  }
}
```

## API Sync Patterns

When your app has both local storage and a remote API, you need to sync data between them.

### DataSyncClient Pattern

Create a dedicated sync client:

```swift
@DependencyClient
public struct DataSyncClient: Sendable {
  public var syncNotes: @Sendable () async throws -> Void
  public var syncNote: @Sendable (UUID) async throws -> Void
}

extension DataSyncClient: DependencyKey {
  public static let liveValue = { () -> Self in
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.myAPIClient) var myAPIClient

    return Self {
      let fetchedNotes = try await myAPIClient.getNotes()
      try await database.write { db in
        for note in fetchedNotes {
          try Note.upsert { .init(note) }.execute(db)
        }
      }
    } syncNote: { id in
      let note = try await myAPIClient.getNote(id)
      try await database.write { db in
        try Note.upsert { .init(note) }.execute(db)
      }
    }
  }()
}
```

### Two-Phase Write Pattern

For mutations, write to the API first, then persist locally:

```swift
case .saveNote:
  return .run { [note = state.note] send in
    // Phase 1: Send to API
    let savedNote = try await apiClient.createNote(note)

    // Phase 2: Persist locally
    try await database.write { db in
      try Note.upsert { .init(savedNote) }.execute(db)
    }

    await send(.noteSaved(savedNote))
  }
```

**Benefits:**

- Server is source of truth for IDs and timestamps
- Local cache stays in sync
- Upsert handles both create and update

### Delete Pattern

```swift
case .deleteNote(let id):
  return .run { send in
    // Delete from API first
    try await apiClient.deleteNote(id)

    // Then remove from local cache
    try await database.write { db in
      try Note.where { $0.id == id }.delete().execute(db)
    }

    await send(.noteDeleted)
  }
```

## Query Building

SQLiteData provides a type-safe DSL for queries:

### Fetching

```swift
// Fetch all
try Note.fetchAll(db)

// Fetch one by ID
try Note.find(id).fetchOne(db)

// Fetch with ordering
try Note.order(by: \.createdAt, .desc).fetchAll(db)

// Fetch with limit
try Note.order(by: \.createdAt).limit(10).fetchAll(db)

// Fetch with offset (pagination)
try Note.order(by: \.createdAt).limit(10).offset(20).fetchAll(db)
```

### Filtering

```swift
// Simple equality
try Note.where { $0.title == "Welcome" }.fetchAll(db)

// Multiple conditions
try Note.where { $0.stackId == stackId && $0.status == .active }.fetchAll(db)

// Contains (LIKE)
try Note.where { $0.title.contains("search") }.fetchAll(db)

// Nil checks
try Note.where { $0.updatedAt != nil }.fetchAll(db)
```

### Writing

```swift
// Insert or update (upsert)
try Note.upsert { .init(note) }.execute(db)

// Delete by predicate
try Note.where { $0.id == id }.delete().execute(db)

// Delete a specific record
try Note.delete(note).execute(db)
```

## Testing

### Preview Values

```swift
extension NotesClient {
  public static let previewValue: NotesClient = {
    let notes = LockIsolated<[Note]>([
      Note(title: "Welcome", body: "Your first note!"),
      Note(title: "Shopping", body: "- Milk\n- Eggs"),
    ])

    return NotesClient(
      fetchAll: { notes.value },
      fetch: { id in notes.value.first { $0.id == id } },
      create: { title, body in
        let note = Note(title: title, body: body)
        notes.withValue { $0.append(note) }
        return note
      },
      update: { note in
        notes.withValue { list in
          if let index = list.firstIndex(where: { $0.id == note.id }) {
            list[index] = note
          }
        }
      },
      delete: { id in
        notes.withValue { $0.removeAll { $0.id == id } }
      }
    )
  }()
}
```

### Unit Tests

```swift
@Test
func createNote() async throws {
  let store = TestStore(initialState: NoteEditorFeature.State(mode: .create)) {
    NoteEditorFeature()
  } withDependencies: {
    $0.notesClient.create = { title, body in
      Note(title: title, body: body)
    }
  }

  store.state.title = "Test Note"
  store.state.body = "Test body"

  await store.send(.saveButtonTapped) {
    $0.isSaving = true
  }

  await store.receive(.saveCompleted(.success(()))) {
    $0.isSaving = false
  }
}
```

## Error Handling

Define typed errors for database operations:

```swift
public enum DatabaseError: Error, Sendable {
  case notFound
  case migrationFailed(Error)
  case writeFailed(Error)
  case readFailed(Error)
}
```

Handle errors in reducers:

```swift
case .loadNotes:
  return .run { send in
    do {
      let notes = try await notesClient.fetchAll()
      await send(.notesLoaded(.success(notes)))
    } catch {
      await send(.notesLoaded(.failure(error)))
    }
  }

case .notesLoaded(.failure(let error)):
  state.errorMessage = "Failed to load notes: \(error.localizedDescription)"
  return .none
```

## Complete Example

Here's a complete feature implementation with local caching:

```swift
import ComposableArchitecture
import SQLiteData

@Reducer
struct NotesListFeature {
  @ObservableState
  struct State: Equatable {
    var notes: [Note] = []
    var isLoading = false
    var errorMessage: String?
    @Presents var editor: NoteEditorFeature.State?
  }

  enum Action {
    case onAppear
    case addButtonTapped
    case noteSelected(Note)
    case notesLoaded(Result<[Note], Error>)
    case deleteNotes(IndexSet)
    case deleteCompleted(Result<Void, Error>)
    case editor(PresentationAction<NoteEditorFeature.Action>)
  }

  @Dependency(\.notesClient) var notesClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        state.isLoading = true
        return .run { send in
          await send(.notesLoaded(Result { try await notesClient.fetchAll() }))
        }

      case .notesLoaded(.success(let notes)):
        state.isLoading = false
        state.notes = notes.sorted { $0.createdAt > $1.createdAt }
        return .none

      case .notesLoaded(.failure(let error)):
        state.isLoading = false
        state.errorMessage = error.localizedDescription
        return .none

      case .addButtonTapped:
        state.editor = NoteEditorFeature.State(mode: .create)
        return .none

      case .noteSelected(let note):
        state.editor = NoteEditorFeature.State(mode: .edit(note))
        return .none

      case .deleteNotes(let indexSet):
        let notesToDelete = indexSet.map { state.notes[$0] }
        return .run { send in
          for note in notesToDelete {
            try await notesClient.delete(note.id)
          }
          await send(.deleteCompleted(.success(())))
        } catch: { error, send in
          await send(.deleteCompleted(.failure(error)))
        }

      case .deleteCompleted(.success):
        // Refetch after the write instead of editing state in place.
        return .send(.onAppear)

      case .deleteCompleted(.failure(let error)):
        state.errorMessage = error.localizedDescription
        return .none

      case .editor:
        return .none
      }
    }
    .ifLet(\.$editor, action: \.editor) {
      NoteEditorFeature()
    }
  }
}

struct NotesListView: View {
  @Bindable var store: StoreOf<NotesListFeature>

  var body: some View {
    List {
      ForEach(store.notes) { note in
        NoteRow(note: note)
          .onTapGesture {
            store.send(.noteSelected(note))
          }
      }
      .onDelete { indexSet in
        store.send(.deleteNotes(indexSet))
      }
    }
    .toolbar {
      Button {
        store.send(.addButtonTapped)
      } label: {
        Image(systemName: "plus")
      }
    }
    .sheet(item: $store.scope(state: \.editor, action: \.editor)) { store in
      NoteEditorView(store: store)
    }
  }
}
```

## Summary

| Pattern         | Use Case                      | Pros                      | Cons                     |
| --------------- | ----------------------------- | ------------------------- | ------------------------ |
| Client          | Simple CRUD, explicit control | Testable, clear data flow | Manual refresh needed    |
| @FetchAll       | Live data, reactive UIs       | Auto-updates, less code   | Less control over timing |
| DataSyncClient  | API + local cache             | Clean separation          | More complexity          |
| Two-Phase Write | Server as source of truth     | Data consistency          | Requires connectivity    |

The shipped example combines the client pattern for reads and writes — refetching through the client after every mutation — with the two-phase write pattern where the API is the source of truth. `@FetchAll` remains available as an alternative for live queries, but nothing in the template uses it.
