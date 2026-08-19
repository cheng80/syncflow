import 'package:flutter_test/flutter_test.dart';
import 'package:syncflow/service/api_client.dart';

void main() {
  test('FastAPI validation detail uses its message', () {
    final error = ApiException([
      {'msg': 'invalid email'},
    ]);

    expect(error.message, 'invalid email');
  });

  test('retry delay is kept for the login countdown', () {
    final error = ApiException('wait', retryAfter: 30);

    expect(error.retryAfter, 30);
  });
}
