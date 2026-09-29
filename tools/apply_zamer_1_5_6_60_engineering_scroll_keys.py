from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCREEN = ROOT / 'zamer-app' / 'lib' / 'screens' / 'engineering_screen.dart'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)


text = SCREEN.read_text()
if "PageStorageKey<String>('engineering-ceiling')" in text:
    print('engineering +60 scroll keys already applied')
    raise SystemExit(0)

text = replace_once(
    text,
    "  Widget _ceiling(RoomFace face, RoomMeta meta) {\n",
    "  Widget _ceiling(RoomFace face, RoomMeta meta) {\n",
    'ceiling marker',
)
text = replace_once(
    text,
    "    return ListView(\n      padding: const EdgeInsets.all(12),\n",
    "    return ListView(\n      key: const PageStorageKey<String>('engineering-ceiling'),\n      padding: const EdgeInsets.all(12),\n",
    'ceiling scroll key',
)

warm_marker = "  Widget _warmFloor(RoomFace face, RoomMeta meta) {\n"
warm_at = text.find(warm_marker)
if warm_at < 0:
    raise SystemExit('warm floor marker missing')
warm_tail = text[warm_at:]
warm_tail = replace_once(
    warm_tail,
    "    return ListView(\n      padding: const EdgeInsets.all(12),\n",
    "    return ListView(\n      key: const PageStorageKey<String>('engineering-warm-floor'),\n      padding: const EdgeInsets.all(12),\n",
    'warm floor scroll key',
)
text = text[:warm_at] + warm_tail

text = replace_once(
    text,
    "  Widget _routes(RoomFace face, RoomMeta meta) => ListView(\n    padding: const EdgeInsets.all(12),\n",
    "  Widget _routes(RoomFace face, RoomMeta meta) => ListView(\n    key: const PageStorageKey<String>('engineering-routes'),\n    padding: const EdgeInsets.all(12),\n",
    'routes scroll key',
)

SCREEN.write_text(text)
print('Applied independent engineering scroll positions for +60')
