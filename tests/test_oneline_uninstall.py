"""Guards on oneline-uninstall.sh.

These are pure filesystem behaviours, so they run offline and as an ordinary
user. The venv is faked with a pyvenv.cfg, which is the marker the script
itself requires before it will delete anything.
"""
import subprocess

from conftest import top_level_statements

SCRIPT = "oneline-uninstall.sh"


def fake_venv(root):
    """Minimal tree that satisfies the script's "is this really a venv" check."""
    venv = root / "venv-dx-compiler"
    (venv / "bin").mkdir(parents=True)
    (venv / "pyvenv.cfg").write_text("home = /usr/bin\n")
    (venv / "bin" / "dxcom").write_text("#!/bin/sh\n")
    (venv / "bin" / "dxcom").chmod(0o755)
    return venv


def test_syntax_is_valid_posix_sh(repo_root):
    assert subprocess.run(["sh", "-n", repo_root / SCRIPT]).returncode == 0


def test_nothing_executes_before_the_final_main_call(repo_root):
    stmts = top_level_statements(repo_root / SCRIPT)
    assert stmts[-1] == 'main "$@"'
    for s in stmts[:-1]:
        assert s == "set -eu" or "=" in s.split()[0], f"would run on a truncated download: {s}"


def test_reports_when_there_is_nothing_to_remove(run_script, tmp_path):
    r = run_script(SCRIPT, env={"DX_INSTALL_DIR": str(tmp_path / "absent"),
                                "DX_BIN_DIR": str(tmp_path / "bin")})
    assert r.returncode == 0
    assert "Nothing to remove" in r.stdout


def test_removes_the_venv_and_its_own_launcher(run_script, tmp_path):
    root = tmp_path / "root"; root.mkdir()
    venv = fake_venv(root)
    bindir = tmp_path / "bin"; bindir.mkdir()
    (bindir / "dxcom").symlink_to(venv / "bin" / "dxcom")

    r = run_script(SCRIPT, env={"DX_INSTALL_DIR": str(root), "DX_BIN_DIR": str(bindir)})

    assert r.returncode == 0
    assert not venv.exists()
    assert not (bindir / "dxcom").exists() and not (bindir / "dxcom").is_symlink()


def test_leaves_a_launcher_owned_by_another_install_alone(run_script, tmp_path):
    """Only a dxcom resolving into the venv being deleted may be removed."""
    root = tmp_path / "root"; root.mkdir()
    fake_venv(root)
    other = tmp_path / "other"; other.mkdir()
    (other / "dxcom").write_text("#!/bin/sh\n")
    bindir = tmp_path / "bin"; bindir.mkdir()
    (bindir / "dxcom").symlink_to(other / "dxcom")

    r = run_script(SCRIPT, env={"DX_INSTALL_DIR": str(root), "DX_BIN_DIR": str(bindir)})

    assert r.returncode == 0
    assert (bindir / "dxcom").is_symlink(), "a dxcom pointing elsewhere must survive"
    assert "leaving it alone" in r.stderr


def test_refuses_to_delete_a_directory_that_is_not_a_venv(run_script, tmp_path):
    """DX_INSTALL_DIR is caller-supplied and ends up in an rm -rf."""
    root = tmp_path / "root"
    victim = root / "venv-dx-compiler"
    victim.mkdir(parents=True)
    (victim / "important.txt").write_text("not a venv")

    r = run_script(SCRIPT, env={"DX_INSTALL_DIR": str(root), "DX_BIN_DIR": str(tmp_path / "bin")})

    assert r.returncode != 0
    assert "pyvenv.cfg" in r.stderr
    assert (victim / "important.txt").exists(), "must not delete a directory it cannot identify"
