# Runs INSIDE the void container (see containers.sh): the Void-specific paths for real.
# Void has no /run/user, no XDG_RUNTIME_DIR and no systemd-run.
import importlib.util, os, shutil, stat, sys
spec = importlib.util.spec_from_file_location("dt", "/repo/src/quickshell/guide/display/display_txn.py")
dt = importlib.util.module_from_spec(spec); spec.loader.exec_module(dt)
print("systemd-run in PATH:", shutil.which("systemd-run"))
print("XDG_RUNTIME_DIR:", repr(os.environ.get("XDG_RUNTIME_DIR")))
rd = dt.runtime_dir()
print("runtime_dir:", rd, oct(stat.S_IMODE(os.lstat(rd).st_mode)), "owner ok:", os.lstat(rd).st_uid == os.getuid())
print("watcher backend:", dt.spawn_watcher("0" * 32))
print("env forwarded:", os.environ.get("SERPANTINUM_DISPLAY_RUNTIME"))
