const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
// admin.initializeApp() is handled in index.js

exports.cleanupExpiredAds = onSchedule(
  {
    schedule: 'every 1 hours',
    timeZone: 'Asia/Seoul',
    memory: '256MiB',
  },
  async (event) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const expiredSpots = await db.collection('parking_spots')
      .where('isPremium', '==', true)
      .where('adExpiresAt', '<=', now)
      .get();

    if (expiredSpots.empty) return;

    const batch = db.batch();
    expiredSpots.forEach(doc => {
      batch.update(doc.ref, { isPremium: false });
    });

    await batch.commit();
    console.log(`[Cleanup] Successfully disabled ${expiredSpots.size} expired ads.`);
  }
);
