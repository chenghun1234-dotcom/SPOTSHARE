const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
admin.initializeApp();

exports.syncPublicParkingData = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
  const apiKey = 'YOUR_PUBLIC_DATA_API_KEY';
  const url = `http://api.data.go.kr/openapi/tn_pubr_public_prkplce_info_api?serviceKey=${apiKey}&type=json&numRows=1000`;

  const response = await axios.get(url);
  const parkingLots = response.data.response.body.items;

  const db = admin.firestore();
  const batch = db.batch();

  parkingLots.forEach((lot) => {
    const docRef = db.collection('parking_spots').doc(`public_${lot.prkplceNo}`);
    batch.set(docRef, {
      title: lot.prkplceNm,
      address: lot.rdnmadr || lot.lnmadr,
      lat: parseFloat(lot.latitude),
      lng: parseFloat(lot.longitude),
      type: 'PUBLIC',
      priceInfo: lot.prkpc,
      isPremium: false
    }, { merge: true });
  });

  await batch.commit();
});
