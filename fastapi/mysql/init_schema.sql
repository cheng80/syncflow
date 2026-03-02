-- HabitCell MySQL Init Schema
-- DB 생성 및 백업 저장소 테이블 초기화
-- 실행: mysql -u user -p < init_schema.sql

-- 1. 데이터베이스 생성
CREATE DATABASE IF NOT EXISTS habitcell_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE habitcell_db;

-- 2. devices: 기기 등록 (device_uuid 기준)
CREATE TABLE IF NOT EXISTS devices (
  device_uuid CHAR(36) PRIMARY KEY,
  email VARCHAR(255) DEFAULT NULL,
  email_verified_at DATETIME DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. email_verifications: 이메일 6자리 코드 인증
CREATE TABLE IF NOT EXISTS email_verifications (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  device_uuid CHAR(36) NOT NULL,
  email VARCHAR(255) NOT NULL,
  code_hash CHAR(64) NOT NULL,
  expires_at DATETIME NOT NULL,
  attempt_count INT NOT NULL DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_email (email),
  INDEX idx_device_uuid (device_uuid),
  FOREIGN KEY (device_uuid) REFERENCES devices(device_uuid) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. backups: SQLite 스냅샷 JSON (device당 최신 1개)
CREATE TABLE IF NOT EXISTS backups (
  device_uuid CHAR(36) PRIMARY KEY,
  payload_json LONGTEXT NOT NULL,
  checksum CHAR(64) NOT NULL,
  payload_updated_at DATETIME NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (device_uuid) REFERENCES devices(device_uuid) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
