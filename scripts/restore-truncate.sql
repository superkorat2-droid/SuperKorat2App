-- ล้างข้อมูลที่ migrations ใส่ไว้ ก่อนโหลด data.sql ของ backup ทับ
-- ถ้าไม่ล้างก่อน จะชน primary key ที่ area_config, pages, storage.buckets
--
-- ต้องดักข้อผิดพลาดรายตาราง เพราะ storage.buckets_vectors กับ storage.vector_indexes
-- แม้แต่ user postgres ก็ TRUNCATE ไม่ได้ ถ้าปล่อยให้ error ทั้ง DO block จะ rollback
-- แปลว่าไม่มีอะไรถูกล้างเลย แต่ไม่มีอะไรฟ้อง
SET session_replication_role = replica;
DO $$
DECLARE
  r record;
  skipped int := 0;
  done int := 0;
BEGIN
  FOR r IN
    SELECT format('%I.%I', schemaname, tablename) AS t
    FROM pg_tables
    WHERE schemaname IN ('public', 'auth', 'storage')
      AND tablename NOT IN ('schema_migrations', 'migrations')
  LOOP
    BEGIN
      EXECUTE 'TRUNCATE ' || r.t || ' CASCADE';
      done := done + 1;
    EXCEPTION WHEN insufficient_privilege THEN
      skipped := skipped + 1;
      RAISE NOTICE 'ข้าม % (ไม่มีสิทธิ์)', r.t;
    END;
  END LOOP;
  RAISE NOTICE 'ล้างแล้ว % ตาราง / ข้าม % ตาราง', done, skipped;
END $$;
RESET session_replication_role;
