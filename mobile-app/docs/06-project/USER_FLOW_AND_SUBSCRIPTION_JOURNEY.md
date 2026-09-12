# User Flow & Subscription Journey
## Complete Flow from Signup to Feature Access

**Last Updated**: February 9, 2026

---

## 🎯 Product Tiers Overview

### **Tier 1: Free** (Manual Tracking)
- **Price**: $0
- **Features**: Manual tracking, basic charts (24h), 100 photos, 1 baby
- **Device**: None
- **Target**: Parents trying the app

### **Tier 2: Premium** (AI-Powered)
- **Price**: $9.99/month
- **Features**: AI insights, predictions, advanced charts (30d), unlimited photos, 3 babies
- **Device**: None (manual entry + AI)
- **Target**: Engaged parents who track regularly

### **Tier 3: Premium + Basic Device** (AnvayaPod Lite)
- **Price**: $149 device + $9.99/month
- **Features**: All Premium + basic auto-detection
- **Device**: AnvayaPod Lite (60GHz mmWave sensor only)
  - Auto sleep tracking
  - Real-time vitals (HR, RR)
  - Movement detection
- **Target**: Parents wanting basic automation

### **Tier 4: Premium + Advanced Device** (AnvayaPod Pro)
- **Price**: $299 device + $14.99/month
- **Features**: All Tier 3 + advanced AI
- **Device**: AnvayaPod Pro (60GHz mmWave + ESP32-CAM + Audio)
  - All Lite features
  - Cry detection & classification
  - Auto photo/video capture
  - Two-way audio (baby monitor)
  - Temperature/humidity sensors
- **Target**: Premium parents wanting full automation

### **Tier 5: Premium + Pro Device + Family Plan**
- **Price**: $299 device + $24.99/month
- **Features**: All Tier 4 + family sharing
- **Device**: AnvayaPod Pro
- **Extra**: Up to 5 babies, 5 family members, 100GB storage, priority support
- **Target**: Multi-child families, nannies, daycare

---

## 📱 Complete User Journey Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                        USER JOURNEY STAGES                           │
└─────────────────────────────────────────────────────────────────────┘

STAGE 1: DISCOVERY & SIGNUP (Day 0)
├─ App Install (App Store / Google Play)
├─ Onboarding Carousel (3 screens)
│  ├─ Screen 1: "Track your baby's journey" (manual features)
│  ├─ Screen 2: "AI-powered insights" (premium features)
│  └─ Screen 3: "Hands-free with AnvayaPod" (device features)
├─ Signup Options
│  ├─ Google Sign-in
│  ├─ Apple Sign-in
│  └─ Email/Password
└─ Create Baby Profile
   ├─ Name, Date of Birth, Gender
   ├─ Photo (optional)
   └─ Initial weight/height

STAGE 2: SUBSCRIPTION SELECTION (Day 0)
├─ Welcome Screen with Tier Comparison
│  ├─ "Start Free" button (prominent)
│  ├─ "Try Premium Free (7 days)" button
│  └─ "I have an AnvayaPod" button (for device owners)
│
├─ CHOICE A: User Selects "Start Free"
│  ├─ Default tier = Free
│  ├─ Skip to Dashboard (free features only)
│  └─ Show "Try Premium" banner (dismissible)
│
├─ CHOICE B: User Selects "Try Premium Free"
│  ├─ RevenueCat subscription flow
│  ├─ Select: Monthly ($9.99) or Annual ($99.99, save 17%)
│  ├─ 7-day free trial starts
│  ├─ Default tier = Premium (trial)
│  └─ Go to Dashboard (all premium features unlocked)
│
└─ CHOICE C: User Selects "I have an AnvayaPod"
   ├─ Show device selection screen
   │  ├─ "AnvayaPod Lite ($149)" → Tier 3
   │  └─ "AnvayaPod Pro ($299)" → Tier 4
   ├─ Scan device QR code
   ├─ Activate subscription
   │  ├─ Lite: $9.99/month
   │  └─ Pro: $14.99/month
   ├─ Pair device via WiFi provisioning
   └─ Go to Dashboard (device features unlocked)

STAGE 3: DASHBOARD EXPERIENCE (Daily Use)
├─ Dashboard shows tier-specific features
├─ Feature gates control visibility
└─ Upgrade prompts appear contextually

STAGE 4: UPGRADE FLOWS (Anytime)
├─ Free → Premium: In-app paywall
├─ Free → Device: Device purchase flow → subscription
├─ Premium → Device: Purchase device → upgrade subscription
└─ Basic Device → Pro Device: Trade-in program
```

---

## 🏗️ Technical Implementation: Feature Control System

### **1. User Record Structure (Firestore)**

```typescript
// users/{userId}
{
  uid: "user123",
  email: "parent@example.com",
  tier: "premium_device_pro", // Current tier
  subscriptionStatus: "active", // active, trial, expired, cancelled
  deviceType: "anvayapod_pro", // null, anvayapod_lite, anvayapod_pro
  deviceId: "ANVAYA-PRO-12345", // Paired device ID
  subscriptionId: "rc_sub_xyz", // RevenueCat subscription ID
  trialEndsAt: Timestamp(2026-02-16), // Trial expiry
  subscriptionEndsAt: Timestamp(2026-03-09), // Next billing date
  createdAt: Timestamp(2026-02-09),
  
  // Feature quotas
  quotas: {
    maxBabies: 5,
    maxPhotos: -1, // unlimited
    maxStorageMB: 102400, // 100GB for family plan
    chartHistoryDays: 90
  },
  
  // Family sharing (Tier 5 only)
  familyMembers: ["user456", "user789"], // Up to 5
}
```

### **2. Subscription Tier Enum (Updated)**

```dart
// lib/models/subscription_model.dart

enum SubscriptionTier {
  free('free', 'Free', null, 0),
  premium('premium', 'Premium', null, 9.99),
  premiumLite('premium_lite', 'Premium + Lite', 'anvayapod_lite', 9.99),
  premiumPro('premium_pro', 'Premium + Pro', 'anvayapod_pro', 14.99),
  premiumFamily('premium_family', 'Family Plan', 'anvayapod_pro', 24.99);

  final String value;
  final String displayName;
  final String? deviceType;
  final double monthlyPrice;

  const SubscriptionTier(this.value, this.displayName, this.deviceType, this.monthlyPrice);

  bool get isPremium => this != SubscriptionTier.free;
  bool get hasDevice => deviceType != null;
  bool get hasBasicDevice => deviceType == 'anvayapod_lite';
  bool get hasProDevice => deviceType == 'anvayapod_pro';
  bool get isFamilyPlan => this == SubscriptionTier.premiumFamily;
}
```

### **3. Feature Access Matrix**

```dart
// lib/services/feature_access_matrix.dart

class FeatureAccessMatrix {
  static final Map<String, Set<SubscriptionTier>> _featureAccess = {
    // Basic Features (Free+)
    'manual_tracking': {
      SubscriptionTier.free,
      SubscriptionTier.premium,
      SubscriptionTier.premiumLite,
      SubscriptionTier.premiumPro,
      SubscriptionTier.premiumFamily,
    },
    'basic_charts': {SubscriptionTier.free, ...},
    
    // Premium Features (Premium+)
    'ai_insights': {
      SubscriptionTier.premium,
      SubscriptionTier.premiumLite,
      SubscriptionTier.premiumPro,
      SubscriptionTier.premiumFamily,
    },
    'predictions': {...},
    'advanced_charts': {...},
    'export_pdf': {...},
    'unlimited_photos': {...},
    
    // Lite Device Features (Lite+)
    'auto_sleep_tracking': {
      SubscriptionTier.premiumLite,
      SubscriptionTier.premiumPro,
      SubscriptionTier.premiumFamily,
    },
    'real_time_vitals': {...},
    'movement_alerts': {...},
    
    // Pro Device Features (Pro+)
    'cry_detection': {
      SubscriptionTier.premiumPro,
      SubscriptionTier.premiumFamily,
    },
    'auto_photo_capture': {...},
    'video_monitoring': {...},
    'two_way_audio': {...},
    'environmental_sensors': {...},
    
    // Family Plan Features (Family only)
    'family_sharing': {SubscriptionTier.premiumFamily},
    'multiple_caregivers': {...},
    'priority_support': {...},
  };
  
  static bool canAccess(SubscriptionTier tier, String feature) {
    return _featureAccess[feature]?.contains(tier) ?? false;
  }
  
  static List<String> getAvailableFeatures(SubscriptionTier tier) {
    return _featureAccess.entries
        .where((entry) => entry.value.contains(tier))
        .map((entry) => entry.key)
        .toList();
  }
}
```

---

## 🎨 UI/UX Flow Examples

### **A. First Launch Experience**

```dart
// lib/screens/onboarding/onboarding_screen.dart

class OnboardingScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return PageView(
      children: [
        // Page 1: Manual Tracking (Free)
        OnboardingPage(
          title: "Track Every Moment",
          description: "Log sleep, feeding, diapers manually",
          image: "assets/onboarding/manual_tracking.png",
          tier: SubscriptionTier.free,
        ),
        
        // Page 2: AI Insights (Premium)
        OnboardingPage(
          title: "Smart AI Insights",
          description: "Get predictions & recommendations",
          image: "assets/onboarding/ai_insights.png",
          tier: SubscriptionTier.premium,
        ),
        
        // Page 3: Device Automation (Device Tiers)
        OnboardingPage(
          title: "Hands-Free Monitoring",
          description: "AnvayaPod automates everything",
          image: "assets/onboarding/device_monitoring.png",
          tier: SubscriptionTier.premiumPro,
        ),
        
        // Final Page: Tier Selection
        TierSelectionPage(),
      ],
    );
  }
}
```

### **B. Tier Selection Screen**

```dart
// lib/screens/onboarding/tier_selection_screen.dart

class TierSelectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("Choose Your Plan", style: heading),
        
        // Option 1: Start Free
        TierCard(
          tier: SubscriptionTier.free,
          title: "Start Free",
          subtitle: "Try manual tracking",
          features: ["1 baby", "100 photos", "24h charts"],
          price: "Free",
          isPrimary: true, // Highlighted
          onTap: () => _selectFreeTier(context),
        ),
        
        // Option 2: Premium Trial
        TierCard(
          tier: SubscriptionTier.premium,
          title: "Premium",
          subtitle: "AI-powered insights",
          features: ["AI insights", "Predictions", "30d charts", "3 babies"],
          price: "\$9.99/month",
          badge: "7-day free trial",
          onTap: () => _startPremiumTrial(context),
        ),
        
        // Option 3: I Have a Device
        OutlinedButton(
          child: Text("I have an AnvayaPod"),
          onPressed: () => _navigateToDeviceSetup(context),
        ),
      ],
    );
  }
  
  void _selectFreeTier(BuildContext context) async {
    await SubscriptionService().createFreeSubscription(userId);
    Navigator.pushReplacementNamed(context, '/dashboard');
  }
  
  void _startPremiumTrial(BuildContext context) async {
    // Launch RevenueCat paywall
    await Purchases.presentPaywall();
  }
  
  void _navigateToDeviceSetup(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DeviceTypeSelectionScreen(),
    ));
  }
}
```

### **C. Device Setup Flow**

```dart
// lib/screens/device/device_type_selection_screen.dart

class DeviceTypeSelectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("Select Your AnvayaPod", style: heading),
        
        // Lite Device
        DeviceCard(
          deviceType: 'anvayapod_lite',
          name: "AnvayaPod Lite",
          price: "\$149 + \$9.99/mo",
          features: [
            "✅ Auto sleep tracking",
            "✅ Real-time vitals (HR, RR)",
            "✅ Movement detection",
            "❌ No camera",
            "❌ No audio",
          ],
          onSelect: () => _selectDevice('anvayapod_lite'),
        ),
        
        // Pro Device
        DeviceCard(
          deviceType: 'anvayapod_pro',
          name: "AnvayaPod Pro",
          price: "\$299 + \$14.99/mo",
          badge: "Most Popular",
          features: [
            "✅ All Lite features",
            "✅ Cry detection & classification",
            "✅ Auto photo/video capture",
            "✅ Two-way audio monitor",
            "✅ Environmental sensors",
          ],
          onSelect: () => _selectDevice('anvayapod_pro'),
        ),
      ],
    );
  }
  
  void _selectDevice(String deviceType) async {
    // Navigate to QR scanning
    final deviceId = await Navigator.push(context, MaterialPageRoute(
      builder: (_) => DeviceQRScanScreen(deviceType: deviceType),
    ));
    
    if (deviceId != null) {
      // Create subscription with device
      final tier = deviceType == 'anvayapod_lite' 
          ? SubscriptionTier.premiumLite 
          : SubscriptionTier.premiumPro;
          
      await SubscriptionService().createDeviceSubscription(
        userId: userId,
        tier: tier,
        deviceId: deviceId,
      );
      
      // Navigate to WiFi provisioning
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => DeviceProvisioningScreen(deviceId: deviceId),
      ));
    }
  }
}
```

### **D. Dashboard with Dynamic Features**

```dart
// lib/screens/main/dashboard_screen.dart

class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final tier = subscriptionProvider.tier;
    
    return Column(
      children: [
        // Quick Actions (all tiers)
        QuickActionsRow(
          children: [
            ActionButton(icon: Icons.bed, label: "Sleep", onTap: _logSleep),
            ActionButton(icon: Icons.restaurant, label: "Feed", onTap: _logFeeding),
            ActionButton(icon: Icons.baby_changing_station, label: "Diaper", onTap: _logDiaper),
          ],
        ),
        
        // Premium AI Insights (Premium+)
        FeatureGate(
          feature: 'ai_insights',
          child: AIInsightsCard(),
          fallback: UpgradePromptCard(
            title: "Unlock AI Insights",
            description: "Get smart predictions & recommendations",
            requiredTier: SubscriptionTier.premium,
          ),
        ),
        
        // Real-Time Vitals (Lite Device+)
        if (tier.hasDevice)
          FeatureGate(
            feature: 'real_time_vitals',
            child: LiveVitalsCard(deviceId: subscriptionProvider.deviceId),
          ),
        
        // Cry Alerts (Pro Device+)
        FeatureGate(
          feature: 'cry_detection',
          child: CryAlertCard(),
          fallback: tier.hasBasicDevice
              ? UpgradePromptCard(
                  title: "Upgrade to Pro",
                  description: "Get cry detection & video monitoring",
                  requiredTier: SubscriptionTier.premiumPro,
                )
              : null,
        ),
        
        // Family Access (Family Plan only)
        FeatureGate(
          feature: 'family_sharing',
          child: FamilyMembersCard(),
        ),
      ],
    );
  }
}
```

---

## 🔄 Upgrade Flow Examples

### **Free → Premium**

```dart
// Triggered when user taps upgrade prompt
void _upgradeToPremium(BuildContext context) async {
  final offerings = await Purchases.getOfferings();
  final package = offerings.current?.monthly; // $9.99/mo
  
  try {
    final customerInfo = await Purchases.purchasePackage(package);
    
    // Update Firestore
    await SubscriptionService().updateSubscription(
      userId: userId,
      tier: SubscriptionTier.premium,
      revenueCatCustomerId: customerInfo.originalAppUserId,
    );
    
    // Show success
    showDialog(
      context: context,
      builder: (_) => SuccessDialog(
        title: "Welcome to Premium! 🎉",
        message: "AI insights unlocked. Enjoy 30-day charts & predictions!",
      ),
    );
    
    // Refresh dashboard
    context.read<SubscriptionProvider>().loadSubscription(userId);
    
  } catch (e) {
    // Handle purchase error
    showSnackBar("Purchase failed: $e");
  }
}
```

### **Premium → Premium + Pro Device**

```dart
// User purchased device, now pairing
void _pairDeviceAndUpgrade(String deviceId, String deviceType) async {
  // Determine new tier
  final newTier = deviceType == 'anvayapod_lite'
      ? SubscriptionTier.premiumLite
      : SubscriptionTier.premiumPro;
  
  // Upgrade subscription in RevenueCat
  final newPrice = newTier == SubscriptionTier.premiumPro ? 14.99 : 9.99;
  await Purchases.purchaseProduct(newPrice);
  
  // Link device to user
  await SubscriptionService().updateSubscription(
    userId: userId,
    tier: newTier,
    deviceId: deviceId,
  );
  
  // Start WiFi provisioning
  await DeviceService().provisionDevice(deviceId);
  
  // Navigate to celebration screen
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => DeviceSuccessScreen(deviceType: deviceType),
  ));
}
```

---

## 📊 Feature Visibility Decision Tree

```
User Opens App
    ↓
Load Subscription from Firestore
    ↓
Determine Tier (free, premium, premiumLite, premiumPro, premiumFamily)
    ↓
    ├─ Free Tier
    │   ├─ Show: Manual tracking, basic charts (24h)
    │   ├─ Hide: AI insights, advanced charts, device features
    │   └─ Show: Upgrade prompts (dismissible)
    │
    ├─ Premium Tier
    │   ├─ Show: All Free + AI insights, predictions, 30d charts
    │   ├─ Hide: Device features (auto-detection, cry alerts, video)
    │   └─ Show: Device purchase prompts
    │
    ├─ Premium + Lite Device
    │   ├─ Show: All Premium + auto sleep, real-time vitals, movement alerts
    │   ├─ Hide: Cry detection, video, two-way audio
    │   └─ Show: Pro device upgrade prompts
    │
    ├─ Premium + Pro Device
    │   ├─ Show: All Lite + cry detection, video, audio, environmental sensors
    │   ├─ Hide: Family sharing (only for family plan)
    │   └─ Show: Family plan upgrade prompts (if multi-child)
    │
    └─ Family Plan
        ├─ Show: Everything unlocked
        ├─ Hide: Nothing
        └─ Show: Referral bonuses, exclusive content
```

---

## 🚀 RevenueCat Integration

### **Product IDs Setup**

```dart
// lib/config/revenue_cat_config.dart

class RevenueCatConfig {
  static const String apiKey = "your_revenuecat_key";
  
  static const Map<SubscriptionTier, String> productIds = {
    SubscriptionTier.premium: "premium_monthly",
    SubscriptionTier.premiumLite: "premium_lite_monthly",
    SubscriptionTier.premiumPro: "premium_pro_monthly",
    SubscriptionTier.premiumFamily: "premium_family_monthly",
  };
  
  static Future<void> initialize() async {
    await Purchases.configure(
      PurchasesConfiguration(apiKey)
        ..appUserID = FirebaseAuth.instance.currentUser?.uid,
    );
  }
  
  static Future<void> syncSubscription(String userId) async {
    final customerInfo = await Purchases.getCustomerInfo();
    
    // Determine tier from active entitlements
    SubscriptionTier tier = SubscriptionTier.free;
    
    if (customerInfo.entitlements.active.containsKey('family')) {
      tier = SubscriptionTier.premiumFamily;
    } else if (customerInfo.entitlements.active.containsKey('pro_device')) {
      tier = SubscriptionTier.premiumPro;
    } else if (customerInfo.entitlements.active.containsKey('lite_device')) {
      tier = SubscriptionTier.premiumLite;
    } else if (customerInfo.entitlements.active.containsKey('premium')) {
      tier = SubscriptionTier.premium;
    }
    
    // Update Firestore
    await SubscriptionService().updateSubscription(
      userId: userId,
      tier: tier,
    );
  }
}
```

---

## 🎯 Summary: How It All Works

1. **User Signs Up** → Default Free tier created in Firestore
2. **User Chooses Tier** → During onboarding or later via settings
3. **Tier Stored** → `users/{userId}` document has `tier`, `deviceType`, `deviceId`
4. **App Reads Tier** → SubscriptionProvider loads on app launch
5. **Features Gated** → FeatureGate widget checks tier before rendering
6. **Upgrade Prompts** → Shown contextually when user tries locked feature
7. **Device Pairing** → QR scan → WiFi provisioning → Tier upgrade
8. **RevenueCat Sync** → Webhooks update Firestore when subscription changes

---

**Key Principle**: The app always shows the **maximum value** for the user's current tier while **naturally encouraging upgrades** through contextual prompts, not aggressive paywalls.

Would you like me to implement any specific part of this flow? 🚀
