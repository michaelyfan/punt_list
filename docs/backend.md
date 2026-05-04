# Backend Architecture

## Why Firebase

PuntList's backend requirements are simple: auth, a database, and per-user data isolation. There is no server-side business logic — all logic (punt, check, sublist management) runs client-side.

**Offline-first is the critical requirement.** Firestore provides built-in offline persistence and automatic sync out of the box. With a relational DB, you'd need SQLite locally + a sync layer + conflict resolution — significantly more work.

**Why Firestore over Postgres/SQL:**
- PuntList's access patterns are simple — "get lists for user" and "get items for list" — no joins needed
- Firestore's subcollection model maps naturally to these patterns
- Offline persistence is built-in (mobile: on by default; web: one line to enable)
- Referential integrity (the main SQL advantage) is enforced in app code, which is acceptable for this simple model
- Free tier is generous (50K reads/day, 20K writes/day, 1GB storage)

**Why Firebase over AWS Amplify:**
- Flutter integration is more mature (FlutterFire is well-maintained with extensive docs)
- Simpler architecture — Firestore SDK talks directly to the database vs. Amplify stitching together Cognito + AppSync + DynamoDB
- Firebase Auth is turnkey vs. Cognito's complexity
- Firestore offline sync is battle-tested vs. Amplify DataStore's historical rough edges

**Why BaaS over serverless/self-managed:**
- Zero backend code needed — Flutter SDK talks directly to Firestore
- No server to manage, deploy, or monitor
- If server-side logic is needed later, Cloud Functions can be bolted on

**Scale context (BOTECs):** At <1K users with ~100 items each: ~22MB total storage, ~2 QPS peak writes, ~10 QPS peak reads. No caching, CDN, load balancer, or sharding needed. Cost: $0/month on free tier.

**Migration path:** If PuntList outgrows Firebase, the key enabler is that all business logic lives in the Flutter app — the database is a dumb persistence layer. Supabase (Postgres + real-time) or a custom backend + PowerSync are viable migration targets.

## Architecture

```
Flutter App
  UI (Screens) ←→ AppState (Provider/ChangeNotifier) ←→ Firestore SDK (offline cache)
                                                              ↕ automatic sync
                                                         Cloud Firestore
                                                              ↕
                                                         Firebase Auth
```

- **State pattern**: `AppState` + `ChangeNotifier` + `Provider`. Mutations update local state immediately (optimistic), then fire-and-forget Firestore writes.
- **Firestore SDK** queues writes and retries automatically, including offline. Disk-backed queue persists across app restarts.
- **Real-time sync**: Not in v1. Data loads from Firestore on app start; cross-device sync happens via cache on next launch.

## Firestore Data Model

```
users/{userId}
  ├── themePreference: string ("light" | "dark" | "system")
  ├── listOrder: [listId, ...]          ← one doc write on reorder
  │
  └── lists/{listId}
        ├── name, destinationListId, createdAt, updatedAt
        │
        └── items/{itemId}
              ├── text, isChecked, parentId, sortOrder, createdAt, updatedAt
```

**Why subcollections (not embedded arrays)?** Firestore charges per-document-read. Subcollections allow reading/writing individual items and enable granular real-time listeners.

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| List ordering | `listOrder` array on user doc | One doc write on reorder; list count is always small |
| Item ordering | `sortOrder` double, reassigned as clean integers | Simpler than fractional indexing; bulk-write acceptable at hobby scale |
| Timestamps | Firestore server timestamps with `estimate` behavior | Authoritative server time; client sees estimate instantly while offline |
| Item IDs | Firestore auto-IDs (`doc().id`) | Collision-resistant across devices; works offline |
| Write strategy | Surgical for edits/toggles; bulk for order changes; atomic batch for punts | Balances write efficiency with code simplicity |
| Conflict resolution | Last-write-wins (Firestore default) | Acceptable for single-user app; only realistic conflict is same-item text edit on two devices |

## Security Rules

User-scoped isolation on all paths (`request.auth.uid == userId`). No complex rules needed since PuntList is single-user. See `firestore.rules`.

## Auth Flow

- `AuthGate` widget wraps the app; streams `FirebaseAuth.authStateChanges()`
- Unauthenticated → `AuthScreen` (email/password + Google sign-in)
- Authenticated → `AppState` initialized with `FirestoreService(user.uid)`, data loaded from Firestore
- Sign-out available in Settings; state is disposed and recreated on user switch
