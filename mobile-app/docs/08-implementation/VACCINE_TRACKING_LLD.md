# 💉 Vaccine Tracking - Low-Level Design

**Date:** February 2, 2026  
**Feature:** Vaccine Schedule & Tracking with Reminders  
**Type:** App-based Manual Entry (No Device Sensors)

---

## 📋 TABLE OF CONTENTS

1. [System Overview](#system-overview)
2. [Vaccine Schedules](#vaccine-schedules)
3. [Data Models](#data-models)
4. [Cloud Functions](#cloud-functions)
5. [Flutter Implementation](#flutter-implementation)
6. [Reminder System](#reminder-system)
7. [Implementation Roadmap](#implementation-roadmap)

---

## 1️⃣ SYSTEM OVERVIEW

### **1.1 Feature Scope**

| Feature | Description | Automation |
|---------|-------------|------------|
| **Vaccine Schedule** | CDC/WHO/India schedules | Auto-populate based on country |
| **Upcoming Vaccines** | Show next due vaccines | Auto-calculate from birthdate |
| **Record Vaccine** | Log administered vaccines | Manual entry with date/location |
| **Reminders** | Push notifications | 1 week, 3 days, 1 day before |
| **Overdue Alerts** | Alert if missed vaccine | Daily check for overdue |
| **Reaction Tracking** | Log adverse reactions | Manual entry with severity |
| **Certificate Export** | PDF vaccine certificate | Include all administered vaccines |

### **1.2 Supported Vaccine Schedules**

```
CDC (USA):
├─ Birth: HepB-1
├─ 2 months: DTaP-1, IPV-1, Hib-1, PCV13-1, RV-1
├─ 4 months: DTaP-2, IPV-2, Hib-2, PCV13-2, RV-2
├─ 6 months: DTaP-3, IPV-3, Hib-3, PCV13-3, RV-3, HepB-2
├─ 12 months: MMR-1, Varicella-1, HepA-1, PCV13-4
├─ 15 months: Hib-4
├─ 18 months: DTaP-4, HepA-2
├─ 4-6 years: DTaP-5, IPV-4, MMR-2, Varicella-2
└─ ... (extended schedule)

WHO (Global):
├─ Similar structure with regional variations
└─ Includes BCG, Oral Polio in some regions

India (IAP):
├─ Birth: BCG, OPV-0, HepB-1
├─ 6 weeks: DTwP/DTaP-1, IPV-1, Hib-1, RV-1, PCV-1
├─ 10 weeks: DTwP/DTaP-2, IPV-2, Hib-2, RV-2, PCV-2
├─ 14 weeks: DTwP/DTaP-3, IPV-3, Hib-3, RV-3, PCV-3
├─ 6 months: OPV-1, HepB-2
├─ 9 months: MMR-1, OPV-2
└─ ... (extended schedule)
```

### **1.3 Data Flow Architecture**

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        VACCINE TRACKING FLOW                             │
└─────────────────────────────────────────────────────────────────────────┘

Flutter App                    Firebase Cloud              Reminders
┌────────────────┐            ┌──────────────────┐         ┌─────────────┐
│                │            │                  │         │             │
│  Baby Profile  │            │  Cloud Function  │         │  FCM Push   │
│  ────────────  │  Create    │  ──────────────  │ Schedule│  Notif.     │
│  Birthdate     │  ──────>   │                  │ ──────> │  ─────────  │
│  Country: USA  │            │  onBabyCreate    │         │             │
│                │            │  - Get CDC/WHO   │         │  "MMR due   │
│  Vaccine Plan  │   Auto     │  - Calculate     │         │   in 3 days"│
│  ────────────  │  Generate  │    schedule      │         │             │
│  📅 2 months:  │ <─────────  │  - Create docs   │         │  Overdue    │
│   DTaP, IPV,   │            │                  │         │  ─────────  │
│   Hib, PCV     │            │  Vaccine Docs    │         │             │
│  📅 4 months:  │            │  ──────────────  │         │  "DTaP is   │
│   ...          │            │  vaccines/{id}   │         │   5 days    │
│                │            │  - scheduledDate │         │   overdue!" │
│  Record        │            │  - doseNumber    │         │             │
│  ────────────  │   Write    │  - status: due   │         │  Daily      │
│  Vaccine: MMR  │  Firestore │                  │         │  Check      │
│  Date: 1/2/26  │  ──────>   │  onVaccineUpdate │ Check   │  ─────────  │
│  Location:     │            │  ──────────────  │ Overdue │             │
│   Dr. Smith    │            │  - Mark admin.   │ ──────> │  Scheduled  │
│  Reaction:     │            │  - Cancel remind.│         │  Daily at   │
│   Mild fever   │            │  - Log reaction  │         │  9 AM       │
│  [Save]        │            │  - Update cert.  │         │             │
│                │            │                  │         │  Reminders  │
│  Timeline      │   Read     │  Certificate     │         │  ─────────  │
│  ────────────  │  Firestore │  ──────────────  │         │             │
│  ✅ Birth:     │ <───────── │  Generate PDF    │         │  1 week     │
│     HepB       │            │  - Baby info     │         │  3 days     │
│  ✅ 2 mo:      │            │  - All vaccines  │         │  1 day      │
│     DTaP, ...  │            │  - Dates/Loc.    │         │  before due │
│  ⏰ 4 mo:      │            │  - Reactions     │         │             │
│     DTaP (due) │            │                  │         │             │
└────────────────┘            └──────────────────┘         └─────────────┘
```

### **1.4 Storage Strategy**

```
Firestore Collections:
├─ babies/{babyId}/vaccines/{vaccineId}             (Individual vaccine records)
├─ babies/{babyId}/vaccine_schedule/{scheduleId}    (Scheduled vaccines)
├─ babies/{babyId}/vaccine_reactions/{reactionId}   (Adverse reactions)
├─ reference_data/vaccine_schedules/{country}       (CDC/WHO/IAP schedules)
└─ scheduled_reminders/{reminderId}                 (Reminder jobs)

Assets (Local):
├─ assets/vaccine_schedules/cdc_usa.json
├─ assets/vaccine_schedules/who_global.json
└─ assets/vaccine_schedules/iap_india.json

Data Retention:
- Vaccine records: Permanent
- Reactions: Permanent
- Reminders: Auto-delete after sent
```

---

## 2️⃣ VACCINE SCHEDULES

### **2.1 CDC Schedule (USA)**

```json
// assets/vaccine_schedules/cdc_usa.json
{
  "country": "USA",
  "schedule_name": "CDC Recommended Immunization Schedule",
  "version": "2026",
  "vaccines": [
    {
      "vaccine_name": "Hepatitis B (HepB)",
      "short_name": "HepB",
      "doses": [
        {
          "dose_number": 1,
          "age_months": 0,
          "age_display": "Birth",
          "description": "First dose within 24 hours of birth"
        },
        {
          "dose_number": 2,
          "age_months": 2,
          "age_display": "2 months",
          "description": "Second dose at 1-2 months"
        },
        {
          "dose_number": 3,
          "age_months": 6,
          "age_display": "6-18 months",
          "description": "Third dose at 6-18 months"
        }
      ],
      "disease": "Hepatitis B",
      "route": "Intramuscular",
      "site": "Anterolateral thigh"
    },
    {
      "vaccine_name": "DTaP (Diphtheria, Tetanus, Pertussis)",
      "short_name": "DTaP",
      "doses": [
        { "dose_number": 1, "age_months": 2, "age_display": "2 months" },
        { "dose_number": 2, "age_months": 4, "age_display": "4 months" },
        { "dose_number": 3, "age_months": 6, "age_display": "6 months" },
        { "dose_number": 4, "age_months": 18, "age_display": "15-18 months" },
        { "dose_number": 5, "age_months": 60, "age_display": "4-6 years" }
      ],
      "disease": "Diphtheria, Tetanus, Pertussis",
      "route": "Intramuscular",
      "site": "Anterolateral thigh"
    },
    {
      "vaccine_name": "MMR (Measles, Mumps, Rubella)",
      "short_name": "MMR",
      "doses": [
        { "dose_number": 1, "age_months": 12, "age_display": "12-15 months" },
        { "dose_number": 2, "age_months": 48, "age_display": "4-6 years" }
      ],
      "disease": "Measles, Mumps, Rubella",
      "route": "Subcutaneous",
      "site": "Outer upper arm"
    }
    // ... more vaccines
  ]
}
```

### **2.2 IAP Schedule (India)**

```json
// assets/vaccine_schedules/iap_india.json
{
  "country": "India",
  "schedule_name": "IAP Recommended Immunization Schedule",
  "version": "2023-24",
  "vaccines": [
    {
      "vaccine_name": "BCG",
      "short_name": "BCG",
      "doses": [
        {
          "dose_number": 1,
          "age_months": 0,
          "age_display": "Birth",
          "description": "At birth or within first month"
        }
      ],
      "disease": "Tuberculosis",
      "route": "Intradermal",
      "site": "Left upper arm"
    },
    {
      "vaccine_name": "OPV (Oral Polio)",
      "short_name": "OPV",
      "doses": [
        { "dose_number": 0, "age_months": 0, "age_display": "Birth" },
        { "dose_number": 1, "age_months": 1.5, "age_display": "6 weeks" },
        { "dose_number": 2, "age_months": 2.5, "age_display": "10 weeks" },
        { "dose_number": 3, "age_months": 3.5, "age_display": "14 weeks" }
      ],
      "disease": "Poliomyelitis",
      "route": "Oral",
      "site": "Mouth"
    }
    // ... more vaccines
  ]
}
```

---

## 3️⃣ DATA MODELS

### **3.1 Firestore Schema**

```typescript
// ═══════════════════════════════════════════════════════════
// Firestore Document Schemas
// ═══════════════════════════════════════════════════════════

// Collection: babies/{babyId}/vaccines/{vaccineId}
interface VaccineRecordDocument {
  id: string;
  babyId: string;
  
  // Vaccine details
  vaccineName: string;        // "DTaP", "MMR", etc.
  vaccineFullName: string;    // "Diphtheria, Tetanus, Pertussis"
  doseNumber: number;         // 1, 2, 3, etc.
  totalDoses: number;         // Total expected doses
  
  // Schedule
  scheduledDate: FirebaseFirestore.Timestamp;  // When it's due
  ageMonths: number;          // Age when due (from schedule)
  
  // Administration
  administeredDate?: FirebaseFirestore.Timestamp;
  administeredBy?: string;    // Doctor/Nurse name
  location?: string;          // Clinic/Hospital name
  lotNumber?: string;         // Vaccine lot number
  manufacturer?: string;      // Pfizer, Moderna, etc.
  
  // Status
  status: 'scheduled' | 'administered' | 'overdue' | 'skipped' | 'rescheduled';
  
  // Reactions
  hadReaction: boolean;
  reactionDetails?: {
    severity: 'mild' | 'moderate' | 'severe';
    symptoms: string[];       // ['fever', 'swelling', 'rash']
    notes: string;
    reportedAt: FirebaseFirestore.Timestamp;
  };
  
  // Reminders
  remindersSent: {
    oneWeekBefore: boolean;
    threeDaysBefore: boolean;
    oneDayBefore: boolean;
    overdueAlert: boolean;
  };
  
  // Metadata
  loggedBy?: string;
  loggedAt?: FirebaseFirestore.Timestamp;
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt?: FirebaseFirestore.Timestamp;
}

// Collection: babies/{babyId}/vaccine_reactions/{reactionId}
interface VaccineReactionDocument {
  id: string;
  babyId: string;
  vaccineRecordId: string;
  vaccineName: string;
  doseNumber: number;
  
  // Reaction details
  severity: 'mild' | 'moderate' | 'severe';
  symptoms: string[];         // ['fever', 'redness', 'swelling', 'irritability']
  
  // Specifics
  feverTempC?: number;
  swellingLocation?: string;  // 'injection_site', 'arm', 'leg'
  swellingSizeCm?: number;
  durationHours?: number;
  
  // Treatment
  treatmentGiven?: string;    // 'paracetamol', 'ice_pack', 'none'
  doctorConsulted: boolean;
  hospitalized: boolean;
  
  // Timeline
  onsetTime: FirebaseFirestore.Timestamp;  // When reaction started
  resolvedTime?: FirebaseFirestore.Timestamp;
  
  // Notes
  notes?: string;
  
  // Reported by
  reportedBy: string;         // userId
  reportedAt: FirebaseFirestore.Timestamp;
  createdAt: FirebaseFirestore.Timestamp;
}

// Collection: scheduled_reminders/{reminderId}
interface VaccineReminderDocument {
  id: string;
  babyId: string;
  vaccineRecordId: string;
  vaccineName: string;
  doseNumber: number;
  
  // Reminder timing
  reminderType: '1_week' | '3_days' | '1_day' | 'overdue';
  dueDate: FirebaseFirestore.Timestamp;
  scheduledTime: FirebaseFirestore.Timestamp;
  
  // Status
  status: 'pending' | 'sent' | 'cancelled';
  sentAt?: FirebaseFirestore.Timestamp;
  
  // Notification
  title: string;
  message: string;
  
  createdAt: FirebaseFirestore.Timestamp;
}
```

### **3.2 Flutter Dart Models**

```dart
// ═══════════════════════════════════════════════════════════
// lib/models/vaccine_record_model.dart
// ═══════════════════════════════════════════════════════════

class VaccineRecordModel {
  final String id;
  final String babyId;
  final String vaccineName;
  final String vaccineFullName;
  final int doseNumber;
  final int totalDoses;
  
  final DateTime scheduledDate;
  final int ageMonths;
  
  final DateTime? administeredDate;
  final String? administeredBy;
  final String? location;
  final String? lotNumber;
  final String? manufacturer;
  
  final VaccineStatus status;
  
  final bool hadReaction;
  final VaccineReactionDetails? reactionDetails;
  
  final VaccineReminders remindersSent;
  
  final String? loggedBy;
  final DateTime? loggedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  VaccineRecordModel({
    required this.id,
    required this.babyId,
    required this.vaccineName,
    required this.vaccineFullName,
    required this.doseNumber,
    required this.totalDoses,
    required this.scheduledDate,
    required this.ageMonths,
    this.administeredDate,
    this.administeredBy,
    this.location,
    this.lotNumber,
    this.manufacturer,
    required this.status,
    required this.hadReaction,
    this.reactionDetails,
    required this.remindersSent,
    this.loggedBy,
    this.loggedAt,
    required this.createdAt,
    this.updatedAt,
  });
  
  // Display helpers
  String get doseDisplay => 'Dose $doseNumber of $totalDoses';
  
  String get statusDisplay {
    switch (status) {
      case VaccineStatus.scheduled:
        return 'Scheduled';
      case VaccineStatus.administered:
        return 'Completed';
      case VaccineStatus.overdue:
        return 'Overdue';
      case VaccineStatus.skipped:
        return 'Skipped';
      case VaccineStatus.rescheduled:
        return 'Rescheduled';
    }
  }
  
  bool get isCompleted => status == VaccineStatus.administered;
  bool get isDue {
    if (status != VaccineStatus.scheduled) return false;
    return DateTime.now().isAfter(scheduledDate);
  }
  bool get isOverdue {
    if (status != VaccineStatus.scheduled) return false;
    return DateTime.now().difference(scheduledDate).inDays > 7;
  }
  
  int get daysUntilDue {
    return scheduledDate.difference(DateTime.now()).inDays;
  }
  
  String get dueDisplay {
    if (isCompleted) {
      return 'Completed ${_formatDate(administeredDate!)}';
    }
    
    final days = daysUntilDue;
    if (days < 0) {
      return 'Overdue by ${-days} days';
    } else if (days == 0) {
      return 'Due today';
    } else if (days == 1) {
      return 'Due tomorrow';
    } else if (days <= 7) {
      return 'Due in $days days';
    } else {
      return 'Due ${_formatDate(scheduledDate)}';
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
  
  factory VaccineRecordModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return VaccineRecordModel(
      id: doc.id,
      babyId: data['babyId'] ?? '',
      vaccineName: data['vaccineName'] ?? '',
      vaccineFullName: data['vaccineFullName'] ?? '',
      doseNumber: data['doseNumber'] ?? 1,
      totalDoses: data['totalDoses'] ?? 1,
      scheduledDate: (data['scheduledDate'] as Timestamp).toDate(),
      ageMonths: data['ageMonths'] ?? 0,
      administeredDate: data['administeredDate'] != null
          ? (data['administeredDate'] as Timestamp).toDate()
          : null,
      administeredBy: data['administeredBy'],
      location: data['location'],
      lotNumber: data['lotNumber'],
      manufacturer: data['manufacturer'],
      status: VaccineStatus.values.firstWhere(
        (e) => e.toString() == 'VaccineStatus.${data['status']}',
        orElse: () => VaccineStatus.scheduled,
      ),
      hadReaction: data['hadReaction'] ?? false,
      reactionDetails: data['reactionDetails'] != null
          ? VaccineReactionDetails.fromMap(data['reactionDetails'])
          : null,
      remindersSent: VaccineReminders.fromMap(data['remindersSent'] ?? {}),
      loggedBy: data['loggedBy'],
      loggedAt: data['loggedAt'] != null
          ? (data['loggedAt'] as Timestamp).toDate()
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'babyId': babyId,
      'vaccineName': vaccineName,
      'vaccineFullName': vaccineFullName,
      'doseNumber': doseNumber,
      'totalDoses': totalDoses,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'ageMonths': ageMonths,
      'administeredDate': administeredDate != null
          ? Timestamp.fromDate(administeredDate!)
          : null,
      'administeredBy': administeredBy,
      'location': location,
      'lotNumber': lotNumber,
      'manufacturer': manufacturer,
      'status': status.toString().split('.').last,
      'hadReaction': hadReaction,
      'reactionDetails': reactionDetails?.toMap(),
      'remindersSent': remindersSent.toMap(),
      'loggedBy': loggedBy,
      'loggedAt': loggedAt != null ? Timestamp.fromDate(loggedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

// ═══════════════════════════════════════════════════════════
// Supporting Enums & Classes
// ═══════════════════════════════════════════════════════════

enum VaccineStatus {
  scheduled,
  administered,
  overdue,
  skipped,
  rescheduled,
}

class VaccineReactionDetails {
  final String severity;  // 'mild', 'moderate', 'severe'
  final List<String> symptoms;
  final String notes;
  final DateTime reportedAt;
  
  VaccineReactionDetails({
    required this.severity,
    required this.symptoms,
    required this.notes,
    required this.reportedAt,
  });
  
  factory VaccineReactionDetails.fromMap(Map<String, dynamic> map) {
    return VaccineReactionDetails(
      severity: map['severity'] ?? 'mild',
      symptoms: List<String>.from(map['symptoms'] ?? []),
      notes: map['notes'] ?? '',
      reportedAt: (map['reportedAt'] as Timestamp).toDate(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'severity': severity,
      'symptoms': symptoms,
      'notes': notes,
      'reportedAt': Timestamp.fromDate(reportedAt),
    };
  }
}

class VaccineReminders {
  final bool oneWeekBefore;
  final bool threeDaysBefore;
  final bool oneDayBefore;
  final bool overdueAlert;
  
  VaccineReminders({
    this.oneWeekBefore = false,
    this.threeDaysBefore = false,
    this.oneDayBefore = false,
    this.overdueAlert = false,
  });
  
  factory VaccineReminders.fromMap(Map<String, dynamic> map) {
    return VaccineReminders(
      oneWeekBefore: map['oneWeekBefore'] ?? false,
      threeDaysBefore: map['threeDaysBefore'] ?? false,
      oneDayBefore: map['oneDayBefore'] ?? false,
      overdueAlert: map['overdueAlert'] ?? false,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'oneWeekBefore': oneWeekBefore,
      'threeDaysBefore': threeDaysBefore,
      'oneDayBefore': oneDayBefore,
      'overdueAlert': overdueAlert,
    };
  }
}
```

---

## 4️⃣ CLOUD FUNCTIONS

```typescript
// ═══════════════════════════════════════════════════════════
// functions/src/vaccineScheduling.ts
// ═══════════════════════════════════════════════════════════

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

// ═══════════════════════════════════════════════════════════
// Generate Vaccine Schedule when Baby is Created
// ═══════════════════════════════════════════════════════════

export const onBabyCreate = functions.firestore
  .document('babies/{babyId}')
  .onCreate(async (snap, context) => {
    
    const baby = snap.data();
    const { babyId } = context.params;
    
    const birthDate = baby.birthDate.toDate();
    const country = baby.country || 'USA';  // Default to USA/CDC
    
    console.log(`[onBabyCreate] Generating vaccine schedule for ${babyId}, Country: ${country}`);
    
    try {
      // Load vaccine schedule (CDC/WHO/IAP)
      const schedule = await loadVaccineSchedule(country);
      
      // Create vaccine records
      const batch = db.batch();
      
      for (const vaccine of schedule.vaccines) {
        for (const dose of vaccine.doses) {
          const scheduledDate = calculateScheduledDate(birthDate, dose.age_months);
          
          const vaccineRef = db
            .collection('babies')
            .doc(babyId)
            .collection('vaccines')
            .doc();
          
          batch.set(vaccineRef, {
            babyId,
            vaccineName: vaccine.short_name,
            vaccineFullName: vaccine.vaccine_name,
            doseNumber: dose.dose_number,
            totalDoses: vaccine.doses.length,
            scheduledDate: admin.firestore.Timestamp.fromDate(scheduledDate),
            ageMonths: dose.age_months,
            status: 'scheduled',
            hadReaction: false,
            remindersSent: {
              oneWeekBefore: false,
              threeDaysBefore: false,
              oneDayBefore: false,
              overdueAlert: false,
            },
            createdAt: admin.firestore.Timestamp.now(),
          });
          
          // Schedule reminders
          await scheduleReminders(babyId, vaccineRef.id, vaccine.short_name, dose.dose_number, scheduledDate);
        }
      }
      
      await batch.commit();
      console.log(`[onBabyCreate] Created ${schedule.vaccines.length} vaccine schedules`);
      
    } catch (error) {
      console.error('[onBabyCreate] Error:', error);
    }
  });

function calculateScheduledDate(birthDate: Date, ageMonths: number): Date {
  const scheduled = new Date(birthDate);
  scheduled.setMonth(scheduled.getMonth() + ageMonths);
  return scheduled;
}

async function loadVaccineSchedule(country: string): Promise<any> {
  // In production, load from Firestore reference_data/vaccine_schedules/{country}
  // For now, return CDC schedule
  return {
    country: 'USA',
    vaccines: [
      {
        vaccine_name: 'Hepatitis B (HepB)',
        short_name: 'HepB',
        doses: [
          { dose_number: 1, age_months: 0 },
          { dose_number: 2, age_months: 2 },
          { dose_number: 3, age_months: 6 },
        ],
      },
      {
        vaccine_name: 'DTaP',
        short_name: 'DTaP',
        doses: [
          { dose_number: 1, age_months: 2 },
          { dose_number: 2, age_months: 4 },
          { dose_number: 3, age_months: 6 },
          { dose_number: 4, age_months: 18 },
          { dose_number: 5, age_months: 60 },
        ],
      },
      // ... more vaccines
    ],
  };
}

// ═══════════════════════════════════════════════════════════
// Schedule Reminders
// ═══════════════════════════════════════════════════════════

async function scheduleReminders(
  babyId: string,
  vaccineRecordId: string,
  vaccineName: string,
  doseNumber: number,
  dueDate: Date
): Promise<void> {
  
  const reminders = [
    { type: '1_week', daysBefore: 7 },
    { type: '3_days', daysBefore: 3 },
    { type: '1_day', daysBefore: 1 },
  ];
  
  for (const reminder of reminders) {
    const scheduledTime = new Date(dueDate);
    scheduledTime.setDate(scheduledTime.getDate() - reminder.daysBefore);
    scheduledTime.setHours(9, 0, 0, 0);  // 9 AM
    
    await db.collection('scheduled_reminders').add({
      babyId,
      vaccineRecordId,
      vaccineName,
      doseNumber,
      reminderType: reminder.type,
      dueDate: admin.firestore.Timestamp.fromDate(dueDate),
      scheduledTime: admin.firestore.Timestamp.fromDate(scheduledTime),
      status: 'pending',
      title: `💉 ${vaccineName} Dose ${doseNumber} Reminder`,
      message: `${vaccineName} dose ${doseNumber} is due in ${reminder.daysBefore} day(s)`,
      createdAt: admin.firestore.Timestamp.now(),
    });
  }
}

// ═══════════════════════════════════════════════════════════
// Send Reminders (Scheduled Function - Runs Daily at 9 AM)
// ═══════════════════════════════════════════════════════════

export const sendVaccineReminders = functions.pubsub
  .schedule('0 9 * * *')  // Every day at 9 AM
  .timeZone('America/New_York')
  .onRun(async (context) => {
    
    console.log('[sendVaccineReminders] Checking for due reminders');
    
    const now = admin.firestore.Timestamp.now();
    
    // Get pending reminders that are due
    const remindersSnapshot = await db
      .collection('scheduled_reminders')
      .where('status', '==', 'pending')
      .where('scheduledTime', '<=', now)
      .get();
    
    console.log(`[sendVaccineReminders] Found ${remindersSnapshot.size} reminders to send`);
    
    for (const reminderDoc of remindersSnapshot.docs) {
      const reminder = reminderDoc.data();
      
      try {
        // Get baby data for family members
        const babyDoc = await db.collection('babies').doc(reminder.babyId).get();
        const familyMembers = babyDoc.data()?.familyMembers || [];
        
        // Get FCM tokens
        const tokens: string[] = [];
        for (const userId of familyMembers) {
          const userDoc = await db.collection('users').doc(userId).get();
          const fcmToken = userDoc.data()?.fcmToken;
          if (fcmToken) tokens.push(fcmToken);
        }
        
        if (tokens.length > 0) {
          await admin.messaging().sendMulticast({
            tokens,
            notification: {
              title: reminder.title,
              body: reminder.message,
            },
            data: {
              type: 'vaccine_reminder',
              babyId: reminder.babyId,
              vaccineRecordId: reminder.vaccineRecordId,
            },
          });
          
          // Update reminder status
          await reminderDoc.ref.update({
            status: 'sent',
            sentAt: admin.firestore.Timestamp.now(),
          });
          
          // Update vaccine record
          await db
            .collection('babies')
            .doc(reminder.babyId)
            .collection('vaccines')
            .doc(reminder.vaccineRecordId)
            .update({
              [`remindersSent.${reminder.reminderType.replace('_', '')}`]: true,
            });
        }
        
      } catch (error) {
        console.error(`[sendVaccineReminders] Error sending reminder ${reminderDoc.id}:`, error);
      }
    }
  });

// ═══════════════════════════════════════════════════════════
// Check for Overdue Vaccines (Daily at 10 AM)
// ═══════════════════════════════════════════════════════════

export const checkOverdueVaccines = functions.pubsub
  .schedule('0 10 * * *')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    
    console.log('[checkOverdueVaccines] Checking for overdue vaccines');
    
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    
    // Find scheduled vaccines that are 7+ days overdue
    const overdueSnapshot = await db
      .collectionGroup('vaccines')
      .where('status', '==', 'scheduled')
      .where('scheduledDate', '<', admin.firestore.Timestamp.fromDate(sevenDaysAgo))
      .where('remindersSent.overdueAlert', '==', false)
      .get();
    
    console.log(`[checkOverdueVaccines] Found ${overdueSnapshot.size} overdue vaccines`);
    
    for (const vaccineDoc of overdueSnapshot.docs) {
      const vaccine = vaccineDoc.data();
      
      try {
        // Send overdue alert
        const babyDoc = await db.collection('babies').doc(vaccine.babyId).get();
        const familyMembers = babyDoc.data()?.familyMembers || [];
        
        const tokens: string[] = [];
        for (const userId of familyMembers) {
          const userDoc = await db.collection('users').doc(userId).get();
          const fcmToken = userDoc.data()?.fcmToken;
          if (fcmToken) tokens.push(fcmToken);
        }
        
        if (tokens.length > 0) {
          const daysOverdue = Math.floor(
            (Date.now() - vaccine.scheduledDate.toDate().getTime()) / (1000 * 60 * 60 * 24)
          );
          
          await admin.messaging().sendMulticast({
            tokens,
            notification: {
              title: `⚠️ ${vaccine.vaccineName} Overdue`,
              body: `${vaccine.vaccineName} dose ${vaccine.doseNumber} is ${daysOverdue} days overdue. Please schedule an appointment.`,
            },
            data: {
              type: 'vaccine_overdue',
              babyId: vaccine.babyId,
              vaccineRecordId: vaccineDoc.id,
            },
          });
          
          // Mark as overdue and alert sent
          await vaccineDoc.ref.update({
            status: 'overdue',
            'remindersSent.overdueAlert': true,
            updatedAt: admin.firestore.Timestamp.now(),
          });
        }
        
      } catch (error) {
        console.error(`[checkOverdueVaccines] Error for vaccine ${vaccineDoc.id}:`, error);
      }
    }
  });
```

---

## 5️⃣ FLUTTER IMPLEMENTATION

```dart
// ═══════════════════════════════════════════════════════════
// lib/services/vaccine_service.dart
// ═══════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vaccine_record_model.dart';

class VaccineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Stream upcoming vaccines (scheduled only)
  Stream<List<VaccineRecordModel>> streamUpcomingVaccines(String babyId) {
    return _firestore
        .collection('babies')
        .doc(babyId)
        .collection('vaccines')
        .where('status', isEqualTo: 'scheduled')
        .orderBy('scheduledDate')
        .limit(5)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => VaccineRecordModel.fromFirestore(doc))
          .toList();
    });
  }
  
  /// Get all vaccines (for timeline view)
  Stream<List<VaccineRecordModel>> streamAllVaccines(String babyId) {
    return _firestore
        .collection('babies')
        .doc(babyId)
        .collection('vaccines')
        .orderBy('scheduledDate')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => VaccineRecordModel.fromFirestore(doc))
          .toList();
    });
  }
  
  /// Record administered vaccine
  Future<void> recordVaccine({
    required String babyId,
    required String vaccineId,
    required String userId,
    required DateTime administeredDate,
    String? administeredBy,
    String? location,
    String? lotNumber,
    String? manufacturer,
    bool hadReaction = false,
    String? reactionSeverity,
    List<String>? reactionSymptoms,
    String? reactionNotes,
  }) async {
    
    final updates = <String, dynamic>{
      'administeredDate': Timestamp.fromDate(administeredDate),
      'administeredBy': administeredBy,
      'location': location,
      'lotNumber': lotNumber,
      'manufacturer': manufacturer,
      'status': 'administered',
      'hadReaction': hadReaction,
      'loggedBy': userId,
      'loggedAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
    
    if (hadReaction && reactionSeverity != null) {
      updates['reactionDetails'] = {
        'severity': reactionSeverity,
        'symptoms': reactionSymptoms ?? [],
        'notes': reactionNotes ?? '',
        'reportedAt': Timestamp.fromDate(DateTime.now()),
      };
      
      // Also create separate reaction document
      await _firestore
          .collection('babies')
          .doc(babyId)
          .collection('vaccine_reactions')
          .add({
        'babyId': babyId,
        'vaccineRecordId': vaccineId,
        'severity': reactionSeverity,
        'symptoms': reactionSymptoms ?? [],
        'notes': reactionNotes ?? '',
        'reportedBy': userId,
        'reportedAt': Timestamp.fromDate(DateTime.now()),
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    }
    
    await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('vaccines')
        .doc(vaccineId)
        .update(updates);
  }
  
  /// Get completion percentage
  Future<double> getCompletionPercentage(String babyId) async {
    final snapshot = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('vaccines')
        .get();
    
    if (snapshot.docs.isEmpty) return 0.0;
    
    final total = snapshot.docs.length;
    final completed = snapshot.docs
        .where((doc) => doc.data()['status'] == 'administered')
        .length;
    
    return (completed / total) * 100;
  }
}
```

---

## 6️⃣ REMINDER SYSTEM

### **6.1 Reminder Schedule**

```
Vaccine Reminder Timeline:
├─ 1 week before: "MMR dose 1 due in 7 days"
├─ 3 days before: "MMR dose 1 due in 3 days - schedule appointment"
├─ 1 day before: "MMR dose 1 due tomorrow"
├─ Due date: No notification (already sent 1 day before)
└─ 7 days overdue: "MMR dose 1 is 7 days overdue - schedule now!"
```

### **6.2 Notification Examples**

```dart
// 1 Week Before
Notification(
  title: "💉 MMR Dose 1 Reminder",
  body: "MMR dose 1 is due in 7 days (Feb 15). Schedule pediatrician appointment.",
  data: {
    type: "vaccine_reminder",
    babyId: "baby123",
    vaccineRecordId: "vaccine456"
  }
)

// 3 Days Before
Notification(
  title: "💉 MMR Dose 1 - 3 Days",
  body: "MMR dose 1 due in 3 days. Don't forget to schedule!",
)

// Overdue
Notification(
  title: "⚠️ MMR Overdue",
  body: "MMR dose 1 is 7 days overdue. Please schedule appointment soon.",
)
```

---

## 7️⃣ IMPLEMENTATION ROADMAP

### **Phase 1: Vaccine Schedules (Week 1)**
- [ ] Add CDC/WHO/IAP schedule JSON files to assets
- [ ] Create VaccineRecordModel
- [ ] Implement onBabyCreate to generate schedule
- [ ] Test with sample baby

### **Phase 2: Vaccine Service & UI (Week 1-2)**
- [ ] Create VaccineService
- [ ] Build vaccine timeline screen
- [ ] Create "record vaccine" form
- [ ] Add reaction tracking
- [ ] Test CRUD operations

### **Phase 3: Reminder System (Week 2)**
- [ ] Implement scheduleReminders
- [ ] Create sendVaccineReminders (Cloud Function)
- [ ] Create checkOverdueVaccines (Cloud Function)
- [ ] Test notification delivery

### **Phase 4: Certificate Export (Week 3)**
- [ ] Generate PDF vaccine certificate
- [ ] Include all administered vaccines
- [ ] Add QR code with verification
- [ ] Test PDF generation

---

## ✅ SUCCESS METRICS

- [ ] Vaccine schedule auto-generated on baby creation
- [ ] Reminders sent 1 week, 3 days, 1 day before due date
- [ ] Overdue alerts triggered after 7 days
- [ ] Completion percentage calculated correctly
- [ ] PDF certificate includes all vaccines
- [ ] Record vaccine takes <90 seconds

---

**Ready to implement!** Start with Phase 1 (Vaccine Schedules). 💉

