class RepositoryException implements Exception {
  RepositoryException({
    required this.code,
    required this.message,
    this.cause,
    this.stackTrace,
  });

  final String code;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() {
    final buffer =
        StringBuffer('RepositoryException(code: ')
          ..write(code)
          ..write(', message: ')
          ..write(message);
    if (cause != null) {
      buffer
        ..write(', cause: ')
        ..write(cause);
    }
    buffer.write(')');
    return buffer.toString();
  }
}
