import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

Request _request() {
  final request = RequestInternal.create(
    Method.get,
    Uri.parse('http://test.com/'),
    Object(),
  );
  return request;
}

void main() {
  group('Given a ContextProperty<String> and a Request,', () {
    late ContextProperty<String> stringProperty;
    late Request request;

    setUp(() {
      stringProperty = ContextProperty<String>('testStringProperty');
      request = _request();
    });

    test('when a value is set for the context using the property, '
        'then the same value can be retrieved using get.', () {
      const value = 'hello world';
      stringProperty[request] = value;
      final retrievedValue = stringProperty.get(request);
      expect(retrievedValue, value);
    });

    test('when no value is set for the context, '
        'then operator[] returns null.', () {
      final result = stringProperty[request];
      expect(result, isNull);
    });

    test('when a value is set for the context and then retrieved using [], '
        'then the originally set value is returned.', () {
      const value = 'test value';
      stringProperty[request] = value;
      final retrievedValue = stringProperty[request];
      expect(retrievedValue, value);
    });
  });

  group('Given a Request and a ContextProperty for which no value is set,', () {
    test(
      'when the property has a debug name and the value is accessed using get, '
      'then a StateError is thrown with a message containing the debug name.',
      () {
        final property = ContextProperty<String>('debugNameProperty');
        final context = _request();
        expect(
          () => property.get(context),
          throwsA(
            isA<StateError>().having(
              (final e) => e.message,
              'message',
              contains(
                'ContextProperty value not found. Property: debugNameProperty.',
              ),
            ),
          ),
        );
      },
    );

    test(
      'when the property (e.g., for int type) has no debug name and the value is accessed using get, '
      'then a StateError is thrown with a message containing the type name.',
      () {
        final property = ContextProperty<int>(); // No debug name
        final context = _request();
        expect(
          () => property.get(context),
          throwsA(
            isA<StateError>().having(
              (final e) => e.message,
              'message',
              contains('ContextProperty value not found. Property: int.'),
            ),
          ),
        );
      },
    );
  });

  group('Given a ContextProperty<String> and two Requests,', () {
    late ContextProperty<String> stringProperty;
    late Request context1;
    late Request context2;

    setUp(() {
      stringProperty = ContextProperty<String>('multiContextProp');
      context1 = _request();
      context2 = _request();
    });

    test(
      'when different values are set for each context using the same property, '
      'then retrieving values for each context returns their respective, isolated values.',
      () {
        const value1 = 'value for context1';
        const value2 = 'value for context2';

        stringProperty[context1] = value1;
        stringProperty[context2] = value2;

        expect(stringProperty.get(context1), value1);
        expect(stringProperty.get(context2), value2);
        expect(stringProperty[context1], value1);
        expect(stringProperty[context2], value2);
      },
    );
  });

  group(
    'Given a single Request and multiple different ContextProperty instances,',
    () {
      test(
        'when different values are set for the same context using these different properties, '
        'then retrieving values using each property returns its respective, isolated value.',
        () {
          final context = _request();
          final stringProperty = ContextProperty<String>('testStringProperty');
          final anotherStringProperty = ContextProperty<String>(
            'anotherString',
          );
          final intProperty = ContextProperty<int>(); // No debug name

          const valStrProp = 'value for stringProperty';
          const valAnotherStrProp = 'value for anotherStringProperty';
          const valIntProp = 123;

          stringProperty[context] = valStrProp;
          anotherStringProperty[context] = valAnotherStrProp;
          intProperty[context] = valIntProp;

          expect(stringProperty.get(context), valStrProp);
          expect(anotherStringProperty.get(context), valAnotherStrProp);
          expect(intProperty.get(context), valIntProp);
        },
      );
    },
  );
}

// Dummy User class for testing with custom objects
class User {
  final String name;
  final int age;
  User(this.name, this.age);

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          age == other.age;

  @override
  int get hashCode => name.hashCode ^ age.hashCode;

  @override
  String toString() {
    return 'User{name: $name, age: $age}';
  }
}
