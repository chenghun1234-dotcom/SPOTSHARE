const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.activateAdByDeposit = functions.https.onRequest(async (req, res) => {
  const { memo, amount, sender } = req.body;
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
  batch.update(adDoc.ref, { status: 'active', activatedAt: admin.firestore.FieldValue.serverTimestamp() });

  await batch.commit();
  res.status(200).send('Ad activated successfully.');
});
