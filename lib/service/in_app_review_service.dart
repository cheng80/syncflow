// in_app_review_service.dart
// 스토어 평점/리뷰 (in_app_review) 서비스

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:syncflow/util/app_storage.dart';

/// 인앱 리뷰 요청 조건
class InAppReviewConfig {
  /// 습관 N회 달성 후 요청 (목표 달성 시 +1)
  static const int minHabitAchievedCount = 5;

  /// 앱 사용 N일 후 요청 (첫 실행일 기준)
  static const int minDaysSinceFirstLaunch = 3;
}

/// InAppReviewService - requestReview / openStoreListing
class InAppReviewService {
  final InAppReview _review = InAppReview.instance;

  /// 조건 만족 시 인앱 리뷰 팝업 요청 (자동 호출용)
  /// - 습관 달성 5회 이상 또는 첫 실행 후 3일 경과
  /// - 이미 요청했으면 스킵
  Future<void> maybeRequestReview() async {
    if (AppStorage.getReviewRequested()) return;

    final firstLaunch = AppStorage.getFirstLaunchDate();
    if (firstLaunch == null) return;

    final count = AppStorage.getHabitAchievedCount();
    final firstDate = DateTime.tryParse(firstLaunch);
    if (firstDate == null) return;

    final daysSince = DateTime.now().difference(firstDate).inDays;
    final countOk = count >= InAppReviewConfig.minHabitAchievedCount;
    final daysOk = daysSince >= InAppReviewConfig.minDaysSinceFirstLaunch;

    if (!countOk && !daysOk) return;

    if (await _review.isAvailable()) {
      await _review.requestReview();
      await AppStorage.setReviewRequested();
    }
  }

  /// 스토어 리뷰 화면으로 이동 (Drawer 버튼용, 횟수 제한 없음)
  /// iOS: appStoreId 필수 (App Store Connect > General > App Information > Apple ID)
  /// 값이 비어 있으면 false 반환 (호출 측에서 스낵바 등 처리)
  static const String appStoreId = '6759329455';

  /// 스토어 화면 열기. 성공 시 true, 실패 시 false (예: appStoreId 미설정)
  Future<bool> openStoreListing() async {
    if (appStoreId.isEmpty) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return false;
      }
    }
    try {
      await _review.openStoreListing(appStoreId: appStoreId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
