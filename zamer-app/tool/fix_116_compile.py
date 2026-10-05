from pathlib import Path

path = Path(__file__).resolve().parents[1] / 'lib/screens/plan_editor_master_v4_screen.dart'
text = path.read_text(encoding='utf-8')
unused = '''  PlanObject? _planObjectById(String? id) {
    if (id == null) return null;
    for (final object in floor.planObjects) {
      if (object.id == id) return object;
    }
    return null;
  }

'''
if unused not in text:
    raise SystemExit('unused helper anchor missing')
text = text.replace(unused, '', 1)
text = text.replace('width: math.max(1, maxX - minX),', 'width: math.max(1.0, maxX - minX),', 1)
text = text.replace('height: math.max(1, maxY - minY),', 'height: math.max(1.0, maxY - minY),', 1)
path.write_text(text, encoding='utf-8')
# trigger after workflow creation
