import { ref, onMounted } from 'vue'
import { supabase } from '../supabase'

// รายชื่อหน้าที่เผยแพร่แล้วทั้งหมด สำหรับ dropdown เลือกลิงก์ภายใน แทนการพิมพ์ path เอง
// (กันพิมพ์ผิด เช่นลืม /page/ นำหน้าหน้า CMS ที่ slug เป็น page-<timestamp>)
export function useInternalPages() {
  const internalPages = ref([])
  onMounted(async () => {
    const { data } = await supabase.from('pages')
      .select('slug, title, page_type, system_route')
      .eq('is_published', true).order('title')
    internalPages.value = (data || [])
      .filter(p => p.page_type !== 'link')
      .map(p => ({
        title: p.title,
        path: p.page_type === 'system' ? (p.system_route || `/${p.slug}`) : `/page/${p.slug}`,
      }))
  })
  return { internalPages }
}
