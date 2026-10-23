#[test_only]
module passport::passport_tests;

use passport::passport::{Self, AdminCap, HandlerCap, Lot, Registry};
use sui::clock;
use sui::test_scenario as ts;

const ARIKINA: address = @0xA;
const FORWARDER: address = @0xB;

fun s(b: vector<u8>): std::string::String { b.to_string() }

fun setup(): ts::Scenario {
    let mut sc = ts::begin(ARIKINA);
    passport::init_for_testing(sc.ctx());
    sc.next_tx(ARIKINA);
    let cap = sc.take_from_sender<AdminCap>();
    let clk = clock::create_for_testing(sc.ctx());
    passport::create_lot(&cap, s(b"SUN/O/26E189"), s(b"Organic Castor Oil"), s(b"Ricinus Communis (Castor) Seed Oil"),
        s(b"India"), s(b"Cold pressed"), s(b"2026-01"), s(b"2027-12"), vector[s(b"Organic")], &clk, sc.ctx());
    clk.destroy_for_testing();
    sc.return_to_sender(cap);
    sc
}

#[test]
fun admin_and_handler_write() {
    let mut sc = setup();
    sc.next_tx(ARIKINA);
    let cap = sc.take_from_sender<AdminCap>();
    let mut lot = sc.take_shared<Lot>();
    let clk = clock::create_for_testing(sc.ctx());
    passport::attach_document(&cap, &mut lot, s(b"COA"), s(b"abc123"), s(b"on request"), &clk);
    passport::admin_checkpoint(&cap, &mut lot, s(b"QC tested"), s(b"India"), s(b"COA issued"), &clk);
    passport::issue_handler(&cap, s(b"Forwarder Co"), s(b"freight"), FORWARDER, sc.ctx());
    assert!(passport::documents_len(&lot) == 1);
    assert!(passport::custody_len(&lot) == 1);
    ts::return_shared(lot);
    sc.return_to_sender(cap);
    clk.destroy_for_testing();

    sc.next_tx(FORWARDER);
    let hcap = sc.take_from_sender<HandlerCap>();
    let reg = sc.take_shared<Registry>();
    let mut lot = sc.take_shared<Lot>();
    let clk = clock::create_for_testing(sc.ctx());
    passport::handler_checkpoint(&hcap, &reg, &mut lot, s(b"Exported"), s(b"Mumbai"), s(b"BL 123"), &clk);
    assert!(passport::custody_len(&lot) == 2);
    ts::return_shared(lot);
    ts::return_shared(reg);
    sc.return_to_sender(hcap);
    clk.destroy_for_testing();
    sc.end();
}

#[test, expected_failure(abort_code = passport::EHandlerRevoked)]
fun revoked_handler_blocked() {
    let mut sc = setup();
    sc.next_tx(ARIKINA);
    let cap = sc.take_from_sender<AdminCap>();
    passport::issue_handler(&cap, s(b"Bad Actor"), s(b"freight"), FORWARDER, sc.ctx());
    sc.return_to_sender(cap);

    sc.next_tx(FORWARDER);
    let hcap = sc.take_from_sender<HandlerCap>();
    let hid = object::id(&hcap);
    sc.return_to_sender(hcap);

    sc.next_tx(ARIKINA);
    let cap = sc.take_from_sender<AdminCap>();
    let mut reg = sc.take_shared<Registry>();
    passport::revoke_handler(&cap, &mut reg, hid);
    ts::return_shared(reg);
    sc.return_to_sender(cap);

    sc.next_tx(FORWARDER);
    let hcap = sc.take_from_sender<HandlerCap>();
    let reg = sc.take_shared<Registry>();
    let mut lot = sc.take_shared<Lot>();
    let clk = clock::create_for_testing(sc.ctx());
    passport::handler_checkpoint(&hcap, &reg, &mut lot, s(b"Exported"), s(b"x"), s(b"x"), &clk);
    abort 0
}

#[test, expected_failure(abort_code = passport::EInvalidStatus)]
fun bad_status_rejected() {
    let mut sc = setup();
    sc.next_tx(ARIKINA);
    let cap = sc.take_from_sender<AdminCap>();
    let mut lot = sc.take_shared<Lot>();
    passport::set_status(&cap, &mut lot, 9);
    abort 0
}
