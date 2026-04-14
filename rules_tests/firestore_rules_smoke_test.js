const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc
} = require('firebase/firestore');

async function run() {
  const rules = fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8');
  const testEnv = await initializeTestEnvironment({
    projectId: 'spotshare-rules-test',
    firestore: { rules }
  });

  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'parking_spots/spotA'), {
      ownerId: 'userA',
      region: 'SEOUL',
      title: 'A Spot',
      price: 1000,
      lat: 37.5,
      lng: 127.0,
      isPremium: false
    });
    await setDoc(doc(db, 'reservations/resA'), {
      userId: 'userA',
      ownerId: 'userB',
      spotId: 'spotA',
      status: 'reserved',
      checkedOut: false
    });
    await setDoc(doc(db, 'reviews/revA'), {
      userId: 'userA',
      spotId: 'spotA',
      rating: 5,
      comment: 'good'
    });
    await setDoc(doc(db, 'reports/repA'), {
      userId: 'userA',
      spotId: 'spotA',
      reason: 'illegal parking'
    });
    await setDoc(doc(db, 'ad_requests/adA'), {
      userId: 'userA',
      status: 'pending',
      spotId: 'spotA'
    });
    await setDoc(doc(db, 'ad_requests/adActive'), {
      userId: 'userA',
      status: 'active',
      spotId: 'spotA'
    });
  });

  const unauth = testEnv.unauthenticatedContext().firestore();
  const userA = testEnv.authenticatedContext('userA').firestore();
  const userB = testEnv.authenticatedContext('userB').firestore();
  const admin = testEnv.authenticatedContext('admin1', { admin: true }).firestore();

  // parking_spots
  await assertSucceeds(getDoc(doc(unauth, 'parking_spots/spotA')));
  await assertSucceeds(setDoc(doc(userA, 'parking_spots/newSpot1'), { ownerId: 'userA', title: 'ok' }));
  await assertFails(setDoc(doc(userA, 'parking_spots/newSpot2'), { ownerId: 'userB', title: 'no' }));
  await assertSucceeds(updateDoc(doc(userA, 'parking_spots/spotA'), { title: 'updated' }));
  await assertFails(updateDoc(doc(userA, 'parking_spots/spotA'), { ownerId: 'userB' }));
  await assertFails(deleteDoc(doc(userB, 'parking_spots/spotA')));
  await assertSucceeds(deleteDoc(doc(admin, 'parking_spots/spotA')));

  // reservations
  await assertSucceeds(setDoc(doc(userA, 'reservations/newRes1'), { userId: 'userA', ownerId: 'userB' }));
  await assertFails(setDoc(doc(userA, 'reservations/newRes2'), { userId: 'userB', ownerId: 'userA' }));
  await assertSucceeds(getDoc(doc(userA, 'reservations/resA')));
  await assertSucceeds(getDoc(doc(userB, 'reservations/resA')));
  await assertFails(getDoc(doc(unauth, 'reservations/resA')));

  // reviews/reports/ad_requests
  await assertSucceeds(getDoc(doc(unauth, 'reviews/revA')));
  await assertFails(deleteDoc(doc(userB, 'reviews/revA')));
  await assertSucceeds(getDoc(doc(admin, 'reports/repA')));
  await assertFails(getDoc(doc(userA, 'reports/repA')));
  await assertSucceeds(getDoc(doc(unauth, 'ad_requests/adActive')));
  await assertFails(getDoc(doc(unauth, 'ad_requests/adA')));

  await testEnv.cleanup();
  console.log('Firestore rules smoke tests passed.');
}

run().catch((error) => {
  console.error('Firestore rules smoke tests failed:', error);
  process.exit(1);
});
