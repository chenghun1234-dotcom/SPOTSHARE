/**
 * Admin Custom Claim 테스트 스크립트
 *
 * 사용법:
 *   node scripts/set_admin_claim.js <uid>
 *
 * <uid> 생략 시 신규 테스트 이메일 계정을 생성하고 admin=true 클레임을 설정합니다.
 *
 * 전제:
 *   - Firebase Authentication 활성화 완료
 *   - service-account.json이 프로젝트 루트에 존재
 *   - firebase-admin npm 패키지 설치: npm install firebase-admin (firebase_functions/에 이미 있음)
 */

const path = require('path');
const fs = require('fs');
const admin = require(path.join(__dirname, '..', 'firebase_functions', 'node_modules', 'firebase-admin'));

const ROOT_DIR = path.join(__dirname, '..');
const DEFAULT_SERVICE_ACCOUNT_PATH = path.join(ROOT_DIR, 'service-account.json');
const TEST_EMAIL = `admin-test-${Date.now()}@spotshare.test`;
const TEST_PASSWORD = 'Test@12345!';

function resolveServiceAccountPath() {
  if (fs.existsSync(DEFAULT_SERVICE_ACCOUNT_PATH)) {
    return DEFAULT_SERVICE_ACCOUNT_PATH;
  }

  const fallback = fs
    .readdirSync(ROOT_DIR)
    .find((name) => /^spotshare-.*-firebase-adminsdk-.*\.json$/i.test(name));

  if (fallback) {
    return path.join(ROOT_DIR, fallback);
  }

  throw new Error(
    'Service account key not found. Place service-account.json at project root or keep the Firebase Admin SDK JSON filename.'
  );
}

const SERVICE_ACCOUNT_PATH = resolveServiceAccountPath();

admin.initializeApp({
  credential: admin.credential.cert(SERVICE_ACCOUNT_PATH),
  projectId: 'spotshare-5103d',
});

async function run() {
  let uid = process.argv[2];

  // UID 미제공 시 테스트 계정 생성
  if (!uid) {
    console.log(`[1/4] 테스트 사용자 생성: ${TEST_EMAIL}`);
    const user = await admin.auth().createUser({
      email: TEST_EMAIL,
      password: TEST_PASSWORD,
      displayName: 'Admin Test User',
    });
    uid = user.uid;
    console.log(`      UID: ${uid}`);
  } else {
    console.log(`[1/4] 기존 UID 사용: ${uid}`);
  }

  // admin=true 클레임 설정
  console.log('[2/4] admin=true 커스텀 클레임 설정 중...');
  await admin.auth().setCustomUserClaims(uid, { admin: true });
  console.log('      완료');

  // 검증
  console.log('[3/4] 클레임 검증 중...');
  const userRecord = await admin.auth().getUser(uid);
  const claims = userRecord.customClaims;
  if (claims && claims.admin === true) {
    console.log(`      ✅ PASS: customClaims = ${JSON.stringify(claims)}`);
  } else {
    console.error(`      ❌ FAIL: customClaims = ${JSON.stringify(claims)}`);
    process.exitCode = 1;
  }

  // 정리 (테스트 계정만 삭제)
  if (!process.argv[2]) {
    console.log(`[4/4] 테스트 계정 삭제 (${uid})`);
    await admin.auth().deleteUser(uid);
    console.log('      완료 — 테스트 계정 제거됨');
  } else {
    console.log(`[4/4] 기존 UID는 삭제하지 않음 — admin claim이 영구 적용되었습니다.`);
    console.log(`      Firestore 규칙의 isAdmin() 함수가 이 UID에 대해 true를 반환합니다.`);
  }
}

run().catch((err) => {
  console.error('오류:', err.message || err);
  process.exit(1);
});
