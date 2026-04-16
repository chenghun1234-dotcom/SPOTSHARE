const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const ROOT_DIR = path.join(__dirname, '..');
const DEFAULT_SERVICE_ACCOUNT_PATH = path.join(ROOT_DIR, 'service-account.json');
const PROJECT_ID = 'spotshare-5103d';
const FUNCTION_URL = process.env.TOSS_WEBHOOK_URL || `https://us-central1-${PROJECT_ID}.cloudfunctions.net/handleTossAdWebhook`;

function resolveServiceAccountPath() {
  if (fs.existsSync(DEFAULT_SERVICE_ACCOUNT_PATH)) {
    return DEFAULT_SERVICE_ACCOUNT_PATH;
  }

  const fallback = fs
    .readdirSync(ROOT_DIR)
    .find((name) => /^spotshare-.*-firebase-adminsdk-.*\.json$/i.test(name));

  if (!fallback) {
    throw new Error('Service account key not found in project root.');
  }

  return path.join(ROOT_DIR, fallback);
}

async function run() {
  const serviceAccountPath = resolveServiceAccountPath();
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
    projectId: PROJECT_ID,
  });

  const db = admin.firestore();
  const testId = `webhook-test-${Date.now()}`;
  const spotRef = db.collection('parking_spots').doc(testId);
  const adRef = db.collection('ad_requests').doc(testId);
  const webhookSecret = `secret-${Date.now()}`;
  const orderId = `ad_${testId}`;

  try {
    await spotRef.set({
      ownerId: 'admin-webhook-test',
      region: 'SEOUL',
      title: 'Webhook Test Spot',
      price: 30000,
      lat: 37.5,
      lng: 127.0,
      isPremium: false,
    });

    await adRef.set({
      userId: 'admin-webhook-test',
      spotId: testId,
      durationDays: 7,
      amount: 30000,
      depositCode: orderId,
      orderId,
      status: 'pending',
      tossStatus: 'WAITING_FOR_DEPOSIT',
      tossSecret: webhookSecret,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const response = await fetch(FUNCTION_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'tosspayments-webhook-transmission-id': `smoke-${Date.now()}`,
        'tosspayments-webhook-transmission-time': new Date().toISOString(),
        'tosspayments-webhook-transmission-retried-count': '0',
      },
      body: JSON.stringify({
        createdAt: new Date().toISOString(),
        secret: webhookSecret,
        status: 'DONE',
        transactionKey: `txn-${Date.now()}`,
        orderId,
      }),
    });

    const body = await response.text();
    if (!response.ok) {
      throw new Error(`Webhook call failed: ${response.status} ${body}`);
    }

    const [spotSnap, adSnap] = await Promise.all([spotRef.get(), adRef.get()]);
    const spotData = spotSnap.data() || {};
    const adData = adSnap.data() || {};

    if (spotData.isPremium !== true) {
      throw new Error(`Expected parking_spots/${testId}.isPremium=true, got ${JSON.stringify(spotData)}`);
    }

    if (adData.status !== 'active') {
      throw new Error(`Expected ad_requests/${testId}.status=active, got ${JSON.stringify(adData)}`);
    }

    console.log('Toss webhook smoke test passed.');
    console.log(body);
  } finally {
    await Promise.allSettled([adRef.delete(), spotRef.delete()]);
  }
}

run().catch((error) => {
  console.error('Toss webhook smoke test failed:', error.message || error);
  process.exit(1);
});
