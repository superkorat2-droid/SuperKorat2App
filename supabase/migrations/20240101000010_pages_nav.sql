-- Migration 10: Dynamic nav columns for pages table
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='pages' AND column_name='page_type') THEN
    ALTER TABLE public.pages ADD COLUMN page_type    text    NOT NULL DEFAULT 'cms'
      CHECK (page_type IN ('cms','system','link'));
    ALTER TABLE public.pages ADD COLUMN system_route text    NOT NULL DEFAULT '';
    ALTER TABLE public.pages ADD COLUMN show_in_nav  boolean NOT NULL DEFAULT false;
    ALTER TABLE public.pages ADD COLUMN nav_group    text    NOT NULL DEFAULT 'general'
      CHECK (nav_group IN ('general','work','service','other'));
    ALTER TABLE public.pages ADD COLUMN nav_order    int     NOT NULL DEFAULT 99;
    ALTER TABLE public.pages ADD COLUMN nav_icon     text    NOT NULL DEFAULT 'document';
  END IF;
END $$;

-- ── Seed nav settings สำหรับ pages เดิม ──────────────────────────
-- publish ทุก page ที่จะแสดงในเมนู
UPDATE public.pages SET is_published = true WHERE slug IN (
  'vision','org','personnel','site-info',
  'curriculum','supervision-edu','evaluation','quality','research','secretariat'
);

UPDATE public.pages SET
  page_type='cms', show_in_nav=true, nav_group='general', nav_order=1, nav_icon='eye'
WHERE slug='vision';

UPDATE public.pages SET
  page_type='cms', show_in_nav=true, nav_group='general', nav_order=2, nav_icon='building'
WHERE slug='org';

UPDATE public.pages SET
  page_type='system', system_route='/personnel', show_in_nav=true, nav_group='general', nav_order=3, nav_icon='users'
WHERE slug='personnel';

UPDATE public.pages SET
  page_type='system', system_route='/site-info', show_in_nav=true, nav_group='general', nav_order=4, nav_icon='chart-bar'
WHERE slug='site-info';

UPDATE public.pages SET
  page_type='cms', show_in_nav=true, nav_group='work', nav_order=1, nav_icon='book-open'
WHERE slug='curriculum';

UPDATE public.pages SET
  page_type='cms', show_in_nav=true, nav_group='work', nav_order=2, nav_icon='magnify'
WHERE slug='supervision-edu';

UPDATE public.pages SET
  page_type='cms', show_in_nav=true, nav_group='work', nav_order=3, nav_icon='clipboard'
WHERE slug='evaluation';

UPDATE public.pages SET
  page_type='cms', show_in_nav=true, nav_group='work', nav_order=4, nav_icon='star'
WHERE slug='quality';

UPDATE public.pages SET
  page_type='cms', show_in_nav=true, nav_group='work', nav_order=5, nav_icon='beaker'
WHERE slug='research';

UPDATE public.pages SET
  page_type='cms', show_in_nav=true, nav_group='work', nav_order=6, nav_icon='wrench'
WHERE slug='secretariat';

-- service pages (system routes)
INSERT INTO public.pages (slug, title, icon, nav_icon, page_type, system_route, show_in_nav, is_published, nav_group, nav_order, blocks)
VALUES
  ('download',  'ดาวน์โหลดเอกสาร', 'download', 'download', 'system', '/download',  true, true, 'service', 1, '[]'),
  ('url-short', 'ย่อลิงค์',         'link',     'link',     'system', '/url-short', true, true, 'service', 2, '[]'),
  ('qrcode',    'สร้าง QR Code',    'qrcode',   'qrcode',   'system', '/qrcode',    true, true, 'service', 3, '[]')
ON CONFLICT (slug) DO UPDATE SET
  page_type='system', show_in_nav=true, is_published=true,
  nav_group='service', nav_order=EXCLUDED.nav_order,
  system_route=EXCLUDED.system_route, nav_icon=EXCLUDED.nav_icon;
