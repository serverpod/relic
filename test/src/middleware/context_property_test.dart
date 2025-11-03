import 'package:relic/relic.dart';
import 'package:relic/src/context/context.dart';
import 'package:test/test.dart';

RequestContext _createContextInstance([final String uriSuffix = 'test']) {
  final request = Request(Method.get, Uri.parse('http://test.com/$uriSuffix'));
  return request..setToken(Object());
}

void main() {
  group('Given a ContextProperty<String> and a RequestContext,', () {
    late ContextProperty<String> stringProperty;
    late RequestContext context;

    setUp(() {
      stringProperty = ContextProperty<String>('testStringProperty');
      context = _createContextInstance('singleCtx');
    });

    test('when a value is set for the context using the property, '
        'then the same value can be retrieved using [].', () {
      const value = 'hello world';
      stringProperty[context] = value;
      final retrievedValue = stringProperty[context];
      expect(retrievedValue, value);
    });

    test('when no value is set for the context, '
        'then getOrNull returns null.', () {
      final result = stringProperty.getOrNull(context);
      expect(result, isNull);
    });

    test(
      'when a value is set for the context and then retrieved using getOrNull, '
      'then the originally set value is returned.',
      () {
        const value = 'test value';
        stringProperty[context] = value;
        final retrievedValue = stringProperty.getOrNull(context);
        expect(retrievedValue, value);
      },
    );

    test('when no value is set for the context, '
        'then exists returns false.', () {
      final result = stringProperty.exists(context);
      expect(result, isFalse);
    });

    test('when a value is set for the context and exists is called, '
        'then true is returned.', () {
      const value = 'exists';
      stringProperty[context] = value;
      final result = stringProperty.exists(context);
      expect(result, isTrue);
    });

    test('when a value is set and then clear is called for the context, '
        'then the value is removed and subsequent accesses reflect this.', () {
      stringProperty[context] = 'to be cleared';
      expect(
        stringProperty.exists(context),
        isTrue,
        reason: 'Pre-condition: value should exist',
      );

      stringProperty.clear(context);

      expect(stringProperty.exists(context), isFalse);
      expect(stringProperty.getOrNull(context), isNull);
      expect(() => stringProperty[context], throwsStateError);
    });

    test('when a value is set and then clear is called, '
        'then exists returns true after setting and false after clearing.', () {
      const value = 'temporary';

      stringProperty[context] = value;
      expect(
        stringProperty.exists(context),
        isTrue,
        reason: 'Value should exist after being set',
      );

      stringProperty.clear(context);

      expect(
        stringProperty.exists(context),
        isFalse,
        reason: 'Value should not exist after clear',
      );
    });
  });

  group(
    'Given a RequestContext and a ContextProperty for which no value is set,',
    () {
      test(
        'when the property has a debug name and the value is accessed using [], '
        'then a StateError is thrown with a message containing the debug name.',
        () {
          final property = ContextProperty<String>('debugNameProperty');
          final context = _createContextInstance('errorCtxDebug');
          expect(
            () => property[context],
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
        'when the property (e.g., for int type) has no debug name and the value is accessed using [], '
        'then a StateError is thrown with a message containing the type name.',
        () {
          final property = ContextProperty<int>(); // No debug name
          final context = _createContextInstance('errorCtxType');
          expect(
            () => property[context],
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
    },
  );

  group('Given a ContextProperty<String> and two RequestContexts,', () {
    late ContextProperty<String> stringProperty;
    late RequestContext context1;
    late RequestContext context2;

    setUp(() {
      stringProperty = ContextProperty<String>('multiContextProp');
      context1 = _createContextInstance('ctx1');
      context2 = _createContextInstance('ctx2');
    });

    test(
      'when different values are set for each context using the same property, '
      'then retrieving values for each context returns their respective, isolated values.',
      () {
        const value1 = 'value for context1';
        const value2 = 'value for context2';

        stringProperty[context1] = value1;
        stringProperty[context2] = value2;

        expect(stringProperty[context1], value1);
        expect(stringProperty[context2], value2);
        expect(stringProperty.getOrNull(context1), value1);
        expect(stringProperty.getOrNull(context2), value2);
      },
    );

    test(
      'when values are set for both contexts and clear is called for the first context, '
      'then only the first context value is removed and the second remains unaffected.',
      () {
        stringProperty[context1] = 'value1';
        stringProperty[context2] = 'value2';

        stringProperty.clear(context1);

        expect(stringProperty.exists(context1), isFalse);
        expect(stringProperty.exists(context2), isTrue);
        expect(stringProperty[context2], 'value2');
      },
    );
  });

  group(
    'Given a single RequestContext and multiple different ContextProperty instances,',
    () {
      test(
        'when different values are set for the same context using these different properties, '
        'then retrieving values using each property returns its respective, isolated value.',
        () {
          final context = _createContextInstance('multiPropCtx');
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

          expect(stringProperty[context], valStrProp);
          expect(anotherStringProperty[context], valAnotherStrProp);
          expect(intProperty[context], valIntProp);
        },
      );
    },
  );

  group('Given a RequestContext and a ContextProperty for a specific data type,', () {
    test(
      'when the type is int, an int value is set, retrieved, its existence checked, and then cleared, '
      'then all operations behave as expected.',
      () {
        final numberProperty = ContextProperty<int>('numberProperty');
        final context = _createContextInstance('intTypeCtx');
        const value = 42;

        numberProperty[context] = value;
        expect(numberProperty[context], value);
        expect(numberProperty.getOrNull(context), value);
        expect(numberProperty.exists(context), isTrue);

        numberProperty.clear(context);
        expect(numberProperty.exists(context), isFalse);
      },
    );

    test(
      'when the type is a custom User object, a User instance is set, retrieved, its existence checked, and then cleared, '
      'then all operations behave as expected and the same instance is retrieved.',
      () {
        final userProperty = ContextProperty<User>('userProperty');
        final context = _createContextInstance('userTypeCtx');
        final user = User('Test User', 30);

        userProperty[context] = user;
        expect(userProperty[context], same(user));
        expect(userProperty.getOrNull(context), same(user));
        expect(userProperty.exists(context), isTrue);

        userProperty.clear(context);
        expect(userProperty.exists(context), isFalse);
      },
    );
  });
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
