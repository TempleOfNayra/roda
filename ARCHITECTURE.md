# Roda App Architecture

## Overview
The app follows a clean architecture pattern with clear separation of concerns:

```
lib/
├── core/                    # Core models, configs, constants, utils
│   ├── models/             # Pure data models (fromJson/toJson only)
│   ├── config/             # App configuration
│   └── utils/              # Utility functions
├── data/                    # Data layer (repositories, DB access)
│   ├── core/               # Base repository, exceptions, client setup
│   └── repositories/       # Repository implementations
├── application/             # Business logic layer (controllers)
│   └── *_controller.dart   # Controllers orchestrate repositories
├── features/                # UI layer (legacy structure, being migrated)
│   └── */                  # Feature modules with pages/widgets
└── main.dart               # App entry point
```

## Layer Responsibilities

### 1. Models Layer (`core/models/`)
- **Purpose**: Define data structures
- **Rules**: 
  - Pure data classes with serialization only
  - No business logic, no network calls
  - Methods: `fromJson()`, `toJson()`, `copyWith()`

### 2. Data Layer (`data/`)
- **Purpose**: Handle all external data operations
- **Components**:
  - `repositories/`: Database operations, API calls
  - `core/supabase_client.dart`: Centralized Supabase client
  - `core/db_exceptions.dart`: Error mapping and handling
  - `core/base_repository.dart`: Common repository patterns

- **Rules**:
  - Only repositories talk to Supabase
  - All errors are mapped to app-specific exceptions
  - No UI code, no business logic

### 3. Application Layer (`application/`)
- **Purpose**: Business logic and orchestration
- **Components**:
  - Controllers coordinate between repositories
  - Handle complex business rules
  - Manage state transitions

- **Rules**:
  - No direct Supabase/database calls
  - Use repositories for data operations
  - Throw app-specific exceptions

### 4. Presentation Layer (`features/`)
- **Purpose**: UI components and user interaction
- **Rules**:
  - No direct repository calls
  - Use controllers via Riverpod providers
  - Handle only UI-specific logic

## Dependency Injection

All dependencies are provided via Riverpod:

```dart
// Client providers
final supabaseClientProvider = Provider<SupabaseClient>(...);

// Repository providers
final authRepositoryProvider = Provider<AuthRepository>(...);
final userRepositoryProvider = Provider<UserRepository>(...);
final groupRepositoryProvider = Provider<GroupRepository>(...);

// Controller providers
final authControllerProvider = Provider<AuthController>(...);
final groupControllerProvider = Provider<GroupController>(...);

// State providers
final authStateProvider = StreamProvider<User?>(...);
final currentUserProvider = StreamProvider<UserModel?>(...);
```

## Error Handling

All errors are mapped to app-specific exceptions:

```dart
abstract class AppException
├── AuthException       // Authentication errors
├── DatabaseException   // Database operation errors
├── StorageException    // File storage errors
├── NetworkException    // Network connectivity errors
├── ValidationException // Input validation errors
├── NotFoundException   // Resource not found errors
└── PermissionException // Authorization errors
```

## Best Practices

### 1. Repository Pattern
```dart
class UserRepository extends BaseRepository {
  Future<UserModel> createUser(UserModel user) {
    return executeWithErrorHandling(() async {
      // Database operation
    });
  }
}
```

### 2. Controller Pattern
```dart
class AuthController {
  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  
  Future<UserModel> signIn() async {
    try {
      final auth = await _authRepository.signIn();
      return await _userRepository.getUser(auth.userId);
    } catch (e) {
      throw ExceptionMapper.mapError(e);
    }
  }
}
```

### 3. RLS-First Database Design
- Use join tables instead of array fields
- Implement `INSERT ... ON CONFLICT` patterns
- Let Row Level Security handle permissions

### 4. Testing Strategy
- Mock repositories for controller tests
- Mock controllers for UI tests
- Use `BaseRepository` helpers for consistent error handling

## Migration Path

### Legacy Code
- `features/*/providers/` - Being migrated to controllers
- `features/*/repositories/` - Being moved to `data/repositories/`
- Direct `SupabaseConfig.client` usage - Being replaced with DI

### New Code
- All new features use the clean architecture
- Backward compatibility maintained via wrapper services
- Gradual migration of existing features

## Key Files

- `data/core/supabase_client.dart` - Supabase client setup
- `data/core/base_repository.dart` - Repository base class
- `data/core/db_exceptions.dart` - Exception handling
- `application/auth_controller.dart` - Auth business logic
- `application/group_controller.dart` - Group business logic
- `data/repositories/*_repository.dart` - Data operations

## Environment Configuration

- Supabase URL and keys in `core/config/supabase_config.dart`
- Feature flags in `main.dart` (e.g., `useMockMode`)
- Environment-specific configs in respective config files