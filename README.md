# Arikina Lot Passport (Sui)

A tamper-evident "passport" for each natural ingredient lot Arikina sources, recorded on the [Sui](https://sui.io) blockchain. Buyers can check where a lot came from, who has handled it, and whether the COA they received matches the one recorded at origin. They don't need a login or a blockchain wallet.

## Why

Ingredient buyers rely on paperwork (COAs, organic transaction certificates, shipping records) that is easy to lose, swap or alter between farm and factory. The passport keeps that record in one public place that can only be appended to:

- **Specs and certifications** for the lot: product, INCI name, origin, process, production and expiry dates
- **Document fingerprints**: SHA-256 hashes of the COA and organic certificate. The documents stay private; only the fingerprint is public.
- **Chain of custody**: each handoff (exported, in transit, warehoused) with stage, location, timestamp and who recorded it
- **Status**: Active, Hold, Recalled or Depleted

## How it works

| Piece | Role |
|---|---|
| `Lot` (shared object) | One per lot. Anyone can read it. |
| `AdminCap` | Held by Arikina. Creates lots, attaches documents, sets status, issues and revokes partner access. |
| `HandlerCap` | Issued by Arikina to a partner (processor, freight forwarder, warehouse). Lets them add custody checkpoints, and can be revoked at any time. |
| `Registry` | Tracks revoked handler caps. |
| Events | `LotCreated`, `DocumentAttached`, `CheckpointAdded`, `StatusChanged`, `HandlerIssued` for indexing and alerts |

The **verification page** (`web/`) shows a lot's passport and refreshes live from the chain when hosted. A buyer can drop their COA file on the page, and the page hashes it in the browser and tells them whether it matches the on-chain fingerprint. The file is never uploaded.

## Repository layout

```
passport/
  sources/passport.move     Move smart contract
  tests/passport_tests.move unit tests
build_page.py               builds the verification page from live chain data
web/template.html           page template
web/lot-passport.html       generated page (sample: castor oil lot)
deployment.json             testnet package and object IDs
```

## Setup

Requires the [Sui CLI](https://docs.sui.io/guides/developer/getting-started/sui-install) and Python 3.9+ (standard library only).

```bash
cd passport
sui move build
sui move test          # 3 tests: admin/handler writes, revoked handler blocked, invalid status rejected
```

## Usage

**Build the verification page** for the sample lot, or any lot ID:

```bash
python build_page.py                      # uses castor_lot from deployment.json
python build_page.py <LOT_ID> out.html
```

**Write to the chain.** Set `PKG`, `CAP` (AdminCap) and `LOT` from `deployment.json`:

```bash
# Create a lot
sui client call --package $PKG --module passport --function create_lot \
  --args $CAP "<lot code>" "<product>" "<INCI>" "India" "Cold pressed" "2026-01" "2027-12" '["Certified Organic"]' 0x6

# Attach a document fingerprint
sui client call --package $PKG --module passport --function attach_document \
  --args $CAP $LOT "COA" "<sha256>" "Available on request" 0x6

# Record a custody step
sui client call --package $PKG --module passport --function admin_checkpoint \
  --args $CAP $LOT "Exported" "Mumbai" "<note>" 0x6

# Give a partner write access
sui client call --package $PKG --module passport --function issue_handler \
  --args $CAP "<partner name>" "freight" <partner address>
```

To get a document's fingerprint: `sha256sum coa.pdf` (macOS/Linux) or `certutil -hashfile coa.pdf SHA256` (Windows).

## Status

**Prototype, deployed on Sui testnet.** One sample lot (castor oil) is live. See `deployment.json` for IDs.

**Next steps**
- Hosted verification page with a QR code printed on drums and bags
- Partner onboarding flow for issuing handler caps
- Mainnet deployment
