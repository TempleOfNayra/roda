import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roda/data/core/db_exceptions.dart';
import 'package:roda/core/utils/logger.dart';

abstract class BaseRepository {
  final Ref ref;
  
  BaseRepository(this.ref);
  
  Future<T> executeWithErrorHandling<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    try {
      return await operation();
    } catch (e, stack) {
      final appException = ExceptionMapper.mapSupabaseError(e);
      Logger.debug('${operationName ?? 'Operation'} failed: ${appException.message}');
      Logger.debug('Stack trace: $stack');
      throw appException;
    }
  }
  
  Future<T?> executeWithNullableResult<T>(
    Future<T?> Function() operation, {
    String? operationName,
  }) async {
    try {
      return await operation();
    } catch (e, stack) {
      final appException = ExceptionMapper.mapSupabaseError(e);
      
      if (appException is NotFoundException) {
        return null;
      }
      
      Logger.debug('${operationName ?? 'Operation'} failed: ${appException.message}');
      Logger.debug('Stack trace: $stack');
      throw appException;
    }
  }
  
  Stream<T> executeStream<T>(
    Stream<T> Function() streamOperation, {
    String? operationName,
  }) {
    return streamOperation().handleError((error, stack) {
      final appException = ExceptionMapper.mapSupabaseError(error);
      Logger.debug('${operationName ?? 'Stream operation'} error: ${appException.message}');
      Logger.debug('Stack trace: $stack');
      throw appException;
    });
  }
  
  Future<void> retryOperation(
    Future<void> Function() operation, {
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 1),
  }) async {
    int attempts = 0;
    
    while (attempts < maxAttempts) {
      try {
        await operation();
        return;
      } catch (e) {
        attempts++;
        
        if (attempts >= maxAttempts) {
          rethrow;
        }
        
        final appException = ExceptionMapper.mapSupabaseError(e);
        
        if (appException is NetworkException) {
          await Future.delayed(delay * attempts);
        } else {
          rethrow;
        }
      }
    }
  }
}