from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class OrganizationContext:
    company: str
    branch: str | None = None
    holding: str | None = None
    branch_name: str | None = None


@dataclass(frozen=True, slots=True)
class AccessGrant:
    company: str
    branch: str | None = None
    holding: str | None = None
    holding_manager: bool = False
    enabled: bool = True


def can_access(
    grants: list[AccessGrant],
    context: OrganizationContext,
    *,
    privileged: bool = False,
) -> bool:
    if privileged:
        return True

    for grant in grants:
        if not grant.enabled:
            continue
        if grant.holding_manager and grant.holding and grant.holding == context.holding:
            return True
        if grant.company != context.company:
            continue
        if not grant.branch or grant.branch == context.branch:
            return True
    return False


def resolve_accessible_contexts(
    grants: list[AccessGrant],
    contexts: list[OrganizationContext],
    *,
    privileged: bool = False,
) -> list[OrganizationContext]:
    allowed = [
        context
        for context in contexts
        if can_access(grants, context, privileged=privileged)
    ]
    return sorted(
        set(allowed),
        key=lambda item: (
            item.company.casefold(),
            item.branch is not None,
            (item.branch_name or item.branch or "").casefold(),
        ),
    )
