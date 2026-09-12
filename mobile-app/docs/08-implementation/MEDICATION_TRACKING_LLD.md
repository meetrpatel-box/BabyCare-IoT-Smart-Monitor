# Medication Tracking - Low-Level Design (LLD)

**Document ID**: LLD-MEDICATION-001  
**Version**: 1.0.0  
**Status**: 🟢 Ready for Implementation  
**Last Updated**: February 2, 2026  
**Feature**: Medication & Supplement Tracking with Reminders

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Data Models](#data-models)
3. [Service Layer](#service-layer)
4. [Cloud Functions](#cloud-functions)
5. [UI Components](#ui-components)
6. [User Flows](#user-flows)
7. [Safety Features](#safety-features)
8. [Implementation Roadmap](#implementation-roadmap)

---

## 1. Overview

### 1.1 Purpose

Medication tracking helps parents safely manage:
- **Prescription medications** (antibiotics, fever reducers, etc.)
- **Over-the-counter medicines** (pain relief, gas drops, vitamins)
- **Supplements** (vitamin D, iron, probiotics)
- **Vaccinations** (cross-reference with vaccine tracking)

The system provides:
- Safe dosage calculations based on weight/age
- Reminders for recurring medications
- Overdose prevention (time-based warnings)
- Medication history and adherence tracking
- Inventory management with refill reminders

### 1.2 Key Features

| Feature | Description | Priority |
|---------|-------------|----------|
| Log Medication | Quick logging with timestamp | P0 |
| Dosage Calculator | Weight/age-based safe dosing | P0 |
| Recurring Schedule | Set up daily/weekly medication | P0 |
| Reminders | Push notifications for doses | P0 |
| Overdose Protection | Warn if dose too soon | P0 |
| Medication Library | Searchable database of common meds | P1 |
| Inventory Tracking | Monitor supply and refills | P1 |
| Photo Attachment | Capture prescription labels | P2 |
| Adherence Reports | Missed dose tracking | P2 |
| Export to Pediatrician | Medical history export | P2 |

### 1.3 Medication Categories

```dart
enum MedicationType {
  prescription,      // Doctor-prescribed medications
  overTheCounter,    // OTC medicines
  supplement,        // Vitamins, minerals, probiotics
  homeopathic,       // Homeopathic remedies
  other,            // Other treatments
}

enum MedicationForm {
  liquid,           // Liquid suspension, drops
  tablet,           // Pills, tablets
  capsule,          // Capsules
  chewable,         // Chewable tablets
  suppository,      // Rectal/vaginal suppository
  topical,          // Creams, ointments, patches
  inhaler,          // Inhalers, nebulizers
  injection,        // Injections (usually medical professional)
  other,
}

enum DosageUnit {
  ml,               // Milliliters
  mg,               // Milligrams
  mcg,              // Micrograms
  drops,            // Drops
  teaspoon,         // Teaspoons
  tablespoon,       // Tablespoons
  units,            // Units (e.g., insulin)
  puff,             // Puffs (inhalers)
  application,      // Applications (topical)
}

enum FrequencyType {
  asNeeded,         // PRN (as needed)
  onceDaily,        // Once per day
  twiceDaily,       // Twice per day (BID)
  threeTimes,       // Three times daily (TID)
  fourTimes,        // Four times daily (QID)
  everyXHours,      // Every X hours
  weekly,           // Once per week
  custom,           // Custom schedule
}
```

---

## 2. Data Models

### 2.1 Flutter Model: `MedicationModel`

**File**: `lib/models/medication_model.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum MedicationType {
  prescription,
  overTheCounter,
  supplement,
  homeopathic,
  other;

  String get displayName {
    switch (this) {
      case MedicationType.prescription:
        return 'Prescription';
      case MedicationType.overTheCounter:
        return 'Over-the-Counter';
      case MedicationType.supplement:
        return 'Supplement';
      case MedicationType.homeopathic:
        return 'Homeopathic';
      case MedicationType.other:
        return 'Other';
    }
  }
}

enum MedicationForm {
  liquid,
  tablet,
  capsule,
  chewable,
  suppository,
  topical,
  inhaler,
  injection,
  other;

  String get displayName {
    switch (this) {
      case MedicationForm.liquid:
        return 'Liquid';
      case MedicationForm.tablet:
        return 'Tablet';
      case MedicationForm.capsule:
        return 'Capsule';
      case MedicationForm.chewable:
        return 'Chewable';
      case MedicationForm.suppository:
        return 'Suppository';
      case MedicationForm.topical:
        return 'Topical';
      case MedicationForm.inhaler:
        return 'Inhaler';
      case MedicationForm.injection:
        return 'Injection';
      case MedicationForm.other:
        return 'Other';
    }
  }
}

enum DosageUnit {
  ml,
  mg,
  mcg,
  drops,
  teaspoon,
  tablespoon,
  units,
  puff,
  application;

  String get displayName {
    switch (this) {
      case DosageUnit.ml:
        return 'mL';
      case DosageUnit.mg:
        return 'mg';
      case DosageUnit.mcg:
        return 'mcg';
      case DosageUnit.drops:
        return 'drops';
      case DosageUnit.teaspoon:
        return 'tsp';
      case DosageUnit.tablespoon:
        return 'tbsp';
      case DosageUnit.units:
        return 'units';
      case DosageUnit.puff:
        return 'puff';
      case DosageUnit.application:
        return 'application';
    }
  }
}

enum FrequencyType {
  asNeeded,
  onceDaily,
  twiceDaily,
  threeTimes,
  fourTimes,
  everyXHours,
  weekly,
  custom;

  String get displayName {
    switch (this) {
      case FrequencyType.asNeeded:
        return 'As Needed (PRN)';
      case FrequencyType.onceDaily:
        return 'Once Daily';
      case FrequencyType.twiceDaily:
        return 'Twice Daily';
      case FrequencyType.threeTimes:
        return 'Three Times Daily';
      case FrequencyType.fourTimes:
        return 'Four Times Daily';
      case FrequencyType.everyXHours:
        return 'Every X Hours';
      case FrequencyType.weekly:
        return 'Weekly';
      case FrequencyType.custom:
        return 'Custom';
    }
  }
}

class DosageInfo {
  final double amount;
  final DosageUnit unit;
  final String? instructions; // "Take with food", "Before bedtime"

  DosageInfo({
    required this.amount,
    required this.unit,
    this.instructions,
  });

  String get formattedDosage => '$amount ${unit.displayName}';

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'unit': unit.name,
      'instructions': instructions,
    };
  }

  factory DosageInfo.fromMap(Map<String, dynamic> map) {
    return DosageInfo(
      amount: (map['amount'] as num).toDouble(),
      unit: DosageUnit.values.firstWhere((e) => e.name == map['unit']),
      instructions: map['instructions'] as String?,
    );
  }
}

class MedicationSchedule {
  final FrequencyType frequencyType;
  final int? intervalHours; // For everyXHours type
  final List<String>? customTimes; // ["08:00", "14:00", "20:00"] for custom
  final DateTime startDate;
  final DateTime? endDate; // null = ongoing
  final bool enableReminders;

  MedicationSchedule({
    required this.frequencyType,
    this.intervalHours,
    this.customTimes,
    required this.startDate,
    this.endDate,
    this.enableReminders = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'frequencyType': frequencyType.name,
      'intervalHours': intervalHours,
      'customTimes': customTimes,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'enableReminders': enableReminders,
    };
  }

  factory MedicationSchedule.fromMap(Map<String, dynamic> map) {
    return MedicationSchedule(
      frequencyType: FrequencyType.values.firstWhere(
        (e) => e.name == map['frequencyType'],
      ),
      intervalHours: map['intervalHours'] as int?,
      customTimes: (map['customTimes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: map['endDate'] != null
          ? (map['endDate'] as Timestamp).toDate()
          : null,
      enableReminders: map['enableReminders'] as bool? ?? true,
    );
  }

  /// Get next scheduled dose time
  DateTime? getNextDoseTime() {
    final now = DateTime.now();
    
    if (endDate != null && now.isAfter(endDate!)) {
      return null; // Schedule ended
    }

    switch (frequencyType) {
      case FrequencyType.asNeeded:
        return null; // No scheduled time

      case FrequencyType.onceDaily:
        final scheduledTime = DateTime(
          now.year,
          now.month,
          now.day,
          startDate.hour,
          startDate.minute,
        );
        if (scheduledTime.isBefore(now)) {
          return scheduledTime.add(const Duration(days: 1));
        }
        return scheduledTime;

      case FrequencyType.everyXHours:
        if (intervalHours == null) return null;
        // Calculate next dose based on start date
        var nextDose = startDate;
        while (nextDose.isBefore(now)) {
          nextDose = nextDose.add(Duration(hours: intervalHours!));
        }
        return nextDose;

      case FrequencyType.custom:
        if (customTimes == null || customTimes!.isEmpty) return null;
        // Find next scheduled time today or tomorrow
        final today = DateTime(now.year, now.month, now.day);
        for (final timeStr in customTimes!) {
          final parts = timeStr.split(':');
          final scheduled = today.add(Duration(
            hours: int.parse(parts[0]),
            minutes: int.parse(parts[1]),
          ));
          if (scheduled.isAfter(now)) {
            return scheduled;
          }
        }
        // All times passed today, return first time tomorrow
        final parts = customTimes!.first.split(':');
        return today.add(Duration(
          days: 1,
          hours: int.parse(parts[0]),
          minutes: int.parse(parts[1]),
        ));

      default:
        return null;
    }
  }
}

/// Master medication definition (reusable across doses)
class MedicationModel {
  final String id;
  final String babyId;
  final String userId;
  
  // Medication info
  final String name; // "Tylenol", "Vitamin D"
  final String? genericName; // "Acetaminophen"
  final MedicationType type;
  final MedicationForm form;
  
  // Dosage info
  final DosageInfo dosage;
  final double? concentrationMg; // For liquids: mg/mL
  final double? maxDailyDose; // Maximum allowed per 24 hours
  final int? minHoursBetweenDoses; // Minimum time between doses
  
  // Schedule
  final MedicationSchedule? schedule; // null for PRN medications
  
  // Prescription details
  final String? prescribedBy; // Doctor name
  final String? pharmacyName;
  final String? prescriptionNumber;
  final DateTime? prescriptionDate;
  
  // Inventory
  final double? currentStock; // How much is left
  final DosageUnit? stockUnit;
  final double? lowStockThreshold; // Alert when below this
  final DateTime? expirationDate;
  
  // Additional info
  final String? purpose; // "Fever", "Pain", "Vitamin supplement"
  final String? sideEffects; // Known side effects
  final String? notes;
  final String? photoUrl; // Photo of prescription label
  
  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive; // false if discontinued

  MedicationModel({
    required this.id,
    required this.babyId,
    required this.userId,
    required this.name,
    this.genericName,
    required this.type,
    required this.form,
    required this.dosage,
    this.concentrationMg,
    this.maxDailyDose,
    this.minHoursBetweenDoses,
    this.schedule,
    this.prescribedBy,
    this.pharmacyName,
    this.prescriptionNumber,
    this.prescriptionDate,
    this.currentStock,
    this.stockUnit,
    this.lowStockThreshold,
    this.expirationDate,
    this.purpose,
    this.sideEffects,
    this.notes,
    this.photoUrl,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  // Computed properties
  bool get isPrescription => type == MedicationType.prescription;
  bool get isScheduled => schedule != null;
  bool get isAsNeeded => schedule?.frequencyType == FrequencyType.asNeeded || schedule == null;
  
  bool get isLowStock {
    if (currentStock == null || lowStockThreshold == null) return false;
    return currentStock! <= lowStockThreshold!;
  }

  bool get isExpiringSoon {
    if (expirationDate == null) return false;
    final daysUntilExpiry = expirationDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry >= 0 && daysUntilExpiry <= 30;
  }

  bool get isExpired {
    if (expirationDate == null) return false;
    return DateTime.now().isAfter(expirationDate!);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'babyId': babyId,
      'userId': userId,
      'name': name,
      'genericName': genericName,
      'type': type.name,
      'form': form.name,
      'dosage': dosage.toMap(),
      'concentrationMg': concentrationMg,
      'maxDailyDose': maxDailyDose,
      'minHoursBetweenDoses': minHoursBetweenDoses,
      'schedule': schedule?.toMap(),
      'prescribedBy': prescribedBy,
      'pharmacyName': pharmacyName,
      'prescriptionNumber': prescriptionNumber,
      'prescriptionDate': prescriptionDate != null
          ? Timestamp.fromDate(prescriptionDate!)
          : null,
      'currentStock': currentStock,
      'stockUnit': stockUnit?.name,
      'lowStockThreshold': lowStockThreshold,
      'expirationDate': expirationDate != null
          ? Timestamp.fromDate(expirationDate!)
          : null,
      'purpose': purpose,
      'sideEffects': sideEffects,
      'notes': notes,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  factory MedicationModel.fromMap(Map<String, dynamic> map) {
    return MedicationModel(
      id: map['id'] as String,
      babyId: map['babyId'] as String,
      userId: map['userId'] as String,
      name: map['name'] as String,
      genericName: map['genericName'] as String?,
      type: MedicationType.values.firstWhere((e) => e.name == map['type']),
      form: MedicationForm.values.firstWhere((e) => e.name == map['form']),
      dosage: DosageInfo.fromMap(map['dosage'] as Map<String, dynamic>),
      concentrationMg: map['concentrationMg'] as double?,
      maxDailyDose: map['maxDailyDose'] as double?,
      minHoursBetweenDoses: map['minHoursBetweenDoses'] as int?,
      schedule: map['schedule'] != null
          ? MedicationSchedule.fromMap(map['schedule'] as Map<String, dynamic>)
          : null,
      prescribedBy: map['prescribedBy'] as String?,
      pharmacyName: map['pharmacyName'] as String?,
      prescriptionNumber: map['prescriptionNumber'] as String?,
      prescriptionDate: map['prescriptionDate'] != null
          ? (map['prescriptionDate'] as Timestamp).toDate()
          : null,
      currentStock: map['currentStock'] as double?,
      stockUnit: map['stockUnit'] != null
          ? DosageUnit.values.firstWhere((e) => e.name == map['stockUnit'])
          : null,
      lowStockThreshold: map['lowStockThreshold'] as double?,
      expirationDate: map['expirationDate'] != null
          ? (map['expirationDate'] as Timestamp).toDate()
          : null,
      purpose: map['purpose'] as String?,
      sideEffects: map['sideEffects'] as String?,
      notes: map['notes'] as String?,
      photoUrl: map['photoUrl'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  factory MedicationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MedicationModel.fromMap({...data, 'id': doc.id});
  }

  MedicationModel copyWith({
    String? id,
    String? babyId,
    String? userId,
    String? name,
    String? genericName,
    MedicationType? type,
    MedicationForm? form,
    DosageInfo? dosage,
    double? concentrationMg,
    double? maxDailyDose,
    int? minHoursBetweenDoses,
    MedicationSchedule? schedule,
    String? prescribedBy,
    String? pharmacyName,
    String? prescriptionNumber,
    DateTime? prescriptionDate,
    double? currentStock,
    DosageUnit? stockUnit,
    double? lowStockThreshold,
    DateTime? expirationDate,
    String? purpose,
    String? sideEffects,
    String? notes,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return MedicationModel(
      id: id ?? this.id,
      babyId: babyId ?? this.babyId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      genericName: genericName ?? this.genericName,
      type: type ?? this.type,
      form: form ?? this.form,
      dosage: dosage ?? this.dosage,
      concentrationMg: concentrationMg ?? this.concentrationMg,
      maxDailyDose: maxDailyDose ?? this.maxDailyDose,
      minHoursBetweenDoses: minHoursBetweenDoses ?? this.minHoursBetweenDoses,
      schedule: schedule ?? this.schedule,
      prescribedBy: prescribedBy ?? this.prescribedBy,
      pharmacyName: pharmacyName ?? this.pharmacyName,
      prescriptionNumber: prescriptionNumber ?? this.prescriptionNumber,
      prescriptionDate: prescriptionDate ?? this.prescriptionDate,
      currentStock: currentStock ?? this.currentStock,
      stockUnit: stockUnit ?? this.stockUnit,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      expirationDate: expirationDate ?? this.expirationDate,
      purpose: purpose ?? this.purpose,
      sideEffects: sideEffects ?? this.sideEffects,
      notes: notes ?? this.notes,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
```

### 2.2 Flutter Model: `MedicationDoseModel`

**File**: `lib/models/medication_dose_model.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'medication_model.dart';

/// Individual dose administration record
class MedicationDoseModel {
  final String id;
  final String medicationId; // Reference to MedicationModel
  final String babyId;
  final String userId;
  
  // Dose details
  final DateTime administeredAt;
  final DosageInfo dosageGiven;
  final bool wasScheduled; // true if from schedule, false if PRN
  
  // Additional info
  final String? reasonGiven; // For PRN: "fever", "pain", etc.
  final double? temperatureBefore; // If given for fever
  final double? temperatureAfter; // Check effectiveness
  final String? notes;
  final String? administeredBy; // "Mom", "Dad", "Caregiver Name"
  
  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  MedicationDoseModel({
    required this.id,
    required this.medicationId,
    required this.babyId,
    required this.userId,
    required this.administeredAt,
    required this.dosageGiven,
    this.wasScheduled = false,
    this.reasonGiven,
    this.temperatureBefore,
    this.temperatureAfter,
    this.notes,
    this.administeredBy,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicationId': medicationId,
      'babyId': babyId,
      'userId': userId,
      'administeredAt': Timestamp.fromDate(administeredAt),
      'dosageGiven': dosageGiven.toMap(),
      'wasScheduled': wasScheduled,
      'reasonGiven': reasonGiven,
      'temperatureBefore': temperatureBefore,
      'temperatureAfter': temperatureAfter,
      'notes': notes,
      'administeredBy': administeredBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory MedicationDoseModel.fromMap(Map<String, dynamic> map) {
    return MedicationDoseModel(
      id: map['id'] as String,
      medicationId: map['medicationId'] as String,
      babyId: map['babyId'] as String,
      userId: map['userId'] as String,
      administeredAt: (map['administeredAt'] as Timestamp).toDate(),
      dosageGiven: DosageInfo.fromMap(map['dosageGiven'] as Map<String, dynamic>),
      wasScheduled: map['wasScheduled'] as bool? ?? false,
      reasonGiven: map['reasonGiven'] as String?,
      temperatureBefore: map['temperatureBefore'] as double?,
      temperatureAfter: map['temperatureAfter'] as double?,
      notes: map['notes'] as String?,
      administeredBy: map['administeredBy'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  factory MedicationDoseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MedicationDoseModel.fromMap({...data, 'id': doc.id});
  }

  MedicationDoseModel copyWith({
    String? id,
    String? medicationId,
    String? babyId,
    String? userId,
    DateTime? administeredAt,
    DosageInfo? dosageGiven,
    bool? wasScheduled,
    String? reasonGiven,
    double? temperatureBefore,
    double? temperatureAfter,
    String? notes,
    String? administeredBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicationDoseModel(
      id: id ?? this.id,
      medicationId: medicationId ?? this.medicationId,
      babyId: babyId ?? this.babyId,
      userId: userId ?? this.userId,
      administeredAt: administeredAt ?? this.administeredAt,
      dosageGiven: dosageGiven ?? this.dosageGiven,
      wasScheduled: wasScheduled ?? this.wasScheduled,
      reasonGiven: reasonGiven ?? this.reasonGiven,
      temperatureBefore: temperatureBefore ?? this.temperatureBefore,
      temperatureAfter: temperatureAfter ?? this.temperatureAfter,
      notes: notes ?? this.notes,
      administeredBy: administeredBy ?? this.administeredBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
```

### 2.3 Firestore Schema

#### Collection: `medications`

```
medications/{medicationId}
├── id: string
├── babyId: string (indexed)
├── userId: string
├── name: string
├── genericName: string | null
├── type: string ('prescription' | 'overTheCounter' | 'supplement' | 'homeopathic' | 'other')
├── form: string ('liquid' | 'tablet' | 'capsule' | etc.)
├── dosage: object
│   ├── amount: number
│   ├── unit: string
│   └── instructions: string | null
├── concentrationMg: number | null
├── maxDailyDose: number | null
├── minHoursBetweenDoses: number | null
├── schedule: object | null
│   ├── frequencyType: string
│   ├── intervalHours: number | null
│   ├── customTimes: array<string> | null
│   ├── startDate: timestamp
│   ├── endDate: timestamp | null
│   └── enableReminders: boolean
├── prescribedBy: string | null
├── pharmacyName: string | null
├── prescriptionNumber: string | null
├── prescriptionDate: timestamp | null
├── currentStock: number | null
├── stockUnit: string | null
├── lowStockThreshold: number | null
├── expirationDate: timestamp | null
├── purpose: string | null
├── sideEffects: string | null
├── notes: string | null
├── photoUrl: string | null
├── createdAt: timestamp
├── updatedAt: timestamp
└── isActive: boolean
```

**Firestore Indexes**:
```javascript
{
  collectionGroup: "medications",
  fields: [
    { fieldPath: "babyId", order: "ASCENDING" },
    { fieldPath: "isActive", order: "ASCENDING" },
    { fieldPath: "name", order: "ASCENDING" }
  ]
}
```

#### Collection: `medication_doses`

```
medication_doses/{doseId}
├── id: string
├── medicationId: string (indexed)
├── babyId: string (indexed)
├── userId: string
├── administeredAt: timestamp (indexed)
├── dosageGiven: object
│   ├── amount: number
│   ├── unit: string
│   └── instructions: string | null
├── wasScheduled: boolean
├── reasonGiven: string | null
├── temperatureBefore: number | null
├── temperatureAfter: number | null
├── notes: string | null
├── administeredBy: string | null
├── createdAt: timestamp
└── updatedAt: timestamp
```

**Firestore Indexes**:
```javascript
{
  collectionGroup: "medication_doses",
  fields: [
    { fieldPath: "medicationId", order: "ASCENDING" },
    { fieldPath: "administeredAt", order: "DESCENDING" }
  ]
},
{
  collectionGroup: "medication_doses",
  fields: [
    { fieldPath: "babyId", order: "ASCENDING" },
    { fieldPath: "administeredAt", order: "DESCENDING" }
  ]
}
```

---

## 3. Service Layer

### 3.1 MedicationService

**File**: `lib/services/medication_service.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medication_model.dart';
import '../models/medication_dose_model.dart';

class MedicationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  CollectionReference get _medicationsCollection =>
      _firestore.collection('medications');
  
  CollectionReference get _dosesCollection =>
      _firestore.collection('medication_doses');

  // ============================================================================
  // Medication CRUD
  // ============================================================================

  /// Add new medication to baby's profile
  Future<MedicationModel> addMedication({
    required String babyId,
    required String userId,
    required String name,
    String? genericName,
    required MedicationType type,
    required MedicationForm form,
    required DosageInfo dosage,
    double? concentrationMg,
    double? maxDailyDose,
    int? minHoursBetweenDoses,
    MedicationSchedule? schedule,
    String? prescribedBy,
    String? pharmacyName,
    String? prescriptionNumber,
    DateTime? prescriptionDate,
    double? currentStock,
    DosageUnit? stockUnit,
    double? lowStockThreshold,
    DateTime? expirationDate,
    String? purpose,
    String? sideEffects,
    String? notes,
    String? photoUrl,
  }) async {
    final now = DateTime.now();
    
    final medication = MedicationModel(
      id: '',
      babyId: babyId,
      userId: userId,
      name: name,
      genericName: genericName,
      type: type,
      form: form,
      dosage: dosage,
      concentrationMg: concentrationMg,
      maxDailyDose: maxDailyDose,
      minHoursBetweenDoses: minHoursBetweenDoses,
      schedule: schedule,
      prescribedBy: prescribedBy,
      pharmacyName: pharmacyName,
      prescriptionNumber: prescriptionNumber,
      prescriptionDate: prescriptionDate,
      currentStock: currentStock,
      stockUnit: stockUnit,
      lowStockThreshold: lowStockThreshold,
      expirationDate: expirationDate,
      purpose: purpose,
      sideEffects: sideEffects,
      notes: notes,
      photoUrl: photoUrl,
      createdAt: now,
      updatedAt: now,
    );

    final docRef = await _medicationsCollection.add(medication.toMap());
    
    return medication.copyWith(id: docRef.id);
  }

  /// Update medication details
  Future<void> updateMedication({
    required String medicationId,
    String? name,
    String? genericName,
    MedicationType? type,
    MedicationForm? form,
    DosageInfo? dosage,
    double? concentrationMg,
    double? maxDailyDose,
    int? minHoursBetweenDoses,
    MedicationSchedule? schedule,
    String? prescribedBy,
    String? pharmacyName,
    String? prescriptionNumber,
    DateTime? prescriptionDate,
    double? currentStock,
    DosageUnit? stockUnit,
    double? lowStockThreshold,
    DateTime? expirationDate,
    String? purpose,
    String? sideEffects,
    String? notes,
    String? photoUrl,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    if (name != null) updates['name'] = name;
    if (genericName != null) updates['genericName'] = genericName;
    if (type != null) updates['type'] = type.name;
    if (form != null) updates['form'] = form.name;
    if (dosage != null) updates['dosage'] = dosage.toMap();
    if (concentrationMg != null) updates['concentrationMg'] = concentrationMg;
    if (maxDailyDose != null) updates['maxDailyDose'] = maxDailyDose;
    if (minHoursBetweenDoses != null) updates['minHoursBetweenDoses'] = minHoursBetweenDoses;
    if (schedule != null) updates['schedule'] = schedule.toMap();
    if (prescribedBy != null) updates['prescribedBy'] = prescribedBy;
    if (pharmacyName != null) updates['pharmacyName'] = pharmacyName;
    if (prescriptionNumber != null) updates['prescriptionNumber'] = prescriptionNumber;
    if (prescriptionDate != null) updates['prescriptionDate'] = Timestamp.fromDate(prescriptionDate);
    if (currentStock != null) updates['currentStock'] = currentStock;
    if (stockUnit != null) updates['stockUnit'] = stockUnit.name;
    if (lowStockThreshold != null) updates['lowStockThreshold'] = lowStockThreshold;
    if (expirationDate != null) updates['expirationDate'] = Timestamp.fromDate(expirationDate);
    if (purpose != null) updates['purpose'] = purpose;
    if (sideEffects != null) updates['sideEffects'] = sideEffects;
    if (notes != null) updates['notes'] = notes;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (isActive != null) updates['isActive'] = isActive;

    await _medicationsCollection.doc(medicationId).update(updates);
  }

  /// Discontinue medication (soft delete)
  Future<void> discontinueMedication(String medicationId) async {
    await updateMedication(medicationId: medicationId, isActive: false);
  }

  /// Delete medication permanently
  Future<void> deleteMedication(String medicationId) async {
    // Delete all doses first
    final dosesSnapshot = await _dosesCollection
        .where('medicationId', isEqualTo: medicationId)
        .get();
    
    final batch = _firestore.batch();
    for (final doc in dosesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_medicationsCollection.doc(medicationId));
    
    await batch.commit();
  }

  // ============================================================================
  // Medication Queries
  // ============================================================================

  /// Get active medications for baby
  Future<List<MedicationModel>> getActiveMedications(String babyId) async {
    final snapshot = await _medicationsCollection
        .where('babyId', isEqualTo: babyId)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .get();

    return snapshot.docs
        .map((doc) => MedicationModel.fromFirestore(doc))
        .toList();
  }

  /// Stream active medications
  Stream<List<MedicationModel>> streamActiveMedications(String babyId) {
    return _medicationsCollection
        .where('babyId', isEqualTo: babyId)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MedicationModel.fromFirestore(doc))
            .toList());
  }

  /// Get medications expiring soon (within 30 days)
  Future<List<MedicationModel>> getExpiringSoonMedications(String babyId) async {
    final thirtyDaysFromNow = DateTime.now().add(const Duration(days: 30));
    
    final snapshot = await _medicationsCollection
        .where('babyId', isEqualTo: babyId)
        .where('isActive', isEqualTo: true)
        .where('expirationDate', isLessThanOrEqualTo: Timestamp.fromDate(thirtyDaysFromNow))
        .get();

    return snapshot.docs
        .map((doc) => MedicationModel.fromFirestore(doc))
        .toList();
  }

  /// Get low stock medications
  Future<List<MedicationModel>> getLowStockMedications(String babyId) async {
    final allMeds = await getActiveMedications(babyId);
    return allMeds.where((med) => med.isLowStock).toList();
  }

  // ============================================================================
  // Dose Administration
  // ============================================================================

  /// Log a medication dose
  Future<MedicationDoseModel> logDose({
    required String medicationId,
    required String babyId,
    required String userId,
    required DateTime administeredAt,
    required DosageInfo dosageGiven,
    bool wasScheduled = false,
    String? reasonGiven,
    double? temperatureBefore,
    double? temperatureAfter,
    String? notes,
    String? administeredBy,
  }) async {
    // Validate dose is safe
    final medication = await _medicationsCollection.doc(medicationId).get();
    if (!medication.exists) {
      throw Exception('Medication not found');
    }

    final med = MedicationModel.fromFirestore(medication);
    final safetyCheck = await checkDoseSafety(
      medicationId: medicationId,
      proposedDoseTime: administeredAt,
      proposedDosage: dosageGiven.amount,
    );

    if (!safetyCheck.isSafe) {
      throw Exception(safetyCheck.warningMessage);
    }

    final now = DateTime.now();
    final dose = MedicationDoseModel(
      id: '',
      medicationId: medicationId,
      babyId: babyId,
      userId: userId,
      administeredAt: administeredAt,
      dosageGiven: dosageGiven,
      wasScheduled: wasScheduled,
      reasonGiven: reasonGiven,
      temperatureBefore: temperatureBefore,
      temperatureAfter: temperatureAfter,
      notes: notes,
      administeredBy: administeredBy,
      createdAt: now,
      updatedAt: now,
    );

    final docRef = await _dosesCollection.add(dose.toMap());
    
    // Update medication stock
    if (med.currentStock != null) {
      final newStock = med.currentStock! - dosageGiven.amount;
      await updateMedication(
        medicationId: medicationId,
        currentStock: newStock > 0 ? newStock : 0,
      );
    }

    return dose.copyWith(id: docRef.id);
  }

  /// Update a dose record
  Future<void> updateDose({
    required String doseId,
    DateTime? administeredAt,
    DosageInfo? dosageGiven,
    String? reasonGiven,
    double? temperatureBefore,
    double? temperatureAfter,
    String? notes,
    String? administeredBy,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    if (administeredAt != null) updates['administeredAt'] = Timestamp.fromDate(administeredAt);
    if (dosageGiven != null) updates['dosageGiven'] = dosageGiven.toMap();
    if (reasonGiven != null) updates['reasonGiven'] = reasonGiven;
    if (temperatureBefore != null) updates['temperatureBefore'] = temperatureBefore;
    if (temperatureAfter != null) updates['temperatureAfter'] = temperatureAfter;
    if (notes != null) updates['notes'] = notes;
    if (administeredBy != null) updates['administeredBy'] = administeredBy;

    await _dosesCollection.doc(doseId).update(updates);
  }

  /// Delete a dose record
  Future<void> deleteDose(String doseId) async {
    await _dosesCollection.doc(doseId).delete();
  }

  // ============================================================================
  // Dose Queries
  // ============================================================================

  /// Get dose history for a medication
  Future<List<MedicationDoseModel>> getDoseHistory({
    required String medicationId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    Query query = _dosesCollection
        .where('medicationId', isEqualTo: medicationId)
        .orderBy('administeredAt', descending: true);

    if (startDate != null) {
      query = query.where('administeredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('administeredAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => MedicationDoseModel.fromFirestore(doc))
        .toList();
  }

  /// Get all doses for baby today
  Future<List<MedicationDoseModel>> getTodayDoses(String babyId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _dosesCollection
        .where('babyId', isEqualTo: babyId)
        .where('administeredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('administeredAt', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('administeredAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => MedicationDoseModel.fromFirestore(doc))
        .toList();
  }

  /// Stream today's doses
  Stream<List<MedicationDoseModel>> streamTodayDoses(String babyId) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _dosesCollection
        .where('babyId', isEqualTo: babyId)
        .where('administeredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('administeredAt', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('administeredAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MedicationDoseModel.fromFirestore(doc))
            .toList());
  }

  /// Get last dose for a medication
  Future<MedicationDoseModel?> getLastDose(String medicationId) async {
    final snapshot = await _dosesCollection
        .where('medicationId', isEqualTo: medicationId)
        .orderBy('administeredAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return MedicationDoseModel.fromFirestore(snapshot.docs.first);
  }

  // ============================================================================
  // Safety Checks
  // ============================================================================

  /// Check if proposed dose is safe
  Future<DoseSafetyCheck> checkDoseSafety({
    required String medicationId,
    required DateTime proposedDoseTime,
    required double proposedDosage,
  }) async {
    final medDoc = await _medicationsCollection.doc(medicationId).get();
    if (!medDoc.exists) {
      return DoseSafetyCheck(
        isSafe: false,
        warningMessage: 'Medication not found',
      );
    }

    final medication = MedicationModel.fromFirestore(medDoc);

    // Check 1: Minimum time between doses
    if (medication.minHoursBetweenDoses != null) {
      final lastDose = await getLastDose(medicationId);
      if (lastDose != null) {
        final hoursSinceLastDose = proposedDoseTime
            .difference(lastDose.administeredAt)
            .inHours;
        
        if (hoursSinceLastDose < medication.minHoursBetweenDoses!) {
          final hoursToWait = medication.minHoursBetweenDoses! - hoursSinceLastDose;
          return DoseSafetyCheck(
            isSafe: false,
            warningMessage: 'Too soon! Wait $hoursToWait more hour(s) before next dose.',
            hoursUntilNextDose: hoursToWait,
          );
        }
      }
    }

    // Check 2: Maximum daily dose
    if (medication.maxDailyDose != null) {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final todayDoses = await getDoseHistory(
        medicationId: medicationId,
        startDate: startOfDay,
        endDate: endOfDay,
      );

      final totalTodayDosage = todayDoses.fold<double>(
        0,
        (sum, dose) => sum + dose.dosageGiven.amount,
      );

      if (totalTodayDosage + proposedDosage > medication.maxDailyDose!) {
        return DoseSafetyCheck(
          isSafe: false,
          warningMessage: 'Maximum daily dose exceeded! Today: ${totalTodayDosage.toStringAsFixed(1)} ${medication.dosage.unit.displayName}, Max: ${medication.maxDailyDose} ${medication.dosage.unit.displayName}',
          currentDailyTotal: totalTodayDosage,
          maxDailyDose: medication.maxDailyDose!,
        );
      }
    }

    // Check 3: Expired medication
    if (medication.isExpired) {
      return DoseSafetyCheck(
        isSafe: false,
        warningMessage: 'Medication is expired! Expiration date: ${_formatDate(medication.expirationDate!)}',
      );
    }

    // All checks passed
    return DoseSafetyCheck(
      isSafe: true,
      warningMessage: null,
    );
  }

  /// Calculate recommended dosage based on baby weight
  double calculateWeightBasedDosage({
    required double babyWeightKg,
    required double mgPerKg,
    double? maxDose,
  }) {
    final calculatedDose = babyWeightKg * mgPerKg;
    
    if (maxDose != null && calculatedDose > maxDose) {
      return maxDose;
    }
    
    return calculatedDose;
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

/// Result of dose safety check
class DoseSafetyCheck {
  final bool isSafe;
  final String? warningMessage;
  final int? hoursUntilNextDose;
  final double? currentDailyTotal;
  final double? maxDailyDose;

  DoseSafetyCheck({
    required this.isSafe,
    this.warningMessage,
    this.hoursUntilNextDose,
    this.currentDailyTotal,
    this.maxDailyDose,
  });
}
```

---

## 4. Cloud Functions

### 4.1 Medication Reminders

**File**: `functions/src/medication/sendMedicationReminders.ts`

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Scheduled function: Run every hour
 * Send medication reminders for upcoming doses
 */
export const sendMedicationReminders = functions.pubsub
  .schedule('0 * * * *') // Every hour
  .timeZone('America/New_York')
  .onRun(async (context) => {
    const now = new Date();
    const oneHourFromNow = new Date(now.getTime() + 60 * 60 * 1000);

    // Get all active medications with schedules
    const medicationsSnapshot = await admin.firestore()
      .collection('medications')
      .where('isActive', '==', true)
      .where('schedule.enableReminders', '==', true)
      .get();

    const notifications: Array<Promise<any>> = [];

    for (const medDoc of medicationsSnapshot.docs) {
      const medication = medDoc.data();
      const schedule = medication.schedule;

      if (!schedule) continue;

      // Calculate next dose time
      const nextDoseTime = calculateNextDoseTime(schedule);

      if (!nextDoseTime) continue;

      // Send reminder 15 minutes before
      const reminderTime = new Date(nextDoseTime.getTime() - 15 * 60 * 1000);

      if (reminderTime > now && reminderTime <= oneHourFromNow) {
        // Get parent's FCM token
        const babyDoc = await admin.firestore()
          .collection('babies')
          .doc(medication.babyId)
          .get();

        if (!babyDoc.exists) continue;

        const baby = babyDoc.data()!;
        const parentUserId = baby.parentUserId;

        const userDoc = await admin.firestore()
          .collection('users')
          .doc(parentUserId)
          .get();

        if (!userDoc.exists) continue;

        const user = userDoc.data()!;
        const fcmToken = user.fcmToken;

        if (!fcmToken) continue;

        // Send notification
        const notification = admin.messaging().send({
          token: fcmToken,
          notification: {
            title: '💊 Medication Reminder',
            body: `Time to give ${baby.name} ${medication.name} (${medication.dosage.amount} ${medication.dosage.unit})`,
          },
          data: {
            type: 'medication_reminder',
            medicationId: medDoc.id,
            babyId: medication.babyId,
            doseTime: nextDoseTime.toISOString(),
          },
          android: {
            priority: 'high',
            notification: {
              sound: 'default',
              channelId: 'medication_reminders',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        });

        notifications.push(notification);
      }
    }

    await Promise.all(notifications);
    
    console.log(`Sent ${notifications.length} medication reminders`);
    return null;
  });

function calculateNextDoseTime(schedule: any): Date | null {
  const now = new Date();
  
  if (schedule.endDate && new Date(schedule.endDate._seconds * 1000) < now) {
    return null; // Schedule ended
  }

  const startDate = new Date(schedule.startDate._seconds * 1000);

  switch (schedule.frequencyType) {
    case 'onceDaily':
      const scheduledTime = new Date(
        now.getFullYear(),
        now.getMonth(),
        now.getDate(),
        startDate.getHours(),
        startDate.getMinutes()
      );
      if (scheduledTime < now) {
        scheduledTime.setDate(scheduledTime.getDate() + 1);
      }
      return scheduledTime;

    case 'everyXHours':
      if (!schedule.intervalHours) return null;
      let nextDose = new Date(startDate);
      while (nextDose < now) {
        nextDose = new Date(nextDose.getTime() + schedule.intervalHours * 60 * 60 * 1000);
      }
      return nextDose;

    case 'custom':
      if (!schedule.customTimes || schedule.customTimes.length === 0) return null;
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      
      for (const timeStr of schedule.customTimes) {
        const [hours, minutes] = timeStr.split(':').map(Number);
        const scheduled = new Date(today);
        scheduled.setHours(hours, minutes, 0, 0);
        
        if (scheduled > now) {
          return scheduled;
        }
      }
      
      // All times passed today, return first time tomorrow
      const [hours, minutes] = schedule.customTimes[0].split(':').map(Number);
      const tomorrow = new Date(today);
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(hours, minutes, 0, 0);
      return tomorrow;

    default:
      return null;
  }
}
```

### 4.2 Low Stock Alerts

**File**: `functions/src/medication/checkLowStock.ts`

```typescript
/**
 * Trigger: When medication stock is updated
 * Action: Send alert if stock falls below threshold
 */
export const onMedicationStockUpdate = functions.firestore
  .document('medications/{medicationId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Check if stock changed
    if (before.currentStock === after.currentStock) {
      return null;
    }

    // Check if below threshold
    if (!after.lowStockThreshold || !after.currentStock) {
      return null;
    }

    const wasAboveThreshold = before.currentStock > before.lowStockThreshold;
    const isNowBelowThreshold = after.currentStock <= after.lowStockThreshold;

    if (wasAboveThreshold && isNowBelowThreshold) {
      // Send low stock alert
      const babyDoc = await admin.firestore()
        .collection('babies')
        .doc(after.babyId)
        .get();

      if (!babyDoc.exists) return null;

      const baby = babyDoc.data()!;
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(baby.parentUserId)
        .get();

      if (!userDoc.exists) return null;

      const user = userDoc.data()!;
      
      if (user.fcmToken) {
        await admin.messaging().send({
          token: user.fcmToken,
          notification: {
            title: '⚠️ Low Medication Stock',
            body: `${after.name} is running low (${after.currentStock} ${after.stockUnit} remaining). Time to refill!`,
          },
          data: {
            type: 'low_stock_alert',
            medicationId: context.params.medicationId,
            babyId: after.babyId,
          },
        });
      }
    }

    return null;
  });

/**
 * Scheduled function: Run daily at 9 AM
 * Check for expiring medications
 */
export const checkExpiringMedications = functions.pubsub
  .schedule('0 9 * * *')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    const now = new Date();
    const thirtyDaysFromNow = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

    const expiringMeds = await admin.firestore()
      .collection('medications')
      .where('isActive', '==', true)
      .where('expirationDate', '<=', admin.firestore.Timestamp.fromDate(thirtyDaysFromNow))
      .where('expirationDate', '>=', admin.firestore.Timestamp.fromDate(now))
      .get();

    const alerts: Array<Promise<any>> = [];

    for (const medDoc of expiringMeds.docs) {
      const medication = medDoc.data();
      const expirationDate = new Date(medication.expirationDate._seconds * 1000);
      const daysUntilExpiry = Math.ceil((expirationDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));

      const babyDoc = await admin.firestore()
        .collection('babies')
        .doc(medication.babyId)
        .get();

      if (!babyDoc.exists) continue;

      const baby = babyDoc.data()!;
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(baby.parentUserId)
        .get();

      if (!userDoc.exists) continue;

      const user = userDoc.data()!;

      if (user.fcmToken) {
        alerts.push(
          admin.messaging().send({
            token: user.fcmToken,
            notification: {
              title: '⏰ Medication Expiring Soon',
              body: `${medication.name} expires in ${daysUntilExpiry} day(s)`,
            },
            data: {
              type: 'expiring_medication',
              medicationId: medDoc.id,
              babyId: medication.babyId,
              daysUntilExpiry: daysUntilExpiry.toString(),
            },
          })
        );
      }
    }

    await Promise.all(alerts);
    console.log(`Sent ${alerts.length} expiration alerts`);
    return null;
  });
```

---

## 5. UI Components

### 5.1 Medication Card

**File**: `lib/widgets/medication/medication_card.dart`

```dart
import 'package:flutter/material.dart';
import '../../models/medication_model.dart';
import 'package:intl/intl.dart';

class MedicationCard extends StatelessWidget {
  final MedicationModel medication;
  final VoidCallback? onTap;
  final VoidCallback? onLogDose;
  final VoidCallback? onEdit;

  const MedicationCard({
    Key? key,
    required this.medication,
    this.onTap,
    this.onLogDose,
    this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getTypeColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getTypeIcon(),
                      color: _getTypeColor(),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Name and dosage
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medication.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          medication.dosage.formattedDosage,
                          style: TextStyle(
                            fontSize: 16,
                            color: _getTypeColor(),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (medication.genericName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            medication.genericName!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Edit button
                  if (onEdit != null)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: onEdit,
                      color: Colors.grey,
                    ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Purpose/Reason
              if (medication.purpose != null) ...[
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        medication.purpose!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              
              // Schedule info
              if (medication.schedule != null) ...[
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      medication.schedule!.frequencyType.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              
              // Warnings row
              if (medication.isExpiringSoon || medication.isLowStock || medication.isExpired)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (medication.isExpired)
                      _buildWarningChip(
                        'EXPIRED',
                        Icons.warning,
                        Colors.red,
                      ),
                    if (medication.isExpiringSoon && !medication.isExpired)
                      _buildWarningChip(
                        'Expiring Soon',
                        Icons.warning_amber,
                        Colors.orange,
                      ),
                    if (medication.isLowStock)
                      _buildWarningChip(
                        'Low Stock',
                        Icons.inventory_2_outlined,
                        Colors.orange,
                      ),
                  ],
                ),
              
              if (medication.isExpiringSoon || medication.isLowStock || medication.isExpired)
                const SizedBox(height: 12),
              
              // Action button
              if (onLogDose != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: medication.isExpired ? null : onLogDose,
                    icon: const Icon(Icons.add),
                    label: const Text('Log Dose'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getTypeColor(),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon() {
    switch (medication.type) {
      case MedicationType.prescription:
        return Icons.medication;
      case MedicationType.overTheCounter:
        return Icons.local_pharmacy;
      case MedicationType.supplement:
        return Icons.vitamins;
      case MedicationType.homeopathic:
        return Icons.spa;
      default:
        return Icons.healing;
    }
  }

  Color _getTypeColor() {
    switch (medication.type) {
      case MedicationType.prescription:
        return Colors.red.shade600;
      case MedicationType.overTheCounter:
        return Colors.blue.shade600;
      case MedicationType.supplement:
        return Colors.green.shade600;
      case MedicationType.homeopathic:
        return Colors.purple.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
}
```

### 5.2 Log Dose Bottom Sheet

**File**: `lib/widgets/medication/log_dose_sheet.dart`

```dart
import 'package:flutter/material.dart';
import '../../models/medication_model.dart';
import '../../services/medication_service.dart';

class LogDoseSheet extends StatefulWidget {
  final MedicationModel medication;

  const LogDoseSheet({
    Key? key,
    required this.medication,
  }) : super(key: key);

  @override
  State<LogDoseSheet> createState() => _LogDoseSheetState();
}

class _LogDoseSheetState extends State<LogDoseSheet> {
  final _medicationService = MedicationService();
  
  late DateTime _doseTime;
  late double _dosageAmount;
  String? _reasonGiven;
  double? _temperatureBefore;
  String? _notes;
  bool _isLoading = false;
  String? _safetyWarning;

  @override
  void initState() {
    super.initState();
    _doseTime = DateTime.now();
    _dosageAmount = widget.medication.dosage.amount;
    
    _checkSafety();
  }

  Future<void> _checkSafety() async {
    final check = await _medicationService.checkDoseSafety(
      medicationId: widget.medication.id,
      proposedDoseTime: _doseTime,
      proposedDosage: _dosageAmount,
    );

    if (!check.isSafe) {
      setState(() {
        _safetyWarning = check.warningMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Log ${widget.medication.name}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Safety warning
            if (_safetyWarning != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _safetyWarning!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // Time picker
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Time Given'),
              subtitle: Text(
                '${_doseTime.hour.toString().padLeft(2, '0')}:${_doseTime.minute.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_doseTime),
                );
                if (time != null) {
                  setState(() {
                    _doseTime = DateTime(
                      _doseTime.year,
                      _doseTime.month,
                      _doseTime.day,
                      time.hour,
                      time.minute,
                    );
                  });
                  await _checkSafety();
                }
              },
            ),
            
            // Dosage amount
            ListTile(
              leading: const Icon(Icons.medical_services),
              title: const Text('Dosage'),
              subtitle: Text(
                '$_dosageAmount ${widget.medication.dosage.unit.displayName}',
              ),
            ),
            
            // Reason (for PRN medications)
            if (widget.medication.isAsNeeded) ...[
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Reason Given',
                  hintText: 'e.g., Fever, Pain',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                ),
                onChanged: (value) => _reasonGiven = value,
              ),
            ],
            
            // Temperature (if fever medication)
            if (widget.medication.purpose?.toLowerCase().contains('fever') ?? false) ...[
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Temperature Before (°F)',
                  hintText: '100.4',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.thermostat),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final temp = double.tryParse(value);
                  if (temp != null) {
                    _temperatureBefore = temp;
                  }
                },
              ),
            ],
            
            // Notes
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Any additional information',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 2,
              onChanged: (value) => _notes = value,
            ),
            
            const SizedBox(height: 24),
            
            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _safetyWarning != null || _isLoading
                    ? null
                    : _saveDose,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Log Dose',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDose() async {
    setState(() => _isLoading = true);

    try {
      await _medicationService.logDose(
        medicationId: widget.medication.id,
        babyId: widget.medication.babyId,
        userId: widget.medication.userId,
        administeredAt: _doseTime,
        dosageGiven: DosageInfo(
          amount: _dosageAmount,
          unit: widget.medication.dosage.unit,
        ),
        wasScheduled: widget.medication.isScheduled,
        reasonGiven: _reasonGiven,
        temperatureBefore: _temperatureBefore,
        notes: _notes,
      );

      if (mounted) {
        Navigator.pop(context, true); // Return true = success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dose logged successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
```

---

## 6. User Flows

### 6.1 Add Medication Flow

```
┌─────────────────────────────────────────────────────────────┐
│                   ADD MEDICATION FLOW                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. User taps "+" (Add Medication) button                   │
│      │                                                       │
│      ▼                                                       │
│  2. Show "Add Medication" form                              │
│      ├─ Search medication library OR manual entry           │
│      ├─ Select medication type (Rx, OTC, Supplement)        │
│      ├─ Enter name (e.g., "Tylenol")                        │
│      ├─ Enter generic name (e.g., "Acetaminophen")          │
│      ├─ Select form (liquid, tablet, etc.)                  │
│      ├─ Enter dosage (amount + unit)                        │
│      ├─ Optional: Concentration (mg/mL for liquids)         │
│      └─ Optional: Photo of prescription label               │
│      │                                                       │
│      ▼                                                       │
│  3. Set up schedule (if recurring)                          │
│      ├─ Select frequency (once daily, PRN, etc.)            │
│      ├─ Set start/end dates                                 │
│      ├─ Enable/disable reminders                            │
│      └─ For custom: Set specific times                      │
│      │                                                       │
│      ▼                                                       │
│  4. Enter safety limits                                     │
│      ├─ Maximum daily dose                                  │
│      ├─ Minimum hours between doses                         │
│      └─ Purpose/reason for medication                       │
│      │                                                       │
│      ▼                                                       │
│  5. Optional: Prescription details                          │
│      ├─ Prescribed by (doctor name)                         │
│      ├─ Pharmacy name                                       │
│      ├─ Prescription number                                 │
│      └─ Expiration date                                     │
│      │                                                       │
│      ▼                                                       │
│  6. Optional: Inventory tracking                            │
│      ├─ Current stock amount                                │
│      ├─ Low stock threshold                                 │
│      └─ Stock unit                                          │
│      │                                                       │
│      ▼                                                       │
│  7. User taps "Save" button                                 │
│      │                                                       │
│      ▼                                                       │
│  8. Call MedicationService.addMedication()                  │
│      ├─ Save to Firestore medications collection            │
│      ├─ Schedule reminder (if enabled)                      │
│      └─ Return medication object                            │
│      │                                                       │
│      ▼                                                       │
│  9. Update UI                                               │
│      ├─ Add medication card to list                         │
│      ├─ Show success message                                │
│      └─ Enable "Log Dose" button                            │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 Log Dose Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    LOG DOSE FLOW                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. User taps "Log Dose" on medication card                 │
│      │                                                       │
│      ▼                                                       │
│  2. Call MedicationService.checkDoseSafety()                │
│      ├─ Check last dose time                                │
│      ├─ Check daily dose limit                              │
│      ├─ Check expiration date                               │
│      └─ Return safety check result                          │
│      │                                                       │
│      ▼                                                       │
│  3. Show "Log Dose" bottom sheet                            │
│      ├─ Display safety warning (if any)                     │
│      ├─ Pre-fill dosage (editable)                          │
│      ├─ Select time (default: now)                          │
│      ├─ Enter reason (if PRN)                               │
│      ├─ Enter temperature (if fever med)                    │
│      └─ Add notes (optional)                                │
│      │                                                       │
│      ▼                                                       │
│  4. User taps "Log Dose" button                             │
│      │                                                       │
│      ▼                                                       │
│  5. Validate safety (final check)                           │
│      ├─ If unsafe → Show error, block save                  │
│      └─ If safe → Continue                                  │
│      │                                                       │
│      ▼                                                       │
│  6. Call MedicationService.logDose()                        │
│      ├─ Create dose record in Firestore                     │
│      ├─ Update medication stock (if tracked)                │
│      └─ Check for low stock/expiration                      │
│      │                                                       │
│      ▼                                                       │
│  7. Update UI                                               │
│      ├─ Add dose to history list                            │
│      ├─ Update "last dose" time on card                     │
│      ├─ Show success message                                │
│      └─ Show low stock warning (if needed)                  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. Safety Features

### 7.1 Overdose Prevention

**Multi-layer Safety Checks**:

1. **Minimum Time Between Doses**
   ```dart
   if (hoursSinceLastDose < medication.minHoursBetweenDoses) {
     throw Exception('Too soon! Wait ${hoursToWait} more hours');
   }
   ```

2. **Maximum Daily Dose Limit**
   ```dart
   if (totalTodayDosage + proposedDosage > medication.maxDailyDose) {
     throw Exception('Maximum daily dose would be exceeded');
   }
   ```

3. **Expired Medication Check**
   ```dart
   if (medication.isExpired) {
     throw Exception('Medication is expired!');
   }
   ```

4. **UI Blocking**
   - Disable "Log Dose" button if safety check fails
   - Show red warning banner with specific reason
   - Display countdown timer until next allowed dose

### 7.2 Weight-Based Dosing Calculator

```dart
// Example: Acetaminophen dosing
final babyWeightKg = 8.0; // 8 kg baby
final mgPerKg = 15.0; // 10-15 mg/kg per dose
final maxSingleDose = 160.0; // mg

final calculatedDose = medicationService.calculateWeightBasedDosage(
  babyWeightKg: babyWeightKg,
  mgPerKg: mgPerKg,
  maxDose: maxSingleDose,
);

// Result: 120 mg (8 kg × 15 mg/kg = 120 mg, under 160 mg max)
```

### 7.3 Prescription Label OCR (Future)

```dart
// Use ML Kit or Firebase ML Vision
Future<MedicationModel> scanPrescriptionLabel(File imageFile) async {
  final inputImage = InputImage.fromFile(imageFile);
  final textRecognizer = TextRecognizer();
  
  final recognizedText = await textRecognizer.processImage(inputImage);
  
  // Parse medication name, dosage, instructions
  final medicationInfo = _parsePrescriptionText(recognizedText.text);
  
  return MedicationModel(
    name: medicationInfo.medicationName,
    dosage: medicationInfo.dosage,
    prescribedBy: medicationInfo.doctorName,
    // ... other fields
  );
}
```

---

## 8. Implementation Roadmap

### Phase 1: Core Medication Management (Week 1-2)

**Week 1: Data Layer & Service**
- [ ] Create `MedicationModel` with all enums
- [ ] Create `MedicationDoseModel`
- [ ] Implement `MedicationService` CRUD operations
- [ ] Implement dose logging with safety checks
- [ ] Write unit tests for safety validation
- [ ] Set up Firestore collections and indexes

**Week 2: UI & Basic Tracking**
- [ ] Build `MedicationCard` widget
- [ ] Create "Add Medication" form
- [ ] Build "Log Dose" bottom sheet
- [ ] Implement medication list screen
- [ ] Add dose history view

### Phase 2: Scheduling & Reminders (Week 3)

**Week 3: Automated Reminders**
- [ ] Deploy `sendMedicationReminders` Cloud Function
- [ ] Implement FCM notification handling
- [ ] Build reminder settings UI
- [ ] Add snooze/dismiss functionality
- [ ] Test reminder scheduling

### Phase 3: Safety & Alerts (Week 4)

**Week 4: Safety Features**
- [ ] Deploy `checkLowStock` Cloud Function
- [ ] Deploy `checkExpiringMedications` Cloud Function
- [ ] Implement weight-based dosage calculator
- [ ] Build safety warning UI components
- [ ] Add medication interaction warnings (future)

### Phase 4: Advanced Features (Week 5)

**Week 5: Enhancements**
- [ ] Add medication search library (common meds)
- [ ] Implement photo capture for prescriptions
- [ ] Build adherence report (missed doses)
- [ ] Add CSV/PDF export for pediatrician
- [ ] Create inventory management dashboard

---

## 9. Testing Strategy

### 9.1 Unit Tests

```dart
// test/unit/services/medication_service_test.dart
void main() {
  group('Dose Safety Checks', () {
    test('should block dose if too soon', () async {
      // Setup: Last dose was 2 hours ago, min interval is 4 hours
      final service = MedicationService();
      
      final check = await service.checkDoseSafety(
        medicationId: 'med123',
        proposedDoseTime: DateTime.now(),
        proposedDosage: 5.0,
      );
      
      expect(check.isSafe, false);
      expect(check.hoursUntilNextDose, 2);
    });
    
    test('should block dose if daily max exceeded', () async {
      // Setup: Already given 60mg today, max is 80mg, trying to give 30mg
      final check = await service.checkDoseSafety(
        medicationId: 'med123',
        proposedDoseTime: DateTime.now(),
        proposedDosage: 30.0,
      );
      
      expect(check.isSafe, false);
      expect(check.warningMessage, contains('Maximum daily dose'));
    });
  });

  group('Weight-Based Dosing', () {
    test('should calculate correct dose based on weight', () {
      final service = MedicationService();
      
      final dose = service.calculateWeightBasedDosage(
        babyWeightKg: 10.0,
        mgPerKg: 15.0,
        maxDose: 200.0,
      );
      
      expect(dose, 150.0); // 10 kg × 15 mg/kg = 150 mg
    });
    
    test('should cap at maximum dose', () {
      final service = MedicationService();
      
      final dose = service.calculateWeightBasedDosage(
        babyWeightKg: 20.0, // Large baby
        mgPerKg: 15.0,
        maxDose: 200.0,
      );
      
      expect(dose, 200.0); // Capped at max, not 300mg
    });
  });
}
```

### 9.2 Widget Tests

```dart
// test/widgets/medication/medication_card_test.dart
void main() {
  testWidgets('MedicationCard shows low stock warning', (tester) async {
    final medication = MedicationModel(
      // ... setup with low stock
      currentStock: 5.0,
      lowStockThreshold: 10.0,
    );
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MedicationCard(medication: medication),
        ),
      ),
    );
    
    expect(find.text('Low Stock'), findsOneWidget);
  });
}
```

---

## 10. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Medication Adherence Rate | >90% of scheduled doses | Doses logged / Doses scheduled |
| Safety Warnings Displayed | 100% when applicable | Warning count / Total log attempts |
| Reminder Effectiveness | >80% logged within 30 min | Doses logged after reminder |
| Low Stock Alerts | 100% when threshold hit | Alerts sent / Low stock events |
| Feature Adoption | >60% of users | Users with ≥1 active medication |
| Time to Log Dose | <20 seconds | User timing analytics |

---

**Next Steps**:
1. Review and approve this LLD
2. Begin Phase 1 implementation (Data Layer & Service)
3. Create medication library database (common meds with dosing info)
4. Set up Cloud Functions for reminders and safety checks

