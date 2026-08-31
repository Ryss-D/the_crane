# 12 — Payments: Wompi (PAY) · Phase 5

Digital money on top of the LED spine. Commission-first (drivers settle their balance digitally) before customer checkout.

> **Status (2026-08-30):** all five sub-tasks below have real, tested backend code now — see each entry's own note. **No Wompi sandbox account exists yet** (a 5th external secret set, `WOMPI_PUBLIC_KEY`/`WOMPI_PRIVATE_KEY`/`WOMPI_EVENTS_KEY`, distinct from the 4 Google Maps keys tracked in `01-foundations.md`'s FND-6 note), so every path here is exercised against mocked HTTP responses matching Wompi's documented shapes, never a real sandbox call. None of the boxes below are checked for that reason — a real signature algorithm implemented from documentation, and a real transaction-creation payload shape, both still need one live pass to actually confirm. PAY-4's Flutter/web-client/admin UI is explicitly **not built** — this pass is backend-only, by design (see PAY-4's own note).

- [ ] **PAY-1 — Webhook infrastructure** *(deps: LED-3)*
  `POST /v1/webhooks/wompi`: signature verification (events secret checksum), idempotent + out-of-order-tolerant handling, every event appended to `payment_events`.
  *AC: replayed and shuffled sandbox events produce a single correct final state.*
  Built: `app/api/payments.py`'s `wompi_webhook` — verifies Wompi's real events-signature scheme
  (`app/services/payments/wompi.py`'s `verify_event_signature`: SHA-256 over the ordered
  `signature.properties` values pulled from `data`, plus `timestamp`, plus the events secret;
  implemented from Wompi's public docs, not guessed, but never checked against a real payload).
  `payment_events` gained a `dedup_key` column (migration `0010`, `payment_id` + `dedup_key`
  unique together) — a replay of the exact same `(transaction.id, transaction.status)` pair
  inserts nothing and changes nothing twice. Out-of-order tolerance via `is_stale_status`: a
  payment's status can only move forward through pending → processing → a terminal status
  (approved/declined/expired all rank equal — once terminal, nothing moves it again); a stale
  event is acked 2xx but applied nowhere. An unknown `reference` also acks 2xx (nothing local to
  apply to) rather than erroring — only a bad/missing signature 401s, so Wompi only ever retries
  on the one failure that's actually ours to fix. 13 new tests (`tests/test_payments_wompi.py`):
  signature accept/tamper/wrong-key/malformed, replay, out-of-order, unknown reference, plus the
  two ledger-writing paths below. Full backend suite green (335 passed, up from 305).

- [ ] **PAY-2 — Wompi provider** *(deps: PAY-1)*
  `wompi.py` implementing the `PaymentProvider` protocol: create checkout (cards/PSE/Nequi), status query, sandbox + prod key sets per environment. App/web open the checkout URL in a webview/redirect.
  *AC: sandbox payment end to end — approved, declined, and PSE-pending paths.*
  Built: `WompiGateway` (`app/services/payments/wompi.py`) implements the exact same
  `PaymentGateway` protocol `CashGateway` does (`create_intent`/`get_status`/`refund`/
  `parse_webhook`), plus a shared `create_checkout` both PAY-3 and PAY-4 call into. Follows
  Wompi's real documented flow: fetch a merchant acceptance token
  (`GET /merchants/{public_key}`), then `POST /transactions` with it. No key configured ->
  `WompiNotConfiguredError`, mapped to a 503 at the API layer everywhere it's used — same
  graceful-degradation discipline `GoogleDirectionsClient` already established (`pricing.py`).
  `sandbox`/`prod` base URLs picked from `WOMPI_ENV`. Not built/verified: an actual sandbox
  payment end to end (needs the account), and card's real client-side tokenization flow (this
  backend only ever creates the transaction *after* a client already tokenized with the public
  key — there's no server-side card-number handling here, deliberately).

- [ ] **PAY-3 — Driver balance settlement via Wompi** *(deps: PAY-2, LED-2)*
  "Pay my balance" in the driver app → Wompi checkout (Nequi/PSE) for the commission owed → webhook settles the ledger and unblocks if capped.
  *AC: sandbox settlement reduces balance and restores dispatch eligibility automatically.*
  Built: `POST /v1/drivers/me/settle` (`app/api/drivers.py`) — validates the requested amount
  against `driver_owed_balance` (422 over, 409 if nothing owed), then a Wompi checkout under
  reference `settlement_{driver_id}_{random}`. The `payments.job_id` column had to become
  nullable for this (migration `0011`) — it was `NOT NULL`, but a settlement payment isn't for
  any one job; a real, previously-latent schema gap this surfaced. The webhook
  (`app/api/payments.py`) recognizes a `settlement_` reference on approval and writes the same
  `payout` `driver_ledger` row shape `settle_driver`/`settle_fleet` already write
  (`app/api/admin.py`) — there's no separate "capped" flag to clear anywhere; DSP-1's balance-cap
  gate just re-evaluates `owed >= balance_cap` fresh on the next `PATCH /me/status`, so a settled
  balance un-caps a driver automatically, by construction. Not built: the Flutter/web driver-app
  UI for this button — backend-only, matching this pass's scope everywhere. Not verified: a real
  sandbox settlement.

- [ ] **PAY-4 — Customer digital fares (feature-flagged)** *(deps: PAY-2)*
  Optional card/PSE payment at delivery instead of cash; PSE-pending policy: job completes with payment `processing`, driver sees "payment in progress".
  *AC: flag off = cash-only unchanged; flag on = both paths write correct ledger entries (digital fare → platform owes driver net).*
  Built, backend-only (no Flutter/web-client/admin UI — a real, deliberate scope cut, not an
  oversight): the flag lives in `platform_config` under a new `"payments"` key
  (`{"digital_fares_enabled": false}` by default, `scripts/seed.py`/`tests/conftest.py`'s
  `TEST_CONFIG`), read the same way every other runtime-configurable value already is
  (`app/services/config.py`'s `get_config`). `POST /v1/jobs/{id}/confirm-delivery` gained an
  optional body (`ConfirmDeliveryRequest.payment_method`) — omitted or `cash` behaves exactly as
  before (LED-1's existing cash path, completely unchanged); a non-cash method while the flag is
  off is a 422, not a silent fallback to cash, since a caller sending it clearly expects the
  digital path. With the flag on, the job still transitions to `completed` immediately (the AC's
  "job completes with payment processing") but **no ledger entry is written yet** —
  `_accrue_completion` (`app/services/jobs.py`) now only writes one when the payment comes back
  already `approved` (true for cash, which settles synchronously; never true for a fresh Wompi
  checkout). The entry is deferred to the webhook, once Wompi actually reports `approved`
  (`apply_ledger_for_settled_payment`, extracted from the old accrual code so both paths share
  it). "Platform owes driver net" is encoded as a **negative** `commission` on the same
  `earning` row cash uses (positive there) — `driver_owed_balance`'s existing formula
  (`sum(earning.commission) - sum(payout/adjustment.net)`) then naturally nets it against
  whatever the driver already owes, no schema change or new balance formula needed. Verified
  against mocks: flag-off rejection, flag-on job completes with the payment left `pending` and
  zero ledger rows, and the sign convention itself. Not built or verified beyond that: any
  client UI to actually choose a digital method, and a real sandbox PSE-pending run.

  Follow-up (2026-08-31): the Flutter customer-facing checkout UI is built now.

  Real backend gap found and fixed first: `WompiGateway.create_intent`'s
  `PaymentGateway`-protocol return shape (`tuple[Payment, bool]`, shared with
  `CashGateway`, which has no checkout URL to give) had no room for the
  checkout's `async_payment_url` — it was silently discarded before ever
  reaching `confirm_delivery_endpoint`'s response. A customer choosing PSE/card
  had a "successful" confirmation with no URL to actually pay at. Fixed via a
  transient `job.pending_payment_url` attribute (set on the in-memory `job`
  instance by `WompiGateway.create_intent`, not a persisted column — see its
  doc comment) read back into a new `JobRead.async_payment_url` field by
  `_job_read`. Null for cash, for Nequi (no redirect step), and on a re-fetch
  of the same job later — only the exact response that just started a
  PSE/card checkout carries it. 1 new backend test
  (`test_confirm_delivery_with_pse_surfaces_the_redirect_url`, including that
  a follow-up `GET` doesn't resurrect a stale URL); full backend suite green
  (338 passed, up from 337).

  Also confirmed there is genuinely no public/customer-readable endpoint for
  `payments.digital_fares_enabled` — only admin routes can read
  `platform_config`. The customer app has no way to know ahead of time
  whether the flag is on, so the digital-payment option is shown
  unconditionally and a disabled flag surfaces as the 422 this task's AC
  already specifies, handled gracefully with a clear message rather than
  predicted client-side. Flagging this as a real, intentional trade-off, not
  an oversight — a public config-read endpoint is a separate, larger design
  question (what else, if anything, should `platform_config` expose
  publicly?) out of scope to decide unilaterally here.

  Built (Flutter): `JobsRepository.confirmDelivery` gained an optional
  `paymentMethod` parameter (real dio body + fake, both matching the backend
  exactly — `FakeJobsRepository` gained a settable `digitalFaresEnabled` test
  flag mirroring the real config flag, plus realistic fake checkout URLs and
  the same "null commission until the ledger entry lands" semantics as the
  real backend). `RequestBloc`'s `RequestDeliveryConfirmed` event gained the
  same optional field, and a new `confirmDeliveryErrorMessage` carries the
  backend's typed rejection detail (`JobStatusRejectedException`) rather than
  just a bare failure boolean, mirroring `ActiveJobCubit`'s existing
  advance()/cancel() error-surfacing convention. `MatchingScreen`'s CUS-5
  section gained a "pagar con tarjeta, PSE o Nequi" button alongside (not
  replacing) the existing cash-confirm button, opening a payment-method
  picker dialog (`RadioGroup`, not the deprecated per-`RadioListTile`
  `groupValue`/`onChanged` API — this Flutter SDK flags that as deprecated as
  of 3.32); a `BlocListener` launches the checkout redirect the instant one
  appears on the active job.

  Tests: 3 new `RequestBloc` tests (PSE success surfaces the URL with null
  commission, Nequi success with no URL, flag-off rejection surfaces the
  message) and 2 new widget tests (full PSE flow through the dialog to a
  launched redirect, using the same `_FakeUrlLauncher` the call-driver button
  test already established; the flag-off rejection shows the localized
  inline error and stays on the delivered state). Full suite green (all
  customer-feature tests passing; ran scoped to avoid cross-talk with other
  concurrent work in this session rather than the full repo suite).

  Still not built: web-client/admin checkout UI (PAY-4's Flutter half only,
  per this task's original scope note). Still not verified: a real sandbox
  PSE-pending run, or any live pass against a real Wompi account — none
  exists yet.

- [ ] **PAY-5 — Reconciliation job** *(deps: PAY-2)*
  Nightly task diffing Wompi's transaction list against `payments`; mismatches alert (log/email).
  *AC: seeded mismatch is detected and reported.*
  Built: `backend/scripts/reconcile_wompi.py` (`uv run python scripts/reconcile_wompi.py
  [--hours N]`) — per-transaction, not a bulk list: Wompi's public merchant API doesn't
  document a reliable bulk-transaction-listing endpoint for third-party integrations (that's a
  dashboard-only view), so this instead re-checks each locally-known Wompi payment's own status
  endpoint (`WompiGateway.get_status`, already built for PAY-2) — every non-terminal payment,
  plus any terminal one from within the lookback window (catching a webhook that silently never
  arrived, the one failure idempotent webhook handling can't self-heal). Logs and exits 1 on any
  mismatch, 0 otherwise, so a cron/CI wrapper can alert on a non-zero exit. No key configured ->
  logs a warning and reports nothing, same graceful-degradation stance as everywhere else in
  this file. 3 new tests: a seeded mismatch is detected and reported, agreement reports nothing,
  no key configured is a no-op. Not built: an actual nightly schedule/cron entry to run it (no
  scheduler exists yet in this repo — OPS territory) — the script itself is the deliverable
  here, wiring it to run automatically is a separate, small follow-up.
