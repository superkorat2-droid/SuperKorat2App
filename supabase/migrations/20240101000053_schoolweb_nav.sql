-- Migration 53: Seed pages row for /schoolweb (public school-website directory)
-- ให้แสดงในเมนู "บริการ" (service) ต่อจาก download/url-short/qrcode
INSERT INTO public.pages (slug, title, icon, nav_icon, page_type, system_route, show_in_nav, is_published, nav_group, nav_order, blocks)
VALUES
  ('schoolweb', 'เว็บไซต์โรงเรียน', 'globe', 'globe', 'system', '/schoolweb', true, true, 'service', 4, '[]')
ON CONFLICT (slug) DO UPDATE SET
  page_type='system', show_in_nav=true, is_published=true,
  nav_group='service', nav_order=EXCLUDED.nav_order,
  system_route=EXCLUDED.system_route, nav_icon=EXCLUDED.nav_icon;
