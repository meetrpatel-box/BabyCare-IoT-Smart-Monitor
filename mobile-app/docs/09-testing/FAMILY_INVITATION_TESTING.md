# Family Invitation Feature - Testing Guide

## Overview
The family invitation feature allows users to invite family members to share baby profiles and real-time vitals monitoring. This completes the multi-user sharing architecture validated by integration tests.

## Feature Implementation

### 1. **Backend (Already Complete)**
- ✅ `FamilyService` with `inviteMember()` and `acceptInvite()` methods
- ✅ Integration Test 7: Family Member Invitation (PASSING)
- ✅ Firestore collections: `familyInvites` with 7-day expiry
- ✅ Multi-user access to babies via `family.babyIds` array

### 2. **Frontend UI (Just Created)**

#### A. Family Invite Screen (`family_invite_screen.dart`)
**Location:** `/baby_track_flutter/lib/screens/settings/family_invite_screen.dart`

**Features:**
- TabController with 3 invitation methods
- Email, QR Code, and Invite Code tabs
- Complete UI with validation and error handling

**Tab 1: Email Invitation**
- Email input field with validation (regex)
- `_sendEmailInvite()` method:
  * Validates email format
  * Calls `FamilyService.inviteMember()`
  * Creates `familyInvites` document in Firestore
  * Shows success/error snackbars
- 7-day expiry notice displayed

**Tab 2: QR Code**
- `QrImageView` widget (250x250 size)
- Generates invite link: `https://babycare.app/invite/{familyId}?code={code}`
- `qr_flutter` package: ^4.1.0 ✅ INSTALLED
- Share button (currently copies link to clipboard)
- Error correction level: High
- White container with shadow

**Tab 3: Invite Code**
- 8-character uppercase code (from `inviteId.substring(0, 8)`)
- Copy to clipboard functionality
- Step-by-step instructions:
  1. Copy the invite code
  2. Share via text or messaging app
  3. Recipient enters code in app
  4. They join your family
- Monospace font for readability

#### B. Settings Screen Integration
**File:** `/baby_track_flutter/lib/screens/settings/settings_screen.dart`

**Changes:**
1. Added `_buildFamilyInviteSection()` method - Returns Card with "Invite Family Member" ListTile
2. Called from build method after Baby Profiles section
3. Navigation: `context.push('/settings/invite-family', extra: {...})`
4. Shows icon (Icons.person_add), title, subtitle
5. Only displayed if user has a familyId

#### C. Navigation Setup
**File:** `/baby_track_flutter/lib/navigation/app_router.dart`

**Changes:**
1. Added import: `import '../screens/settings/family_invite_screen.dart';`
2. Added route:
```dart
GoRoute(
  path: 'invite-family',
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>?;
    return FamilyInviteScreen(
      familyId: extra?['familyId'] ?? '',
      familyName: extra?['familyName'] ?? 'Family',
    );
  },
)
```

## Testing Flow

### Manual Test Scenario 1: Email Invitation

1. **Setup:**
   - Run Flutter app: `cd baby_track_flutter && flutter run -d web-server --web-port 8080`
   - Login as User A
   - Ensure baby profile exists

2. **Send Invitation:**
   - Navigate to Settings
   - Click "Invite Family Member" card
   - Select "Email" tab
   - Enter partner's email: `partner@example.com`
   - Click "Send Invitation" button
   - Verify success message

3. **Verify Database:**
   ```javascript
   // Check Firestore in Firebase Console
   db.collection('familyInvites').where('email', '==', 'partner@example.com').get()
   ```
   - Should see document with:
     * `familyId`: User A's family ID
     * `email`: partner@example.com
     * `status`: 'pending'
     * `expiresAt`: 7 days from now
     * `invitedBy`: User A's ID

### Manual Test Scenario 2: QR Code Invitation

1. **Generate QR Code:**
   - Navigate to Settings → Invite Family Member
   - Select "QR Code" tab
   - QR code should render (250x250)
   - Verify invite link displays below QR

2. **Share QR Code:**
   - Click "Share Invite Link" button
   - Verify clipboard contains link: `https://babycare.app/invite/{familyId}?code={code}`
   - Verify snackbar: "Invite link copied to clipboard"

3. **Scan QR Code (Future):**
   - Open on mobile device
   - Scan with QR scanner app
   - Should redirect to invite acceptance screen (TO BE IMPLEMENTED)

### Manual Test Scenario 3: Invite Code

1. **Generate Code:**
   - Navigate to Settings → Invite Family Member
   - Select "Invite Code" tab
   - 8-character code should display in large monospace font

2. **Copy Code:**
   - Click "Copy Invite Code" button
   - Verify clipboard contains code
   - Verify snackbar confirmation

3. **Share Code:**
   - Send code via text/messaging app
   - Recipient enters code in app (acceptance screen TO BE IMPLEMENTED)

### Integration Test Verification

The backend functionality is already verified by automated integration tests:

```bash
cd /workspaces/BabyCareApp/test-integration
npm test
```

**Test 7: Family Member Invitation** ✅
- Creates User A with family and baby
- Creates User B
- User A sends invitation
- User B accepts invitation
- User B added to `family.members` array
- User B's `familyIds` includes family
- User B can query vitals via familyId
- Both users see same real-time vitals

## Known Limitations

### 1. Invite Acceptance Screen - NOT YET IMPLEMENTED
**What's Missing:**
- No UI for recipients to accept invitations
- No route: `/accept-invite/:inviteId`
- No deep linking handler for invite URLs

**What's Needed:**
```dart
// accept_invite_screen.dart
- Display family name
- Display inviter name
- Accept/Decline buttons
- Call FamilyService.acceptInvite()
- Navigate to dashboard after acceptance
```

### 2. Deep Linking - NOT CONFIGURED
**What's Missing:**
- iOS: Info.plist URL schemes
- Android: AndroidManifest.xml intent filters
- URL handling for `https://babycare.app/invite/...`

**What's Needed:**
- Firebase Dynamic Links OR Universal Links
- URL parsing logic
- Route to AcceptInviteScreen with inviteId

### 3. Email Sending - PARTIAL IMPLEMENTATION
**Current State:**
- Email invitations create Firestore document
- NO actual email sent to recipient

**What's Needed:**
- Cloud Function triggered on `familyInvites` onCreate
- Email service: SendGrid, Firebase Extensions, or Nodemailer
- Email template with invite link and instructions
- Deploy: `firebase deploy --only functions`

### 4. Invite Code Lookup - NOT IMPLEMENTED
**What's Missing:**
- No UI to enter invite code
- No query: `familyInvites` where code matches

**What's Needed:**
```dart
// In AcceptInviteScreen or separate EnterCodeScreen
1. TextField for 8-character code
2. Query Firestore for matching invite
3. Display family details if found
4. Accept/Decline flow
```

## File Changes Summary

### Created Files
1. ✅ `/baby_track_flutter/lib/screens/settings/family_invite_screen.dart` (534 lines)
   - Complete UI with 3 tabs
   - Email validation and sending
   - QR code generation
   - Invite code display and copy

### Modified Files
1. ✅ `/baby_track_flutter/lib/navigation/app_router.dart`
   - Added family_invite_screen import
   - Added /settings/invite-family route

2. ✅ `/baby_track_flutter/lib/screens/settings/settings_screen.dart`
   - Added _buildFamilyInviteSection() method
   - Called in build method after Baby Profiles

3. ✅ `/baby_track_flutter/pubspec.yaml`
   - Added `qr_flutter: ^4.1.0` dependency
   - Installed successfully with `flutter pub get`

### Existing Files (Already Complete)
- `/baby_track_flutter/lib/services/family_service.dart` - Backend methods
- `/test-integration/full_flow_integration_test.js` - Test 7 passing

## Next Steps

### Priority 1: Complete User Journey (HIGH)
1. **Create AcceptInviteScreen**
   - Display invite details (family name, inviter)
   - Accept/Decline buttons
   - Call `FamilyService.acceptInvite()` or `declineInvite()`
   - Route: `/accept-invite/:inviteId`

2. **Implement Deep Linking**
   - Configure Firebase Dynamic Links or Universal Links
   - Handle `https://babycare.app/invite/{familyId}?code={code}`
   - Parse URL and navigate to AcceptInviteScreen
   - iOS: Update Info.plist
   - Android: Update AndroidManifest.xml

3. **Add Invite Code Entry Screen**
   - TextField for 8-character code
   - Query `familyInvites` collection
   - Navigate to AcceptInviteScreen if found
   - Error handling for invalid codes

### Priority 2: Email Integration (MEDIUM)
1. **Create Cloud Function: sendInviteEmail**
   ```typescript
   // functions/src/sendInviteEmail.ts
   export const sendInviteEmail = functions.firestore
     .document('familyInvites/{inviteId}')
     .onCreate(async (snap, context) => {
       const invite = snap.data();
       // Send email with SendGrid/Firebase Extensions
       // Include invite link and QR code
     });
   ```

2. **Deploy Cloud Function**
   ```bash
   cd functions
   npm install --save sendgrid  # or firebase-extensions
   firebase deploy --only functions:sendInviteEmail
   ```

### Priority 3: Production Readiness (MEDIUM)
1. **Test on Real Devices**
   - iOS: Test QR scanning, deep links
   - Android: Test intent filters, QR scanning

2. **Security Rules Update**
   - Ensure `familyInvites` rules allow query by email or code
   - Verify expiry enforcement

3. **Error Handling**
   - Expired invitation handling
   - Already accepted invitation
   - Invalid invite codes
   - Network errors

### Priority 4: UX Improvements (LOW)
1. **Pending Invites List**
   - Show sent invitations in settings
   - Allow cancellation of pending invites
   - Show accepted/declined status

2. **Family Members List**
   - Display all family members
   - Show who has access to each baby
   - Remove member functionality (admin only)

3. **QR Code Scanning**
   - Add "Scan QR Code" button
   - Camera permission handling
   - Parse scanned invite link

## Testing Commands

```bash
# Run Flutter app
cd /workspaces/BabyCareApp/baby_track_flutter
flutter run -d web-server --web-port 8080

# Run integration tests
cd /workspaces/BabyCareApp/test-integration
npm test

# Check specific test
npm test -- --grep "Family Member Invitation"

# Clean and reinstall dependencies
cd /workspaces/BabyCareApp/baby_track_flutter
flutter clean
flutter pub get

# Check for compilation errors
flutter analyze
```

## Success Criteria

✅ **Current Implementation (COMPLETE):**
- [x] Backend family invitation methods working
- [x] Integration Test 7 passing (multi-user sharing validated)
- [x] FamilyInviteScreen created with 3 tabs
- [x] Settings screen shows "Invite Family Member" button
- [x] Navigation configured
- [x] qr_flutter package installed
- [x] Email tab with validation
- [x] QR code generation working
- [x] Invite code display and copy working
- [x] No compilation errors

❌ **Missing Implementation (TO DO):**
- [ ] AcceptInviteScreen for recipients
- [ ] Deep linking configuration
- [ ] URL handling for invite links
- [ ] Email sending via Cloud Functions
- [ ] Invite code entry screen
- [ ] Pending invites list in settings
- [ ] Family members list screen
- [ ] QR code scanning functionality

## Architecture Diagram

```
User A (Inviter)                    User B (Recipient)
    │                                      │
    ├─ Creates Baby + Family               │
    │                                      │
    ├─ Settings → Invite Family Member     │
    │     │                                │
    │     ├─ Email Tab ──> Enter email     │
    │     │     └─> FamilyService.inviteMember()
    │     │           └─> Firestore: familyInvites (pending)
    │     │                 └─> Cloud Function: sendInviteEmail
    │     │                       └─> Email to User B ─────────►│
    │     │                                                    │
    │     ├─ QR Code Tab ──> Generate QR                      │
    │     │     └─> QrImageView                               │
    │     │           └─> Link: babycare.app/invite/...       │
    │     │                 └─> User B scans QR ──────────────►│
    │     │                                                    │
    │     └─ Invite Code Tab ──> 8-char code                  │
    │           └─> Copy to clipboard                         │
    │                 └─> Share via text ─────────────────────►│
    │                                                          │
    │                                      │                  │
    │                                      ├─ Receives invite │
    │                                      ├─ AcceptInviteScreen
    │                                      ├─ Accept/Decline  │
    │                                      │     │            │
    │                                      │     └─> FamilyService.acceptInvite()
    │                                      │           │      │
    │                                      │           └─> Updates:
    │                                      │               - family.members += User B
    │                                      │               - user.familyIds += familyId
    │                                      │               - invite.status = 'accepted'
    │                                      │                  │
    ├─ Dashboard: See vitals for Baby ◄────────────────────├─ Dashboard: See same vitals
    └─ Real-time updates                                    └─ Real-time updates
```

## Firestore Data Flow

```javascript
// 1. User A sends invitation
db.collection('familyInvites').add({
  familyId: 'family123',
  email: 'userB@example.com',
  invitedBy: 'userA-uid',
  status: 'pending',
  createdAt: serverTimestamp(),
  expiresAt: timestamp(+7 days),
  code: 'ABC12345'  // 8-char code
});

// 2. User B accepts invitation
// (Via AcceptInviteScreen - TO BE IMPLEMENTED)
await FamilyService.acceptInvite(inviteId);

// Updates:
db.collection('families').doc('family123').update({
  members: arrayUnion('userB-uid')
});

db.collection('users').doc('userB-uid').update({
  familyIds: arrayUnion('family123')
});

db.collection('familyInvites').doc(inviteId).update({
  status: 'accepted',
  acceptedAt: serverTimestamp()
});

// 3. User B queries vitals
db.collection('vital_signs')
  .where('babyId', 'in', family.babyIds)  // Shared access
  .orderBy('timestamp', 'desc')
  .limit(50);
```

## Conclusion

**Backend:** ✅ 100% Complete and Tested
- FamilyService methods working
- Integration tests passing
- Multi-user sharing validated

**Frontend:** 🟡 60% Complete
- ✅ Invitation sending UI (Email, QR, Code)
- ✅ Settings integration
- ✅ Navigation setup
- ❌ Invitation acceptance UI
- ❌ Deep linking
- ❌ Email sending Cloud Function

**Next Session Focus:**
1. Create AcceptInviteScreen
2. Configure deep linking
3. Test complete end-to-end flow
4. Deploy email sending Cloud Function

This feature bridges the gap between working backend (verified by automated tests) and usable frontend (what users interact with).
