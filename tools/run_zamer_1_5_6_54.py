from pathlib import Path

helper = Path(__file__).with_name('apply_zamer_1_5_6_54_visual_foundation.py')
source = helper.read_text()
old = "objects = replace_once(objects, '                                                            0xFF79E1B9,\\n', '                                                            0xFFF1C79E,\\n', 'catalog selected text')"
new = "objects = objects.replace('                                                            0xFF79E1B9,\\n', '                                                            0xFFF1C79E,\\n', 2)"
if old not in source:
    raise SystemExit('visual patch wrapper: repeated palette replacement marker not found')
source = source.replace(old, new, 1)
exec(compile(source, str(helper), 'exec'))
