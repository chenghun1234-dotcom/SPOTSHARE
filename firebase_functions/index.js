const crypto = require('crypto');
const functions = require('firebase-functions');
const { onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

admin.initializeApp();

function getNestedConfig(path, fallback = '') {
  let value = process.env[path.toUpperCase().replace(/\./g, '_')] || fallback;
  try {
    let node = functions.config();
    for (const key of path.split('.')) {
      node = node && node[key];
    }
    if (node != null && node !== '') {
      value = node;
    }
  } catch (e) {
    // functions.config may be unavailable depending on runtime setup.
  }
  return value;
}

function getAdSecret() {
  return getNestedConfig('ad.secret', process.env.AD_ACTIVATION_SECRET || '');
}

function getTossConfig() {
  return {
    secretKey: getNestedConfig('toss.secret_key', process.env.TOSS_SECRET_KEY || ''),
    bankCode: getNestedConfig('toss.bank_code', process.env.TOSS_BANK_CODE || ''),
    validHours: Number(getNestedConfig('toss.valid_hours', process.env.TOSS_VALID_HOURS || '24')) || 24,
  };
}

function toPositiveInt(value) {
  const num = Number(value);
  if (!Number.isFinite(num)) return null;
  const intValue = Math.floor(num);
  return intValue > 0 ? intValue : null;
}

function buildTossAuthHeader(secretKey) {
  return `Basic ${Buffer.from(`${secretKey}:`).toString('base64')}`;
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

async function verifyUserToken(req) {
  const authHeader = req.get('authorization') || '';
  if (!authHeader.startsWith('Bearer ')) {
    return null;
  }

  const idToken = authHeader.slice('Bearer '.length).trim();
  if (!idToken) {
    return null;
  }

  try {
    return await admin.auth().verifyIdToken(idToken);
  } catch (e) {
    return null;
  }
}

async function getAdRequestByOrderId(orderId) {
  const snapshot = await admin.firestore()
    .collection('ad_requests')
    .where('orderId', '==', orderId)
    .limit(1)
    .get();

  if (snapshot.empty) {
    return null;
  }
  return snapshot.docs[0];
}

async function activateAdRequestById({ adRequestId, activationSource, paymentDetails = {} }) {
  const db = admin.firestore();
  const adRef = db.collection('ad_requests').doc(adRequestId);
  let result = null;

  await db.runTransaction(async (tx) => {
    const adSnap = await tx.get(adRef);
    if (!adSnap.exists) {
      throw new Error(`ad_requests/${adRequestId} not found`);
    }

    const adData = adSnap.data() || {};
    const spotId = adData.spotId;
    const durationDays = toPositiveInt(adData.durationDays) || 7;
    if (!spotId) {
      throw new Error(`ad_requests/${adRequestId} missing spotId`);
    }

    if (adData.status === 'active') {
      result = {
        status: 200,
        body: {
          message: 'Ad already active.',
          adRequestId,
          spotId,
        },
      };
      return;
    }

    const spotRef = db.collection('parking_spots').doc(spotId);
    const spotSnap = await tx.get(spotRef);
    if (!spotSnap.exists) {
      throw new Error(`parking_spots/${spotId} not found`);
    }

    const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000)
    );

    tx.update(spotRef, {
      isPremium: true,
      adExpiresAt: expiresAt,
      premiumActivatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.update(adRef, {
      status: 'active',
      tossStatus: paymentDetails.tossStatus || adData.tossStatus || 'DONE',
      paymentKey: paymentDetails.paymentKey || adData.paymentKey || null,
      transactionKey: paymentDetails.transactionKey || adData.transactionKey || null,
      activatedAt: admin.firestore.FieldValue.serverTimestamp(),
      activationSource,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      virtualAccount: paymentDetails.virtualAccount || adData.virtualAccount || null,
      lastWebhookCreatedAt: paymentDetails.createdAt || adData.lastWebhookCreatedAt || null,
    });

    result = {
      status: 200,
      body: {
        message: 'Ad activated successfully.',
        adRequestId,
        spotId,
      },
    };
  });

  return result;
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
    .where('status', 'in', ['pending', 'waiting_for_deposit'])
    .limit(1)
    .get();

  if (snapshot.empty) {
    return { status: 404, body: { error: 'Matching pending ad request not found.' } };
  }

  return activateAdRequestById({
    adRequestId: snapshot.docs[0].id,
    activationSource,
    paymentDetails: { tossStatus: 'DONE' },
  });
}

function buildWebhookReceiptId(req, payload) {
  const transmissionId = req.get('tosspayments-webhook-transmission-id') || '';
  if (transmissionId) {
    return transmissionId.replace(/[^a-zA-Z0-9_-]/g, '_');
  }

  const raw = JSON.stringify({
    eventType: payload.eventType || 'DEPOSIT_CALLBACK',
    orderId: payload.orderId || (payload.data && payload.data.orderId) || '',
    status: payload.status || (payload.data && payload.data.status) || '',
    transactionKey: payload.transactionKey || (payload.data && payload.data.lastTransactionKey) || '',
    paymentKey: payload.paymentKey || (payload.data && payload.data.paymentKey) || '',
    createdAt: payload.createdAt || '',
  });
  return crypto.createHash('sha256').update(raw).digest('hex');
}

async function registerWebhookReceipt(req, payload) {
  const receiptId = buildWebhookReceiptId(req, payload);
  const receiptRef = admin.firestore().collection('webhook_receipts').doc(receiptId);
  try {
    await receiptRef.create({
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      transmissionId: req.get('tosspayments-webhook-transmission-id') || null,
      transmissionTime: req.get('tosspayments-webhook-transmission-time') || null,
      retriedCount: req.get('tosspayments-webhook-transmission-retried-count') || '0',
      payloadSummary: {
        eventType: payload.eventType || 'DEPOSIT_CALLBACK',
        orderId: payload.orderId || (payload.data && payload.data.orderId) || null,
        status: payload.status || (payload.data && payload.data.status) || null,
      },
      state: 'received',
    });
    return { duplicate: false, receiptRef };
  } catch (error) {
    if (error && error.code === 6) {
      return { duplicate: true, receiptRef };
    }
    if (error && String(error.message || '').includes('Already exists')) {
      return { duplicate: true, receiptRef };
    }
    throw error;
  }
}

function parseTossWebhookPayload(payload) {
  if (payload && payload.eventType === 'PAYMENT_STATUS_CHANGED') {
    const data = payload.data || {};
    return {
      channel: 'PAYMENT_STATUS_CHANGED',
      orderId: data.orderId || '',
      status: data.status || '',
      paymentKey: data.paymentKey || '',
      transactionKey: data.lastTransactionKey || '',
      secret: data.secret || '',
      method: data.method || '',
      virtualAccount: data.virtualAccount || null,
      createdAt: payload.createdAt || null,
    };
  }

  return {
    channel: 'DEPOSIT_CALLBACK',
    orderId: payload.orderId || '',
    status: payload.status || '',
    paymentKey: payload.paymentKey || '',
    transactionKey: payload.transactionKey || '',
    secret: payload.secret || '',
    method: '가상계좌',
    virtualAccount: null,
    createdAt: payload.createdAt || null,
  };
}

async function callTossApi(path, { method = 'POST', body, idempotencyKey } = {}) {
  const config = getTossConfig();
  if (!config.secretKey) {
    throw new Error('Toss Payments secret key is not configured. Set toss.secret_key first.');
  }

  const response = await fetch(`https://api.tosspayments.com${path}`, {
    method,
    headers: {
      Authorization: buildTossAuthHeader(config.secretKey),
      'Content-Type': 'application/json',
      ...(idempotencyKey ? { 'Idempotency-Key': idempotencyKey } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  const text = await response.text();
  const parsed = text ? JSON.parse(text) : {};
  if (!response.ok) {
    throw new Error(`Toss API ${response.status}: ${JSON.stringify(parsed)}`);
  }
  return parsed;
}

exports.createAdVirtualAccount = onRequest({ cors: true }, async (req, res) => {
  try {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Use POST' });
    }

    const user = await verifyUserToken(req);
    if (!user) {
      return res.status(403).json({ error: 'Authentication required' });
    }

    const spotId = req.body && req.body.spotId ? String(req.body.spotId) : '';
    const durationDays = toPositiveInt(req.body && req.body.durationDays);
    const amount = toPositiveInt(req.body && req.body.amount);

    if (!spotId || !durationDays || !amount) {
      return res.status(400).json({ error: 'spotId, durationDays, amount are required' });
    }

    const spotRef = admin.firestore().collection('parking_spots').doc(spotId);
    const spotSnap = await spotRef.get();
    if (!spotSnap.exists) {
      return res.status(404).json({ error: 'parking_spot not found' });
    }

    const spotData = spotSnap.data() || {};
    if (spotData.ownerId !== user.uid) {
      return res.status(403).json({ error: 'Only the owner can request premium ads for this spot' });
    }

    const tossConfig = getTossConfig();
    if (!tossConfig.secretKey || !tossConfig.bankCode) {
      return res.status(503).json({
        error: 'Toss Payments is not configured',
        message: 'Set toss.secret_key and toss.bank_code in Firebase Functions config.',
      });
    }

    const db = admin.firestore();
    const adRef = db.collection('ad_requests').doc();
    const orderId = `ad_${adRef.id}`;

    await adRef.set({
      userId: user.uid,
      spotId,
      durationDays,
      amount,
      depositCode: orderId,
      orderId,
      status: 'pending',
      tossStatus: 'REQUESTED',
      paymentProvider: 'toss_payments',
      paymentMethod: 'virtual_account',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const payment = await callTossApi('/v1/virtual-accounts', {
      method: 'POST',
      idempotencyKey: `ad-va-${adRef.id}`,
      body: {
        amount,
        orderId,
        orderName: `SpotShare Premium ${spotData.title || spotId}`,
        customerName: user.name || user.email || user.uid,
        customerEmail: user.email || undefined,
        bank: tossConfig.bankCode,
        validHours: tossConfig.validHours,
        metadata: {
          adRequestId: adRef.id,
          spotId,
        },
      },
    });

    await adRef.update({
      orderId: payment.orderId || orderId,
      paymentKey: payment.paymentKey || null,
      tossSecret: payment.secret || null,
      tossStatus: payment.status || 'WAITING_FOR_DEPOSIT',
      checkoutUrl: payment.checkout && payment.checkout.url ? payment.checkout.url : null,
      virtualAccount: payment.virtualAccount || null,
      requestedAt: payment.requestedAt || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(200).json({
      adRequestId: adRef.id,
      orderId: payment.orderId || orderId,
      amount,
      status: payment.status || 'WAITING_FOR_DEPOSIT',
      checkoutUrl: payment.checkout && payment.checkout.url ? payment.checkout.url : null,
      virtualAccount: payment.virtualAccount || null,
      requestedAt: payment.requestedAt || null,
    });
  } catch (error) {
    console.error('createAdVirtualAccount failed', error);
    return res.status(500).json({
      error: 'Failed to issue virtual account',
      message: error && error.message ? error.message : String(error),
    });
  }
});

exports.handleTossAdWebhook = onRequest({ cors: true }, async (req, res) => {
  try {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Use POST' });
    }

    const payload = req.body || {};
    const receipt = await registerWebhookReceipt(req, payload);
    if (receipt.duplicate) {
      return res.status(200).json({ message: 'Duplicate webhook ignored.' });
    }

    const parsed = parseTossWebhookPayload(payload);
    if (!parsed.orderId) {
      await receipt.receiptRef.update({ state: 'ignored', reason: 'missing-order-id' });
      return res.status(200).json({ message: 'Ignored webhook without orderId.' });
    }

    if (parsed.channel === 'PAYMENT_STATUS_CHANGED' && parsed.method !== '가상계좌') {
      await receipt.receiptRef.update({ state: 'ignored', reason: 'not-virtual-account' });
      return res.status(200).json({ message: 'Ignored non-virtual-account payment event.' });
    }

    const adDoc = await getAdRequestByOrderId(parsed.orderId);
    if (!adDoc) {
      await receipt.receiptRef.update({ state: 'ignored', reason: 'unknown-order-id' });
      return res.status(200).json({ message: 'Ignored unknown orderId.' });
    }

    const adData = adDoc.data() || {};
    if (!adData.tossSecret || adData.tossSecret !== parsed.secret) {
      await receipt.receiptRef.update({ state: 'rejected', reason: 'secret-mismatch' });
      return res.status(403).json({ error: 'Invalid webhook secret.' });
    }

    const adUpdate = {
      tossStatus: parsed.status,
      paymentKey: parsed.paymentKey || adData.paymentKey || null,
      transactionKey: parsed.transactionKey || adData.transactionKey || null,
      virtualAccount: parsed.virtualAccount || adData.virtualAccount || null,
      lastWebhookCreatedAt: parsed.createdAt || adData.lastWebhookCreatedAt || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (parsed.status === 'DONE') {
      const result = await activateAdRequestById({
        adRequestId: adDoc.id,
        activationSource: `toss-webhook:${parsed.channel}`,
        paymentDetails: {
          tossStatus: parsed.status,
          paymentKey: parsed.paymentKey,
          transactionKey: parsed.transactionKey,
          virtualAccount: parsed.virtualAccount,
          createdAt: parsed.createdAt,
        },
      });
      await receipt.receiptRef.update({ state: 'processed', adRequestId: adDoc.id, processedStatus: parsed.status });
      return res.status(result.status).json(result.body);
    }

    if (parsed.status === 'CANCELED' || parsed.status === 'EXPIRED') {
      adUpdate.status = parsed.status.toLowerCase();
    }

    if (parsed.status === 'WAITING_FOR_DEPOSIT') {
      adUpdate.status = 'pending';
    }

    await adDoc.ref.update(adUpdate);
    await receipt.receiptRef.update({ state: 'processed', adRequestId: adDoc.id, processedStatus: parsed.status });
    return res.status(200).json({ message: 'Webhook processed.', adRequestId: adDoc.id, status: parsed.status });
  } catch (error) {
    console.error('handleTossAdWebhook failed', error);
    return res.status(500).json({
      error: 'Webhook processing failed',
      message: error && error.message ? error.message : String(error),
    });
  }
});

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

    const result = await activateAdRequestById({
      adRequestId,
      activationSource: `admin:${decoded.uid}`,
      paymentDetails: {
        tossStatus: adData.tossStatus || 'MANUAL_APPROVED',
        paymentKey: adData.paymentKey || null,
        transactionKey: adData.transactionKey || null,
        virtualAccount: adData.virtualAccount || null,
      },
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

exports.onReservationUpdated = functions.firestore
  .document('reservations/{reservationId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    const beforePenalty = beforeData.penalty || 0;
    const afterPenalty = afterData.penalty || 0;

    if (afterPenalty > beforePenalty) {
      const userId = afterData.userId;
      if (!userId) return null;

      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      const fcmToken = userDoc.data().fcmToken;
      if (!fcmToken) return null;

      const message = {
        notification: {
          title: '주차장 이용 시간 초과 안내',
          body: `이용 시간이 초과되어 ${afterPenalty.toLocaleString()}원의 추가 요금이 부과되었습니다. 스팟을 확인해주세요.`,
        },
        token: fcmToken,
      };

      try {
        await admin.messaging().send(message);
        console.log(`Penalty push sent to user ${userId}`);
      } catch (error) {
        console.error('Error sending push notification:', error);
      }
    }
    return null;
  });
