/**
 * sync_public_parking.js
 * 
 * 전국 공영주차장 공공데이터 → Firebase Firestore 자동 동기화
 * API: 공공데이터포털 "전국주차장정보표준데이터" (tn_pubr_public_prkplce_info_api)
 * 
 * 호출 방식:
 *  1) Firebase Scheduled Function (매주 월요일 00:00 KST 자동)
 *  2) HTTP POST /syncPublicParking  (GitHub Actions 크론탭에서 강제 호출)
 */

const axios      = require('axios');
const { onRequest } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin      = require('firebase-admin');

// ── 설정 ──────────────────────────────────────────────────────
const API_BASE_URL =
  'http://api.data.go.kr/openapi/tn_pubr_public_prkplce_info_api';
const PAGE_SIZE    = 1000;   // 한 번에 가져올 최대 레코드 수
const MAX_PAGES    = 20;     // 최대 20,000건 (너무 많으면 batch 시간 초과 방지)

// ── 공공데이터 API 호출 ────────────────────────────────────────
async function fetchPage(serviceKey, pageNo) {
  const params = {
    serviceKey,
    type: 'json',
    numOfRows: PAGE_SIZE,
    pageNo,
  };

  const response = await axios.get(API_BASE_URL, {
    params,
    timeout: 30_000,
  });

  const body = response.data?.response?.body;
  if (!body) throw new Error('공공데이터 API 응답 형식 오류');

  return {
    items:      Array.isArray(body.items?.item) ? body.items.item
                : Array.isArray(body.items)     ? body.items
                : [],
    totalCount: body.totalCount ?? 0,
  };
}

// ── Firestore 배치 저장 (500개 단위 자동 분할) ─────────────────
async function saveToFirestore(db, items) {
  let count = 0;
  let batch = db.batch();
  let batchCount = 0;

  for (const item of items) {
    const lat = parseFloat(item.latitude);
    const lng = parseFloat(item.longitude);

    // 좌표 없으면 건너뜀 (지도에 표시 불가)
    if (!isFinite(lat) || !isFinite(lng) || lat === 0 || lng === 0) continue;

    const docId  = `public_${item.prkplceNo}`;
    const docRef = db.collection('parking_spots').doc(docId);

    // 공공데이터 → SpotShare 스키마 매핑
    batch.set(docRef, {
      title:      item.prkplceNm?.trim() || '공영주차장',
      address:    (item.rdnmadr || item.lnmadr || '').trim(),
      lat,
      lng,
      region:     'PUBLIC',
      type:       'PUBLIC',
      price:      parseInt(item.prkpc) || 0,
      priceUnit:  '시간',
      penaltyRate: 0,
      operTime:   item.operTime || '',
      tel:        item.phoneNumber || '',
      totalSpots: parseInt(item.prkcpPartColrNm) || 0,
      isPremium:  false,
      isActive:   true,
      ownerId:    'PUBLIC_DATA_GOV',
      imageUrl:   '',
      source:     'data.go.kr',
      syncedAt:   admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    count++;
    batchCount++;

    // Firestore 배치는 최대 500건 제한
    if (batchCount === 499) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) await batch.commit();
  return count;
}

// ── 메인 동기화 로직 ──────────────────────────────────────────
async function runSync(serviceKey) {
  const db = admin.firestore();
  let totalSaved = 0;

  // 1페이지 먼저 가져와서 전체 건수 파악
  const { items: firstItems, totalCount } = await fetchPage(serviceKey, 1);
  totalSaved += await saveToFirestore(db, firstItems);

  const totalPages = Math.min(
    Math.ceil(totalCount / PAGE_SIZE),
    MAX_PAGES
  );

  // 나머지 페이지 순차 처리
  for (let page = 2; page <= totalPages; page++) {
    const { items } = await fetchPage(serviceKey, page);
    totalSaved += await saveToFirestore(db, items);
  }

  // 동기화 이력 기록
  await db.collection('sync_logs').add({
    type:       'public_parking',
    totalCount,
    savedCount: totalSaved,
    pages:      totalPages,
    syncedAt:   admin.firestore.FieldValue.serverTimestamp(),
  });

  return { totalCount, totalSaved, pages: totalPages };
}

// ── ① 스케줄 함수: 매주 월요일 00:00 KST 자동 실행 ─────────────
exports.scheduledPublicParkingSync = onSchedule(
  {
    schedule: '0 15 * * 0',   // UTC 15:00 일요일 = KST 00:00 월요일
    timeZone: 'Asia/Seoul',
    memory:   '512MiB',
    timeoutSeconds: 540,
    secrets: ['PUBLIC_DATA_API_KEY'],
  },
  async (_event) => {
    const serviceKey = process.env.PUBLIC_DATA_API_KEY
      || process.env.FUNCTIONS_CONFIG_PUBLIC_DATA_APIKEY
      || '';

    if (!serviceKey) {
      console.error('[Sync] PUBLIC_DATA_API_KEY 환경변수가 설정되지 않았습니다.');
      return;
    }

    console.log('[Sync] 공영주차장 동기화 시작 (자동 스케줄)');
    const result = await runSync(serviceKey);
    console.log('[Sync] 완료:', result);
  }
);

// ── ② HTTP 함수: GitHub Actions Cron 또는 수동 트리거 ───────────
exports.syncPublicParking = onRequest(
  {
    memory: '512MiB',
    timeoutSeconds: 540,
    cors: false,
    secrets: ['PUBLIC_DATA_API_KEY', 'SYNC_SECRET_TOKEN'],
  },
  async (req, res) => {
    // POST만 허용
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Method Not Allowed' });
    }

    // 간단한 Bearer 토큰 인증 (GitHub Actions Secret에 저장)
    const authHeader = req.get('authorization') || '';
    const token      = authHeader.replace('Bearer ', '').trim();
    const expected   = process.env.SYNC_SECRET_TOKEN || '';

    if (!expected || token !== expected) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const serviceKey = process.env.PUBLIC_DATA_API_KEY || '';
    if (!serviceKey) {
      return res.status(500).json({ error: 'PUBLIC_DATA_API_KEY not configured' });
    }

    try {
      console.log('[Sync] 공영주차장 동기화 시작 (HTTP 트리거)');
      const result = await runSync(serviceKey);
      console.log('[Sync] 완료:', result);
      return res.status(200).json({ ok: true, ...result });
    } catch (err) {
      console.error('[Sync] 오류:', err);
      return res.status(500).json({ error: err.message });
    }
  }
);
