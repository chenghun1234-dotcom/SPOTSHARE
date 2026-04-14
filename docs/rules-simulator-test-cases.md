# SpotShare Security Rules Simulator Test Cases

## Scope
- Firestore rules: [firestore.rules](../firestore.rules)
- Storage rules: [storage.rules](../storage.rules)
- Firebase project: `spotshare-5103d`

## Test Actors
- unauthenticated: no auth context
- userA: authenticated uid `userA`
- userB: authenticated uid `userB`
- admin: authenticated uid `admin1`, custom claim `admin=true`

## Firestore Seed Documents
Create seed docs before running simulator tests.

### parking_spots/spotA
```json
{
  "ownerId": "userA",
  "region": "SEOUL",
  "title": "A Spot",
  "price": 1000,
  "lat": 37.5,
  "lng": 127.0,
  "isPremium": false
}
```

### reservations/resA
```json
{
  "userId": "userA",
  "ownerId": "userB",
  "spotId": "spotA",
  "status": "reserved",
  "checkedOut": false
}
```

### reviews/revA
```json
{
  "userId": "userA",
  "spotId": "spotA",
  "rating": 5,
  "comment": "good"
}
```

### reports/repA
```json
{
  "userId": "userA",
  "spotId": "spotA",
  "reason": "illegal parking"
}
```

### ad_requests/adA
```json
{
  "userId": "userA",
  "status": "pending",
  "spotId": "spotA"
}
```

## Firestore Test Cases

### parking_spots
1. unauthenticated read spotA -> ALLOW
2. userA create parking_spots/newSpot with ownerId=userA -> ALLOW
3. userA create parking_spots/newSpot with ownerId=userB -> DENY
4. userA update parking_spots/spotA without changing ownerId -> ALLOW
5. userA update parking_spots/spotA and ownerId=userB -> DENY
6. userB delete parking_spots/spotA -> DENY
7. admin delete parking_spots/spotA -> ALLOW

### reservations
1. userA create reservations/newRes with userId=userA -> ALLOW
2. userA create reservations/newRes with userId=userB -> DENY
3. userA read reservations/resA -> ALLOW
4. userB read reservations/resA (ownerId=userB) -> ALLOW
5. unauthenticated read reservations/resA -> DENY
6. userB update reservations/resA keeping userId=userA -> ALLOW
7. userB update reservations/resA changing userId=userB -> DENY
8. userA delete reservations/resA -> ALLOW

### reviews
1. unauthenticated read reviews/revA -> ALLOW
2. userA create reviews/newRev with userId=userA -> ALLOW
3. userA create reviews/newRev with userId=userB -> DENY
4. userB delete reviews/revA -> DENY
5. admin delete reviews/revA -> ALLOW

### reports
1. userA create reports/newRep with userId=userA -> ALLOW
2. userA create reports/newRep with userId=userB -> DENY
3. userA read reports/repA -> DENY
4. admin read reports/repA -> ALLOW

### ad_requests
1. unauthenticated read ad_requests/adA status=pending -> DENY
2. unauthenticated read ad_requests/adA status=active -> ALLOW
3. userA create ad_requests/newAd with userId=userA -> ALLOW
4. userA create ad_requests/newAd with userId=userB -> DENY
5. userA update ad_requests/adA -> DENY
6. admin update ad_requests/adA -> ALLOW

## Storage Test Cases
Use Rules Playground with path and request metadata.

### checkout/{spotId}/{fileName}
1. unauthenticated read checkout/spotA/1.jpg -> DENY
2. userA read checkout/spotA/1.jpg -> ALLOW
3. userA write checkout/spotA/1.jpg contentType=image/jpeg size=1MB -> ALLOW
4. userA write checkout/spotA/1.jpg contentType=text/plain size=1MB -> DENY
5. userA write checkout/spotA/1.jpg contentType=image/jpeg size=11MB -> DENY

### ads/{fileName}
1. unauthenticated read ads/banner.jpg -> ALLOW
2. userA write ads/banner.jpg contentType=image/png size=1MB -> DENY
3. admin write ads/banner.jpg contentType=image/png size=1MB -> ALLOW
4. admin write ads/banner.jpg contentType=application/pdf size=1MB -> DENY

## Regression Checklist
- Service layer forcibly injects `ownerId`/`userId` on create.
- Client payload `userId` tampering is overridden before write.
- Admin custom claim is available in production auth tokens.
- Legacy docs without ownerId/userId are migrated or handled.
