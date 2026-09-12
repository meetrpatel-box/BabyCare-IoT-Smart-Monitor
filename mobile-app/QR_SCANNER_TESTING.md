# QR Scanner Testing Guide

## Overview
Complete testing guide for the family invitation QR scanner feature.

## Test Environment
- **Flutter Version**: 3.38.9
- **Packages**: mobile_scanner ^5.2.3, qr_flutter ^4.1.0
- **Platform**: iOS/Android (camera required)

---

## Complete Invitation Flow

### Phase 1: Sending Invitation (User A)

**Prerequisites:**
- User A must be logged in
- User A must have a family (familyId exists)

**Steps:**
1. Navigate to Settings screen
2. Tap "Invite Family Member"
3. Select "QR Code" tab
4. QR code is displayed (250x250)
5. Share link button available

**Expected Results:**
- QR code generated with format: `https://babycare.app/invite/{inviteId}`
- QR code contains invitation details
- Share button copies link to clipboard
- Invitation created in Firestore `familyInvites` collection

**Firestore Validation:**
```javascript
{
  id: "auto-generated",
  familyId: "user-a-family-id",
  email: "invitee@email.com",
  role: "parent",
  status: "pending",
  invitedBy: "user-a-uid",
  invitedByName: "User A",
  inviteCode: "ABC12345",
  createdAt: Timestamp,
  expiresAt: Timestamp (+7 days)
}
```

---

### Phase 2: Scanning QR Code (User B)

**Prerequisites:**
- User B must be logged in
- Camera permissions granted
- QR code from User A visible on screen/printed

**Steps:**
1. Navigate to Settings screen
2. Tap "Scan Invitation QR Code"
3. Camera view opens
4. Point camera at QR code
5. QR code detected automatically
6. Navigate to Accept Invite screen

**Expected Results:**
- Camera overlay shows rounded frame with corner indicators
- Torch toggle button visible (top-right)
- Camera switch button visible (top-left)
- Instructions shown at bottom: "Point camera at QR code"
- Upon scan, navigate to `/accept-invite/{inviteId}`
- No duplicate scans (processing state prevents)

**Camera Permissions:**
- iOS: "Camera needed to scan family invitation QR codes"
- Android: CAMERA permission required
- Graceful fallback if permission denied

---

### Phase 3: Accepting Invitation (User B)

**Prerequisites:**
- Valid invitation scanned
- User B email matches invitation email (if specified)
- Invitation not expired
- Invitation status is "pending"

**Steps:**
1. AcceptInviteScreen displays invitation details
2. Review family name, inviter, role
3. Check expiry date
4. Tap "Accept" button

**Expected Results:**
- Display family name
- Display inviter name
- Display role (e.g., "parent")
- Display expiry countdown (e.g., "Expires in 6 days")
- Accept button enabled
- Decline button available

**On Accept:**
- User B added to family.members array
- User B familyIds updated
- Invitation status changed to "accepted"
- Navigate to dashboard
- Success message shown

**On Decline:**
- Invitation status changed to "declined"
- Navigate back to settings
- Declined message shown

---

## Manual Testing Scenarios

### Test 1: Happy Path QR Scan

**Setup:**
1. User A: Create invitation with QR code
2. Display QR code on second device or print it

**Execute:**
1. User B: Open scanner
2. Scan QR code
3. Accept invitation

**Expected:**
✅ QR code scanned successfully
✅ Invitation details displayed correctly
✅ User B added to family
✅ User B can view family babies

---

### Test 2: Manual Code Entry

**Setup:**
1. User A: Generate invite code (e.g., "ABC12345")
2. Share code via text/voice

**Execute:**
1. User B: Open scanner
2. Tap "Enter Code Manually"
3. Enter 8-character code
4. Submit

**Expected:**
✅ Dialog opens with TextField
✅ Input auto-uppercase
✅ 8-character validation
✅ Navigate to AcceptInviteScreen
✅ Accept process works

---

### Test 3: Expired Invitation

**Setup:**
1. Create invitation in Firestore
2. Set expiresAt to past date

**Execute:**
1. Scan QR code or enter code
2. View AcceptInviteScreen

**Expected:**
✅ Error message: "This invitation has expired"
✅ Accept button disabled
✅ Red error card displayed
✅ Cannot accept expired invite

---

### Test 4: Wrong Email

**Setup:**
1. User A: Create invitation for "specific@email.com"
2. User B: Log in with "different@email.com"

**Execute:**
1. User B scans QR code
2. View AcceptInviteScreen

**Expected:**
✅ Error message: "This invitation is for a different email address"
✅ Accept button disabled
✅ Shows expected email vs actual email
✅ Cannot accept with wrong email

---

### Test 5: Already Accepted

**Setup:**
1. User B accepts invitation once
2. Try to scan same QR code again

**Execute:**
1. User B scans QR code again
2. View AcceptInviteScreen

**Expected:**
✅ Error message: "This invitation has already been accepted"
✅ Accept button disabled
✅ Shows invitation already used

---

### Test 6: Invalid QR Code

**Setup:**
1. Create random QR code (non-BabyTrack)

**Execute:**
1. Scan invalid QR code

**Expected:**
✅ Error message: "Invalid QR code format"
✅ Retry button shown
✅ Can scan another code
✅ No crash or navigation

---

### Test 7: Camera Controls

**Execute:**
1. Open scanner
2. Toggle torch/flash
3. Switch camera (front/back)

**Expected:**
✅ Torch toggles on/off
✅ Camera switches between front/back
✅ Icon updates reflect state
✅ Scanning works with both cameras

---

### Test 8: Multiple URL Formats

**Test QR codes with different formats:**

1. `https://babycare.app/invite/{inviteId}`
2. `https://babycare.app/accept-invite/{inviteId}`
3. `babycare://invite/{inviteId}`
4. `https://example.com/share?inviteId={inviteId}`

**Expected:**
✅ All 4 formats extract inviteId correctly
✅ Navigate to AcceptInviteScreen for all
✅ No parsing errors

---

## Camera Permissions Setup

### iOS Configuration

**File:** `ios/Runner/Info.plist`

```xml
<key>NSCameraUsageDescription</key>
<string>Camera needed to scan family invitation QR codes</string>
<key>io.flutter.embedded_views_preview</key>
<true/>
```

**Test:**
1. First launch: Permission dialog appears
2. User denies: Graceful error message
3. User allows: Camera works
4. Settings: Can re-enable in iOS Settings → BabyTrack → Camera

---

### Android Configuration

**File:** `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" />
<uses-feature android:name="android.hardware.camera.autofocus" />
```

**File:** `android/app/build.gradle`

```gradle
android {
    compileSdkVersion 34  // Minimum 21
}
```

**Test:**
1. First launch: Permission dialog appears
2. User denies: Graceful error message
3. User allows: Camera works
4. Settings: Can re-enable in Android Settings → Apps → BabyTrack → Permissions

---

## Error Handling

### Scenario: No Camera Available

**Test:** Run on emulator without camera

**Expected:**
- Error message: "No camera available"
- Fallback to manual code entry
- Button to retry camera

---

### Scenario: Network Error

**Test:** Scan code while offline

**Expected:**
- Scanner works (local processing)
- AcceptInviteScreen shows network error
- Retry button available
- Data cached when online

---

### Scenario: Invalid Invite ID

**Test:** Manually create QR with non-existent inviteId

**Expected:**
- Scanner navigates to AcceptInviteScreen
- AcceptInviteScreen shows "Invitation not found"
- Cannot proceed
- Back button returns to scanner

---

## Performance Testing

### Metrics to Monitor:

1. **Scan Speed:**
   - Target: < 1 second from QR visible to detection
   - Measure: Time from camera open to navigation

2. **Camera Initialization:**
   - Target: < 2 seconds to show camera view
   - Measure: Time from navigation to camera ready

3. **Navigation:**
   - Target: < 500ms to AcceptInviteScreen
   - Measure: Time from detection to screen render

4. **Battery Usage:**
   - Camera should suspend when app in background
   - Torch should auto-off on navigation away

---

## Integration Test Updates

### Add to `test-integration/full_flow_integration_test.js`

**New Test Case: Test 8 - QR Scanner Flow**

```javascript
test('Test 8: QR Scanner Flow', async () => {
  // User A creates invitation
  const inviteId = await createInvitation(userA.familyId);
  
  // User B scans QR code (simulated)
  const qrData = `https://babycare.app/invite/${inviteId}`;
  const extractedId = extractInviteId(qrData);
  expect(extractedId).toBe(inviteId);
  
  // User B accepts invitation
  await acceptInvitation(userB.uid, inviteId);
  
  // Verify User B in family
  const family = await getFamily(userA.familyId);
  expect(family.members).toContainEqual(
    expect.objectContaining({ userId: userB.uid })
  );
});
```

---

## Known Limitations

1. **Camera Permissions:**
   - Must be configured in iOS Info.plist and Android manifest
   - Currently not auto-configured (manual setup required)

2. **Deep Linking:**
   - QR codes contain URLs but deep linking not configured
   - Must manually open app and scan (cannot click link in email)

3. **Email Sending:**
   - Cloud Function not yet deployed
   - Email invitations create but don't send

4. **QR Code Expiry:**
   - QR code remains valid even after invitation expires
   - Error shown only when accepting

5. **Multiple Families:**
   - User can accept multiple invites (multiple familyIds)
   - No UI to switch between families

---

## Next Steps

### High Priority:
1. ✅ Configure camera permissions (iOS/Android)
2. ⬜ Test on physical devices (camera required)
3. ⬜ Add deep linking configuration
4. ⬜ Deploy email sending Cloud Function

### Medium Priority:
5. ⬜ Add family switcher UI
6. ⬜ Role management screen
7. ⬜ Invitation history (sent/received)
8. ⬜ Resend invitation option

### Low Priority:
9. ⬜ Custom QR code styling
10. ⬜ Share QR code as image
11. ⬜ Print QR code option
12. ⬜ QR code expiry warning

---

## Screenshot Checklist

Document the following screens for testing guide:

1. ✅ FamilyInviteScreen - QR Code tab
2. ✅ Settings - "Scan Invitation QR Code" button
3. ⬜ ScanInviteQRScreen - Camera view with overlay
4. ⬜ ScanInviteQRScreen - Manual entry dialog
5. ⬜ AcceptInviteScreen - Valid invitation
6. ⬜ AcceptInviteScreen - Expired invitation error
7. ⬜ AcceptInviteScreen - Wrong email error
8. ⬜ AcceptInviteScreen - Success state

---

## Troubleshooting

### Issue: Camera Not Working

**Symptoms:** Black screen, no camera view

**Solutions:**
1. Check permissions granted (iOS Settings / Android Settings)
2. Restart app after granting permissions
3. Check Info.plist / AndroidManifest.xml configuration
4. Verify mobile_scanner package installed (`flutter pub get`)
5. Test on physical device (emulator may not support camera)

---

### Issue: QR Code Not Detected

**Symptoms:** Camera shows but doesn't beep/navigate

**Solutions:**
1. Ensure QR code is clear and visible
2. Adjust distance (6-12 inches optimal)
3. Check lighting conditions
4. Verify QR code format matches expected URL
5. Try manual code entry as fallback

---

### Issue: "Invitation Not Found" Error

**Symptoms:** QR scans but AcceptInviteScreen shows error

**Solutions:**
1. Check invitation created in Firestore
2. Verify inviteId matches QR code data
3. Check invitation not deleted
4. Verify Firestore rules allow read
5. Check network connection

---

### Issue: "Email Doesn't Match" Error

**Symptoms:** Logged in but cannot accept

**Solutions:**
1. Verify logged-in email matches invitation
2. Check invitation.email field in Firestore
3. Log out and log in with correct email
4. Create new invitation without email restriction

---

## Testing Checklist

Before considering QR scanner complete:

- [ ] Scanner opens camera successfully
- [ ] QR codes detected within 1 second
- [ ] Manual entry works for 8-char codes
- [ ] Navigation to AcceptInviteScreen works
- [ ] Torch toggle works (on supported devices)
- [ ] Camera switch works (front/back)
- [ ] Error handling for expired invites
- [ ] Error handling for wrong email
- [ ] Error handling for invalid QR codes
- [ ] iOS camera permissions configured
- [ ] Android camera permissions configured
- [ ] Tested on iOS physical device
- [ ] Tested on Android physical device
- [ ] Integration test added for QR flow
- [ ] Documentation updated
- [ ] Screenshots captured

---

## Questions for Product Team

1. Should we support multiple families per user?
2. Should QR codes have custom branding/logo?
3. Should we allow invitation resending?
4. Should we show invitation history (sent/received)?
5. Should we add invitation expiry warnings?
6. Should deep links open app automatically?

---

**Status**: 🟢 Ready for Testing
**Last Updated**: 2026-02-06
**Next Review**: After physical device testing
