"""Guards on oneline-install.sh that must hold without network or root."""
import subprocess

import pytest

from conftest import top_level_statements

SCRIPT = "oneline-install.sh"


def test_syntax_is_valid_posix_sh(repo_root):
    assert subprocess.run(["sh", "-n", repo_root / SCRIPT]).returncode == 0


def test_runs_under_plain_sh(repo_root):
    assert (repo_root / SCRIPT).read_text().startswith("#!/bin/sh\n")


def test_aborts_on_error_and_unset(repo_root):
    assert "set -eu" in (repo_root / SCRIPT).read_text()


def test_nothing_executes_before_the_final_main_call(repo_root):
    """A truncated `curl | sh` download must not half-apply.

    Everything the script does lives in main(), which is called on the last
    line, so a cut-off transfer either fails to parse or simply never calls it.
    """
    stmts = top_level_statements(repo_root / SCRIPT)
    assert stmts[-1] == 'main "$@"'
    for s in stmts[:-1]:
        assert s == "set -eu" or "=" in s.split()[0], f"top-level statement would run on a truncated download: {s}"


@pytest.mark.parametrize("value", [
    "../../../evil-org/evil-repo",   # traversal: curl normalises dot-segments client-side
    "/etc/passwd",                   # absolute path
    "1.0;rm -rf /",                  # shell metacharacters
    "1.0 --index-url=http://evil",   # injected pip flag
    "1.0#egg=evil",                  # pip requirement-string confusion
])
def test_rejects_unsafe_dx_version(run_script, value):
    """DX_VERSION reaches a pip requirement string, so it is validated first."""
    r = run_script(SCRIPT, env={"DX_VERSION": value})
    assert r.returncode != 0
    assert "invalid DX_VERSION" in r.stderr


def test_requires_debian_or_ubuntu(run_script):
    r = run_script(SCRIPT, hide=["apt-get"])
    assert r.returncode != 0
    assert "Debian/Ubuntu" in r.stderr


def test_tells_an_unprivileged_user_which_packages_to_install(run_script, stub_bin):
    """Without root the run stops before the venv, naming the apt-get command.

    `id` is stubbed so this holds even when the suite runs as root in CI.
    """
    stub_bin("id", 'echo 1000')
    r = run_script(SCRIPT, hide=["sudo"])
    assert r.returncode != 0
    assert "need root" in r.stderr
    assert "libgl1-mesa-dev" in r.stderr and "libglib2.0-0" in r.stderr
