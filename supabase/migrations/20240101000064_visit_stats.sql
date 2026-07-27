-- ═══════════════════════════════════════════════════════════════════════
-- สถิติการเข้าชมเว็บไซต์ (visit stats)
--
-- ทำไมไม่ใช้ Google Analytics: GA4 Data API บังคับ OAuth2/service account
-- (GOOGLE_API_KEY ที่มีอยู่เป็น API key ธรรมดา ใช้กับ Drive ได้ แต่กับ GA ไม่ได้)
-- และเก็บเองแปลว่าข้อมูลอยู่กับเขต · ไม่ต้องมีแถบขอความยินยอมคุกกี้ ·
-- เอาตัวเลขไปทำรายงาน A4 กับโชว์ในแดชบอร์ดได้ในคิวรีเดียว
--
-- ทำไมไม่ต้องใช้ pg_cron: RPC upsert ยอดสรุปให้ตั้งแต่ตอนบันทึก ตาราง
-- visit_daily / visit_page_daily จึงพร้อมใช้ตลอดเวลา ไม่ต้องมี job ปั่นทีหลัง
--
-- ความเป็นส่วนตัว (PDPA): ไม่เก็บ IP จริง ไม่ใช้คุกกี้ ไม่แตะ localStorage
-- เก็บแค่ hash ของ (IP + user-agent + วันที่ + salt) ซึ่งเปลี่ยนทุกวัน
-- → ย้อนกลับเป็นตัวบุคคลไม่ได้ และข้ามวันแล้วโยงกันไม่ได้
-- ═══════════════════════════════════════════════════════════════════════

-- ── 1. ตาราง ────────────────────────────────────────────────────────────

-- เหตุการณ์ดิบ — มีไว้ตอบ 2 คำถามเท่านั้น: "เปิดซ้ำใน 30 นาทีไหม" กับ
-- "เป็นหัวใหม่ของวันนี้ไหม" · รายงานทั้งหมดอ่านจากตารางสรุป ตารางนี้จึง
-- ลบทิ้งเมื่อเก่าเกิน 90 วันได้โดยสถิติไม่หาย (ดู prune_visit_events)
CREATE TABLE IF NOT EXISTS public.visit_events (
  id           bigserial   PRIMARY KEY,
  visited_at   timestamptz NOT NULL DEFAULT now(),
  visit_date   date        NOT NULL,
  path         text        NOT NULL,
  title        text,
  visitor_hash text        NOT NULL,
  device       text        NOT NULL CHECK (device IN ('mobile','tablet','desktop'))
);

CREATE INDEX IF NOT EXISTS visit_events_dedup_idx
  ON public.visit_events (visitor_hash, path, visited_at DESC);
CREATE INDEX IF NOT EXISTS visit_events_visitor_day_idx
  ON public.visit_events (visitor_hash, visit_date);
CREATE INDEX IF NOT EXISTS visit_events_date_idx
  ON public.visit_events (visit_date);

-- สรุปรายวันของทั้งเว็บ — ใช้กับตัวนับท้ายเว็บ กราฟแนวโน้ม และสัดส่วนอุปกรณ์
CREATE TABLE IF NOT EXISTS public.visit_daily (
  day     date PRIMARY KEY,
  views   integer NOT NULL DEFAULT 0,
  uniques integer NOT NULL DEFAULT 0,
  mobile  integer NOT NULL DEFAULT 0,
  tablet  integer NOT NULL DEFAULT 0,
  desktop integer NOT NULL DEFAULT 0
);

-- สรุปรายวันแยกตามหน้า — ใช้จัดอันดับหน้ายอดนิยม
CREATE TABLE IF NOT EXISTS public.visit_page_daily (
  day     date    NOT NULL,
  path    text    NOT NULL,
  title   text,
  views   integer NOT NULL DEFAULT 0,
  uniques integer NOT NULL DEFAULT 0,
  PRIMARY KEY (day, path)
);

-- ── 2. ปิดตายทั้ง 3 ตาราง เข้าถึงผ่าน RPC เท่านั้น ──────────────────────
-- Supabase ตั้ง default privileges ให้ anon/authenticated บนตารางใหม่ใน public
-- ถ้าไม่ REVOKE จะอ่าน/เขียนตรงได้ (บทเรียนจาก 0059 และ 0062)
-- เปิด RLS โดยไม่มี policy = ปิดสนิทอีกชั้น เผื่อ grant หลุดมาในอนาคต
ALTER TABLE public.visit_events     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visit_daily      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visit_page_daily ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.visit_events     FROM anon, authenticated;
REVOKE ALL ON public.visit_daily      FROM anon, authenticated;
REVOKE ALL ON public.visit_page_daily FROM anon, authenticated;
REVOKE ALL ON SEQUENCE public.visit_events_id_seq FROM anon, authenticated;

-- ── 3. RPC บันทึกการเข้าชม ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.track_visit(
  p_path   text,
  p_title  text DEFAULT NULL,
  p_device text DEFAULT 'desktop'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  -- ตัด query string ทิ้ง ไม่งั้น /news?page=2 กับ /news?page=3 กลายเป็นคนละหน้า
  v_path   text := left(split_part(btrim(coalesce(p_path, '')), '?', 1), 300);
  v_title  text := left(nullif(btrim(coalesce(p_title, '')), ''), 200);
  v_device text := lower(coalesce(p_device, 'desktop'));
  v_hdr    json := nullif(current_setting('request.headers', true), '')::json;
  v_ip     text;
  v_ua     text;
  v_day    date := (now() AT TIME ZONE 'Asia/Bangkok')::date;
  v_hash   text;
  v_new_visitor boolean;
  v_new_on_page boolean;
BEGIN
  IF v_path = '' OR v_path NOT LIKE '/%' THEN RETURN; END IF;

  -- หลังบ้าน + iframe ที่ฝังในเว็บอื่น ต้องไม่ปนกับสถิติสาธารณะ
  -- (/embed สำคัญมาก — ไม่งั้นทุกครั้งที่มีคนเปิดหน้า WordPress ที่ฝังบุคลากร
  --  จะถูกนับเป็นผู้เข้าชมเว็บเขตไปด้วย)
  IF v_path ~ '^/(dashboard|school|embed|login|register)(/|$)' THEN RETURN; END IF;

  IF v_device NOT IN ('mobile','tablet','desktop') THEN v_device := 'desktop'; END IF;

  -- x-forwarded-for เป็นสายทอด อาจมีหลาย IP คั่นด้วย , ตัวแรกคือ client จริง
  v_ip := btrim(split_part(coalesce(v_hdr->>'x-forwarded-for', v_hdr->>'x-real-ip', ''), ',', 1));
  v_ua := coalesce(v_hdr->>'user-agent', '');

  -- ไม่มี user-agent = ไม่ใช่เบราว์เซอร์คนจริง
  IF v_ua = '' THEN RETURN; END IF;
  IF v_ua ~* '(bot|crawl|spider|slurp|scrape|curl|wget|python-requests|http-client|headless|phantom|monitor|uptime|preview|facebookexternalhit|embedly|whatsapp|telegram|discord|lighthouse|pagespeed|gtmetrix)'
    THEN RETURN;
  END IF;

  -- salt คงที่ + วันที่ → hash เปลี่ยนทุกวัน ย้อนกลับเป็น IP ไม่ได้
  -- (ตัวฟังก์ชันเป็น SECURITY DEFINER และ anon อ่าน source ไม่ได้)
  v_hash := encode(
    digest(v_ip || '|' || v_ua || '|' || v_day::text || '|sk2-visit-salt-2569', 'sha256'),
    'hex');

  -- กดรีเฟรชรัวๆ ไม่นับซ้ำ
  IF EXISTS (
    SELECT 1 FROM public.visit_events
    WHERE visitor_hash = v_hash AND path = v_path
      AND visited_at > now() - interval '30 minutes'
  ) THEN RETURN; END IF;

  -- ต้องเช็คก่อน INSERT ไม่งั้นแถวที่เพิ่งใส่จะทำให้ตัวเองไม่ใช่ "หัวใหม่"
  v_new_visitor := NOT EXISTS (
    SELECT 1 FROM public.visit_events WHERE visitor_hash = v_hash AND visit_date = v_day);
  v_new_on_page := NOT EXISTS (
    SELECT 1 FROM public.visit_events
    WHERE visitor_hash = v_hash AND visit_date = v_day AND path = v_path);

  INSERT INTO public.visit_events (visit_date, path, title, visitor_hash, device)
  VALUES (v_day, v_path, v_title, v_hash, v_device);

  INSERT INTO public.visit_daily AS d (day, views, uniques, mobile, tablet, desktop)
  VALUES (v_day, 1,
          CASE WHEN v_new_visitor      THEN 1 ELSE 0 END,
          CASE WHEN v_device='mobile'  THEN 1 ELSE 0 END,
          CASE WHEN v_device='tablet'  THEN 1 ELSE 0 END,
          CASE WHEN v_device='desktop' THEN 1 ELSE 0 END)
  ON CONFLICT (day) DO UPDATE SET
    views   = d.views   + 1,
    uniques = d.uniques + CASE WHEN v_new_visitor      THEN 1 ELSE 0 END,
    mobile  = d.mobile  + CASE WHEN v_device='mobile'  THEN 1 ELSE 0 END,
    tablet  = d.tablet  + CASE WHEN v_device='tablet'  THEN 1 ELSE 0 END,
    desktop = d.desktop + CASE WHEN v_device='desktop' THEN 1 ELSE 0 END;

  INSERT INTO public.visit_page_daily AS pd (day, path, title, views, uniques)
  VALUES (v_day, v_path, v_title, 1, CASE WHEN v_new_on_page THEN 1 ELSE 0 END)
  ON CONFLICT (day, path) DO UPDATE SET
    views   = pd.views   + 1,
    uniques = pd.uniques + CASE WHEN v_new_on_page THEN 1 ELSE 0 END,
    -- ชื่อหน้าอาจเปลี่ยนภายหลัง เก็บชื่อล่าสุดที่ส่งมา
    title   = COALESCE(EXCLUDED.title, pd.title);
END;
$$;

REVOKE ALL ON FUNCTION public.track_visit(text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.track_visit(text, text, text) TO anon, authenticated;

-- ── 4. RPC ตัวนับท้ายเว็บ (สาธารณะ) ─────────────────────────────────────
-- คิวรีเดียว อ่านจากตารางสรุป ไม่แตะ visit_events
CREATE OR REPLACE FUNCTION public.get_visit_counter()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'total', COALESCE((SELECT sum(views) FROM public.visit_daily), 0),
    'today', COALESCE((SELECT views FROM public.visit_daily
                       WHERE day = (now() AT TIME ZONE 'Asia/Bangkok')::date), 0)
  );
$$;

REVOKE ALL ON FUNCTION public.get_visit_counter() FROM public;
GRANT EXECUTE ON FUNCTION public.get_visit_counter() TO anon, authenticated;

-- ── 5. RPC แดชบอร์ด/รายงาน (เฉพาะคนใน) ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_visit_stats(
  p_from date DEFAULT NULL,
  p_to   date DEFAULT NULL,
  p_limit integer DEFAULT 20
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'Asia/Bangkok')::date;
  v_from  date := COALESCE(p_from, v_today - 29);
  v_to    date := COALESCE(p_to, v_today);
  v_limit integer := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 100);
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor')
  ) THEN
    RAISE EXCEPTION 'ไม่มีสิทธิ์ดูสถิติการเข้าชม';
  END IF;

  IF v_from > v_to THEN SELECT v_to, v_from INTO v_from, v_to; END IF;

  RETURN jsonb_build_object(
    'from', v_from,
    'to',   v_to,
    'summary', jsonb_build_object(
      -- ในช่วงที่เลือก: uniques นับหัวไม่ซ้ำจริงจาก raw (แม่นเท่าที่ raw ยังอยู่)
      'views',   COALESCE((SELECT sum(views) FROM public.visit_daily
                           WHERE day BETWEEN v_from AND v_to), 0),
      'uniques', COALESCE((SELECT count(DISTINCT visitor_hash) FROM public.visit_events
                           WHERE visit_date BETWEEN v_from AND v_to), 0),
      'today_views',   COALESCE((SELECT views   FROM public.visit_daily WHERE day = v_today), 0),
      'today_uniques', COALESCE((SELECT uniques FROM public.visit_daily WHERE day = v_today), 0),
      'total_views',   COALESCE((SELECT sum(views) FROM public.visit_daily), 0),
      'days_tracked',  COALESCE((SELECT count(*) FROM public.visit_daily), 0),
      'first_day',     (SELECT min(day) FROM public.visit_daily)
    ),
    -- เติมวันที่ไม่มีคนเข้าให้เป็น 0 ด้วย กราฟจะได้ไม่กระโดดข้ามวัน
    'trend', COALESCE((
      -- ต้อง cast เป็น date ทั้งคู่ — generate_series ของ date คืน timestamptz
      -- ถ้าปล่อยไว้ JSON จะได้ "2026-06-28T00:00:00+00:00" แล้วฝั่งหน้าเว็บงง
      SELECT jsonb_agg(jsonb_build_object(
               'day', g.day::date, 'views', COALESCE(d.views, 0), 'uniques', COALESCE(d.uniques, 0))
             ORDER BY g.day)
      FROM generate_series(v_from, v_to, interval '1 day') AS g(day)
      LEFT JOIN public.visit_daily d ON d.day = g.day::date
    ), '[]'::jsonb),
    'top_pages', COALESCE((
      SELECT jsonb_agg(x ORDER BY (x->>'views')::int DESC)
      FROM (
        SELECT jsonb_build_object(
                 'path', path,
                 'title', max(title),
                 'views', sum(views)::int,
                 'uniques', sum(uniques)::int) AS x
        FROM public.visit_page_daily
        WHERE day BETWEEN v_from AND v_to
        GROUP BY path
        ORDER BY sum(views) DESC
        LIMIT v_limit
      ) t
    ), '[]'::jsonb),
    'devices', (
      SELECT jsonb_build_object(
        'mobile',  COALESCE(sum(mobile), 0),
        'tablet',  COALESCE(sum(tablet), 0),
        'desktop', COALESCE(sum(desktop), 0))
      FROM public.visit_daily WHERE day BETWEEN v_from AND v_to
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_visit_stats(date, date, integer) FROM public;
GRANT EXECUTE ON FUNCTION public.get_visit_stats(date, date, integer) TO authenticated;

-- ── 6. ล้างเหตุการณ์ดิบที่เก่าเกินกำหนด ─────────────────────────────────
-- ตารางสรุปไม่ถูกแตะ สถิติจึงอยู่ครบ · ยังไม่ตั้ง cron ให้ เรียกมือเมื่อจำเป็น
CREATE OR REPLACE FUNCTION public.prune_visit_events(p_keep_days integer DEFAULT 90)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_n integer;
BEGIN
  DELETE FROM public.visit_events
  WHERE visit_date < (now() AT TIME ZONE 'Asia/Bangkok')::date - GREATEST(p_keep_days, 7);
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;

REVOKE ALL ON FUNCTION public.prune_visit_events(integer) FROM public, anon, authenticated;

-- ── 7. สวิตช์เปิด/ปิดตัวนับท้ายเว็บ ─────────────────────────────────────
-- get_area_config() คืน row_to_json(a) ทั้งแถว คอลัมน์ใหม่จึงไหลไปหน้าเว็บเอง
ALTER TABLE public.area_config
  ADD COLUMN IF NOT EXISTS show_visitor_counter boolean NOT NULL DEFAULT true;

GRANT SELECT (show_visitor_counter) ON public.area_config TO anon;
