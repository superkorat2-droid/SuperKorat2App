import { computed } from 'vue'
import { useAreaConfig } from './useAreaConfig'

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
      mediaUrl:  found?.media_url  || '',
      mediaType: found?.media_type || '',
    }
  })
}
