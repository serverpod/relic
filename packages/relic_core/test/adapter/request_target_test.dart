import 'dart:convert';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

Uint8List _bytes(String s) => ascii.encode(s);

void main() {
  group('Given a target from a Uri', () {
    final target = RequestTarget.fromUri(
      Uri.parse('http://example.com/a%2Fb/c%20d?x=1&x=2&y=%C3%A9#frag'),
    );

    test('when the path is read, then it is the encoded path text', () {
      expect(target.path, '/a%2Fb/c%20d');
    });

    test('when the segments are read, '
        'then they split before decoding', () {
      expect(target.pathSegments, ['a/b', 'c d']);
    });

    test('when the query is read, then parameters are decoded', () {
      expect(target.query, 'x=1&x=2&y=%C3%A9');
      expect(target.queryParametersAll, {
        'x': ['1', '2'],
        'y': ['é'],
      });
    });

    test('when the bytes are read, then they are the encoded text', () {
      expect(ascii.decode(target.pathBytes), '/a%2Fb/c%20d');
      expect(ascii.decode(target.queryBytes!), 'x=1&x=2&y=%C3%A9');
    });

    test('when rebuilt under another origin, '
        'then the fragment is gone and the rest is kept', () {
      expect(
        target.toUri(scheme: 'https', authority: 'other:8443').toString(),
        'https://other:8443/a%2Fb/c%20d?x=1&x=2&y=%C3%A9',
      );
    });
  });

  test('Given a Uri without a query, when the query bytes are read, '
      'then they are null', () {
    final target = RequestTarget.fromUri(Uri.parse('http://h/p'));
    expect(target.queryBytes, isNull);
    expect(target.query, '');
  });

  group('Given a target from bytes', () {
    final target = RequestTarget.fromBytes(
      _bytes('/a%2Fb/c%20d'),
      _bytes('x=1&x=2'),
    );

    test('when the bytes are read, then they are the same objects', () {
      expect(ascii.decode(target.pathBytes), '/a%2Fb/c%20d');
      expect(ascii.decode(target.queryBytes!), 'x=1&x=2');
    });

    test('when the segments are read, '
        'then they split before decoding', () {
      expect(target.pathSegments, ['a/b', 'c d']);
    });

    test('when the parameters are read, then they are decoded', () {
      expect(target.queryParametersAll, {
        'x': ['1', '2'],
      });
    });

    test('when rebuilt as a Uri, then it is absolute', () {
      expect(
        target.toUri(scheme: 'http', authority: 'localhost').toString(),
        'http://localhost/a%2Fb/c%20d?x=1&x=2',
      );
    });
  });

  test('Given a path that does not decode, when validated, '
      'then it throws a FormatException', () {
    final target = RequestTarget.fromBytes(_bytes('/%D0%C2%BD.zip'));
    expect(target.validate, throwsFormatException);
  });

  test('Given a query that does not decode, when validated, '
      'then it throws a FormatException', () {
    final target = RequestTarget.fromBytes(_bytes('/'), _bytes('q=%E0%A4'));
    expect(target.validate, throwsFormatException);
  });

  test('Given a request, when its target is read, '
      'then it is the path and query of its url', () {
    final request = RequestInternal.create(
      Method.get,
      Uri.parse('http://localhost/foo/bar?q=1'),
      Object(),
    );
    expect(request.target.pathSegments, ['foo', 'bar']);
    expect(request.target.queryParametersAll, {
      'q': ['1'],
    });
    expect(request.target, same(request.target));
  });
}
