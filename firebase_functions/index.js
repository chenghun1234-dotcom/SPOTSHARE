const functions = require('firebase-functions');
const { onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

admin.initializeApp();

exports.activateAdByDeposit = functions.https.onRequest(async (req, res) => {
  const { memo, amount } = req.body;
  const db = admin.firestore();

  const snapshot = await db.collection('ad_requests')
    .where('depositCode', '==', memo)
    .where('amount', '==', amount)
    .where('status', '==', 'pending')
    .limit(1)
    .get();

  if (snapshot.empty) {
    return res.status(404).send('Matching ad request not found.');
  }

  const adDoc = snapshot.docs[0];
  const { spotId, durationDays } = adDoc.data();

  const batch = db.batch();
  batch.update(db.collection('parking_spots').doc(spotId), {
    isPremium: true,
    adExpiresAt: admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000)
    )
  });
  batch.update(adDoc.ref, {
    status: 'active',
    activatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  await batch.commit();
  return res.status(200).send('Ad activated successfully.');
});

exports.migrateOwnershipFields = onRequest(async (req, res) => {
  try {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Use POST' });
    }

    let expectedKey = process.env.MIGRATION_KEY || '';
    try {
      const cfg = functions.config();
      if (!expectedKey && cfg && cfg.migration && cfg.migration.key) {
        expectedKey = cfg.migration.key;
      }
    } catch (e) {
      // functions.config may be unavailable depending on runtime setup.
    }

    const providedKey = req.get('x-migration-key') || (req.query.key ? String(req.query.key) : '');
    if (!expectedKey || providedKey !== expectedKey) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const db = admin.firestore();
    const dryRun = req.query.dryRun !== 'false';

    const collections = [
      {
        name: 'parking_spots',
        targetField: 'ownerId',
        candidates: ['ownerId', 'userId', 'ownerUid', 'uid', 'createdBy']
      },
      {
        name: 'reservations',
        targetField: 'userId',
        candidates: ['userId', 'reserverId', 'bookerId', 'uid']
      },
      {
        name: 'reviews',
        targetField: 'userId',
        candidates: ['userId', 'authorId', 'uid']
      },
      {
        name: 'reports',
        targetField: 'userId',
        candidates: ['userId', 'reporterId', 'uid']
      },
      {
        name: 'ad_requests',
        targetField: 'userId',
        candidates: ['userId', 'requesterId', 'uid']
      }
    ];

    const result = {};

    for (const spec of collections) {
      const snapshot = await db.collection(spec.name).get();
      let updated = 0;
      let skipped = 0;
      const unresolved = [];
      let batch = db.batch();
      let writes = 0;

      for (const doc of snapshot.docs) {
        const data = doc.data();
        const existing = data[spec.targetField];
        if (typeof existing === 'string' && existing.length > 0) {
          skipped += 1;
          continue;
        }

        let resolved = null;
        for (const key of spec.candidates) {
          const value = data[key];
          if (typeof value === 'string' && value.length > 0) {
            resolved = value;
            break;
          }
        }

        if (!resolved) {
          unresolved.push(doc.id);
          continue;
        }

        if (!dryRun) {
          batch.update(doc.ref, { [spec.targetField]: resolved });
          writes += 1;
          if (writes === 450) {
            await batch.commit();
            batch = db.batch();
            writes = 0;
          }
        }

        updated += 1;
      }

      if (!dryRun && writes > 0) {
        await batch.commit();
      }

      result[spec.name] = {
        total: snapshot.size,
        updated,
        skipped,
        unresolvedCount: unresolved.length,
        unresolvedDocIds: unresolved
      };
    }

    return res.status(200).json({ dryRun, result });
  } catch (error) {
    console.error('migrateOwnershipFields failed', error);
    return res.status(500).json({
      error: 'Internal migration error',
      message: error && error.message ? error.message : String(error)
    });
  }
});

