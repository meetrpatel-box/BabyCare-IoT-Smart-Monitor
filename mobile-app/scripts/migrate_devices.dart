import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Migration script to add ownership fields to existing devices
///
/// This script:
/// 1. Finds all devices without ownerId field
/// 2. Determines the owner from the device's family
/// 3. Sets ownerId, authorizedUsers, and registeredAt fields
///
/// Usage:
/// dart run scripts/migrate_devices.dart
///
/// Note: This should be run BEFORE deploying new Firestore security rules

void main() async {
  print('🚀 Starting device ownership migration...\n');

  // Initialize Firebase
  await Firebase.initializeApp();
  final firestore = FirebaseFirestore.instance;

  try {
    // Get all devices
    print('📦 Fetching all devices...');
    final devicesSnapshot = await firestore.collection('devices').get();
    print('   Found ${devicesSnapshot.docs.length} devices\n');

    int migratedCount = 0;
    int skippedCount = 0;
    int errorCount = 0;

    for (final deviceDoc in devicesSnapshot.docs) {
      final deviceId = deviceDoc.id;
      final data = deviceDoc.data();

      // Skip if already migrated
      if (data.containsKey('ownerId') && data['ownerId'] != null && data['ownerId'] != '') {
        print('   ℹ️  Device $deviceId already migrated, skipping');
        skippedCount++;
        continue;
      }

      try {
        print('   🔄 Migrating device: $deviceId');

        // Get familyId from device
        final familyId = data['familyId'];
        if (familyId == null || familyId.isEmpty) {
          print('      ⚠️  No familyId found, cannot migrate');
          errorCount++;
          continue;
        }

        print('      Family ID: $familyId');

        // Get family document
        final familyDoc = await firestore.collection('families').doc(familyId).get();
        if (!familyDoc.exists) {
          print('      ⚠️  Family $familyId not found');
          errorCount++;
          continue;
        }

        // Get owner ID from family
        final familyData = familyDoc.data()!;
        final ownerId = familyData['ownerId'];

        if (ownerId == null || ownerId.isEmpty) {
          print('      ⚠️  Family has no owner');
          errorCount++;
          continue;
        }

        print('      Owner ID: $ownerId');

        // Determine registeredAt
        // Use createdAt if available, otherwise use current timestamp
        Timestamp registeredAt;
        if (data.containsKey('createdAt') && data['createdAt'] != null) {
          registeredAt = data['createdAt'] as Timestamp;
        } else {
          registeredAt = Timestamp.now();
        }

        // Update device with ownership fields
        await deviceDoc.reference.update({
          'ownerId': ownerId,
          'authorizedUsers': [ownerId], // Initially only owner
          'registeredAt': registeredAt,
        });

        print('      ✅ Migrated successfully');
        migratedCount++;
      } catch (e) {
        print('      ❌ Error migrating device $deviceId: $e');
        errorCount++;
      }

      print(''); // Empty line for readability
    }

    // Summary
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📊 Migration Summary:');
    print('   ✅ Migrated: $migratedCount devices');
    print('   ℹ️  Skipped (already migrated): $skippedCount devices');
    print('   ❌ Errors: $errorCount devices');
    print('   📦 Total processed: ${devicesSnapshot.docs.length} devices');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    if (errorCount > 0) {
      print('⚠️  Some devices could not be migrated. Please review errors above.');
      exit(1);
    } else if (migratedCount == 0 && skippedCount == devicesSnapshot.docs.length) {
      print('✅ All devices were already migrated. No action needed.');
    } else {
      print('✅ Migration completed successfully!');
      print('   You can now deploy the new Firestore security rules.');
    }
  } catch (e) {
    print('❌ Fatal error during migration: $e');
    exit(1);
  }
}
