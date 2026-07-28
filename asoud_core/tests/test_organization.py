from asoud_core.organization import (
    AccessGrant,
    OrganizationContext,
    can_access,
    resolve_accessible_contexts,
)


def context(company: str, branch: str | None = None, holding: str | None = None):
    return OrganizationContext(
        company=company,
        branch=branch,
        holding=holding,
        branch_name=branch,
    )


def test_company_wide_grant_allows_company_and_all_its_branches():
    grant = AccessGrant(company="A")
    assert can_access([grant], context("A"))
    assert can_access([grant], context("A", "A-01"))
    assert not can_access([grant], context("B"))


def test_branch_grant_does_not_expose_company_wide_or_other_branch_documents():
    grant = AccessGrant(company="A", branch="A-01")
    assert can_access([grant], context("A", "A-01"))
    assert not can_access([grant], context("A"))
    assert not can_access([grant], context("A", "A-02"))


def test_disabled_grant_does_not_allow_access():
    grant = AccessGrant(company="A", enabled=False)
    assert not can_access([grant], context("A"))


def test_holding_manager_can_access_all_companies_in_same_holding():
    grant = AccessGrant(company="A", holding="H", holding_manager=True)
    assert can_access([grant], context("B", holding="H"))
    assert can_access([grant], context("B", "B-01", holding="H"))
    assert not can_access([grant], context("C", holding="OTHER"))


def test_holding_manager_requires_a_real_holding():
    grant = AccessGrant(company="A", holding_manager=True)
    assert not can_access([grant], context("B"))


def test_privileged_user_can_access_without_grants():
    assert can_access([], context("A"), privileged=True)


def test_context_resolution_is_unique_and_company_root_precedes_branches():
    grant = AccessGrant(company="A")
    contexts = [context("A", "A-02"), context("A"), context("A", "A-01"), context("A")]
    assert resolve_accessible_contexts([grant], contexts) == [
        context("A"),
        context("A", "A-01"),
        context("A", "A-02"),
    ]
