// habit_db_schema.dart
// docs/habit/sqlite_schema_v1.md (SQLite 확정 스키마)

/// 습관 앱 SQLite 스키마 (클라이언트)
/// - habits, habit_daily_logs (기기 설정은 AppStorage 사용, 백업 제외)
const String habitDbSchema = '''
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS habits (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  daily_target INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  is_dirty INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_habits_active ON habits(is_active);
CREATE INDEX IF NOT EXISTS idx_habits_updated ON habits(updated_at);

CREATE TABLE IF NOT EXISTS habit_daily_logs (
  id TEXT PRIMARY KEY,
  habit_id TEXT NOT NULL,
  date TEXT NOT NULL,
  count INTEGER NOT NULL DEFAULT 0,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  is_dirty INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_habit_date ON habit_daily_logs(habit_id, date);
CREATE INDEX IF NOT EXISTS idx_logs_updated ON habit_daily_logs(updated_at);
''';
