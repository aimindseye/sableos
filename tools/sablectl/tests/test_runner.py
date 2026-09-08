import subprocess
from unittest.mock import patch

from sablectl.runner import CommandRunner


def test_runner_isolates_child_stdin():
    captured = {}

    def fake_run(*args, **kwargs):
        captured.update(kwargs)
        return subprocess.CompletedProcess(args[0], 0, stdout="ok\n", stderr="")

    with patch("subprocess.run", fake_run):
        result = CommandRunner().run(["adb", "devices"])

    assert result.returncode == 0
    assert captured["stdin"] is subprocess.DEVNULL
