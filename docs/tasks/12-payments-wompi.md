# 12 — Payments: Wompi (PAY) · Phase 5

Digital money on top of the LED spine. Commission-first (drivers settle their balance digitally) before customer checkout.

- [ ] **PAY-1 — Webhook infrastructure** *(deps: LED-3)*
  `POST /v1/webhooks/wompi`: signature verification (events secret checksum), idempotent + out-of-order-tolerant handling, every event appended to `payment_events`.
  *AC: replayed and shuffled sandbox events produce a single correct final state.*

- [ ] **PAY-2 — Wompi provider** *(deps: PAY-1)*
  `wompi.py` implementing the `PaymentProvider` protocol: create checkout (cards/PSE/Nequi), status query, sandbox + prod key sets per environment. App/web open the checkout URL in a webview/redirect.
  *AC: sandbox payment end to end — approved, declined, and PSE-pending paths.*

- [ ] **PAY-3 — Driver balance settlement via Wompi** *(deps: PAY-2, LED-2)*
  "Pay my balance" in the driver app → Wompi checkout (Nequi/PSE) for the commission owed → webhook settles the ledger and unblocks if capped.
  *AC: sandbox settlement reduces balance and restores dispatch eligibility automatically.*

- [ ] **PAY-4 — Customer digital fares (feature-flagged)** *(deps: PAY-2)*
  Optional card/PSE payment at delivery instead of cash; PSE-pending policy: job completes with payment `processing`, driver sees "payment in progress".
  *AC: flag off = cash-only unchanged; flag on = both paths write correct ledger entries (digital fare → platform owes driver net).*

- [ ] **PAY-5 — Reconciliation job** *(deps: PAY-2)*
  Nightly task diffing Wompi's transaction list against `payments`; mismatches alert (log/email).
  *AC: seeded mismatch is detected and reported.*
