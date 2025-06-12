import 'package:relic/relic.dart'; // Assuming RequestContext is part of relic.dart
import 'package:relic/src/adapter/context.dart';
import 'package:test/test.dart';

void main() {
  group('ContextProperty', () {
    late ContextProperty<String> stringProperty;
    late ContextProperty<int> intProperty;
    late RequestContext context1;
    late RequestContext context2;

    setUp(() {
      stringProperty = ContextProperty<String>('testStringProperty');
      intProperty = ContextProperty<int>(); // No debug name

      // Assuming Request() is a valid constructor.
      // If Request needs specific arguments or mocking, this will need adjustment.
      final request1 =
          Request(RequestMethod.get, Uri.parse('http://test.com/test1'));
      final request2 =
          Request(RequestMethod.get, Uri.parse('http://test.com/test2'));

      context1 = request1.toContext(Object());
      context2 = request2.toContext(Object());
    });

    test(
        'Given a ContextProperty and a RequestContext, '
        'when a value is set for the context using the property, '
        'then the same value can be retrieved', () {
      // Arrange
      const value = 'hello world';

      // Act
      stringProperty[context1] = value;
      final retrievedValue = stringProperty[context1];

      // Assert
      expect(retrievedValue, value);
    });

    test(
        'Given a ContextProperty with a debug name and a RequestContext for which no value is set, '
        'when the value is accessed using the [] operator, '
        'then a StateError is thrown with a message containing the debug name',
        () {
      // Arrange (stringProperty and context1 are set up in setUp, no value set)

      // Act & Assert
      expect(
        () => stringProperty[context1],
        throwsA(isA<StateError>().having(
          (final e) => e.message,
          'message',
          contains(
              'ContextProperty value not found. Property: testStringProperty.'),
        )),
      );
    });

    test(
        'Given a ContextProperty (for int type, no debug name) and a RequestContext for which no value is set, '
        'when the value is accessed using the [] operator, '
        'then a StateError is thrown with a message containing the type name',
        () {
      // Arrange (intProperty and context1 are set up in setUp, no value set)

      // Act & Assert
      expect(
        () => intProperty[context1],
        throwsA(isA<StateError>().having(
          (final e) => e.message,
          'message',
          contains('ContextProperty value not found. Property: int.'),
        )),
      );
    });

    test(
        'Given a ContextProperty and a RequestContext for which no value is set, '
        'when getOrNull is called, '
        'then null is returned', () {
      // Arrange (stringProperty and context1 are set up, no value set)

      // Act
      final result = stringProperty.getOrNull(context1);

      // Assert
      expect(result, isNull);
    });

    test(
        'Given a ContextProperty and a RequestContext, '
        'when a value is set and then retrieved using getOrNull, '
        'then the originally set value is returned', () {
      // Arrange
      const value = 'test value';
      stringProperty[context1] = value;

      // Act
      final retrievedValue = stringProperty.getOrNull(context1);

      // Assert
      expect(retrievedValue, value);
    });

    test(
        'Given a ContextProperty and a RequestContext for which no value is set, '
        'when exists is called, '
        'then false is returned', () {
      // Arrange (stringProperty and context1 are set up, no value set)

      // Act
      final result = stringProperty.exists(context1);

      // Assert
      expect(result, isFalse);
    });

    test(
        'Given a ContextProperty and a RequestContext, '
        'when a value is set and exists is called, '
        'then true is returned', () {
      // Arrange
      const value = 'exists';
      stringProperty[context1] = value;

      // Act
      final result = stringProperty.exists(context1);

      // Assert
      expect(result, isTrue);
    });

    test(
        'Given a ContextProperty and a RequestContext with a set value, '
        'when clear is called for the context, '
        'then the value is removed and subsequent accesses reflect this', () {
      // Arrange
      stringProperty[context1] = 'to be cleared';
      expect(stringProperty.exists(context1), isTrue,
          reason: 'Pre-condition: value should exist');

      // Act
      stringProperty.clear(context1);

      // Assert
      expect(stringProperty.exists(context1), isFalse);
      expect(stringProperty.getOrNull(context1), isNull);
      expect(
        () => stringProperty[context1],
        throwsStateError,
      );
    });

    test(
        'Given a ContextProperty and two RequestContexts with values set for both, '
        'when clear is called for the first context, '
        'then only the first context value is removed and the second remains unaffected',
        () {
      // Arrange
      stringProperty[context1] = 'value1';
      stringProperty[context2] = 'value2';

      // Act
      stringProperty.clear(context1);

      // Assert
      expect(stringProperty.exists(context1), isFalse);
      expect(stringProperty.exists(context2), isTrue);
      expect(stringProperty[context2], 'value2');
    });

    test(
        'Given a ContextProperty and two different RequestContext instances, '
        'when different values are set for each context using the same property, '
        'then retrieving values for each context returns their respective, isolated values',
        () {
      // Arrange
      const value1 = 'value for context1';
      const value2 = 'value for context2';

      // Act
      stringProperty[context1] = value1;
      stringProperty[context2] = value2;

      // Assert
      expect(stringProperty[context1], value1);
      expect(stringProperty[context2], value2);
      expect(stringProperty.getOrNull(context1), value1);
      expect(stringProperty.getOrNull(context2), value2);
    });

    test(
        'Given a single RequestContext and multiple different ContextProperty instances, '
        'when different values are set for the same context using these different properties, '
        'then retrieving values using each property returns its respective, isolated value',
        () {
      // Arrange
      final anotherStringProperty = ContextProperty<String>('anotherString');
      const valStrProp = 'value for stringProperty';
      const valAnotherStrProp = 'value for anotherStringProperty';
      const valIntProp = 123;

      // Act
      stringProperty[context1] = valStrProp;
      anotherStringProperty[context1] = valAnotherStrProp;
      intProperty[context1] = valIntProp;

      // Assert
      expect(stringProperty[context1], valStrProp);
      expect(anotherStringProperty[context1], valAnotherStrProp);
      expect(intProperty[context1], valIntProp);
    });

    test(
        'Given a ContextProperty and a RequestContext, '
        'when a value is set and then clear is called, '
        'then exists returns true after setting and false after clearing', () {
      // Arrange
      const value = 'temporary';

      // Act & Assert for initial set
      stringProperty[context1] = value;
      expect(stringProperty.exists(context1), isTrue,
          reason: 'Value should exist after being set');

      // Act for clear
      stringProperty.clear(context1);

      // Assert after clear
      expect(stringProperty.exists(context1), isFalse,
          reason: 'Value should not exist after clear');
    });

    test(
        'Given a ContextProperty for int and a RequestContext, '
        'when an int value is set, retrieved, its existence checked, and then cleared, '
        'then all operations behave as expected', () {
      // Arrange
      final numberProperty = ContextProperty<int>('numberProperty');
      const value = 42;

      // Act & Assert Set
      numberProperty[context1] = value;
      expect(numberProperty[context1], value);
      expect(numberProperty.getOrNull(context1), value);
      expect(numberProperty.exists(context1), isTrue);

      // Act & Assert Clear
      numberProperty.clear(context1);
      expect(numberProperty.exists(context1), isFalse);
    });

    test(
        'Given a ContextProperty for a custom User object and a RequestContext, '
        'when a User instance is set, retrieved, its existence checked, and then cleared, '
        'then all operations behave as expected and the same instance is retrieved',
        () {
      // Arrange
      final userProperty = ContextProperty<User>('userProperty');
      final user = User('Test User', 30);

      // Act & Assert Set
      userProperty[context1] = user;
      expect(userProperty[context1], same(user));
      expect(userProperty.getOrNull(context1), same(user));
      expect(userProperty.exists(context1), isTrue);

      // Act & Assert Clear
      userProperty.clear(context1);
      expect(userProperty.exists(context1), isFalse);
    });
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
