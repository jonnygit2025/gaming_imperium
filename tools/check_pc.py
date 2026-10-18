"""Verifica le risorse del PC e dice quali impostazioni del gioco usare.

Uso:  python tools/check_pc.py
Funziona anche senza librerie extra (psutil e pygame sono opzionali).
"""
import os
import platform
import shutil
import subprocess
import sys


def ram_gb():
    try:
        import psutil
        return psutil.virtual_memory().total / 1024**3
    except ImportError:
        pass
    if sys.platform == "win32":
        import ctypes

        class MEMSTAT(ctypes.Structure):
            _fields_ = [("dwLength", ctypes.c_ulong), ("dwMemoryLoad", ctypes.c_ulong),
                        ("ullTotalPhys", ctypes.c_ulonglong), ("ullAvailPhys", ctypes.c_ulonglong),
                        ("ullTotalPageFile", ctypes.c_ulonglong), ("ullAvailPageFile", ctypes.c_ulonglong),
                        ("ullTotalVirtual", ctypes.c_ulonglong), ("ullAvailVirtual", ctypes.c_ulonglong),
                        ("ullAvailExtendedVirtual", ctypes.c_ulonglong)]
        m = MEMSTAT()
        m.dwLength = ctypes.sizeof(MEMSTAT)
        ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(m))
        return m.ullTotalPhys / 1024**3
    try:
        return os.sysconf("SC_PAGE_SIZE") * os.sysconf("SC_PHYS_PAGES") / 1024**3
    except (ValueError, OSError):
        return 0.0


def windows_query(cmd):
    try:
        out = subprocess.run(["powershell", "-NoProfile", "-Command", cmd],
                             capture_output=True, text=True, timeout=20)
        return out.stdout.strip()
    except Exception:
        return ""


def cpu_name():
    if sys.platform == "win32":
        return windows_query("(Get-CimInstance Win32_Processor).Name") or platform.processor()
    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if line.startswith("model name"):
                    return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return platform.processor() or "sconosciuta"


def gpu_info():
    if sys.platform == "win32":
        return windows_query(
            "Get-CimInstance Win32_VideoController | ForEach-Object "
            "{ $_.Name + ' (' + [math]::Round($_.AdapterRAM/1MB) + ' MB)' }") or "sconosciuta"
    return "sconosciuta (controlla su Windows)"


def check_module(name):
    try:
        mod = __import__(name)
        return getattr(mod, "__version__", getattr(mod, "ver", "ok"))
    except ImportError:
        return None


def main():
    ram = ram_gb()
    cores = os.cpu_count() or 1
    disk_free = shutil.disk_usage(os.path.abspath(os.sep)).free / 1024**3

    print("=" * 56)
    print(" VERIFICA PC per Imperium (remake)")
    print("=" * 56)
    print(f" Sistema   : {platform.system()} {platform.release()} ({platform.machine()})")
    print(f" CPU       : {cpu_name()}")
    print(f" Core      : {cores} logici")
    print(f" RAM       : {ram:.1f} GB")
    print(f" GPU       : {gpu_info()}")
    print(f" Disco     : {disk_free:.1f} GB liberi")
    print(f" Python    : {platform.python_version()}")
    pg = check_module("pygame")
    print(f" pygame-ce : {pg or 'NON installato -> esegui setup_windows.bat'}")
    print("-" * 56)

    # Profilo grafico consigliato (letto anche dal gioco)
    if ram < 3 or cores <= 2:
        profile = "basso"
    elif ram < 6 or cores <= 4:
        profile = "medio"
    else:
        profile = "alto"
    print(f" Profilo consigliato: {profile.upper()}")
    if sys.version_info < (3, 10):
        print(" ATTENZIONE: serve Python 3.10 o superiore (consigliato 3.12).")
    print("=" * 56)
    return profile


if __name__ == "__main__":
    main()
