from asoud_core.services.audit import GENESIS_HASH, canonical_event_payload, event_hash


def test_audit_hash_is_deterministic_and_chained():
    first = {"action": "create", "actor": "user@example.test", "amount": 10}
    second = {"action": "submit", "actor": "user@example.test", "amount": 10}
    head = event_hash(GENESIS_HASH, first)
    assert head == event_hash(GENESIS_HASH, first)
    assert event_hash(head, second) != event_hash(GENESIS_HASH, second)


def test_audit_payload_has_stable_key_order_and_unicode():
    assert canonical_event_payload({"ب": 2, "الف": 1}) == '{"الف":1,"ب":2}'
