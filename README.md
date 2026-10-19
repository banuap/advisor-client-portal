# Advisor & Client Portal API

Ruby 3.3 / Rails 7.1 API starter for synthetic client onboarding, financial-goal
tracking and client service requests. It accepts
an external demo reference, display name, and risk profile; new clients always
start with onboarding status `pending`. It intentionally does not expose an
endpoint to approve KYC or enable trading.

## Run locally

```sh
bundle install
bin/rails db:prepare
bin/rails server
```

Check `GET /health`, list clients at `GET /api/v1/clients`, or create a
synthetic client:

```sh
curl -X POST http://localhost:3000/api/v1/clients \
  -H 'Content-Type: application/json' \
  -d '{"client":{"external_reference":"demo-client-001","display_name":"Synthetic Demo Client","risk_profile":"moderate"}}'
```

Run tests with `bin/rails test` (or `ruby bin/rails test` if the script is
not executable in your checkout).

For an existing checkout, run `bin/rails db:migrate` after updating to create
the financial-goal, contribution and service-request tables. Existing client
records and response shapes are unchanged. `db/schema.rb` is checked in for
repeatable schema loading.

## Capabilities

### Financial goals and contribution tracking

- Create, read, list, update and archive goals for a client. Categories:
  `retirement`, `education`, `emergency`, `major_purchase`, `other`.
- Supported currencies are `USD`, `EUR` and `GBP`. Amounts are **integer minor
  units** (cents/pence), from 1 through 1,000,000,000,000 inclusive. No exchange
  rates, currency conversion, returns or investment recommendations are implied.
- Targets must be future dates when created or changed. Goals whose dates
  subsequently pass can still be read, renamed or archived.
- Record positive, nonfuture-dated synthetic contributions. References must
  be unique within each goal; a repeated reference returns HTTP 422 without
  changing totals. Contribution currency is inherited from the goal and cannot
  be supplied independently.
- Goal details show contributed amount, remaining amount and progress percent.
  Overfunding is allowed; progress may exceed 100%, while remaining amount stops
  at zero. Goal lists return the stored fields, not computed progress.
- A goal's currency cannot change after a contribution exists. Archived goals
  reject new contributions; restoring a goal to `active` is supported.
- Contributions have no update/delete API. Goals have no delete API; archive
  instead. Database foreign keys, amount checks and a unique contribution
  reference index complement model validation. Goal updates and contribution
  creation serialize on the parent goal using database locking.

**Contributions are demo bookkeeping records, not deposits, transfers, payments
or evidence of a funded account.**

### Client service requests

- Create, list, read and update requests with subject, description, category
  and priority (`normal` or `high`).
- Categories: `financial_planning`, `profile_update`, `document_question`,
  `general`. Categories label requests; they do not perform a profile change,
  upload documents or grant financial permissions.
- New requests always start `open`. Allowed transitions:
  `open` to `in_progress` or `cancelled`; `in_progress` to `resolved` or
  `cancelled`. Resolved and cancelled statuses cannot be reopened.
- Resolution requires a nonblank `resolution_summary`; the server stamps
  `resolved_at`. No resolution summary is accepted for a nonresolved request.
  Descriptive fields and resolution wording can still be edited after closure;
  the original resolution timestamp is retained. This is not an audit trail.
- Creation ignores caller-supplied lifecycle fields. Neither creation nor
  update accepts `client_id` or `resolved_at`; these are server controlled.
  The lifecycle is validated inside a database row lock during updates.

### Client overview

`GET /api/v1/clients/:client_reference/overview` returns the client record,
active-goal count, target/contribution totals **separated by currency**, request
counts by status and an open-request count (`open` plus `in_progress`).
Archived goals and their contributions are excluded from overview totals.
No amounts are combined across currencies. Empty clients return zero counts
and empty totals. Responses explicitly label `synthetic_data_only: true`.

## API routes

In the paths below, `:client` is the client's **external reference**, not its
database ID. Goal and request IDs are database IDs returned from creation.

| Method | Path | Description |
| --- | --- | --- |
| GET | `/api/v1/clients` | Existing client list (array; unchanged) |
| POST | `/api/v1/clients` | Existing pending-onboarding client creation |
| GET | `/api/v1/clients/:client` | Existing client details |
| GET | `/api/v1/clients/:client/overview` | Synthetic client dashboard summary |
| GET, POST | `/api/v1/clients/:client/financial_goals` | List or create goals |
| GET, PATCH | `/api/v1/clients/:client/financial_goals/:goal` | Read progress or update/archive |
| GET, POST | `/api/v1/clients/:client/financial_goals/:goal/goal_contributions` | List or record contributions |
| GET, POST | `/api/v1/clients/:client/service_requests` | List or create requests |
| GET, PATCH | `/api/v1/clients/:client/service_requests/:request` | Read or update requests |

New list endpoints return `{ "items": [...], "pagination": { "page": 1,
"per_page": 25, "total": 0 } }`. They are ordered by ID, default to 25 records
and accept `page` (1-999999) and `per_page` (1-100). Request lists optionally
filter by `status`, for example `?status=open&per_page=10`. Invalid status
filters or pagination return HTTP 400. New create/update validation failures
return HTTP 422 with `{ "errors": { "field": ["message"] } }`; missing or
nonobject request envelopes return HTTP 400. Unknown clients/resources, including
resources addressed through a different client's path, return HTTP 404.

Resource scoping prevents accidental cross-client lookups **but is not
authorization**: without authentication, any caller can select any known client
reference. Do not expose this API to real customers or put real client data in it.

### Try a synthetic planning workflow

Create `demo-client-001` using the onboarding example above, then:

```sh
curl -X POST http://localhost:3000/api/v1/clients/demo-client-001/financial_goals \
  -H 'Content-Type: application/json' \
  -d '{"financial_goal":{"name":"Demo emergency reserve","category":"emergency","target_amount_cents":500000,"currency":"USD","target_date":"2030-12-31"}}'
```

Use a date later than today and substitute the returned goal ID for `GOAL_ID`:

```sh
curl -X POST http://localhost:3000/api/v1/clients/demo-client-001/financial_goals/GOAL_ID/goal_contributions \
  -H 'Content-Type: application/json' \
  -d '{"goal_contribution":{"external_reference":"demo-contribution-001","amount_cents":25000,"contributed_on":"2026-10-19"}}'

curl http://localhost:3000/api/v1/clients/demo-client-001/overview
```

Use a contribution date on or before today. To create and resolve a demo
service request:

```sh
curl -X POST http://localhost:3000/api/v1/clients/demo-client-001/service_requests \
  -H 'Content-Type: application/json' \
  -d '{"service_request":{"subject":"Discuss demo reserve","category":"financial_planning","priority":"normal","description":"Review synthetic goal progress."}}'

# Substitute the returned request ID for REQUEST_ID.
curl -X PATCH http://localhost:3000/api/v1/clients/demo-client-001/service_requests/REQUEST_ID \
  -H 'Content-Type: application/json' \
  -d '{"service_request":{"status":"in_progress"}}'

curl -X PATCH http://localhost:3000/api/v1/clients/demo-client-001/service_requests/REQUEST_ID \
  -H 'Content-Type: application/json' \
  -d '{"service_request":{"status":"resolved","resolution_summary":"Synthetic goal discussion completed."}}'
```

## Validation and safety boundary

The Rails suite covers field/amount/date constraints, progress calculations,
currency invariants, lifecycle transitions, duplicate contribution references,
client-scoped routes, pagination, overview totals and the existing onboarding
behavior. CI runs schema preparation and the tests on Ruby 3.3 with SQLite.
Production PostgreSQL behavior and concurrent multiworker load have not been
certified by this test suite.

The GitHub Actions **CodeQL** workflow scans Ruby on pushes to `main`, pull
requests targeting `main`, manual dispatch, and weekly. Review findings under
**Security → Code scanning** in GitHub.

The local default is SQLite; production expects PostgreSQL through
`DATABASE_URL`. This starter has no authentication, authorization, real KYC
integration, document storage, or client-data protection controls. Use only
synthetic data and do not deploy it for real customers.
