#!/usr/bin/env python3
"""Run offline Voyage fork regressions. No network, credentials, or Kindle needed."""
import argparse
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
TESTS = Path(__file__).resolve().parent
PLUGIN = ROOT / 'miuread.koplugin'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lua', help='Lua 5.1 or LuaJIT executable')
    args = parser.parse_args()
    lua = args.lua or shutil.which('lua5.1') or shutil.which('luajit') or shutil.which('lua')
    if not lua:
        parser.error('Install Lua 5.1 or LuaJIT, or pass --lua /path/to/lua')
    subprocess.run([lua, '-e', 'assert(_VERSION == "Lua 5.1", "Lua 5.1 or LuaJIT is required")'], check=True)
    # Parse the plugin without loading KOReader dependencies or executing it.
    subprocess.run([lua, str(TESTS / 'check_syntax.lua'), *map(str, sorted(PLUGIN.rglob('*.lua')))], check=True)
    cases = [
        ('test_on_demand.lua', [ROOT]),
        ('test_real_api.lua', [ROOT]),
        ('test_native_contract.lua', [ROOT]),
        ('test_api_paging.lua', [ROOT]),
        ('test_http_bound.lua', [PLUGIN / 'miuread/http.lua']),
        ('test_http_scope.lua', [PLUGIN / 'miuread/http.lua']),
        ('test_home_fix.lua', [PLUGIN / 'main.lua', PLUGIN / 'miuread/background_scheduler.lua']),
        ('test_annotation_render.lua', [PLUGIN / 'miuread/annotations.lua', TESTS / 'fixtures/annotations-v5.9.0.lua']),
    ]
    for name, arguments in cases:
        subprocess.run([lua, str(TESTS / name), *map(str, arguments)], cwd=ROOT, check=True)
    print('All Voyage fork regression suites passed.')


if __name__ == '__main__':
    main()
