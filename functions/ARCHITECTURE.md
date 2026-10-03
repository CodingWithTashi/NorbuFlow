# Backend architecture

How the `functions/` backend is put together, how a request moves through it,
and what the database looks like. The diagrams are Mermaid: GitHub renders
them, and so does VS Code with a Mermaid preview extension.

Drawn from the code as of migration `003_temple_profile.sql`.

## 1. The system

```mermaid
flowchart LR
  app["Flutter app<br/>Backend.call"]
  operator["Operator<br/>curl + ADMIN_KEY"]
  cli["cli/db.ts<br/>db:migrate, db:staff"]

  subgraph firebase["Firebase project norbu-flow"]
    fbauth["Firebase Authentication<br/>email link only"]
    fn["Cloud Functions, 2nd gen<br/>us-central1, max 10 instances"]
  end

  neon[("Neon<br/>Postgres")]
  r2[("Cloudflare R2<br/>photos, card PDFs, logos")]
  assets["functions/assets<br/>fonts, artwork per temple"]

  app -- "1. email link sign-in" --> fbauth
  app -- "2. callable + ID token" --> fn
  operator -- "POST, Bearer key" --> fn
  fn -- "ensure account" --> fbauth
  fn -- "SQL, pool of 5" --> neon
  fn -- "put, get, sign link" --> r2
  fn -- "reads" --> assets
  app -. "photo by signed link, 1 week" .-> r2
  cli -- "SQL" --> neon
```

- The app never talks to Neon or R2 with credentials of its own. It gets a
  member's photo as a link the backend signed.
- `functions/.env` holds `DATABASE_URL`, the `R2_*` settings and `ADMIN_KEY`.

## 2. The functions

| Function | Kind | Who may call | What it does |
| --- | --- | --- | --- |
| `auth-checkEmail` | public callable | anyone | Says whether an email is on some temple's team. Yes or no only. |
| `auth-startSession` | callable | on a team | Upserts the `users` row, returns the profile. |
| `temples-list` | callable | on a team | The caller's temples, with role, logo and what each shows. |
| `temples-create` | admin endpoint | operator | Registers a temple. |
| `temples-setLogo` | admin endpoint | operator | Stores a logo under a new key. |
| `temples-addAdmin` | admin endpoint | operator | Puts an email on the team, ensures a Firebase account. |
| `temples-setFeatures` | admin endpoint | operator | Replaces the tabs and Home cards the temple's app shows. |
| `members-list` | callable | admin, geshe, accountant, frontDesk, coordinator | The temple's members, newest first. |
| `members-card` | callable | same as list | A member and the PDF of the card they hold. |
| `members-preview` | callable, 1 GiB | admin, frontDesk | Draws the card. Saves nothing. |
| `members-create` | callable, 1 GiB | admin, frontDesk | Adds a member, issues their card. |
| `members-update` | callable, 1 GiB | admin, frontDesk | Changes a member, reissues the card if it shows the change. |

`cards` has no functions: it is the renderer the others use.

## 3. Layers inside a feature

```mermaid
flowchart TB
  subgraph entry["Entry: features/x/index.ts"]
    callable["defineCallable<br/>session with a proven email"]
    public["definePublicCallable<br/>no session"]
    admin["defineAdminEndpoint<br/>Bearer ADMIN_KEY"]
  end

  input["x.input.ts<br/>zod schema: present, trimmed, within limits"]
  service["x.service.ts<br/>rules. No HTTP, no Firebase, no SQL"]

  subgraph ports["Ports: interfaces the service depends on"]
    repo["XRepository"]
    access["TempleAccess"]
    files["FileStore"]
    renderer["CardRenderer"]
    accounts["Accounts"]
  end

  subgraph adapters["Adapters"]
    pg["PostgresXRepository<br/>plain SQL"]
    fbacc["FirebaseAccounts"]
    db["Database port"]
  end

  subgraph stores["runtime.ts picks one pair"]
    real["Neon + R2<br/>deployed"]
    standin["PGlite + InMemoryFileStore<br/>tests, demo- project, STAND_INS=true"]
  end

  callable --> input
  public --> input
  admin --> input
  input --> service
  service --> repo
  service --> access
  service --> files
  service --> renderer
  service --> accounts
  repo --> pg
  accounts --> fbacc
  pg --> db
  db --> real
  db --> standin
  files --> real
  files --> standin
```

Each feature's `index.ts` builds its service once, lazily, on the first call.
Heavy libraries (`pg`, the S3 client, `sharp`, `pdf-lib`) are imported where
they are used, so functions that do not need them start fast.

## 4. How the features depend on each other

```mermaid
flowchart TB
  auth["auth<br/>AuthService, UserRepository"]
  members["members<br/>MemberService, MemberRepository"]
  temples["temples<br/>TempleService, TempleAccess, TempleRepository"]
  cards["cards<br/>CardRenderer, templates, prepareCardPhoto"]
  core["core<br/>callable, admin-endpoint, caller, validation, errors,<br/>database, file-store, migrations, assets, calendar-date"]
  runtime["runtime.ts<br/>database, fileStore"]

  auth -- "templeAccess" --> temples
  members -- "templeAccess" --> temples
  members -- "cardRenderer, prepareCardPhoto" --> cards
  temples -- "templeNameProblem" --> cards
  auth --> runtime
  members --> runtime
  temples --> runtime
  runtime --> core
  cards --> core
```

`TempleAccess` is the one place that decides who may do what. It reads
`temple_staff` by the caller's email, so the team list is also the sign-in
invitation list.

## 5. One callable request

```mermaid
sequenceDiagram
  participant App
  participant C as defineCallable
  participant S as Service
  participant A as TempleAccess
  participant DB as Database

  App->>C: call with ID token and data
  C->>C: requireCaller, email_verified must be true
  C->>C: parseInput against the zod schema
  C->>S: handler(caller, input)
  S->>A: templeFor(caller, templeId, allowed roles)
  A->>DB: temple_staff join temples by email
  DB-->>A: roles
  A-->>S: the temple, or AppError
  S->>DB: the feature's own work
  S-->>C: result
  C-->>App: JSON
  Note over C,App: AppError becomes an HttpsError with details.<br/>Anything else is logged and sent as internal.
```

| `AppError` kind | Callable code | Admin endpoint status |
| --- | --- | --- |
| `unauthenticated` | `unauthenticated` | 401 |
| `permissionDenied` | `permission-denied` | 403 |
| `invalid` | `invalid-argument` | 400 |
| `notFound` | `not-found` | 404 |
| `conflict` | `already-exists` | 409 |
| anything else | `internal` | 500 |

`details.reason` and the values of `details.fields` are names of the app's
enums (`PermissionReason`, `ConflictReason`, `ValidationIssue`).

## 6. Sign-in

```mermaid
sequenceDiagram
  participant App
  participant FA as Firebase Auth
  participant F as auth functions
  participant DB as Database

  App->>F: auth-checkEmail(email), no session
  F->>DB: is this email in temple_staff
  F-->>App: invited true or false
  alt not invited
    App->>App: show emailNotInvited under the field
  else invited
    App->>FA: send the sign-in link
    FA-->>App: link opened, delivered by app_links
    App->>FA: sign in with the link
    FA-->>App: session, email proven
    App->>F: auth-startSession
    F->>DB: roles of this email
    alt on no team
      F-->>App: permission-denied, notOnTeam
      App->>FA: sign out
    else on a team
      F->>DB: upsert users by uid
      F-->>App: user profile
      App->>F: temples-list
      F-->>App: temples with role, logo and features
    end
  end
```

## 7. Adding a member (`members-create`)

```mermaid
sequenceDiagram
  participant App
  participant S as MemberService
  participant R as CardRenderer
  participant Repo as MemberRepository
  participant DB as Database
  participant FS as FileStore

  App->>S: id, name, photo, phone, email, number, replace
  S->>S: templeFor, role must be admin or frontDesk
  S->>R: can this name be printed
  S->>R: prepare the photo to the card's photo box
  S->>S: today in the temple's time zone, then the expiry date
  S->>Repo: save(member, number, issueCard)
  Repo->>DB: begin, lock the temple's row
  Repo->>DB: is there a card with this id
  alt the same request arrived before
    Repo-->>S: issued, the first result
    S->>FS: get the PDF
  else number typed, held, no replace
    Repo-->>S: taken, who holds it
  else go on
    Repo->>DB: next free number, move member_number_next
    Repo->>S: issueCard(number, memberId)
    S->>FS: put the photo
    S->>R: render the PDF
    S->>FS: put the PDF
    S-->>Repo: card record
    Repo->>DB: insert members, or update the holder if replace
    Repo->>DB: insert member_cards
    Repo->>DB: commit
    Repo-->>S: member and card
  end
  S-->>App: member with signed photo link, card PDF in base64
```

- The lock on the temple's row is what stops two requests getting the same
  number, and what makes a retry wait for the first attempt's result.
- A typed number skips the counter: it is used as it is, and the counter
  steps over it when it gets there.
- `members-update` takes the same lock. It prints a new card only when the
  name, the photo or the number changed. An edit may not take a held number.
- `members-preview` runs the same checks and the same renderer with no
  transaction and no writes.

## 8. Database schema

```mermaid
erDiagram
  temples ||--o{ temple_staff : "team, cascade delete"
  temples ||--o{ temple_features : "what its app shows, cascade delete"
  temples ||--o{ members : "has"
  members ||--o{ member_cards : "issued, cascade delete"
  users }o..o{ temple_staff : "same email, no FK"
  users |o..o{ members : "created_by is the uid, no FK"
  users |o..o{ member_cards : "issued_by is the uid, no FK"

  temples {
    text id PK "slug, lower case with hyphens"
    text name
    text description "default empty"
    text logo_key "file store key, null until uploaded"
    text time_zone "e.g. America/Toronto"
    text card_template "standard, or a designed one"
    text membership_term "fixed_year_end or rolling"
    smallint membership_year_end_month "1 to 12, for fixed_year_end"
    smallint membership_year_end_day "1 to 31, for fixed_year_end"
    smallint membership_months "for rolling"
    bigint member_number_next "next number to hand out"
    text member_number_prefix "e.g. JC-"
    smallint member_number_min_digits "zero padding"
    timestamptz created_at
  }

  users {
    text id PK "Firebase Auth uid"
    text email "lower case, not unique"
    text display_name
    timestamptz created_at
    timestamptz last_sign_in_at
  }

  temple_staff {
    text temple_id PK, FK
    text email PK "lower case"
    text role "admin, geshe, accountant, frontDesk, coordinator, volunteer, member"
    timestamptz added_at
  }

  temple_features {
    text temple_id PK, FK
    text feature PK "tab.members, home.addMember, ..."
  }

  members {
    uuid id PK "unique with temple_id too"
    text temple_id FK
    bigint number UK "unique per temple"
    text name
    text email "lower case, nullable"
    text phone "nullable, with country code"
    text photo_key "file store key"
    date joined_on
    date renewed_on
    date expires_on
    text created_by "Firebase uid"
    timestamptz created_at
    timestamptz updated_at
  }

  member_cards {
    uuid id PK "chosen by the app, the idempotency key"
    text temple_id FK "composite with member_id"
    uuid member_id FK
    text number "as printed, e.g. JC-0142"
    text name "as printed"
    date valid_from
    date valid_until
    text template
    text photo_key
    text pdf_key
    text issued_by "Firebase uid"
    timestamptz issued_at
  }

  schema_migrations {
    text name PK "migration file name"
    timestamptz applied_at
  }
```

### Keys, constraints and indexes

| Table | Constraint or index | Why |
| --- | --- | --- |
| `temples` | check on `id` format | Ids are URL-safe slugs. |
| `temples` | check: the columns each `membership_term` needs are set | The repository can trust them. |
| `users` | index `users_by_email (email)` | Email is not unique: a remade account has a new uid. |
| `temple_staff` | primary key `(temple_id, email)` | One role per person per temple. |
| `temple_staff` | index `temple_staff_by_email (email)` | Sign-in and access look up by email. |
| `temple_features` | primary key `(temple_id, feature)` | A tab or card is on once per temple. |
| `members` | unique `(temple_id, number)` | A number is held by one member of a temple. |
| `members` | unique `(temple_id, id)` | Target of the composite foreign key below. |
| `members` | index `members_by_name (temple_id, lower(name))` | Search by name. |
| `members` | index `members_by_expiry (temple_id, expires_on)` | Who is due. |
| `member_cards` | foreign key `(temple_id, member_id)` to `members (temple_id, id)` | A card can only point at a member of its own temple. |
| `member_cards` | index `member_cards_by_member (temple_id, member_id, issued_at desc)` | The card a member holds is their newest. |

### What the schema means

- **A temple is the tenant.** Every temple-owned table has `temple_id`, its
  indexes lead with it, and every query filters on it.
- **`members` is today, `member_cards` is history.** A member's row changes;
  a card row never does. A reprint or a changed name adds a card.
- **The card a member holds** is their row in `member_cards` with the latest
  `issued_at`. The code always inserts one with a new member.
- **`members.number` is digits only.** The prefix and padding on the `temples`
  row turn it into what is printed, which `member_cards.number` keeps.
- **`users` is a profile, not a permission.** Access comes from
  `temple_staff`, matched on email.
- **A row in `temple_features` means on.** No row, not shown. Home and More
  are always shown, so they have no names.
- Only `auth`, `temples` and `members` have tables so far. Offerings,
  volunteers, announcements and the rest are still fakes in the app.

## 9. Files in R2

```
temples/<temple id>/
  logo-<uuid>.png                         a new key each time it is replaced
  members/<member id>/cards/<card id>.jpg the photo on that card
  members/<member id>/cards/<card id>.pdf the card as printed, front then back
```

The database stores only these keys (`temples.logo_key`, `members.photo_key`,
`member_cards.photo_key`, `member_cards.pdf_key`).
