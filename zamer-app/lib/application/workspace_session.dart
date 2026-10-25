import 'package:flutter/foundation.dart';

/// The shared state of the active project workspace.
///
/// Screens render this state, while edit commands are responsible for
/// changing the project model. Keeping the interaction state here prevents
/// the Plan, Floor, Objects and Electrical layers from growing separate
/// selections and tool histories.
enum WorkspaceDomain { plan, floor, objects, electrical, engineering, materials }

enum WorkspaceOperationStage {
  idle,
  selecting,
  adding,
  editing,
  routing,
  confirming,
  error,
}

enum WorkspaceView { twoD, threeD, photo }

@immutable
class WorkspaceSelection {
  const WorkspaceSelection({required this.kind, required this.id});

  final String kind;
  final String id;
}

@immutable
class WorkspaceViewport {
  const WorkspaceViewport({
    this.centerX = 0,
    this.centerY = 0,
    this.scale = 1,
    this.rotation = 0,
  });

  final double centerX;
  final double centerY;
  final double scale;
  final double rotation;

  WorkspaceViewport copyWith({
    double? centerX,
    double? centerY,
    double? scale,
    double? rotation,
  }) => WorkspaceViewport(
    centerX: centerX ?? this.centerX,
    centerY: centerY ?? this.centerY,
    scale: scale ?? this.scale,
    rotation: rotation ?? this.rotation,
  );
}

@immutable
class WorkspaceVisibility {
  const WorkspaceVisibility({
    this.walls = true,
    this.dimensions = true,
    this.floor = true,
    this.objects = true,
    this.electrical = true,
    this.engineering = true,
    this.collisions = true,
    this.roomLabels = true,
  });

  final bool walls;
  final bool dimensions;
  final bool floor;
  final bool objects;
  final bool electrical;
  final bool engineering;
  final bool collisions;
  final bool roomLabels;

  WorkspaceVisibility copyWith({
    bool? walls,
    bool? dimensions,
    bool? floor,
    bool? objects,
    bool? electrical,
    bool? engineering,
    bool? collisions,
    bool? roomLabels,
  }) => WorkspaceVisibility(
    walls: walls ?? this.walls,
    dimensions: dimensions ?? this.dimensions,
    floor: floor ?? this.floor,
    objects: objects ?? this.objects,
    electrical: electrical ?? this.electrical,
    engineering: engineering ?? this.engineering,
    collisions: collisions ?? this.collisions,
    roomLabels: roomLabels ?? this.roomLabels,
  );
}

/// Shared interaction state for the live Measure workspace.
///
/// It intentionally does not own FloorPlan. Project edits will be moved to
/// commands incrementally; this object owns only cross-layer UI state.
class WorkspaceSession extends ChangeNotifier {
  WorkspaceDomain _domain = WorkspaceDomain.plan;
  int _taskIndex = 0;
  bool _taskActivated = false;
  WorkspaceOperationStage _stage = WorkspaceOperationStage.idle;
  WorkspaceSelection? _selection;
  String _quickAction = 'select';
  WorkspaceView _view = WorkspaceView.twoD;
  WorkspaceViewport _viewport = const WorkspaceViewport();
  WorkspaceVisibility _visibility = const WorkspaceVisibility();
  bool _dirty = false;

  WorkspaceDomain get domain => _domain;
  int get taskIndex => _taskIndex;
  bool get taskActivated => _taskActivated;
  WorkspaceOperationStage get stage => _stage;
  WorkspaceSelection? get selection => _selection;
  String get selectionKind => _selection?.kind ?? '';
  String get quickAction => _quickAction;
  WorkspaceView get view => _view;
  WorkspaceViewport get viewport => _viewport;
  WorkspaceVisibility get visibility => _visibility;
  bool get dirty => _dirty;

  void selectDomain(WorkspaceDomain value) {
    if (_domain == value) return;
    _domain = value;
    _taskIndex = 0;
    _taskActivated = false;
    _selection = null;
    _quickAction = 'select';
    _stage = WorkspaceOperationStage.idle;
    notifyListeners();
  }

  void selectTask(int index, {bool activated = true}) {
    _taskIndex = index;
    _taskActivated = activated;
    _selection = null;
    _quickAction = 'select';
    _stage = activated
        ? WorkspaceOperationStage.adding
        : WorkspaceOperationStage.idle;
    notifyListeners();
  }

  void setSelection(String? kind, {String? id}) {
    _selection = kind == null
        ? null
        : WorkspaceSelection(kind: kind, id: id ?? '');
    _stage = kind == null
        ? WorkspaceOperationStage.selecting
        : WorkspaceOperationStage.editing;
    notifyListeners();
  }

  void setQuickAction(String value) {
    _quickAction = value;
    _stage = value == 'select'
        ? WorkspaceOperationStage.selecting
        : WorkspaceOperationStage.editing;
    notifyListeners();
  }

  void setView(WorkspaceView value) {
    _view = value;
    notifyListeners();
  }

  void setViewport(WorkspaceViewport value) {
    _viewport = value;
    notifyListeners();
  }

  void setVisibility(WorkspaceVisibility value) {
    _visibility = value;
    notifyListeners();
  }

  void markDirty([bool value = true]) {
    if (_dirty == value) return;
    _dirty = value;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
