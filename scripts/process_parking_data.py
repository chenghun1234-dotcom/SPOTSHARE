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
            for encoding in ['utf-8', 'cp949', 'euc-kr']:
                try:
                    return pd.read_csv(file_path, encoding=encoding, low_memory=False)
                except:
                    continue
        elif ext in ['.xlsx', '.xls']:
            return pd.read_excel(file_path)
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
        if df is None: continue
        
        df = df.rename(columns=lambda x: COLUMN_MAPPING.get(x.strip(), x.strip()))
        required = ['title', 'lat', 'lng']
        if not all(col in df.columns for col in required):
            print(f"Skipping {file}: Missing required columns")
            continue
            
        df['lat'] = pd.to_numeric(df['lat'], errors='coerce')
        df['lng'] = pd.to_numeric(df['lng'], errors='coerce')
        df = df.dropna(subset=['lat', 'lng', 'title'])
        df = df[(df['lat'] != 0) & (df['lng'] != 0)]
        
        for col in ['fee', 'type', 'address', 'info']:
            if col not in df.columns: df[col] = ''
                
        def simplify_type(t):
            t = str(t).upper()
            if '공영' in t or 'PUBLIC' in t: return 'PUBLIC'
            if '무료' in t or 'FREE' in t: return 'FREE'
            return 'PRIVATE'
        df['type'] = df['type'].apply(simplify_type)
        
        records = df[['title', 'lat', 'lng', 'fee', 'type', 'address', 'info']].to_dict('records')
        all_spots.extend(records)
        print(f"Processed {len(records)} spots from {file}")

    unique_spots = []
    seen = set()
    for s in all_spots:
        key = (s['title'], round(s['lat'], 4), round(s['lng'], 4))
        if key not in seen:
            seen.add(key)
            unique_spots.append(s)
            
    output_path = os.path.join(output_dir, 'parking_data.json')
    df_final = pd.DataFrame(unique_spots)
    
    json_spots = []
    for _, row in df_final.iterrows():
        # Extremely robust cleaning
        def clean_val(val, default=''):
            if pd.isna(val) or val is None: return default
            return str(val)

        def clean_num(val, default=0.0):
            try:
                v = pd.to_numeric(val, errors='coerce')
                return float(v) if not pd.isna(v) else default
            except:
                return default

        def clean_int(val, default=0):
            try:
                v = pd.to_numeric(val, errors='coerce')
                return int(v) if not pd.isna(v) else default
            except:
                return default

        json_spots.append({
            "title": clean_val(row['title'], 'Unknown'),
            "lat": clean_num(row['lat']),
            "lng": clean_num(row['lng']),
            "address": clean_val(row['address'], ""),
            "fee": clean_int(row.get('fee', 0)),
            "type": clean_val(row['type'], "PUBLIC"),
            "info": clean_val(row['info'], "")
        })

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump({
            'version': 1,
            'updatedAt': pd.Timestamp.now().isoformat(),
            'totalCount': len(json_spots),
            'spots': json_spots
        }, f, ensure_ascii=False, indent=2)
        
    print(f"Successfully generated {output_path} with {len(json_spots)} unique spots.")

if __name__ == "__main__":
    process_all()
