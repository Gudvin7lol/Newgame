/// Explicit working calendar for a construction object. All holidays and
/// closed days are entered manually; nothing is assumed from location.
class WorkCalendar {
  WorkCalendar({this.weekdaysOnly = false, Iterable<String>? daysOff})
      : daysOff = daysOff?.toSet() ?? <String>{};

  bool weekdaysOnly;
  final Set<String> daysOff;

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String key(DateTime v) =>
      v.year.toString().padLeft(4, '0') + '-' +
      v.month.toString().padLeft(2, '0') + '-' +
      v.day.toString().padLeft(2, '0');

  static DateTime addDays(DateTime date, int n) =>
      DateTime(date.year, date.month, date.day + n);

  bool isWorkday(DateTime date) =>
      !daysOff.contains(key(date)) && (!weekdaysOnly ||
          (date.weekday != DateTime.saturday &&
           date.weekday != DateTime.sunday));

  DateTime nextWorkday(DateTime date) {
    var next = dateOnly(date);
    for (var i = 0; i < 36600; i++) {
      if (isWorkday(next)) return next;
      next = addDays(next, 1);
    }
    throw StateError('Рабочий день не найден.');
  }

  /// Waiting period is in calendar days even in the 5/2 mode.
  DateTime firstDayAfter(DateTime predecessorFinish, int lagDays) =>
      nextWorkday(addDays(predecessorFinish, lagDays + 1));

  int workingDaysInclusive(DateTime start, DateTime finish) {
    var date = dateOnly(start);
    final end = dateOnly(finish);
    var count = 0;
    while (!date.isAfter(end)) {
      if (isWorkday(date)) count++;
      date = addDays(date, 1);
    }
    return count;
  }

  DateTime finishForDuration(DateTime start, int duration) {
    if (duration < 1) throw ArgumentError.value(duration);
    var date = nextWorkday(start);
    for (var i = 1; i < duration; i++) {
      date = nextWorkday(addDays(date, 1));
    }
    return date;
  }

  double plannedFraction(DateTime start, DateTime finish, DateTime at) {
    final begin = dateOnly(start);
    final end = dateOnly(finish);
    final day = dateOnly(at);
    if (day.isBefore(begin)) return 0;
    if (day.isAfter(end)) return 1;
    final count = workingDaysInclusive(begin, end);
    if (count == 0) return 0;
    final before = day.isAfter(begin) ?
        workingDaysInclusive(begin, addDays(day, -1)) : 0;
    final seconds = at.hour * 3600 + at.minute * 60 + at.second;
    final part = isWorkday(day) ? seconds / 86400 : 0.0;
    return ((before + part) / count).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
    'weekdaysOnly': weekdaysOnly,
    'daysOff': daysOff.toList()..sort(),
  };

  factory WorkCalendar.fromJson(Map<String, dynamic> json) => WorkCalendar(
    weekdaysOnly: json['weekdaysOnly'] == true,
    daysOff: ((json['daysOff'] as List?) ?? const [])
      .map((item) => item.toString())
      .where((item) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(item)),
  );
}
