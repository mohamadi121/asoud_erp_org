from asoud_core.services.dashboard import percentage_change


def test_percentage_change_handles_regular_growth_and_decline():
    assert percentage_change(125, 100) == 25.0
    assert percentage_change(75, 100) == -25.0


def test_percentage_change_handles_zero_baseline_without_division_error():
    assert percentage_change(0, 0) == 0.0
    assert percentage_change(10, 0) == 100.0


def test_percentage_change_uses_absolute_baseline():
    assert percentage_change(-50, -100) == 50.0
