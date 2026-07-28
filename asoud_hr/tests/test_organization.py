from datetime import date

from asoud_hr.services.organization import date_ranges_overlap


def test_assignment_ranges_detect_open_and_closed_overlaps():
    assert date_ranges_overlap(
        date(2026, 1, 1),
        None,
        date(2026, 7, 1),
        date(2026, 8, 1),
    )
    assert date_ranges_overlap(
        date(2026, 1, 1),
        date(2026, 3, 1),
        date(2026, 3, 1),
        date(2026, 4, 1),
    )
    assert not date_ranges_overlap(
        date(2026, 1, 1),
        date(2026, 2, 1),
        date(2026, 2, 2),
        date(2026, 3, 1),
    )

