from __future__ import annotations


def boot_session(bootinfo) -> None:
    from asoud_core.api import accessible_contexts, active_context

    bootinfo.asoud_organization = {
        "accessible_contexts": accessible_contexts(),
        "active_context": active_context(),
    }
