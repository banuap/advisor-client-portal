# Advisor & Client Portal API

Ruby 3.3 / Rails 7.1 API starter for synthetic client onboarding. It accepts
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

The GitHub Actions **CodeQL** workflow scans Ruby on pushes to `main`, pull
requests targeting `main`, manual dispatch, and weekly. Review findings under
**Security → Code scanning** in GitHub.

The local default is SQLite; production expects PostgreSQL through
`DATABASE_URL`. This starter has no authentication, authorization, real KYC
integration, document storage, or client-data protection controls. Use only
synthetic data and do not deploy it for real customers.
