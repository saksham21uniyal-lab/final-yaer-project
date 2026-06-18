# Quick Reference - Testing the Fixes

## Before You Start
1. Rebuild the app: `flutter clean && flutter pub get`
2. Terminal 1: `cd backend && python chat_server.py` (should show "Running on http://127.0.0.1:5000")
3. Terminal 2: `flutter run -d chrome`

---

## Test 1: Chatbot (Issue #1) ✅ Fixed

**What was broken:** 500 errors on chat messages  
**What's fixed:** Better error handling, detailed logging, meaningful error messages

### Quick Test:
1. Open Chat tab
2. Send message: "I have a headache"
3. ✅ Expected: Get suggested conditions (NOT 500 error)
4. Check browser console: Should see `[CHAT]` debug messages
5. Check backend terminal: Should see `[CHAT]` log messages

**Error Messages You'll NOW See Instead of Generic 500:**
- "Message cannot be empty" - If you send empty message
- "Chatbot processing failed. Please try again." - If chatbot module fails
- "Request timed out..." - If backend doesn't respond in 10 seconds
- Specific condition suggestions - If successful

---

## Test 2: Diet Plan Age (Issue #2) ✅ Fixed

**What was broken:** Showed "Age group: 19-25" instead of "Age: 19"  
**What's fixed:** Now displays exact age entered

### Quick Test:
1. Signup with age 19
2. Go to Wellness Profile → Diet Plan
3. ✅ Expected: Shows "Age: 19" (NOT "Age group: 15-20")

### More Tests:
- Age 20 → Should show "Age: 20"
- Age 25 → Should show "Age: 25"  
- Age 45 → Should show "Age: 45"

---

## Test 3: Signup & Login Database Sync (Issue #3) ✅ Fixed

**What was broken:** Users not saved to database after signup  
**What's fixed:** Backend database sync after signup, verification during login

### Quick Test - Signup:
1. Click "Sign up"
2. Email: `test1@example.com`
3. Password: `password123`
4. ✅ Expected: "Account created successfully" message
5. Check browser console: Should see `[SIGNUP] User synced to backend: <uid>`
6. Check backend terminal: Should see same message

### Quick Test - Login:
1. Logout (or restart app)
2. Click "Sign in"
3. Email: `test1@example.com`
4. Password: `password123`
5. ✅ Expected: Redirected to home
6. Check browser console: Should see `[LOGIN] User found in backend database`
7. Check backend terminal: Should see backend verification messages

### Database Verification:
```bash
sqlite3 main_app_database.db
SELECT * FROM users;
```
✅ Expected: Should see users table with your test accounts

---

## What You Should See in Logs

### Backend Terminal (after running python chat_server.py)
```
[SIGNUP] User synced to backend: abc123def456
[LOGIN] Attempting Firebase authentication...
[LOGIN] Firebase auth successful: abc123def456
[LOGIN] Verifying user in backend...
[LOGIN] User found in backend database

[CHAT] Received message: I have a headache
[CHAT] Detected conditions: ['Migraine', 'Tension Headache']
[CHAT] Response: {...}
```

### Browser Console (F12 → Console tab)
```
[CHAT] Sending message to backend
[CHAT] Response status: 200
[CHAT] Parsed conditions: ['Migraine']

[SIGNUP] User synced to backend: abc123def456
[LOGIN] Verifying user in backend database
[LOGIN] User found in backend database
```

---

## If Something Goes Wrong

| Symptom | Check |
|---------|-------|
| Still getting 500 errors | Backend running? Browser console shows `[CHAT]` logs? |
| Age still showing as range | Did you rebuild? (`flutter clean && flutter pub get`) |
| Users not appearing in DB | Check browser/backend console for `[SIGNUP]` message |
| Login says "User not found" | Try signing up again (fresh email) |
| Timeout errors | Is backend running? `python chat_server.py` in terminal? |

---

## Success Checklist

- [ ] Chatbot: Send message → Get condition suggestions (no 500)
- [ ] Diet: Signup with age 19 → Shows "Age: 19" on diet plan
- [ ] Auth: Signup → See `[SIGNUP]` in console → User appears in database
- [ ] Auth: Login with created account → See `[LOGIN]` in console → Redirect to home
- [ ] Database: `SELECT * FROM users;` → Shows signed-up users

---

## Files That Were Changed

**Backend (3 changes):**
- `backend/chat_server.py` - Line 220+ (chat endpoint)
- `backend/diet.py` - Line 72 (added age field)

**Frontend (8 files):**
- `lib/models/diet_plan.dart` - Changed ageGroup to age
- `lib/services/diet_plan_service.dart` - Use exact age
- `lib/services/backend_service.dart` - Added getUser() method
- `lib/screens/chat_home_screen.dart` - Error handling & logging
- `lib/screens/diet_plan_screen.dart` - Display age instead of ageGroup
- `lib/screens/signup_screen.dart` - Backend sync after signup
- `lib/screens/login_screen.dart` - Backend verification after login

---

## Advanced Debugging

### Check Backend Health
```bash
curl http://localhost:5000/health
# Expected: {"status": "ok", ...}
```

### Query Wellness Profiles
```bash
sqlite3 main_app_database.db "SELECT firebase_uid, age FROM wellness_profiles;"
```

### Check Diet Database
```bash
sqlite3 feature_database.db "SELECT * FROM diet_plan_templates LIMIT 1;"
```

### Enable Backend Debug Mode
In `chat_server.py`, uncomment:
```python
if __name__ == '__main__':
    app.run(debug=True, port=5000)  # Debug mode = verbose logging
```

---

**For complete details, see: FIXES_IMPLEMENTED.md**
