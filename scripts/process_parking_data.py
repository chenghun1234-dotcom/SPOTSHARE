import os
import json
import pandas as pd
import glob

# Normalize column names based on common variations in Korean public data
COLUMN_MAPPING = {
    '주차장명': 'title',
    'prkplceNm': 'title',
    '위도': 'lat',
    'latitude': 'lat',
    '경도': 'lng',
    'longitude': 'lng',
    '주차장구분': 'type',
    'prkplceSe': 'type',
    '요금정보': 'fee',
    'prkpc': 'fee',
    '소재지도로명주소': 'address',
    'rdnmadr': 'address',
    '소재지지번주소': 'address',
    'lnmadr': 'address',
    '운영시간': 'info',
    'operTime': 'info'
}

def load_data(file_path):
    ext = os.path.splitext(file_path)[1].lower()
    try:
        if ext == '.csv':
            # Try different encodings common in Korea
            for encoding in ['utf-8', 'cp949', 'euc-kr']:
                try:
                    return pd.read_csv(file_path, encoding=encoding)
                except:
                    continue
        elif ext in ['.xlsx', '.xls']:
            return pd.read_excel(file_path)
        elif ext == '.json':
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                if isinstance(data, list):
                    return pd.DataFrame(data)
                elif 'records' in data:
                    return pd.DataFrame(data['records'])
    except Exception as e:
        print(f"Error loading {file_path}: {e}")
    return None

def process_all():
    data_dir = 'data'
    output_dir = 'dist'
    
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        
    all_spots = []
    
    files = glob.glob(os.path.join(data_dir, '*.*'))
    print(f"Found {len(files)} files in {data_dir}")
    
    for file in files:
        df = load_data(file)
        if df is None:
            continue
            
        # Re-map columns
        df = df.rename(columns=lambda x: COLUMN_MAPPING.get(x.strip(), x.strip()))
        
        # Keep only necessary columns if they exist
        required = ['title', 'lat', 'lng']
        if not all(col in df.columns for col in required):
            print(f"Skipping {file}: Missing required columns {set(required) - set(df.columns)}")
            continue
            
        # Convert to numeric lat/lng
        df['lat'] = pd.to_numeric(df['lat'], errors='coerce')
        df['lng'] = pd.to_numeric(df['lng'], errors='coerce')
        
        # Clean data
        df = df.dropna(subset=['lat', 'lng', 'title'])
        df = df[(df['lat'] != 0) & (df['lng'] != 0)]
        
        # Ensure optional columns exist
        for col in ['fee', 'type', 'address', 'info']:
            if col not in df.columns:
                df[col] = ''
                
        # Simplify type
        def simplify_type(t):
            t = str(t).upper()
            if '공영' in t or 'PUBLIC' in t: return 'PUBLIC'
            if '무료' in t or 'FREE' in t: return 'FREE'
            return 'PRIVATE'
            
        df['type'] = df['type'].apply(simplify_type)
        
        # Convert to list of dicts
        records = df[['title', 'lat', 'lng', 'fee', 'type', 'address', 'info']].to_dict('records')
        all_spots.extend(records)
        print(f"Processed {len(records)} spots from {file}")

    # Deduplicate by Title + Lat/Lng with small offset
    unique_spots = []
    seen = set()
    for s in all_spots:
        key = (s['title'], round(s['lat'], 4), round(s['lng'], 4))
        if key not in seen:
            seen.add(key)
            unique_spots.append(s)
            
    # Output JSON
    output_path = os.path.join(output_dir, 'parking_data.json')
    df_final = pd.DataFrame(unique_spots)
    df_final = df_final.replace({np.nan: None})
    df_final['fee'] = pd.to_numeric(df_final['fee'], errors='coerce').fillna(0).astype(int)
    
    spots = []
    for _, row in df_final.iterrows():
        spots.append({
            "title": str(row['title']) if row['title'] else "Unknown",
            "lat": float(row['lat']) if row['lat'] else 0.0,
            "lng": float(row['lng']) if row['lng'] else 0.0,
            "address": str(row['address']) if row['address'] else "",
            "fee": int(row['fee']),
            "type": str(row['type']) if row['type'] else "PUBLIC",
            "info": str(row['info']) if row['info'] else ""
        })

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump({
            'version': 1,
            'updatedAt': pd.Timestamp.now().isoformat(),
            'totalCount': len(spots),
            'spots': spots
        }, f, ensure_ascii=False, indent=2)
        
    print(f"Successfully generated {output_path} with {len(spots)} unique spots.")

if __name__ == "__main__":
    process_all()
