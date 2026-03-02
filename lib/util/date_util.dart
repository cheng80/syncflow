// date_util.dart
// 날짜 유틸리티 (YYYY-MM-DD 문자열 기준)
//
// [정책] 앱 전역에서 날짜는 YYYY-MM-DD 문자열로 통일 (로컬 타임존)

/// 오늘 날짜 YYYY-MM-DD
String dateToday() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// 날짜에 일수 더하기
String addDays(String dateStr, int days) {
  final parts = dateStr.split('-');
  final d = DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
  final result = d.add(Duration(days: days));
  return '${result.year}-${result.month.toString().padLeft(2, '0')}-${result.day.toString().padLeft(2, '0')}';
}

/// 날짜 범위 리스트 (start ~ end 포함)
List<String> dateRange(String start, String end) {
  final list = <String>[];
  var d = DateTime.parse(start);
  final e = DateTime.parse(end);
  while (!d.isAfter(e)) {
    list.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    d = d.add(const Duration(days: 1));
  }
  return list;
}

/// 해당 월의 1일
String firstDayOfMonth(int year, int month) {
  return '$year-${month.toString().padLeft(2, '0')}-01';
}

/// 해당 월의 마지막 날
String lastDayOfMonth(int year, int month) {
  final last = DateTime(year, month + 1, 0);
  return '${last.year}-${last.month.toString().padLeft(2, '0')}-${last.day.toString().padLeft(2, '0')}';
}
