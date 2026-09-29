from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEST = ROOT / 'zamer-app' / 'test' / 'engineering_screen_test.dart'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)


text = TEST.read_text()
if "find.text('Трассы')" in text and "tester.drag(find.byType(ListView).first" in text:
    print('engineering +60 test update already applied')
    raise SystemExit(0)

text = replace_once(
    text,
    "    await tester.ensureVisible(find.text('Ш 1200'));\n    await tester.tap(find.text('Ш 1200'));\n",
    "    await tester.drag(\n      find.byType(ListView).first,\n      const Offset(0, -320),\n    );\n    await tester.pumpAndSettle();\n    await tester.tap(find.text('Ш 1200'));\n",
    'scroll to ceiling zone size control',
)
text = replace_once(
    text,
    "    await tester.tap(find.text('Трубы'));\n",
    "    await tester.tap(find.text('Трассы'));\n",
    'routes tab label',
)
TEST.write_text(text)
print('Updated engineering screen test for +60 UI')
