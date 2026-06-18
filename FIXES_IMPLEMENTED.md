# SymTrack App - Backend Integration Fixes

## Summary of Issues Fixed

Three critical backend integration issues have been identified and fixed:

1. **Chatbot Backend Connection Error** - 500 errors on chat messages
2. **Diet Plan Age Display** - Shows age ranges instead of exact age
3. **Login & Signup Verification** - Missing database sync and persistence

---

## Issue 1: Chatbot Backend Connection Error

### Root Cause
- Missing input validation in backend `/chat` endpoint
- Inadequate error handling with generic 500 responses
- Poor error logging making debugging difficult
- No error information returned to frontend

### Files Modified

#### 1. Backend: `symptrack_flutter/backend/chat_server.py`
**Lines 220-260** - Complete rewrite of `/chat` endpoint

**Changes:**
- Added request data validation (empty message check)
- Added try-catch around `get_disease()` call with specific error messages
- Ensure `conditions` is always a list
- Added detailed logging with `[CHAT]` prefix
- Return meaningful error messages instead of generic 500 errors
- Handle 400 (bad request) for empty/invalid messages
- Include debug info in development mode

**Key Improvements:**
```python
# NOW: Validate input
user_input = data.get("message", "").strip()
if not user_input:
    return jsonify({"error": "Message cannot be empty", ...}), 400

# NOW: Separate error handling for chatbot vs endpoint
try:
    conditions = get_disease(user_input)
except Exception as chatbot_error:
    print(f"[CHATBOT ERROR] {str(chatbot_error)}")
    return jsonify({"error": "Chatbot processing failed", ...}), 500

# NOW: Ensure conditions is list
if not isinstance(conditions, list):
    conditions = [str(conditions)] if conditions else []
```

#### 2. Frontend: `lib/screens/chat_home_screen.dart`
**Lines 56-133** - Complete rewrite of `_sendToBackend()` method

**Changes:**
- Added 10-second timeout for requests (prevents hanging)
- Added detailed debug logging with `[CHAT]` prefix
- Handle 200, 400, 500 status codes separately
- Handle `error` field in response JSON
- Validate `conditions` is a list before using it
- Handle TimeoutException separately
- Provide specific, actionable error messages to user
- Added import for `dart:async`

**Key Improvements:**
```dart
// NOW: Timeout protection
.timeout(const Duration(seconds: 10))

// NOW: Log all responses
debugPrint('[CHAT] Response status: ${response.statusCode}');
debugPrint('[CHAT] Response body: ${response.body}');

// NOW: Handle error field in response
if (data['error'] != null) {
    return 'Error: ${data['error']}\n\n${data['suggestions'] ?? "Please try again."}';
}

// NOW: Handle TimeoutException
} on TimeoutException catch (_) {
    return 'Request timed out. Please check that the backend server is running...';
}
```

### Testing Checklist - Issue 1
- [ ] Start backend: `python backend/chat_server.py`
- [ ] Start frontend: `flutter run -d chrome`
- [ ] Send message: "I have a headache"
  - Expected: Get condition suggestions (not 500 error)
  - Check console for `[CHAT]` debug messages
- [ ] Send message: "fever and cough"
  - Expected: Specific disease suggestions
- [ ] Stop backend, try to send message
  - Expected: Timeout message (not generic 500)
- [ ] Send empty message
  - Expected: "Message cannot be empty" error

**Success Criteria:**
- ✅ No 500 errors on valid input
- ✅ Specific error messages shown to user
- ✅ Backend logs show clear `[CHAT]` debug messages
- ✅ Timeout errors handled gracefully

---

## Issue 2: Diet Plan Age Display

### Root Cause
- `DietPlan.ageGroup` field stored age ranges (e.g., "15-20") instead of exact age
- `getAgeGroup(age: int)` function mapped exact ages to ranges
- Display showed "Age group: 19-25" instead of "Age: 19"

### Files Modified

#### 1. Model: `lib/models/diet_plan.dart`
**Line 38** - Changed `ageGroup` field

**Before:**
```dart
final String ageGroup;
```

**After:**
```dart
final int age;
```

#### 2. Service: `lib/services/diet_plan_service.dart`
**Line 47** - Updated `_generateLocalPlan()` to use exact age

**Before:**
```dart
return DietPlan(
  title: template.title,
  ageGroup: ageGroup,
  ...
);
```

**After:**
```dart
return DietPlan(
  title: template.title,
  age: profile.age,
  ...
);
```

**Line 110** - Updated title generation in `_findDietPlan()`

**Before:**
```dart
final title = '$ageGroup $bmiCategory $dietGoal Plan ($foodPreference)';
```

**After:**
```dart
final title = '$ageGroup | $bmiCategory | $dietGoal | $foodPreference';
```

#### 3. Screen: `lib/screens/diet_plan_screen.dart`
**Line 37** - Updated display

**Before:**
```dart
Text('Age group: ${plan.ageGroup}'),
```

**After:**
```dart
Text('Age: ${plan.age}'),
```

#### 4. Backend Service: `lib/services/backend_service.dart`
**Line 109** - Updated diet plan parsing

**Before:**
```dart
ageGroup: plan['age_group'] as String,
```

**After:**
```dart
age: plan['age'] as int,
```

#### 5. Backend: `symptrack_flutter/backend/diet.py`
**Line 72** - Added exact age to response

**Before:**
```python
return {
    "template_id": row["template_id"],
    "title": row["title"],
    "age_group": row["age_group"],
    ...
}
```

**After:**
```python
return {
    "template_id": row["template_id"],
    "title": row["title"],
    "age": age,  # ← NEW: Exact age
    "age_group": row["age_group"],
    ...
}
```

### Testing Checklist - Issue 2
- [ ] Login to app, go to diet plan
- [ ] For age 19:
  - Expected: "Age: 19" (not "Age group: 15-20")
- [ ] For age 20:
  - Expected: "Age: 20" (not "Age group: 21-25")
- [ ] For age 25:
  - Expected: "Age: 25" (not "Age group: 21-25")
- [ ] For age 45:
  - Expected: "Age: 45" (not "Age group: 41-45")
- [ ] Verify title format:
  - Expected: "15-20 | Normal Weight | Maintain Weight | Veg"

**Success Criteria:**
- ✅ Exact age displayed (not range)
- ✅ All ages 15-50 display correctly
- ✅ Database still uses age groups for template lookup (internal only)

---

## Issue 3: Login & Signup Verification - Database Sync

### Root Cause
- Signup created Firebase account but didn't sync to app database
- Login only checked Firebase, not app database
- No backend user persistence
- Users not stored in `main_app_database.db` after signup

### Files Modified

#### 1. Backend Service: `lib/services/backend_service.dart`
**Lines 38-56** - Added `getUser()` method

**New Method:**
```dart
Future<Map<String, dynamic>?> getUser(String firebaseUid) async {
  try {
    final response = await http
        .get(Uri.parse('$_baseUrl/users/$firebaseUid'))
        .timeout(const Duration(seconds: 5));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['user'] as Map<String, dynamic>?;
    } else if (response.statusCode == 404) {
      return null;  // User not found
    }
    return null;
  } catch (e) {
    debugPrint('Backend getUser failed: $e');
    return null;
  }
}
```

#### 2. Signup Screen: `lib/screens/signup_screen.dart`
**Line 2** - Added import for BackendService

**Before:**
```dart
import 'package:firebase_auth/firebase_auth.dart';
```

**After:**
```dart
import 'package:firebase_auth/firebase_auth.dart';
import '../services/backend_service.dart';
```

**Lines 55-80** - Added backend sync after Firebase signup

**Before:**
```dart
await FirebaseAuth.instance.createUserWithEmailAndPassword(...);

if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(...);
  Navigator.pushReplacementNamed(context, '/home');
}
```

**After:**
```dart
final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(...);

// Sync user to backend database
if (userCredential.user != null) {
  try {
    await BackendService().syncUser(
      firebaseUid: userCredential.user!.uid,
      email: userCredential.user!.email ?? usernameController.text.trim(),
      name: userCredential.user!.displayName,
      authProvider: 'email',
    );
    debugPrint('[SIGNUP] User synced to backend: ${userCredential.user!.uid}');
  } catch (syncError) {
    debugPrint('[SIGNUP] Warning: Failed to sync user to backend: $syncError');
    // Don't block signup if backend sync fails
  }
}

if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(...);
  Navigator.pushReplacementNamed(context, '/home');
}
```

#### 3. Login Screen: `lib/screens/login_screen.dart`
**Line 2** - Added import for BackendService

**Before:**
```dart
import 'package:firebase_auth/firebase_auth.dart';
```

**After:**
```dart
import 'package:firebase_auth/firebase_auth.dart';
import '../services/backend_service.dart';
```

**Lines 22-72** - Complete rewrite of `_login()` method

**Before:**
```dart
Future<void> _login() async {
  ...
  await FirebaseAuth.instance.signInWithEmailAndPassword(...);
  if (mounted) {
    Navigator.pushReplacementNamed(context, '/home');
  }
}
```

**After:**
```dart
Future<void> _login() async {
  ...
  debugPrint('[LOGIN] Attempting Firebase authentication...');
  final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(...);
  debugPrint('[LOGIN] Firebase auth successful: ${userCredential.user?.uid}');
  
  // Verify user exists in backend database
  if (userCredential.user != null) {
    try {
      debugPrint('[LOGIN] Verifying user in backend...');
      final backendUser = await BackendService().getUser(userCredential.user!.uid);
      
      if (backendUser == null) {
        debugPrint('[LOGIN] User not found in backend, syncing...');
        await BackendService().syncUser(...);
        debugPrint('[LOGIN] User synced to backend');
      } else {
        debugPrint('[LOGIN] User found in backend database');
      }
    } catch (backendError) {
      debugPrint('[LOGIN] Warning: Backend verification failed: $backendError');
      // Don't block login
    }
  }
  
  if (mounted) {
    Navigator.pushReplacementNamed(context, '/home');
  }
}
```

**Lines 59-65** - Improved error messages

**Before:**
```dart
'user-not-found': 'No user found with this email',
'wrong-password': 'Incorrect password',
```

**After:**
```dart
'user-not-found': 'No user found with this email. Please sign up first.',
'wrong-password': 'Incorrect password. Please try again.',
'invalid-email': 'Invalid email address',
'user-disabled': 'This account has been disabled',
```

#### 4. Backend Database Schema: `backend/init_app_db.py`
**NO CHANGES NEEDED** - Schema already supports users table (verified existing)

```sql
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    firebase_uid TEXT UNIQUE NOT NULL,
    email TEXT NOT NULL,
    name TEXT,
    auth_provider TEXT DEFAULT 'email',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Testing Checklist - Issue 3

#### Signup Test
- [ ] Start backend and frontend
- [ ] Click "Sign up"
- [ ] Enter: email = `test@example.com`, password = `password123`
- [ ] Click "Sign up" button
- [ ] Expected: Success message, redirected to /home
- [ ] Check backend logs:
  - Should see `[SIGNUP] User synced to backend: <firebase_uid>`
- [ ] Query database:
  ```bash
  sqlite3 main_app_database.db "SELECT * FROM users WHERE email='test@example.com';"
  ```
  - Expected: One row with firebase_uid, email, auth_provider='email'

#### Login Test - New User
- [ ] Click "Don't have an account? Sign up" from login screen
- [ ] Repeat signup with: email = `newuser@test.com`, password = `password123`
- [ ] Should see in backend logs:
  - `[SIGNUP] User synced to backend: <uid>`
- [ ] Logout (if available) or close app
- [ ] Login with: email = `newuser@test.com`, password = `password123`
- [ ] Should see in backend logs:
  - `[LOGIN] Attempting Firebase authentication...`
  - `[LOGIN] Firebase auth successful: <uid>`
  - `[LOGIN] Verifying user in backend...`
  - `[LOGIN] User found in backend database`
- [ ] Expected: Redirected to /home

#### Database Verification
- [ ] After signup and login, verify database:
  ```bash
  sqlite3 main_app_database.db "SELECT firebase_uid, email, auth_provider FROM users;"
  ```
  - Expected: Multiple rows with all recent signups

#### Edge Cases
- [ ] Signup with existing email
  - Expected: "Email already exists. Please log in."
- [ ] Login with non-existent email
  - Expected: "No user found with this email. Please sign up first."
- [ ] Login with wrong password
  - Expected: "Incorrect password. Please try again."
- [ ] Stop backend, attempt login
  - Expected: Should still login (doesn't block), with warning in logs

**Success Criteria:**
- ✅ Users synced to backend after signup
- ✅ Users verified in backend during login
- ✅ User records appear in `main_app_database.db`
- ✅ firebase_uid, email, auth_provider are correct
- ✅ Login doesn't block if backend temporarily unavailable

---

## Complete Testing Workflow

### 1. Environment Setup
```bash
# Terminal 1: Start Backend
cd symptrack_flutter/backend
python chat_server.py
# Expected: "Running on http://127.0.0.1:5000" (or similar)

# Terminal 2: Start Frontend
cd symptrack_flutter
flutter run -d chrome
# Expected: App opens in Chrome on localhost
```

### 2. Issue 1: Chatbot Testing
- Send messages with symptoms
- Verify no 500 errors
- Check browser console and backend terminal for `[CHAT]` logs

### 3. Issue 2: Diet Plan Testing
- Complete signup and wellness profile
- Navigate to diet plan
- Verify exact age displayed (e.g., "Age: 19" not "Age group: 15-20")

### 4. Issue 3: Auth Testing
- Test fresh signup with new email
- Verify user appears in database
- Test login with created credentials
- Verify backend sync messages in logs

### 5. Database Verification
```bash
# Check users table
sqlite3 main_app_database.db
SELECT * FROM users;

# Check wellness profiles
SELECT * FROM wellness_profiles;

# Check database was initialized
.schema
```

---

## Debugging Information

### Backend Logs to Watch For

**Successful Chatbot Message:**
```
[CHAT] Received message: I have a headache
[CHAT] Detected conditions: ['Migraine', 'Tension Headache']
[CHAT] Response: {...}
```

**Chatbot Error:**
```
[CHATBOT ERROR] <error_message>
Traceback (most recent call last):
  ...
[CHAT] Response: {"error": "Chatbot processing failed", ...}
```

**Successful Signup Sync:**
```
[SIGNUP] User synced to backend: abc123def456
```

**Successful Login:**
```
[LOGIN] Attempting Firebase authentication for user@email.com
[LOGIN] Firebase auth successful: abc123def456
[LOGIN] Verifying user in backend...
[LOGIN] User found in backend database
```

### Frontend Logs to Watch For (Console)
- Look for `[CHAT]`, `[SIGNUP]`, `[LOGIN]` prefixed debug messages
- Status codes and response bodies for all API calls
- Error details for connection issues

### Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| 500 error on chat | `get_disease()` fails | Check chatbot.py, database connection, imports |
| Age shows as range | Old ageGroup field | Rebuild app (`flutter clean`, `flutter pub get`) |
| Signup succeeds but user not in DB | Backend sync not called | Verify imports in signup_screen.dart |
| Login succeeds but backend verify fails | Backend not running | Ensure chat_server.py is running |
| Timeout errors on login | Backend response slow | Check backend for sync_user logs |

---

## Files Changed Summary

### Backend (Python)
- `backend/chat_server.py` - Improved `/chat` error handling
- `backend/diet.py` - Added exact age to response

### Frontend (Dart)
- `lib/models/diet_plan.dart` - Changed `ageGroup: String` to `age: int`
- `lib/services/diet_plan_service.dart` - Use exact age in generation
- `lib/services/backend_service.dart` - Added `getUser()` method
- `lib/screens/chat_home_screen.dart` - Improved error handling, added logging
- `lib/screens/diet_plan_screen.dart` - Display exact age
- `lib/screens/signup_screen.dart` - Added backend sync after Firebase signup
- `lib/screens/login_screen.dart` - Added backend verification after Firebase login

### Total Changes
- **8 files modified**
- **~250 lines added** (error handling, logging, backend sync)
- **~50 lines removed** (old error handling, age group logic)

---

## Next Steps

1. Rebuild Flutter app: `flutter clean && flutter pub get`
2. Restart backend server
3. Run complete testing workflow above
4. Monitor logs for issues
5. If problems persist, check:
   - Backend `/health` endpoint returns 200
   - Database initialization ran successfully
   - All required Python packages installed

---

## Questions & Support

If you encounter issues:

1. **Check Backend Logs** - Look for `[CHAT]`, `[SIGNUP]`, `[LOGIN]` messages
2. **Check Frontend Console** - Browser DevTools → Console tab
3. **Verify Database** - Run SQLite queries to check user records
4. **Check Network** - Browser DevTools → Network tab for API calls
5. **Restart Services** - Restart backend and frontend if needed
