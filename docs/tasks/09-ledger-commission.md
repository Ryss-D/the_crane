# 09 — Ledger & commission (LED) · Phase 1 (accrual) + 3 (screens/settlement)

The money spine. Built during the cash MVP so monetization works from day one and the Wompi switch is a settlement detail.

- [x] **LED-1 — Ledger + payments models, commission accrual** *(deps: JOB-2, JOB-3)*
  Tables: `payments` (provider cash|wompi, reference unique, status machine), `payment_events`, `driver_ledger` (gross, commission, net, type earning|payout|adjustment), `payouts`. On job `completed`: cash payment row + ledger debit computed from the job's **config snapshot** (percent or flat per vehicle type).
  *AC: completing a job writes payment + ledger exactly once (idempotent under retries); commission matches snapshot, not current config.*

- [x] **LED-2 — Balance service + offer gating** *(deps: LED-1, DSP-1)*
  Running balance per driver; if `balance_cap` (from config, nullable = disabled) exceeded, driver is excluded from dispatch and sees the blocked state (DRV-1).
  *AC: crossing the cap removes the driver from the geo search; settling restores them.*

- [ ] **LED-3 — Cash payment provider** *(deps: LED-1)*
  First implementation of the `PaymentProvider` protocol (`base.py` + `cash.py`): create intent = pending cash payment; driver confirmation settles it.
  *AC: protocol interface covers create_intent / get_status / refund / parse_webhook so Wompi (PAY-2) slots in without API changes.*
  Status: the cash side effect (accrual on completion) exists inline in `app/services/jobs.py`, but the formal `PaymentProvider` protocol abstraction isn't extracted yet — needed before PAY-2 (Wompi) lands so it slots in without an API change.

- [x] **LED-4 — Manual settlement recording** *(deps: LED-1)*
  `POST /v1/admin/ledger/{driver_id}/settle` — record a balance payment or adjustment with note; feeds ADM-6.
  *AC: settlement zeroes/reduces balance; adjustment audit-trailed.*
