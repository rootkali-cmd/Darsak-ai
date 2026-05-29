sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

final class Failure<T> extends Result<T> {
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
  const Failure(this.message, {this.error, this.stackTrace});
}

extension ResultExtensions<T> on Result<T> {
  T get OrThrow => switch (this) {
        Success(data: final d) => d,
        Failure(message: final m) => throw Exception(m),
      };

  T OrDefault(T defaultValue) => switch (this) {
        Success(data: final d) => d,
        Failure() => defaultValue,
      };
}
