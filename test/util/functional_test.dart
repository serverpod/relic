import 'package:relic/src/util/functional.dart';
import 'package:test/test.dart';

void main() {
  group('Pipe Extension', () {
    test(
        'Given a value and a function, '
        'when the pipe extension is used, '
        'then the function should be applied to the value', () {
      // Arrange
      const initialValue = 5;
      int addTwo(final int x) => x + 2;

      // Act
      final result = initialValue.pipe(addTwo);

      // Assert
      expect(result, equals(7));
    });

    test(
        'Given a string and a sequence of string operations, '
        'when piped together, '
        'then the correct final string is produced', () {
      // Arrange
      const initialValue = 'hello';
      String toUpper(final String s) => s.toUpperCase();
      String addWorld(final String s) => '$s WORLD';
      String exclaim(final String s) => '$s!';

      // Act
      final result = initialValue.pipe(toUpper).pipe(addWorld).pipe(exclaim);

      // Assert
      expect(result, equals('HELLO WORLD!'));
    });
  });

  group('Compose Extension', () {
    test(
        'Given two functions, '
        'when they are composed, '
        'then the resulting function should be their composition', () {
      // Arrange
      int addTwo(final int x) => x + 2;
      int multiplyByThree(final int x) => x * 3;

      // Act
      final composedFunction =
          multiplyByThree.compose(addTwo); // multiplyByThree(addTwo(x))
      final result = composedFunction(
          5); // multiplyByThree(addTwo(5)) = multiplyByThree(7) = 21

      // Assert
      expect(result, equals(21));
    });

    test(
        'Given three functions for string manipulation, '
        'when composed sequentially, '
        'then the result is the correct transformation', () {
      // Arrange
      String toUpper(final String s) => s.toUpperCase();
      String addSuffix(final String s) => '${s}_suffix';
      String prefixWith(final String prefix, final String s) => '$prefix$s';

      String addHelloPrefix(final String s) => prefixWith('hello_', s);

      // Act
      // Desired: hello_INPUT_suffix
      // addSuffix(toUpper(s)) = INPUT_suffix
      // addHelloPrefix(addSuffix(toUpper(s))) = hello_INPUT_suffix
      final composed = addHelloPrefix.compose(addSuffix.compose(toUpper));
      final result = composed('input');

      // Assert
      expect(result, equals('hello_INPUT_suffix'));
    });
  });

  group('Apply Extensions', () {
    group('Apply1', () {
      test(
          'Given a function of one argument, '
          'when apply is used, '
          'then the function is called with the argument', () {
        // Arrange
        int func(final int a) => a * 2;
        const arg = 5;

        // Act
        final result = func.apply(arg);

        // Assert
        expect(result, equals(10));
      });
    });

    group('Apply2', () {
      test(
          'Given a function of two arguments and one argument, '
          'when apply is used, '
          'then it should return a function that takes the second argument',
          () {
        // Arrange
        int func(final int a, final int b) => a + b;
        const arg1 = 10;
        const arg2 = 5;

        // Act
        final partiallyApplied = func.apply(arg1);
        final result = partiallyApplied(arg2);

        // Assert
        expect(result, equals(15));
      });
    });

    group('Apply3', () {
      test(
          'Given a function of three arguments and one argument, '
          'when apply is used, '
          'then it should return a function that takes the remaining two arguments',
          () {
        // Arrange
        String func(final String a, final String b, final String c) =>
            '$a $b $c';
        const arg1 = 'Hello';
        const arg2 = 'World';
        const arg3 = '!';

        // Act
        final partiallyApplied = func.apply(arg1);
        final result = partiallyApplied(arg2, arg3);

        // Assert
        expect(result, equals('Hello World !'));
      });
    });

    group('Apply4', () {
      test(
          'Given a function of four arguments and one argument, '
          'when apply is used, '
          'then it should return a function that takes the remaining three arguments',
          () {
        // Arrange
        int func(final int a, final int b, final int c, final int d) =>
            a + b + c + d;
        const arg1 = 1;
        const arg2 = 2;
        const arg3 = 3;
        const arg4 = 4;

        // Act
        final partiallyApplied = func.apply(arg1);
        final result = partiallyApplied(arg2, arg3, arg4);

        // Assert
        expect(result, equals(10));
      });
    });
  });

  group('Pack Extensions', () {
    group('Pack1', () {
      test(
          'Given a function of one argument, '
          'when pack is used, '
          'then it should return a function that takes a 1-tuple', () {
        // Arrange
        int func(final int a) => a * 2;
        const tuple = (5,);

        // Act
        final packedFunc = func.pack;
        final result = packedFunc(tuple);

        // Assert
        expect(result, equals(10));
      });
    });

    group('Pack2', () {
      test(
          'Given a function of two arguments, '
          'when pack is used, '
          'then it should return a function that takes a 2-tuple', () {
        // Arrange
        int func(final int a, final int b) => a + b;
        const tuple = (10, 5);

        // Act
        final packedFunc = func.pack;
        final result = packedFunc(tuple);

        // Assert
        expect(result, equals(15));
      });
    });

    group('Pack3', () {
      test(
          'Given a function of three arguments, '
          'when pack is used, '
          'then it should return a function that takes a 3-tuple', () {
        // Arrange
        String func(final String a, final String b, final String c) =>
            '$a $b $c';
        const tuple = ('Hello', 'World', '!');

        // Act
        final packedFunc = func.pack;
        final result = packedFunc(tuple);

        // Assert
        expect(result, equals('Hello World !'));
      });
    });

    group('Pack4', () {
      test(
          'Given a function of four arguments, '
          'when pack is used, '
          'then it should return a function that takes a 4-tuple', () {
        // Arrange
        int func(final int a, final int b, final int c, final int d) =>
            a + b + c + d;
        const tuple = (1, 2, 3, 4);

        // Act
        final packedFunc = func.pack;
        final result = packedFunc(tuple);

        // Assert
        expect(result, equals(10));
      });
    });
  });
}
