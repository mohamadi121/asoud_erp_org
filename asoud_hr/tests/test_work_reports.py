from datetime import time, timedelta

from asoud_hr.services.work_reports import calculated_minutes, time_to_seconds


def test_time_values_support_frappe_timedelta_and_iso_text():
    assert time_to_seconds(timedelta(hours=8, minutes=15)) == 29700
    assert time_to_seconds(time(9, 30)) == 34200
    assert time_to_seconds("10:45:30") == 38730


def test_activity_duration_is_calculated_and_supports_midnight():
    assert calculated_minutes("08:00:00", "09:45:00") == 105
    assert calculated_minutes("23:30:00", "00:15:00") == 45
    assert calculated_minutes(None, "09:00:00") is None

