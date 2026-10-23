/// Arikina Lot Passport
///
/// Each ingredient lot becomes a shared, publicly readable `Lot` object carrying its
/// specs, certifications, document fingerprints (SHA-256 of COA / organic TC) and an
/// append-only chain-of-custody log. Only Arikina (AdminCap) or partners holding a
/// HandlerCap issued by Arikina can write to it; anyone can read and verify it.
module passport::passport;

use std::string::String;
use sui::clock::Clock;
use sui::event;

// ----- status codes -----
const STATUS_ACTIVE: u8 = 0;
const STATUS_HOLD: u8 = 1;
const STATUS_RECALLED: u8 = 2;
const STATUS_DEPLETED: u8 = 3;

// ----- errors -----
const EInvalidStatus: u64 = 1;
const EHandlerRevoked: u64 = 2;
const ELotClosed: u64 = 3;

/// Held by Arikina. Creates lots, issues handler caps, attaches documents, sets status.
public struct AdminCap has key, store { id: UID }

/// Issued to a supply-chain partner (processor, freight forwarder, warehouse).
/// Lets them append custody checkpoints to any lot. Arikina can revoke it at any
/// time by adding its ID to the shared Registry (`revoke_handler`).
public struct HandlerCap has key, store {
    id: UID,
    handler: String,
    role: String,
}

/// Shared list of revoked handler caps (checked on every checkpoint write).
public struct Registry has key {
    id: UID,
    revoked: vector<ID>,
}

public struct Document has copy, drop, store {
    kind: String, // "COA", "Organic TC", "SDS", "Spec sheet"
    sha256: String, // hex fingerprint of the exact file - anyone holding the file can verify it
    uri: String, // where to obtain it (may be "on request")
    added_ms: u64,
}

public struct Checkpoint has copy, drop, store {
    stage: String, // "Pressed", "QC tested", "Exported", "Received", ...
    location: String,
    handler: String,
    note: String,
    recorded_ms: u64,
}

public struct Lot has key {
    id: UID,
    lot_code: String,
    product: String,
    inci: String,
    origin: String,
    process: String,
    mfg: String,
    exp: String,
    certifications: vector<String>,
    documents: vector<Document>,
    custody: vector<Checkpoint>,
    status: u8,
    created_ms: u64,
}

// ----- events (indexable history) -----
public struct LotCreated has copy, drop { lot_id: ID, lot_code: String, product: String }
public struct CheckpointAdded has copy, drop { lot_id: ID, stage: String, handler: String }
public struct DocumentAttached has copy, drop { lot_id: ID, kind: String, sha256: String }
public struct StatusChanged has copy, drop { lot_id: ID, status: u8 }
public struct HandlerIssued has copy, drop { cap_id: ID, handler: String, role: String, recipient: address }

fun init(ctx: &mut TxContext) {
    transfer::transfer(AdminCap { id: object::new(ctx) }, ctx.sender());
    transfer::share_object(Registry { id: object::new(ctx), revoked: vector[] });
}

// ----- admin -----

public fun create_lot(
    _: &AdminCap,
    lot_code: String,
    product: String,
    inci: String,
    origin: String,
    process: String,
    mfg: String,
    exp: String,
    certifications: vector<String>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let lot = Lot {
        id: object::new(ctx),
        lot_code,
        product,
        inci,
        origin,
        process,
        mfg,
        exp,
        certifications,
        documents: vector[],
        custody: vector[],
        status: STATUS_ACTIVE,
        created_ms: clock.timestamp_ms(),
    };
    event::emit(LotCreated { lot_id: object::id(&lot), lot_code: lot.lot_code, product: lot.product });
    transfer::share_object(lot);
}

public fun attach_document(
    _: &AdminCap,
    lot: &mut Lot,
    kind: String,
    sha256: String,
    uri: String,
    clock: &Clock,
) {
    lot.documents.push_back(Document { kind, sha256, uri, added_ms: clock.timestamp_ms() });
    event::emit(DocumentAttached { lot_id: object::id(lot), kind, sha256 });
}

public fun admin_checkpoint(
    _: &AdminCap,
    lot: &mut Lot,
    stage: String,
    location: String,
    note: String,
    clock: &Clock,
) {
    add_checkpoint(lot, stage, location, b"Arikina".to_string(), note, clock);
}

public fun set_status(_: &AdminCap, lot: &mut Lot, status: u8) {
    assert!(status <= STATUS_DEPLETED, EInvalidStatus);
    lot.status = status;
    event::emit(StatusChanged { lot_id: object::id(lot), status });
}

public fun issue_handler(
    _: &AdminCap,
    handler: String,
    role: String,
    recipient: address,
    ctx: &mut TxContext,
) {
    let cap = HandlerCap { id: object::new(ctx), handler, role };
    event::emit(HandlerIssued { cap_id: object::id(&cap), handler, role, recipient });
    transfer::transfer(cap, recipient);
}

public fun revoke_handler(_: &AdminCap, registry: &mut Registry, cap_id: ID) {
    if (!registry.revoked.contains(&cap_id)) registry.revoked.push_back(cap_id);
}

// ----- partners -----

public fun handler_checkpoint(
    cap: &HandlerCap,
    registry: &Registry,
    lot: &mut Lot,
    stage: String,
    location: String,
    note: String,
    clock: &Clock,
) {
    assert!(!registry.revoked.contains(&object::id(cap)), EHandlerRevoked);
    add_checkpoint(lot, stage, location, cap.handler, note, clock);
}

fun add_checkpoint(lot: &mut Lot, stage: String, location: String, handler: String, note: String, clock: &Clock) {
    assert!(lot.status != STATUS_RECALLED && lot.status != STATUS_DEPLETED, ELotClosed);
    lot.custody.push_back(Checkpoint { stage, location, handler, note, recorded_ms: clock.timestamp_ms() });
    event::emit(CheckpointAdded { lot_id: object::id(lot), stage, handler });
}

// ----- reads -----
public fun lot_code(lot: &Lot): String { lot.lot_code }
public fun status(lot: &Lot): u8 { lot.status }
public fun custody_len(lot: &Lot): u64 { lot.custody.length() }
public fun documents_len(lot: &Lot): u64 { lot.documents.length() }

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) { init(ctx) }

#[test_only]
public fun status_hold(): u8 { STATUS_HOLD }
