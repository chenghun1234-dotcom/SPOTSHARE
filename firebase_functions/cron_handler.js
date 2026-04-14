const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.cleanupExpiredAds = functions.https.onRequest(async (req, res) => {
  if (req.headers.authorization !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(403).send('Unauthorized');
  }
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();

  const expiredSpots = await db.collection('parking_spots')
    .where('isPremium', '==', true)
    .where('adExpiresAt', '<=', now)
    .get();

  const batch = db.batch();
  expiredSpots.forEach(doc => {
    batch.update(doc.ref, { isPremium: false });
  });

  await batch.commit();
  res.status(200).send(`Cleaned up ${expiredSpots.size} ads.`);
});
