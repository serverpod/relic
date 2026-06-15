import 'package:relic_core/src/headers/typed/headers/util/report_to.dart';
import 'package:test/test.dart';

void main() {
  group('encodeReportToParam', () {
    group('Given a normal value,', () {
      test('when encoded, '
          'then it is wrapped and escaped as report-to="...".', () {
        expect(encodeReportToParam('endpoint'), equals('report-to="endpoint"'));
        expect(encodeReportToParam(r'a"b'), equals(r'report-to="a\"b"'));
      });
    });

    group('Given a value with a control character,', () {
      test('when encoded, '
          'then it throws to prevent header injection.', () {
        expect(
          () => encodeReportToParam('a\r\nInjected: evil'),
          throwsFormatException,
        );
      });
    });
  });
}
