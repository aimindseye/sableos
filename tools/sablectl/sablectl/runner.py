from __future__ import annotations

import os
import subprocess
from pathlib import Path
from typing import Mapping, Sequence

from .types import CommandResult


class CommandError(RuntimeError):
    def __init__(self, result: CommandResult):
        self.result = result
        super().__init__(
            f"command failed rc={result.returncode}: {' '.join(result.cmd)}\n"
            f"{result.stderr.strip()}"
        )


class CommandRunner:
    """Small subprocess boundary with deterministic stdin isolation.

    stdin is always DEVNULL. This is deliberate: a child such as adb must never
    consume the caller's loop/input stream, which was the root cause of the R10R3
    one-of-five ART verification bug.
    """

    def __init__(self, *, dry_run: bool = False, verbose: bool = False, timeout: int = 60):
        self.dry_run = dry_run
        self.verbose = verbose
        self.timeout = timeout

    def run(
        self,
        cmd: Sequence[str],
        *,
        timeout: int | None = None,
        check: bool = False,
        cwd: str | Path | None = None,
        env: Mapping[str, str] | None = None,
    ) -> CommandResult:
        argv = [str(x) for x in cmd]
        if self.dry_run:
            return CommandResult(cmd=argv, returncode=0, stdout="[dry-run]\n")

        resolved_env = os.environ.copy()
        if env:
            resolved_env.update({str(k): str(v) for k, v in env.items()})

        try:
            cp = subprocess.run(
                argv,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=timeout if timeout is not None else self.timeout,
                cwd=str(cwd) if cwd is not None else None,
                env=resolved_env,
                check=False,
            )
            result = CommandResult(
                cmd=argv,
                returncode=cp.returncode,
                stdout=cp.stdout or "",
                stderr=cp.stderr or "",
            )
        except subprocess.TimeoutExpired as exc:
            result = CommandResult(
                cmd=argv,
                returncode=124,
                stdout=(exc.stdout or "") if isinstance(exc.stdout, str) else "",
                stderr=(exc.stderr or "") if isinstance(exc.stderr, str) else "",
                timed_out=True,
            )
        except FileNotFoundError:
            result = CommandResult(cmd=argv, returncode=127, stderr=f"not found: {argv[0]}\n")

        if check and result.returncode != 0:
            raise CommandError(result)
        return result
