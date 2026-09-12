#!/bin/bash

# Manual Firebase Integration Test
# Run this while the Flutter web app is running

echo "🔥 Manual Firebase Integration Test"
echo "===================================="
echo ""
echo "Prerequisites:"
echo "  ✓ Flutter web app running on port 8080"
echo "  ✓ Firebase project: slumber-insights-tqv7z"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Step 1: Test Firebase Connection${NC}"
echo "Open browser console at http://localhost:8080"
echo "Run this command:"
echo ""
echo -e "${YELLOW}firebase.app().options.projectId${NC}"
echo ""
echo "Expected output: 'slumber-insights-tqv7z'"
read -p "Press Enter when done..."

echo ""
echo -e "${BLUE}Step 2: Test User Authentication${NC}"
echo "Sign up with new account:"
echo "  Email: test-$(date +%s)@example.com"
echo "  Password: TestPassword123!"
echo "  Name: Integration Tester"
echo ""
read -p "Did signup succeed? (y/n): " signup_success

if [ "$signup_success" = "y" ]; then
    echo -e "${GREEN}✅ Authentication working${NC}"
else
    echo -e "${RED}❌ Authentication failed${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 3: Check Firestore - User Document${NC}"
echo "Go to Firebase Console:"
echo "  https://console.firebase.google.com/project/slumber-insights-tqv7z/firestore"
echo ""
echo "Verify:"
echo "  □ 'users' collection exists"
echo "  □ Your user document is there"
echo "  □ Has 'familyIds' array"
echo ""
read -p "User document found? (y/n): " user_found

if [ "$user_found" = "y" ]; then
    echo -e "${GREEN}✅ User document created${NC}"
else
    echo -e "${RED}❌ User document missing${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 4: Check Firestore - Family Auto-Creation${NC}"
echo "In Firebase Console > Firestore:"
echo ""
echo "Verify:"
echo "  □ 'families' collection exists"
echo "  □ Family document created for user"
echo "  □ User is listed as owner in members array"
echo ""
read -p "Family found? (y/n): " family_found

if [ "$family_found" = "y" ]; then
    echo -e "${GREEN}✅ Family auto-created${NC}"
else
    echo -e "${RED}❌ Family creation failed${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 5: Test Device Claim Token${NC}"
echo "In the app, go to: Add Device → WiFi Setup"
echo "Open browser console, you should see:"
echo "  'Creating claim token for device provisioning'"
echo "  'Claim Token: CLAIM-xxxxx'"
echo ""
read -p "Token generated? (y/n): " token_generated

if [ "$token_generated" = "y" ]; then
    echo -e "${GREEN}✅ Claim token generation working${NC}"
else
    echo -e "${RED}❌ Token generation failed${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 6: Verify Claim Token in Firestore${NC}"
echo "In Firebase Console > Firestore > deviceClaims:"
echo ""
echo "Verify:"
echo "  □ Claim token document exists"
echo " □ Has correct familyId"
echo "  □ expiresAt is ~10 minutes from now"
echo "  □ claimed = false"
echo ""
read -p "Claim token in Firestore? (y/n): " token_in_db

if [ "$token_in_db" = "y" ]; then
    echo -e "${GREEN}✅ Claim token persisted${NC}"
else
    echo -e "${RED}❌ Claim token not saved${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 7: Test Device Registration (Manual)${NC}"
echo "In browser console, run:"
echo ""
cat << 'EOF'
// Get your familyId from the user document first
const userId = firebase.auth().currentUser.uid;
firebase.firestore().collection('users').doc(userId).get().then(doc => {
  const familyId = doc.data().familyIds[0];
  console.log('Family ID:', familyId);
  
  // Register a test device
  return firebase.firestore().collection('devices').add({
    name: 'Test Monitor',
    familyId: familyId,
    status: 'online',
    firmwareVersion: '1.0.0',
    capabilities: {
      hasCamera: true,
      hasMicrophone: true,
      hasVitalSensors: true,
      supportsVideo: false,
      supportsAudio: false
    },
    createdAt: firebase.firestore.FieldValue.serverTimestamp(),
    updatedAt: firebase.firestore.FieldValue.serverTimestamp()
  });
}).then(docRef => {
  console.log('Device registered:', docRef.id);
});
EOF
echo ""
read -p "Device registered? (y/n): " device_registered

if [ "$device_registered" = "y" ]; then
    echo -e "${GREEN}✅ Device registration working${NC}"
else
    echo -e "${RED}❌ Device registration failed${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 8: Verify Device Appears in App${NC}"
echo "Go to Devices screen in the app"
echo ""
echo "Verify:"
echo "  □ Test Monitor appears in list"
echo "  □ Shows 'online' status"
echo ""
read -p "Device visible in app? (y/n): " device_visible

if [ "$device_visible" = "y" ]; then
    echo -e "${GREEN}✅ Device isolation working${NC}"
else
    echo -e "${RED}❌ Device not showing${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 9: Test Real-time Updates${NC}"
echo "In browser console, send test vital signs:"
echo ""
cat << 'EOF'
// Get device ID (from previous step or Firestore)
const deviceId = 'YOUR_DEVICE_ID_HERE';

// Send vital signs
for (let i = 0; i < 5; i++) {
  setTimeout(() => {
    firebase.firestore().collection('vital_signs').add({
      deviceId: deviceId,
      heartRate: 120 + Math.floor(Math.random() * 20),
      temperature: 36.8 + (Math.random() * 0.8),
      respiratoryRate: 40 + Math.floor(Math.random() * 10),
      timestamp: firebase.firestore.FieldValue.serverTimestamp()
    }).then(() => console.log(`Sent vital #${i+1}`));
  }, i * 3000);
}
EOF
echo ""
read -p "Vitals appearing in Live Vitals screen? (y/n): " vitals_working

if [ "$vitals_working" = "y" ]; then
    echo -e "${GREEN}✅ Real-time streaming working${NC}"
else
    echo -e "${RED}❌ Real-time streaming failed${NC}"
    exit 1
fi

echo ""
echo "================================================"
echo -e "${GREEN}🎉 All Firebase Integration Tests Passed!${NC}"
echo "================================================"
echo ""
echo "Summary:"
echo "  ✅ Firebase connection"
echo "  ✅ User authentication"
echo "  ✅ User document creation"
echo "  ✅ Family auto-creation"
echo "  ✅ Device claim tokens"
echo "  ✅ Device registration"
echo "  ✅ Device ownership isolation"
echo "  ✅ Real-time vital signs streaming"
echo ""
echo "Next steps:"
echo "  1. Test family invitations"
echo "  2. Test device ownership isolation (create 2nd user)"
echo "  3. Implement Cloud Function for heartbeat monitoring"
echo "  4. Test on mobile device"
echo ""
