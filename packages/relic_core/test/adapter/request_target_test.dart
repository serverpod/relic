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
      null,
    );
    expect(request.target.pathSegments, ['foo', 'bar']);
    expect(request.target.queryParametersAll, {
      'q': ['1'],
    });
    expect(request.target, same(request.target));
  });

  group('Given the same target from bytes and from a Uri', () {
    const targets = [
      '',
      '/',
      '/a',
      '/a/b',
      '/a/b/',
      '/a//b',
      '/a%2Fb/c%20d',
      '/caf%C3%A9',
      '/p?',
      '/p?q',
      '/p?x=1&x=2&y=%C3%A9',
      '/p?a+b=c+d',
    ];
    for (final form in targets) {
      test("when '$form' is read both ways, "
          'then the segments, the parameters and the origin form agree', () {
        final q = form.indexOf('?');
        final bytes = RequestTarget.fromBytes(
          _bytes(q < 0 ? form : form.substring(0, q)),
          q < 0 ? null : _bytes(form.substring(q + 1)),
        );
        final uri = RequestTarget.fromUri(Uri.parse('http://h$form'));
        expect(bytes.pathSegments, uri.pathSegments);
        expect(bytes.queryParametersAll, uri.queryParametersAll);
        expect(bytes.originForm, uri.originForm);
      });
    }
  });

  test('Given a target from bytes with dot segments, '
      'when the segments are read, then they are kept for the router', () {
    final target = RequestTarget.fromBytes(_bytes('/a/./b/../c'));
    expect(target.pathSegments, ['a', '.', 'b', '..', 'c']);
    expect(NormalizedPath.fromPathSegments(target.pathSegments).segments, [
      'a',
      'c',
    ]);
  });

  test('Given a target from bytes with a backslash, when validated, '
      'then its segments are those of the url built from it', () {
    final target = RequestTarget.fromBytes(_bytes(r'/files/a\b'))..validate();
    final url = target.toUri(scheme: 'http', authority: 'h');

    expect(target.pathSegments, url.pathSegments);
  });

  test('Given a request from a target and an authority, '
      'when url is read, then it is the absolute URL for them', () {
    final request = RequestInternal.create(
      Method.get,
      null,
      null,
      target: RequestTarget.fromBytes(_bytes('/a/b'), _bytes('x=1')),
      authority: 'example.com:8080',
    );
    expect(request.target.pathSegments, ['a', 'b']);
    expect(request.url, Uri.parse('http://example.com:8080/a/b?x=1'));
  });

  test('Given a request with neither a url nor a target, '
      'when created, then it throws', () {
    expect(
      () => RequestInternal.create(Method.get, null, null),
      throwsArgumentError,
    );
  });
}
