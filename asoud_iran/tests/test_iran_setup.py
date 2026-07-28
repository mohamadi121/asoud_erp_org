from asoud_iran.services.iran_setup import DEFAULT_ACCOUNTS, _detail_type_for_account


def test_general_coa_has_a_material_multi_level_baseline():
    codes = {row[0] for row in DEFAULT_ACCOUNTS}
    assert len(DEFAULT_ACCOUNTS) == 96
    assert len(codes) == len(DEFAULT_ACCOUNTS)
    assert {"111001", "112001", "211001", "410001", "510001"} <= codes


def test_detail_type_is_derived_from_account_semantics():
    assert _detail_type_for_account("Receivable", "Accounts Receivable") == "Customer"
    assert _detail_type_for_account("Payable", "Accounts Payable") == "Supplier"
    assert _detail_type_for_account("", "Employee Benefits Payable") == "Employee"
    assert _detail_type_for_account("Expense Account", "Rent Expense") == "Cost Center"
    assert _detail_type_for_account("", "Guarantee Deposits") == "Other"

