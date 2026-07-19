import { computed } from 'vue'
import { useAreaConfig } from './useAreaConfig'

// map: pages.system_route -> usePageHeader() key ที่ view นั้นเรียกจริง
// ใช้เชื่อมจากหน้า "จัดการหน้าเนื้อหา" (หน้าที่ page_type='system') ไปยัง "หัวข้อหน้า (Header)" ให้ตรงแถวเป๊ะ
export const SYSTEM_ROUTE_HEADER_KEYS = {
  '/personnel':       'personnel',
  '/schools':          'schools',
  '/principals':       'principals',
  '/newsletters':      'newsletters',
  '/media':            'media',
  '/student-stats':    'studentStats',
  '/news':             'news',
  '/education-news':   'educationNews',
  '/download':         'download',
  '/school-documents': 'school-documents',
  '/url-short':        'urlShort',
  '/qrcode':           'qrcode',
  '/contact':          'contact',
  '/nithet':           'nithet',
  '/page/org':         'org',
  '/schoolweb':        'schoolWebsites',
}

// ดึงการตั้งค่า header (ไอคอน/ชื่อ default หรือ รูป/วิดีโอ/GIF) ของหน้า public ตาม route key
// จาก area_config.page_headers — ถ้าไม่มี entry หรือไม่ได้ตั้งค่าอะไร จะใช้ defaults ของไฟล์นั้นเป๊ะ (ไม่เปลี่ยนพฤติกรรมเดิม)
export function usePageHeader(routeKey, defaults = {}) {
  const { config } = useAreaConfig()
  return computed(() => {
    const found = (config.value?.page_headers || []).find(h => h.key === routeKey)
    return {
      mode:      found?.mode || 'icon',
      icon:      found?.icon || defaults.icon || '',
      title:     found?.title || defaults.title || '',
      subtitle:  found?.subtitle || defaults.subtitle || '',
      mediaUrl:    found?.media_url  || '',
      mediaType:   found?.media_type || '',
      aspectRatio: found?.aspect_ratio || '21:9',
      align:       found?.align || defaults.align || 'center',
      hidden:      found?.hidden ?? false,
    }
  })
}
