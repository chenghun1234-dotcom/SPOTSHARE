const functions = require('firebase-functions');
const admin = require('firebase-admin');
// admin.initializeApp() is handled in index.js

// 하루(24시간) 지난 출차 인증 이미지 자동 삭제
exports.cleanupCheckoutImages = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
  const db = admin.firestore();
  const storage = admin.storage().bucket();
  const now = Date.now();
  const oneDayAgo = now - 24 * 60 * 60 * 1000;

  // 예약 중 하루 지난 출차 인증 이미지 찾기
  const reservations = await db.collection('reservations')
    .where('checkoutTime', '<', new Date(oneDayAgo).toISOString())
    .where('checkoutImageUrl', '!=', null)
    .get();

  for (const doc of reservations.docs) {
    try {
      const data = doc.data();
      const imageUrl = data.checkoutImageUrl;
      if (!imageUrl) continue;
      // gs:// 경로 추출
      const match = imageUrl.match(/\/o\/(.*)\?/);
      const filePath = match ? decodeURIComponent(match[1]) : null;
      if (!filePath) {
        console.warn('파일 경로 추출 실패:', imageUrl);
        continue;
      }
      try {
        await storage.file(filePath).delete();
        await doc.ref.update({ checkoutImageUrl: null });
      } catch (e) {
        // 파일이 이미 없거나 네트워크 오류 등
        console.error('이미지 삭제 실패:', filePath, e);
        // 서비스는 계속 동작
      }
    } catch (outerErr) {
      console.error('예약 문서 처리 중 오류:', doc.id, outerErr);
      // 다음 문서로 계속 진행
    }
  }
});
