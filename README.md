# Arikina Lot Passport (Sui)

Each ingredient lot is a shared `Lot` object on Sui. It carries the lot's specs and certifications, the SHA-256 fingerprints of its documents (COA, organic TC), and a chain-of-custody log that can only be appended to. Arikina writes with an `AdminCap`. Partners such as a processor, forwarder or warehouse write with a `HandlerCap`, which Arikina issues and can revoke. Anyone can read a lot and verify it.

- Contract: `passport/sources/passport.move` (tests: `sui move test`, 3 passing)
- Deployment IDs: `deployment.json` (testnet)
- Public page: `python build_page.py [LOT_ID]` writes `web/lot-passport.html`. The page shows a snapshot, refreshes from the chain when it is hosted normally, and checks a dropped COA file against the on-chain hash.
- Sui CLI: `C:\Users\cmaha\tools\sui\sui.exe` (testnet wallet in `%USERPROFILE%\.sui`)

## Add a lot / step
```
sui client call --package $PKG --module passport --function create_lot --args $CAP "<lot>" "<product>" "<INCI>" "India" "Cold pressed" "2026-01" "2027-12" '["Certified Organic"]' 0x6
sui client call --package $PKG --module passport --function attach_document --args $CAP $LOT "COA" "<sha256>" "Available on request" 0x6
sui client call --package $PKG --module passport --function admin_checkpoint --args $CAP $LOT "Exported" "Mumbai" "<note>" 0x6
sui client call --package $PKG --module passport --function issue_handler --args $CAP "<partner>" "freight" <their address>
```
