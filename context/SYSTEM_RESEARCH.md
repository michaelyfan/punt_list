# PuntList System Design Research

Research notes for PuntList's backend architecture, database choice, third-party services, and non-functional requirements.

---

## 1. Requirements

### Functional Requirements

Derived from CLAUDE.md and SUBLIST_RESEARCH.md (assuming sublists are implemented):

- **Authentication** — users sign up / sign in to access their data
- **List CRUD** — create, rename, delete lists
- **Item CRUD** — add, edit, check/uncheck, delete items within a list
- **Sublists** — items have optional `parentId`; one level deep; ghost-parent semantics on punt
- **Punt (→)** — move an item (or parent + children block) from one list to another instantly
- **Move destination config** — each list optionally maps to one destination list
- **Theme preference** — per-user light/dark/system setting
- **Multi-device access** — same account, same data, across devices
- **Offline support** — full read/write offline, sync on reconnect

### Non-Functional Requirements

| Requirement | Target | Rationale |
|---|---|---|
| **Availability** | 99.9% (three nines) | Hobby scale; managed services give this for free |
| **Latency** | < 200ms for local operations; < 1s for sync propagation | Near-real-time sync expectation; local-first approach makes local ops instant |
| **Offline resilience** | Full read/write offline, automatic conflict resolution on reconnect | Critical requirement — users must never lose work |
| **Consistency** | Eventual consistency across devices | Acceptable for a personal list app; last-write-wins is fine for most fields |
| **Scalability** | < 1K users initially | No need to over-engineer; pick a stack that scales *if needed* without rearchitecting |
| **Data durability** | No data loss | Users will be frustrated if lists disappear; use a service with built-in backups |
| **Security** | Auth + per-user data isolation | Users must never see another user's lists |
| **Cost** | Minimize at hobby scale | Should run free or near-free under 1K users |

---

## 2. BOTECs (Back-of-the-Envelope Calculations)

### Assumptions

- 1,000 users (ceiling estimate)
- Average user has 5 lists, 20 items per list = 100 items per user
- Average item: ~200 bytes (id, text, isChecked, parentId, timestamps)
- Average list metadata: ~300 bytes (id, name, destinationId, timestamps)
- Average user writes 20 item operations/day (add, check, move, edit)
- Peak concurrent users: ~50 (5% of user base)

### Storage

| Data | Calculation | Result |
|---|---|---|
| Items | 1,000 users × 100 items × 200 B | **20 MB** |
| Lists | 1,000 users × 5 lists × 300 B | **1.5 MB** |
| User profiles | 1,000 × 500 B | **0.5 MB** |
| **Total** | | **~22 MB** |
| 5-year projection (10x growth) | 22 MB × 10 | **~220 MB** |

**Verdict:** Storage is trivially small. Any database or service tier handles this easily. Even the free tiers of Firebase/Supabase/Planetscale are more than sufficient.

### Throughput

| Metric | Calculation | Result |
|---|---|---|
| Daily writes | 1,000 users × 20 ops/day | 20,000 writes/day |
| Writes per second (avg) | 20,000 / 86,400 | **~0.2 QPS** |
| Writes per second (peak, 10x) | | **~2 QPS** |
| Reads per second (peak) | 50 concurrent × 1 read/5s | **~10 QPS** |

**Verdict:** Essentially zero load. A single serverless function or a $5/mo server handles this without breaking a sweat. No need for caching, CDNs, load balancers, sharding, or read replicas.

### Bandwidth

| Metric | Calculation | Result |
|---|---|---|
| Full sync payload | 100 items × 200 B | **20 KB per user** |
| Peak sync bandwidth | 50 users × 20 KB | **1 MB** |

**Verdict:** Negligible. No bandwidth optimization needed.

### Key Takeaway

At this scale, **cost and developer velocity dominate all other concerns.** Performance, scalability, and throughput are non-issues. Pick the stack that gets you shipping fastest with the least operational burden.

---

## 3. Database: Relational vs Non-Relational

### The Data Model

PuntList's data has clear structure:

```
User (1) → (many) List (1) → (many) Item
List (1) → (0 or 1) destination List
Item (0 or 1) → parent Item (via parentId)
```

This is inherently relational — there are foreign key relationships between entities.

### Tradeoffs Applied to PuntList

| Factor | Relational (Postgres, SQLite) | Non-Relational (Firestore, MongoDB) |
|---|---|---|
| **Data model fit** | Natural fit — Users, Lists, Items are distinct entities with clear relationships. Foreign keys enforce referential integrity (e.g., deleting a list cascading to items). | Works fine — Lists can embed Items as subcollections. But cross-list operations (punt) require reading/writing across documents, losing atomicity without transactions. |
| **Punt operation** | Single transaction: delete from source list, insert into destination list, create ghost parent if needed — all atomic. Referential integrity guaranteed. | Requires a multi-document transaction (Firestore supports these but they're slower and have limits). Or accept eventual consistency with client-side reconciliation. |
| **Sublists / parentId** | Simple self-referencing foreign key. Query children with `WHERE parentId = ?`. Cascade deletes for free. | Same query is possible but no referential integrity — deleting a parent without manually deleting children leaves orphans. App code must enforce consistency. |
| **Offline support** | Requires a local DB (SQLite via Drift/sqflite) that syncs to remote. You build the sync layer yourself or use a sync framework. | **Firestore wins here** — built-in offline persistence and automatic sync/conflict resolution out of the box. This is a huge DX advantage. |
| **Schema flexibility** | Schema changes require migrations. Not a big deal at this scale but it's ceremony. | Schema-free — just add fields. Faster iteration. |
| **Querying** | Rich queries, joins, aggregations. Useful if you ever want analytics or complex filtering. | Limited querying (no joins). For PuntList's simple access patterns (get all lists for user, get all items for list), this doesn't matter. |
| **Cost at hobby scale** | Free tier on Supabase (Postgres), Neon, or PlanetScale. SQLite is free (local). | Free tier on Firestore (generous: 50K reads, 20K writes, 1GB storage per day). |

### Recommendation

**For PuntList specifically: Firestore (non-relational) is the pragmatic choice**, despite the data being relational in nature. Here's why:

1. **Offline-first is your critical requirement.** Firestore's built-in offline persistence + automatic sync is a massive feature you'd otherwise have to build yourself. With a relational DB, you'd need SQLite locally + a sync layer + conflict resolution — that's weeks of work.

2. **Your access patterns are simple.** You never need joins. Every query is "get lists for user" or "get items for list." These map perfectly to Firestore's collection/subcollection model.

3. **The punt operation is your most complex transaction.** Firestore transactions handle this adequately at your scale. You won't hit the limits.

4. **Referential integrity (the main SQL advantage) can be enforced in app code** for your simple model. When deleting a list, also delete its items and clear it as a destination — you're already doing this in Flutter.

If you later hit a scale where Firestore's limitations matter (complex queries, heavy cross-document transactions), migrating to Postgres + a sync layer like PowerSync is a reasonable evolution path — but don't build for that now.

---

## 4. AWS (DynamoDB + Amplify) vs Firebase

AWS could work but is a worse fit for PuntList specifically.

### DynamoDB vs Firestore

DynamoDB has no built-in client SDK with offline persistence and automatic sync. You'd need AWS AppSync + Amplify DataStore to get Firestore-equivalent functionality — which is AWS's answer to Firebase, but with more seams.

DynamoDB's pricing model (read/write capacity units) is more complex to reason about than Firestore's per-operation billing, though both are free at PuntList's scale. DynamoDB is more powerful for high-throughput server-side workloads, but that's irrelevant when the client talks directly to the database.

### AWS Amplify (the Real Comparison)

Amplify is AWS's BaaS competitor to Firebase. It bundles Cognito (auth), AppSync (GraphQL API), DynamoDB, and Amplify DataStore (offline sync). On paper it matches Firebase feature-for-feature.

| Factor | Firebase | AWS Amplify |
|---|---|---|
| **Flutter integration** | First-class, mature, years of investment. FlutterFire is well-maintained with extensive docs and community examples. | Less mature Flutter support. More rough edges, fewer community examples. |
| **Architecture simplicity** | One coherent product. Firestore SDK talks directly to the database. | Stitches together Cognito + AppSync + DynamoDB + IAM roles. When something breaks, debugging spans multiple AWS services. |
| **API model** | Direct document reads/writes — simple for PuntList's access patterns. | AppSync uses GraphQL, adding a schema/resolver layer you don't need for basic CRUD. |
| **Offline sync** | On by default for mobile. One line to enable for web. Battle-tested. | Amplify DataStore has had historical reliability issues and a steeper learning curve. |
| **Auth** | Firebase Auth is turnkey — Google, Apple, email/password with minimal config. | Cognito is powerful but notoriously complex to configure. More knobs than you need. |
| **Ecosystem lock-in** | Moderate. Proprietary APIs, but migration to Supabase or custom backend is tractable. | Similar lock-in. AWS services are deeply intertwined. |
| **Cost at < 1K users** | Free tier: 50K reads/day, 20K writes/day, 1GB storage. | Free tier: 25K reads/writes/month (AppSync), 25GB DynamoDB storage. Both more than sufficient. |

### When AWS Would Be the Better Choice

- Your company is already on AWS and you need to stay in-ecosystem
- You need complex server-side processing (Lambda + Step Functions is best-in-class)
- You're at a scale where DynamoDB's predictable single-digit-ms performance at millions of QPS matters
- You need fine-grained IAM policies for a multi-developer team

None of these apply to PuntList. **Firebase is the simpler, faster, better-documented path for a Flutter list app at hobby scale with offline-first requirements.**

---

## 5. Infrastructure: BaaS vs Serverless vs Self-Managed

You mentioned you weren't anticipating backend business logic — and for PuntList, **you barely need any.** Almost all logic (punt, check, sublist management) is client-side state manipulation that gets persisted to a database. The "backend" is really just: auth, a database, and security rules to isolate user data.

### Option A: Fully Managed BaaS (Firebase) — Recommended

**What it is:** Firebase provides auth, database (Firestore), hosting, and more as turnkey services. No backend code needed. Security is enforced via declarative rules, not server logic.

| Pros | Cons |
|---|---|
| **Zero backend code.** Flutter SDK talks directly to Firestore. Auth is a few lines. | **Vendor lock-in.** Migrating off Firebase is painful (proprietary APIs, Firestore query model). |
| **Built-in offline support** with automatic sync and conflict resolution. | **Limited backend logic.** If you ever need server-side validation or complex workflows, you bolt on Cloud Functions (which is essentially Option B). |
| **Free tier is generous** — easily covers < 1K users with headroom. | **Firestore pricing can surprise** at scale (per-read billing). Not an issue at your scale. |
| **Fastest time to ship.** Firebase + Flutter is extremely well-documented. | **Security rules can get complex** as your data model grows, though PuntList's model is simple enough. |
| **Push-based real-time listeners** — near-real-time sync is automatic. | |
| **Google Auth, Apple Auth, email/password** all built in. | |

**Backend logic you might need later and how Firebase handles it:**
- *"When a list is deleted, clear it as a destination from other lists"* — This can be done client-side (as you do now) or via a Cloud Function trigger. No dedicated server needed.
- *"Ghost parent creation during punt"* — Pure client-side logic.

**Cost estimate at < 1K users:** $0/month (free tier: 50K reads/day, 20K writes/day, 1GB storage).

### Option B: Serverless Backend (Cloud Functions / Lambda)

**What it is:** You write individual functions that run in response to events (HTTP requests, database triggers). No server to manage, pay-per-invocation.

| Pros | Cons |
|---|---|
| **Server-side logic** when you need it (validation, complex transactions, notifications). | **More code to write and maintain** — you're building an API layer that BaaS gives you for free. |
| **Still no infra management.** Auto-scales, auto-deploys. | **Cold starts** add 200-500ms latency on first invocation. Annoying for a snappy list app. |
| **Can combine with Firebase** — use Firestore as the DB but add Cloud Functions for server logic. | **No built-in offline support.** You'd need to implement a sync layer yourself unless you pair with Firestore. |
| Pay-per-use pricing is cheap at low scale. | **More moving parts** — API design, deployment config, function orchestration. |

**When this makes sense:** If you find yourself needing server-side validation, scheduled tasks, or integrations (email notifications, webhooks) that can't live in the client. But for PuntList today, there's nothing that requires this.

**Cost estimate at < 1K users:** $0-5/month (Firebase free tier includes 2M Cloud Function invocations/month).

### Option C: Self-Managed Server (Docker / VPS)

**What it is:** You write a traditional API server (Dart Shelf, Node Express, Go, etc.), deploy it on a VPS or container service, and manage the infrastructure.

| Pros | Cons |
|---|---|
| **Full control.** Any database, any framework, any deployment. | **You manage everything** — uptime, deploys, scaling, backups, SSL, monitoring. |
| **No vendor lock-in.** Standard REST/GraphQL API works with any client. | **Slowest to ship.** You're building auth, API endpoints, database migrations, a sync layer, and deployment infra from scratch. |
| **Predictable pricing** — a $5/mo DigitalOcean droplet handles your scale. | **No built-in offline support or real-time sync.** You build it all yourself (or integrate something like PowerSync). |
| **Better for complex server logic** if your app evolves in that direction. | **Overkill for PuntList's current needs.** Most of the "backend" is just CRUD that Firestore handles natively. |

**When this makes sense:** If you have strong opinions about your stack, want to avoid vendor lock-in, or anticipate complex server-side logic (multi-user collaboration, complex permissions, heavy data processing). None of these apply to PuntList today.

**Cost estimate at < 1K users:** $5-15/month (VPS + managed DB).

### Verdict

**Go with Firebase (Option A).** The reasons stack up:

1. You have no backend business logic — Firebase's direct-client-to-database model is a perfect fit
2. Offline support is critical — Firestore gives this for free; other options require building it
3. Near-real-time sync — Firestore listeners handle this automatically
4. Auth — Firebase Auth is turnkey (Google, Apple, email)
5. Cost — free at your scale
6. Flutter + Firebase has first-class support and extensive documentation

The vendor lock-in concern is real but acceptable: at < 1K users, the cost of migrating later (if ever needed) is low. Ship now, optimize later.

---

## 6. High-Level Architecture

```
┌─────────────────────────────────────────────────┐
│                  Flutter App                     │
│                                                  │
│  ┌───────────┐  ┌───────────┐  ┌─────────────┐  │
│  │  UI Layer  │  │ AppState  │  │ Local Cache  │  │
│  │ (Screens)  │←→│ (Provider)│←→│ (Firestore   │  │
│  └───────────┘  └───────────┘  │  offline SDK)│  │
│                                 └──────┬──────┘  │
└────────────────────────────────────────┼─────────┘
                                         │ automatic
                                         │ sync
                                    ┌────▼────┐
                                    │Firestore │
                                    │ (Cloud)  │
                                    └────┬────┘
                                         │
                              ┌──────────┼──────────┐
                              │          │          │
                        ┌─────▼──┐ ┌─────▼──┐ ┌────▼───┐
                        │Firebase│ │Firebase│ │Cloud   │
                        │  Auth  │ │Hosting │ │Functions│
                        │        │ │(if web)│ │(future)│
                        └────────┘ └────────┘ └────────┘
```

### Firestore Data Model

```
users/{userId}
  ├── email, displayName, themePreference
  │
  ├── lists/{listId}
  │     ├── name, destinationListId, createdAt, updatedAt
  │     │
  │     └── items/{itemId}
  │           ├── text, isChecked, parentId, createdAt, updatedAt, sortOrder
```

**Why subcollections (not embedded arrays)?**
- Firestore charges per-document-read. If items were an array inside the list document, every single item change would rewrite the entire list document.
- Subcollections allow reading/writing individual items.
- Firestore's real-time listeners work at the collection level — you can listen to `lists/{id}/items` and get granular updates.

**sortOrder field:** A numeric field for manual ordering. Use fractional indexing (e.g., insert between items at position 1.0 and 2.0 by using 1.5) to avoid rewriting all items on every reorder.

### Security Rules (Sketch)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;

      match /lists/{listId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;

        match /items/{itemId} {
          allow read, write: if request.auth != null && request.auth.uid == userId;
        }
      }
    }
  }
}
```

Simple user-scoped isolation. No complex rules needed since PuntList is single-user (no sharing).

---

## 7. Do You Need Microservices?

**No.** Not even close. Microservices solve problems you don't have:

| Microservices solve... | PuntList's situation |
|---|---|
| Independent scaling of services | ~2 QPS total. One Firestore instance handles millions of QPS. |
| Independent deployment of teams | You're a solo developer. |
| Polyglot persistence (different DBs for different services) | One data model, one DB. |
| Fault isolation between services | If Firestore is down, your whole app is down regardless. |
| Organizational boundaries | No organizational boundaries to reflect. |

Microservices would add: network hops, deployment complexity, distributed tracing needs, and eventual consistency headaches — all for zero benefit.

**What you have is simpler than even a monolith** — it's a client app that talks directly to a managed database. That's the right architecture for PuntList.

---

## 8. API Design

With Firebase's direct-client-to-database model, **you don't need a traditional REST API.** The Flutter app uses the Firestore SDK directly:

```dart
// Example: Punt an item from one list to another
Future<void> puntItem(String userId, String sourceListId,
    String destListId, String itemId) async {
  final firestore = FirebaseFirestore.instance;

  await firestore.runTransaction((transaction) async {
    // Read the item
    final itemRef = firestore
        .collection('users/$userId/lists/$sourceListId/items')
        .doc(itemId);
    final itemSnap = await transaction.get(itemRef);
    final itemData = itemSnap.data()!;

    // Write to destination
    final destRef = firestore
        .collection('users/$userId/lists/$destListId/items')
        .doc(itemId);
    transaction.set(destRef, itemData);

    // Delete from source
    transaction.delete(itemRef);
  });
}
```

If you later need a REST API (for integrations, web hooks, etc.), Cloud Functions can expose HTTP endpoints without changing the data model.

---

## 9. Conflict Resolution Strategy

Since offline support is critical, conflicts will happen (e.g., user edits an item on phone while offline, then edits it on tablet).

**Firestore's default behavior:** Last-write-wins at the document level. The most recent `set()` or `update()` overwrites the previous value.

**For PuntList, this is acceptable because:**
- It's a single-user app (no multi-user collaboration conflicts)
- List operations are generally non-conflicting (adding items on two devices produces two items, not a conflict)
- The only real conflict scenario is editing the same item's text on two devices simultaneously — rare, and last-write-wins is fine

**One edge case to handle in app code:** If a user punts an item on device A (offline), then deletes the same item on device B (also offline), when both sync: the punt writes to the destination and the delete removes from source. Net result: item exists in destination only — which is actually correct behavior.

---

## 10. Third-Party Recommendation Summary

| Concern | Recommendation | Why |
|---|---|---|
| **Auth** | Firebase Authentication | Turnkey; supports Google, Apple, email/password; free tier covers your needs |
| **Database** | Cloud Firestore | Built-in offline support + real-time sync; generous free tier; natural fit for Flutter |
| **Hosting (if web)** | Firebase Hosting | Free, CDN-backed, integrates with Firebase deploy pipeline |
| **Server logic (future)** | Cloud Functions for Firebase | Only if/when needed; triggered by Firestore events or HTTP |
| **Analytics (optional)** | Firebase Analytics / Crashlytics | Free; useful for understanding usage patterns and crash reports |
| **CI/CD** | GitHub Actions | Free for public repos; Firebase CLI deploys easily from CI |

### What You Don't Need

- **Load balancer** — Firestore handles this internally
- **CDN** — No static assets to serve (unless you go web)
- **Redis / caching layer** — Firestore's local cache is your cache
- **Message queue** — No async processing needed
- **Search indexing** — List/item search is simple `where` queries
- **Blob storage** — No file uploads
- **Rate limiter** — Firestore security rules + Firebase's built-in abuse protection

---

## 11. Migration Path (If You Outgrow Firebase)

If PuntList grows beyond Firebase's sweet spot (> 100K users, complex queries, cost concerns), the migration path is:

1. **Supabase** — Open-source Firebase alternative built on Postgres. Has real-time subscriptions and auth. Offline support requires a client-side sync layer (e.g., PowerSync).
2. **Custom backend** — Dart (Shelf/Serverpod) or Node API server + Postgres + PowerSync for offline sync. Maximum flexibility, maximum effort.

The key architectural decision that makes migration possible: **keep business logic in the Flutter app, not in Firestore security rules or Cloud Functions.** Your app already does this (punt logic, sublist management, etc. are all client-side). This means the database is just a dumb persistence layer that can be swapped.

---

## 12. Immediate Next Steps

1. **Add Firebase to the Flutter project** — `flutterfire configure`
2. **Implement Firebase Auth** — email/password to start; add Google/Apple later
3. **Migrate in-memory state to Firestore** — replace `AppState`'s in-memory lists with Firestore reads/writes via `StreamBuilder` or Provider listening to Firestore snapshots
4. **Enable Firestore offline persistence** — it's on by default for mobile, one line for web
5. **Write security rules** — the sketch in section 5 is nearly production-ready
6. **Deploy** — `firebase deploy` for web; app stores for mobile
