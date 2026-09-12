# 🚀 Device Activation & Sales Flow

## Overview
Complete system for activating Anavaya devices when sold by salespeople. Supports **3 activation methods** for maximum flexibility and ease of use.

---

## 📊 Activation Methods

### ✅ Method 1: QR Code Scan (Recommended - 30 seconds)
**Best for**: Self-service, instant activation

**Flow**:
1. Customer receives Anavaya device from salesperson
2. Opens app → "Activate Device" screen
3. Scans QR code on device box
4. ✅ **Instant activation** → Subscription unlocked

**UX**: No typing, camera-based, foolproof

---

### ✅ Method 2: Activation Code (1 minute)
**Best for**: Backup if camera doesn't work

**Flow**:
1. Customer opens app → "Activate Device"
2. Selects "Enter Code" tab
3. Types 6-digit code from device label
4. Taps "Activate Device"
5. ✅ **Subscription unlocked**

**UX**: Simple PIN entry, works offline

---

### ✅ Method 3: Pre-registration by Salesperson (VIP)
**Best for**: White-glove sales, enterprise customers

**Flow**:
1. **Salesperson** enters customer email during sale (via sales portal)
2. **System** sends activation email to customer
3. **Customer** receives email → Clicks activation link
4. **App** auto-detects device → One-tap activation
5. ✅ **Subscription unlocked**

**UX**: Premium experience, no manual steps

---

## 🔄 Complete User Journey

### New Customer Purchase Flow

```
[Salesperson sells device]
         ↓
[Customer receives device box with QR code + 6-digit code]
         ↓
[Customer downloads Anavaya app]
         ↓
[Creates account OR signs in]
         ↓
[App shows: "Activate Your Device" screen]
         ↓
    ┌────┴────┬────────────┐
    ↓         ↓            ↓
 [QR Scan] [Enter Code] [Use Email]
    ↓         ↓            ↓
    └────┬────┴────────────┘
         ↓
[Device activated ✅]
         ↓
[Subscription tier unlocked: Premium or Pro]
         ↓
[Redirect to WiFi provisioning]
         ↓
[Device connected to WiFi]
         ↓
[Start monitoring baby! 🎉]
```

---

## 🏷️ Device Packaging Requirements

### What's on the Device Box

#### 1. **QR Code** (Primary activation method)
- **Location**: Front of box, 2x2 inches
- **Content**: `deviceId:secret` (e.g., `ANVAYA-PRO-12345:a9f2b8c3d4e5`)
- **Format**: Standard QR code, high contrast

#### 2. **Activation Code** (Backup method)
- **Location**: Inside box on device label
- **Content**: 6-digit code (e.g., `482916`)
- **Format**: Large, clear numerals

#### 3. **Quick Start Card**
```
┌─────────────────────────────────────┐
│   ANAVAYA PRO - QUICK START         │
│                                      │
│   📱 Download Anavaya App            │
│   📷 Scan QR Code → Activate         │
│   🔗 Connect WiFi → Start Monitoring │
│                                      │
│   Activation Code: 482916            │
│   Device ID: ANVAYA-PRO-12345        │
│                                      │
│   Support: support@anavaya.com       │
└─────────────────────────────────────┘
```

---

## 👨‍💼 Salesperson Portal

### Sales Process

#### **Step 1: Select Device from Inventory**
- Salesperson scans device barcode or enters device ID
- System shows device details:
  - Device Type: Anavaya Pro
  - Serial Number: ANVAYA-PRO-12345
  - Status: Available
  - Price: $299 + $17.99/mo

#### **Step 2: Enter Customer Information** (Optional but recommended)
```
Customer Email: john@example.com
Customer Phone: +1-555-0123 (optional)
```

#### **Step 3: Complete Sale**
- Mark device as "Sold"
- System automatically:
  - Updates device status in Firestore
  - Sends activation email to customer
  - Logs sale for commission tracking

#### **Step 4: Hand Device to Customer**
- Give device box with QR code
- Show quick start card
- (Optional) Help customer download app

---

## 💾 Firestore Database Schema

### Collection: `device_activations`

```js
device_activations/{deviceId}
{
  // Device identification
  "deviceId": "ANVAYA-PRO-12345",
  "deviceType": "anavaya_pro", // or "anavaya_device"
  "serialNumber": "SN-2026-02-00123",
  "activationCode": "482916",
  "qrCodeData": "ANVAYA-PRO-12345:a9f2b8c3d4e5",
  
  // Activation status
  "isActivated": false, // true after customer activates
  "userId": null, // User ID after activation
  "activatedAt": null, // Timestamp
  "activatedBy": null, // Customer email
  
  // Sales information
  "salesPersonId": "SP-12345", // Who sold it
  "soldAt": Timestamp(2026-02-09),
  "customerEmail": "john@example.com", // Pre-registered
  "customerPhone": "+1-555-0123",
  
  // Metadata
  "manufacturedAt": Timestamp(2026-01-15),
  "firmwareVersion": "1.0.0",
  "metadata": {
    "batchNumber": "BATCH-2026-01-A",
    "factoryLocation": "Shenzhen, China"
  }
}
```

### Collection: `activation_events` (Analytics)

```js
activation_events/{eventId}
{
  "deviceId": "ANVAYA-PRO-12345",
  "userId": "user-abc123",
  "activatedAt": Timestamp(2026-02-09 14:30:00),
  "activatedBy": "john@example.com",
  "activationMethod": "qr_code", // or "activation_code" or "email"
  "salesPersonId": "SP-12345",
  "deviceType": "anavaya_pro"
}
```

---

## 📧 Email Templates

### Activation Email (Sent when salesperson pre-registers)

**Subject**: Your Anavaya Pro Device is Ready!

**Body**:
```html
Hi there!

Your Anavaya Pro baby monitoring device has been registered and is ready to activate.

Device ID: ANVAYA-PRO-12345
Activation Code: 482916

🚀 Get Started in 3 Steps:
1. Download the Anavaya app (App Store / Google Play)
2. Sign in with this email (john@example.com)
3. Tap "Activate Device" → Your device will auto-activate!

Or scan the QR code on your device box for instant activation.

Need help? Contact support@anavaya.com

Welcome to Anavaya!
The Anavaya Team
```

---

## 🔐 Security Considerations

### QR Code Security
- **Format**: `deviceId:secret`
- **Secret**: 16-character random hash (generated at manufacturing)
- **Validation**: Server checks QR data matches device record
- **One-time use**: After activation, QR becomes invalid

### Activation Code Security
- **Format**: 6-digit numeric code
- **Generation**: Random, no sequential patterns
- **Rate limiting**: Max 5 attempts per hour per IP
- **Expiration**: Codes expire after device activation

### Pre-registration Security
- **Email verification**: Customer must sign in with registered email
- **Time window**: Devices unmarked as "sold" after 90 days if not activated
- **Fraud detection**: Alert if multiple devices registered to same email in short time

---

## 📊 Activation Analytics Dashboard (for Sales Team)

### Key Metrics
- **Activation Rate**: % of sold devices activated within 7 days
- **Time to Activation**: Average time from sale to activation
- **Activation Method**: QR (70%) vs Code (25%) vs Email (5%)
- **Salesperson Performance**: Devices sold per salesperson
- **Regional Performance**: Activation rates by region

### Sample Dashboard View
```
┌─────────────────────────────────────────────┐
│  ACTIVATION METRICS - February 2026         │
├─────────────────────────────────────────────┤
│  Devices Sold: 1,247                        │
│  Activated: 1,089 (87%)                     │
│  Pending: 158 (13%)                         │
│                                             │
│  Average Time to Activation: 2.3 hours      │
│                                             │
│  Activation Method:                         │
│    QR Code: 761 (70%)                       │
│    Activation Code: 272 (25%)               │
│    Email Link: 56 (5%)                      │
│                                             │
│  Top Salesperson: Sarah Chen (89 devices)   │
└─────────────────────────────────────────────┘
```

---

## 🛠️ Implementation Checklist

### Backend (Firestore + Cloud Functions)

- [x] **DeviceActivationModel** - Data model for device records
- [x] **DeviceActivationService** - Activation logic (QR, code, email)
- [ ] **Cloud Function**: `onDeviceSold` - Send activation email
- [ ] **Cloud Function**: `onDeviceActivated` - Analytics logging
- [ ] **Security Rules**: Prevent unauthorized device access

### Frontend (Flutter)

- [x] **DeviceActivationScreen** - UI for activation (3 methods)
- [ ] **SalesPortalScreen** - Salesperson device registration UI
- [ ] **ActivationSuccessScreen** - Celebration + next steps
- [ ] **Route**: `/activate` - Deep link from email
- [ ] **Package**: `mobile_scanner` - QR code scanning (add to pubspec.yaml)

### Manufacturing & Logistics

- [ ] **QR Code Generation**: Script to generate unique QR codes per device
- [ ] **Label Printing**: Template for device labels (QR + code)
- [ ] **Device Registration**: Upload devices to Firestore on manufacturing
- [ ] **Inventory Tracking**: Mark devices as "available" → "sold" → "activated"

### Sales Team Training

- [ ] **Sales Portal Access**: Give login credentials to sales team
- [ ] **Demo Script**: How to demonstrate activation to customers
- [ ] **FAQ Document**: Common questions (lost code, wrong email, etc.)
- [ ] **Support Escalation**: When to contact technical support

---

## 🎯 Success Criteria

### Customer Experience
- ✅ Activation takes < 1 minute (QR method)
- ✅ Success rate > 95% (minimal support needed)
- ✅ Clear error messages if activation fails
- ✅ Seamless transition to WiFi provisioning

### Business Metrics
- ✅ Activation rate > 85% within 7 days of sale
- ✅ Support tickets < 2% of sold devices
- ✅ Salesperson satisfaction > 4.5/5
- ✅ Zero fraudulent activations

---

## 🆘 Troubleshooting Guide

### Customer: "QR code won't scan"
**Solution**:
1. Clean camera lens
2. Improve lighting
3. Hold device steady
4. Use "Enter Code" method as backup

### Customer: "Activation code invalid"
**Solution**:
1. Verify code is 6 digits (not serial number)
2. Check for similar-looking characters (0 vs O)
3. Contact support with device ID

### Customer: "Email link doesn't work"
**Solution**:
1. Check spam/junk folder
2. Use "Scan QR" method instead
3. Verify email matches account email

### Salesperson: "Can't find device in system"
**Solution**:
1. Verify device ID is correct
2. Check device hasn't been activated already
3. Contact inventory manager

---

## 📞 Support Contacts

- **Customer Support**: support@anavaya.com / 1-800-ANAVAYA
- **Sales Portal Issues**: sales-support@anavaya.com
- **Technical Issues**: tech-support@anavaya.com
- **Device Returns**: returns@anavaya.com

---

**Last Updated**: February 9, 2026
**Document Version**: 1.0
**Owner**: Product Team
