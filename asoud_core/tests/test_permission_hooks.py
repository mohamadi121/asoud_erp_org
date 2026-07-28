from types import SimpleNamespace

from asoud_core import permissions


class DocumentStub(dict):
    company = "A"
    name = "A-01"


def install_frappe_stub(monkeypatch):
    monkeypatch.setitem(
        __import__("sys").modules,
        "frappe",
        SimpleNamespace(session=SimpleNamespace(user="user@example.com")),
    )


def test_standard_permission_does_not_override_erpnext_role_permission(monkeypatch):
    install_frappe_stub(monkeypatch)
    monkeypatch.setattr(permissions, "can_access_context", lambda *args: True)
    assert permissions.standard_document_permission(DocumentStub()) is None


def test_standard_permission_explicitly_denies_out_of_scope_document(monkeypatch):
    install_frappe_stub(monkeypatch)
    monkeypatch.setattr(permissions, "can_access_context", lambda *args: False)
    assert permissions.standard_document_permission(DocumentStub()) is False


def test_branch_permission_keeps_standard_role_check_for_allowed_branch(monkeypatch):
    install_frappe_stub(monkeypatch)
    monkeypatch.setattr(permissions, "_is_privileged", lambda user: False)
    monkeypatch.setattr(permissions, "can_access_context", lambda *args: True)
    assert permissions.branch_permission(DocumentStub()) is None
