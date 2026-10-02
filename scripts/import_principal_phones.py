"""นำเข้าเบอร์โทรผู้บริหารจาก tel.xlsx → school_principals (สร้างไฟล์ SQL ให้ psql รัน)

ใช้:  python scripts/import_principal_phones.py tel.xlsx out.sql
กติกา:
  - รหัสในไฟล์ = schools.dmc_code · ตัดแถวสรุป "รวม N โรงเรียน"
  - เบอร์: เลขไทย→อารบิก ตัดช่องว่าง/ขีด ต้องเป็น 10 หลักขึ้นต้น 06/08/09
  - เบอร์ผิดรูป: ถ้าผู้บริหารคนเดียวกัน (ชื่อตรงกันเมื่อตัดช่องว่าง) มีเบอร์ถูกที่โรงอื่น → ใช้เบอร์นั้น
    ไม่เช่นนั้นเว้นว่างแล้วรายงาน (ห้ามเดาเลข)
  - visibility ปิดหมด · idempotent: ไม่เพิ่มซ้ำ, เติมเบอร์เฉพาะที่ยังว่าง, ไม่ทับคนอื่น
ไฟล์ SQL ที่ได้มีเบอร์ส่วนตัว — ห้าม commit
"""
import re
import sys
import openpyxl

TH = str.maketrans('๐๑๒๓๔๕๖๗๘๙', '0123456789')
POSITION = {'ผอ.รร.': 'ผู้อำนวยการ', 'รก.ผอ.รร.': 'รักษาการผู้อำนวยการ'}
# สาขาที่ไม่มีเบอร์ของตัวเอง ใช้เบอร์เดียวกับโรงหลักซึ่งผู้บริหารคนเดียวกัน (ชื่อสะกดต่างกันเล็กน้อย)
SAME_AS = {'30020024': '30020031'}

norm_name = lambda s: re.sub(r'\s+', '', s or '')
tidy_name = lambda s: re.sub(r'\s+', ' ', s or '').strip()
q = lambda s: "'" + str(s).replace("'", "''") + "'"


def clean_phone(v):
    d = re.sub(r'\D', '', str(v or '').translate(TH))
    return d if re.fullmatch(r'0[689]\d{8}', d) else None


def main(src, out):
    rows = [r for r in openpyxl.load_workbook(src).active.iter_rows(values_only=True)][1:]
    rows = [r for r in rows if r[0] and r[4]]
    phone = {r[0]: clean_phone(r[6]) for r in rows}

    by_name = {}
    for r in rows:
        if phone[r[0]]:
            by_name.setdefault(norm_name(r[4]), phone[r[0]])

    fixed, missing = [], []
    for r in rows:
        if phone[r[0]]:
            continue
        alt = by_name.get(norm_name(r[4])) or phone.get(SAME_AS.get(r[0]))
        if alt:
            phone[r[0]] = alt
            fixed.append((r[0], r[1], r[4], r[6]))
        else:
            missing.append((r[0], r[1], r[4], r[6]))

    sql = ['BEGIN;', 'CREATE TEMP TABLE _imp(dmc_code text, name text, position text, phone text);']
    for r in rows:
        pos = POSITION.get(str(r[5]).strip(), tidy_name(r[5]))
        sql.append(f"INSERT INTO _imp VALUES ({q(r[0])},{q(tidy_name(r[4]))},{q(pos)},"
                   f"{q(phone[r[0]]) if phone[r[0]] else 'NULL'});")
    sql += [
        # เติมเบอร์ให้คนที่มีอยู่แล้ว (ชื่อตรงเมื่อตัดช่องว่าง) เฉพาะที่ยังว่าง
        """WITH upd AS (
  UPDATE school_principals p SET phone = i.phone, updated_at = now()
  FROM _imp i JOIN schools s ON s.dmc_code = i.dmc_code
  WHERE p.school_id = s.id AND regexp_replace(p.name,'\\s','','g') = regexp_replace(i.name,'\\s','','g')
    AND COALESCE(p.phone,'') = '' AND i.phone IS NOT NULL
  RETURNING 1) SELECT 'updated' AS what, count(*) FROM upd;""",
        # เพิ่มเฉพาะโรงที่ยังไม่มีผู้บริหารชื่อนี้ และไม่มีผู้บริหารตำแหน่งเดียวกันอยู่ก่อน
        """WITH ins AS (
  INSERT INTO school_principals (school_id, name, position, phone, sort_order, visibility)
  SELECT s.id, i.name, i.position, i.phone, 0, '{"phone":false,"email":false,"line":false}'::jsonb
  FROM _imp i JOIN schools s ON s.dmc_code = i.dmc_code
  WHERE NOT EXISTS (SELECT 1 FROM school_principals p WHERE p.school_id = s.id)
  RETURNING 1) SELECT 'inserted' AS what, count(*) FROM ins;""",
        """SELECT 'skipped_other_person_exists' AS what, count(*)
FROM _imp i JOIN schools s ON s.dmc_code = i.dmc_code
WHERE EXISTS (SELECT 1 FROM school_principals p WHERE p.school_id = s.id
              AND regexp_replace(p.name,'\\s','','g') <> regexp_replace(i.name,'\\s','','g'));""",
        'COMMIT;',
    ]
    open(out, 'w', encoding='utf-8').write('\n'.join(sql))

    print(f'rows={len(rows)} phone_ok={sum(1 for v in phone.values() if v)}')
    print('แก้จากโรงอื่นของผู้บริหารคนเดียวกัน:')
    for f in fixed:
        print('  ', f)
    print('ไม่มีเบอร์ (เว้นว่าง):')
    for m in missing:
        print('  ', m)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
