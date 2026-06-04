import { ref } from 'vue'
import { supabase } from '../supabase'

const pages  = ref([])
const loaded = ref(false)

const DEFAULT_GROUPS = [
  { key: 'general', label: 'ข้อมูลทั่วไป',   visible: true,  order: 1 },
  { key: 'work',    label: 'งานนิเทศติดตาม', visible: true,  order: 2 },
  { key: 'service', label: 'บริการ',          visible: true,  order: 3 },
  { key: 'other',   label: 'อื่นๆ',           visible: false, order: 4 },
]

export function useNavPages() {
  async function fetchNavPages(force = false) {
    if (loaded.value && !force) return
    const { data } = await supabase
      .from('pages')
      .select('id, slug, title, nav_icon, nav_group, nav_order, page_type, system_route, show_in_nav, is_published')
      .eq('show_in_nav', true)
      .eq('is_published', true)
      .order('nav_order', { ascending: true })
    pages.value  = data || []
    loaded.value = true
  }

  // groupConfig: array จาก area_config.nav_groups
  function getNavGroups(groupConfig = null) {
    const cfg = (groupConfig || DEFAULT_GROUPS)
      .filter(g => g.visible)
      .sort((a, b) => a.order - b.order)

    return cfg.map(g => ({
      key:   g.key,
      label: g.label,
      items: pages.value.filter(p => p.nav_group === g.key),
    })).filter(g => g.items.length > 0)
  }

  function pageRoute(p) {
    if (p.page_type === 'system') return p.system_route || `/${p.slug}`
    if (p.page_type === 'link')   return p.system_route || '#'
    return `/page/${p.slug}`
  }

  function isExternal(p) {
    return p.page_type === 'link' && /^https?:\/\//.test(p.system_route)
  }

  return { pages, loaded, fetchNavPages, getNavGroups, pageRoute, isExternal, DEFAULT_GROUPS }
}
