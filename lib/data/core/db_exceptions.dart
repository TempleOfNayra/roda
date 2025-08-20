import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => message;
}

class AuthException extends AppException {
  AuthException(super.message, {super.code, super.originalError});
}

class DatabaseException extends AppException {
  DatabaseException(super.message, {super.code, super.originalError});
}

class StorageException extends AppException {
  StorageException(super.message, {super.code, super.originalError});
}

class NetworkException extends AppException {
  NetworkException(super.message, {super.code, super.originalError});
}

class ValidationException extends AppException {
  ValidationException(super.message, {super.code, super.originalError});
}

class NotFoundException extends AppException {
  NotFoundException(super.message, {super.code, super.originalError});
}

class PermissionException extends AppException {
  PermissionException(super.message, {super.code, super.originalError});
}

class ExceptionMapper {
  static AppException mapSupabaseError(dynamic error) {
    if (error is AuthException) {
      return error;
    }
    
    if (error is PostgrestException) {
      final code = error.code;
      final message = error.message;
      
      if (code == '23505') {
        return DatabaseException('Record already exists', code: code, originalError: error);
      } else if (code == '23503') {
        return DatabaseException('Referenced record does not exist', code: code, originalError: error);
      } else if (code == '42501') {
        return PermissionException('Insufficient permissions', code: code, originalError: error);
      } else if (code == 'PGRST116') {
        return NotFoundException('Record not found', code: code, originalError: error);
      } else {
        return DatabaseException(message, code: code, originalError: error);
      }
    }
    
    if (error is StorageException) {
      return error;
    }
    
    if (error.toString().contains('SocketException') || 
        error.toString().contains('NetworkException')) {
      return NetworkException('Network error occurred', originalError: error);
    }
    
    return DatabaseException('An unexpected error occurred', originalError: error);
  }
  
  static String getUserFriendlyMessage(AppException exception) {
    if (exception is AuthException) {
      if (exception.code == 'invalid_credentials') {
        return 'Invalid email or password';
      } else if (exception.code == 'user_not_found') {
        return 'User not found';
      } else if (exception.code == 'email_not_confirmed') {
        return 'Please verify your email address';
      }
      return 'Authentication failed';
    }
    
    if (exception is DatabaseException) {
      if (exception.message.contains('already exists')) {
        return 'This record already exists';
      }
      return 'Database operation failed';
    }
    
    if (exception is StorageException) {
      return 'File operation failed';
    }
    
    if (exception is NetworkException) {
      return 'Please check your internet connection';
    }
    
    if (exception is ValidationException) {
      return exception.message;
    }
    
    if (exception is NotFoundException) {
      return 'The requested item was not found';
    }
    
    if (exception is PermissionException) {
      return 'You do not have permission to perform this action';
    }
    
    return 'Something went wrong. Please try again.';
  }
}