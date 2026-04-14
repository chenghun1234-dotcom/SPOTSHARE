const functions = require('firebase-functions');
const { onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

admin.initializeApp();

function getAdSecret() {
  let secret = process.env.AD_ACTIVATION_SECRET || '';
  try {
    const cfg = functions.config();
    if (!secret && cfg && cfg.ad && cfg.ad.secret) {
      secret = cfg.ad.secret;
    }
  } catch (e) {
    // functions.config may be unavailable depending on runtime setup.
  }
  return secret;
}

function toPositiveInt(value) {
  const num = Number(value);
  if (!Number.isFinite(num)) return null;
  const intValue = Math.floor(num);
  return intValue > 0 ? intValue : null;
}

async function verifyAdminToken(req) {
  const authHeader = req.get('authorization') || '';
  if (!authHeader.startsWith('Bearer ')) {
    return null;
  }

  const idToken = authHeader.slice('Bearer '.length).trim();
  if (!idToken) {
    return null;
  }

  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    if (decoded && decoded.admin === true) {
      return decoded;
    }
  } catch (e) {
    // Invalid token
  }
  return null;
}

async function activatePendingAd({ depositCode, amount, activationSource }) {
  const db = admin.firestore();
  const normalizedAmount = toPositiveInt(amount);
  if (!depositCode || !normalizedAmount) {
    return { status: 400, body: { error: 'Invalid payload. Require depositCode and amount.' } };
  }

  const snapshot = await db.collection('ad_requests')
    .where('depositCode', '==', String(depositCode))
    .where('amount', '==', normalizedAmount)
    .where('status', '==', 'pending')
    .limit(1)
    .get();

  if (snapshot.empty) {
    return { status: 404, body: { error: 'Matching pending ad request not found.' } };
  }

  const adDoc = snapshot.docs[0];
  const adData = adDoc.data();
  const spotId = adData.spotId;
  const durationDays = toPositiveInt(adData.durationDays) || 7;

  if (!spotId) {
    return { status: 422, body: { error: 'ad_requests document missing spotId.' } };
  }

  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000)
  );

  await db.runTransaction(async (tx) => {
    const spotRef = db.collection('parking_spots').doc(spotId);
    const spotSnap = await tx.get(spotRef);
    if (!spotSnap.exists) {
      throw new Error(`parking_spots/${spotId} not found`);
    }

    tx.update(spotRef, {
      isPremium: true,
      adExpiresAt: expiresAt,
      premiumActivatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.update(adDoc.ref, {
      status: 'active',
      activatedAt: admin.firestore.FieldValue.serverTimestamp(),
      activationSource,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return {
    status: 200,
    body: {
      message: 'Ad activated successfully.',
      adRequestId: adDoc.id,
      spotId,
    },
  };
}

// Bank webhook trigger (automatic approval path).
exports.activateAdByDeposit = onRequest({ cors: true }, async (req, res) => {
  try {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Use POST' });
    }

    const expectedSecret = getAdSecret();
    const providedSecret = req.get('x-ad-secret') || '';
    if (!expectedSecret || providedSecret !== expectedSecret) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const payload = req.body || {};
    const depositCode = payload.depositCode || payload.memo;
    const amount = payload.amount;
    const result = await activatePendingAd({
      depositCode,
      amount,
      activationSource: 'bank-webhook',
    });
    return res.status(result.status).json(result.body);
  } catch (error) {
    console.error('activateAdByDeposit failed', error);
    return res.status(500).json({ error: 'Internal error' });
  }
});

// Admin dashboard trigger (manual approval fallback).
exports.approveAdRequestByAdmin = onRequest({ cors: true }, async (req, res) => {
  try {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Use POST' });
    }

    const decoded = await verifyAdminToken(req);
    if (!decoded) {
      return res.status(403).json({ error: 'Admin token required' });
    }

    const adRequestId = req.body && req.body.adRequestId ? String(req.body.adRequestId) : '';
    if (!adRequestId) {
      return res.status(400).json({ error: 'adRequestId is required' });
    }

    const db = admin.firestore();
    const adRef = db.collection('ad_requests').doc(adRequestId);
    const adSnap = await adRef.get();
    if (!adSnap.exists) {
      return res.status(404).json({ error: 'ad_request not found' });
    }

    const adData = adSnap.data() || {};
    if (adData.status !== 'pending') {
      return res.status(409).json({ error: 'ad_request is not pending' });
    }

    const result = await activatePendingAd({
      depositCode: adData.depositCode,
      amount: adData.amount,
      activationSource: `admin:${decoded.uid}`,
    });
    return res.status(result.status).json(result.body);
  } catch (error) {
    console.error('approveAdRequestByAdmin failed', error);
    return res.status(500).json({
      error: 'Internal approval error',
      message: error && error.message ? error.message : String(error),
    });
  }
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

