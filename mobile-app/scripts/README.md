# Data Migration Scripts

This directory contains scripts for migrating data when implementing new features or schema changes.

## Device Ownership Migration

**Script:** `migrate_devices.dart`

### Purpose
Adds ownership fields (`ownerId`, `authorizedUsers`, `registeredAt`) to existing devices in preparation for role-based permission enforcement.

### When to Run
**BEFORE** deploying new Firestore security rules that enforce device ownership.

### Prerequisites
1. Firebase project configured
2. Admin/service account credentials (if running against production)
3. Backup of Firestore data (recommended)

### Usage

#### Local/Development
```bash
# From baby_track_flutter directory
dart run scripts/migrate_devices.dart
```

#### Production
1. **Create a backup first:**
```bash
gcloud firestore export gs://YOUR_BACKUP_BUCKET/$(date +%Y%m%d)
```

2. **Run migration:**
```bash
dart run scripts/migrate_devices.dart
```

3. **Verify results:**
   - Check the summary output
   - Manually verify a few devices in Firebase Console
   - Ensure `ownerId`, `authorizedUsers`, and `registeredAt` fields are populated

4. **Deploy security rules:**
```bash
firebase deploy --only firestore:rules
```

### What It Does

For each device without an `ownerId`:
1. Fetches the device's `familyId`
2. Looks up the family document
3. Gets the family's `ownerId`
4. Sets:
   - `ownerId` = family owner's user ID
   - `authorizedUsers` = `[ownerId]` (initially only owner)
   - `registeredAt` = device's `createdAt` (or current time if not available)

### Expected Output

```
🚀 Starting device ownership migration...

📦 Fetching all devices...
   Found 15 devices

   🔄 Migrating device: abc123
      Family ID: family1
      Owner ID: user1
      ✅ Migrated successfully

   ℹ️  Device def456 already migrated, skipping

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Migration Summary:
   ✅ Migrated: 12 devices
   ℹ️  Skipped (already migrated): 3 devices
   ❌ Errors: 0 devices
   📦 Total processed: 15 devices
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Migration completed successfully!
   You can now deploy the new Firestore security rules.
```

### Error Handling

The script handles several error cases:
- **No familyId:** Device not associated with a family (cannot migrate)
- **Family not found:** FamilyId exists but family document is missing
- **No owner:** Family exists but has no `ownerId` field

Devices with errors will be logged but won't stop the migration. Review errors and handle manually if needed.

### Rollback

If you need to rollback:

1. **Restore from backup:**
```bash
gcloud firestore import gs://YOUR_BACKUP_BUCKET/TIMESTAMP
```

2. **Or remove fields manually:**
```dart
// Script to remove ownership fields (create if needed)
devices.forEach((device) {
  device.update({
    'ownerId': FieldValue.delete(),
    'authorizedUsers': FieldValue.delete(),
    'registeredAt': FieldValue.delete(),
  });
});
```

### Deployment Checklist

- [ ] Backup Firestore data
- [ ] Run migration script in staging environment
- [ ] Verify migration results
- [ ] Run migration script in production
- [ ] Verify production migration results
- [ ] Deploy new Firestore security rules
- [ ] Test app functionality with new rules
- [ ] Monitor for any permission-denied errors

### Troubleshooting

**Error: "Permission denied"**
- Ensure you're running with proper credentials
- Check Firebase emulator settings if testing locally

**Error: "Family not found"**
- Device references a family that doesn't exist
- Manually create the family or update the device's familyId

**Some devices show errors**
- Review error messages in the output
- Manually fix data issues in Firebase Console
- Re-run migration for fixed devices

### Support

For issues or questions, refer to the main implementation plan at:
`/home/codespace/.claude/plans/zany-spinning-grove.md`
