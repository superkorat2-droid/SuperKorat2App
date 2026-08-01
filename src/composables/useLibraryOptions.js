import { ref, computed } from 'vue'
import { supabase } from '../supabase'

/**
 * useLibraryOptions — ตัวเลือกของคลังหนังสือและคู่มือ
 *
 * ทั้งกลุ่มงานและผู้เผยแพร่ **ดึงจากข้อมูลจริงในระบบ ไม่ใช่รายการตายตัว**
 * เพิ่ม ศน. คนใหม่หรือเปลี่ยนชื่อกลุ่มงานแล้วตัวเลือกตามทันทีโดยไม่ต้องแก้โค้ด
 */

// ── ชนิดของสิ่งพิมพ์ ────────────────────────────────────────────────────
export const LIBRARY_KINDS = [
  { value: 'book',       label: 'หนังสือ',        color: 'bg-indigo-100 text-indigo-700' },
  { value: 'handbook',   label: 'คู่มือ',          color: 'bg-emerald-100 text-emerald-700' },
  { value: 'research',   label: 'งานวิจัย',       color: 'bg-violet-100 text-violet-700' },
  { value: 'regulation', label: 'ระเบียบ/แนวทาง', color: 'bg-amber-100 text-amber-700' },
  { value: 'other',      label: 'อื่นๆ',          color: 'bg-slate-100 text-slate-500' },
]

export function kindLabel(v) { return LIBRARY_KINDS.find(k => k.value === v)?.label || v }
/** ⚠️ ห้ามใช้รูปแบบ `bg-primary/10` — primary ไม่ใช่สีใน theme ของ Tailwind คลาสจะไม่มีอยู่จริง */
export function kindColor(v) { return LIBRARY_KINDS.find(k => k.value === v)?.color || 'bg-slate-100 text-slate-500' }

/**
 * กลุ่มงาน — มาจาก area_config.personnel_groups (แอดมินแก้เองได้ในหน้าจัดการบุคลากร)
 *
 * ⚠️ เราเก็บลง library_items.group_key เป็น **key** ไม่ใช่ label
 * เพราะแอดมินเปลี่ยนชื่อกลุ่มได้ ถ้าเก็บ label ข้อมูลเก่าจะขาดทันทีที่เปลี่ยนชื่อ
 * (ในระบบมี 2 ธรรมเนียมปนกันจริง: profiles.department เก็บ label ส่วน
 *  nithet_events.responsible_group / supervision_forms.responsible_group เก็บ key)
 *
 * @param config ref ของ area_config จาก useAreaConfig()
 */
export function useGroupOptions(config) {
  const groupOptions = computed(() =>
    (config.value?.personnel_groups || [])
      .filter(g => g.visible !== false)
      .sort((a, b) => (a.order ?? 99) - (b.order ?? 99))
      .map(g => ({ key: g.key, label: g.label }))
  )

  function groupLabel(key) {
    if (!key) return ''
    return groupOptions.value.find(g => g.key === key)?.label || key
  }

  /** แปลง label → key ใช้ตอนเดาค่าเริ่มต้นจาก profiles.department ซึ่งเก็บเป็น label */
  function keyFromLabel(label) {
    if (!label) return ''
    return groupOptions.value.find(g => g.label === label)?.key || ''
  }

  return { groupOptions, groupLabel, keyFromLabel }
}

/**
 * ผู้เผยแพร่ — สมาชิกที่เป็น ศน./เจ้าหน้าที่/ผู้ดูแล ที่อนุมัติแล้วเท่านั้น
 *
 * บังคับให้เป็นบัญชีสมาชิกจริง (publisher_id เป็น FK ไป profiles) ไม่ใช่ข้อความอิสระ
 * แบบ documents.publisher_name ที่พิมพ์อะไรก็ได้จนข้อมูลไม่เกาะกลุ่ม
 *
 * ⚠️ ใช้ได้เฉพาะฝั่งที่ล็อกอินแล้ว — migration 0060 สั่ง REVOKE profiles จาก anon
 * หน้าสาธารณะต้องอ่านชื่อผู้เผยแพร่จาก view library_public แทน
 */
export function usePublisherOptions() {
  const publishers = ref([])
  const loadingPublishers = ref(false)

  async function fetchPublishers() {
    loadingPublishers.value = true
    const { data } = await supabase
      .from('profiles')
      .select('id, title, first_name, last_name, full_name, role, department, avatar_url')
      .in('role', ['supervisor', 'staff', 'admin', 'super_admin'])
      .eq('is_active', true)
      .eq('is_approved', true)
      .order('sort_order', { ascending: true })
    publishers.value = (data || []).map(p => ({ ...p, display: personDisplayName(p) }))
    loadingPublishers.value = false
    return publishers.value
  }

  const publisherById = computed(() =>
    Object.fromEntries(publishers.value.map(p => [p.id, p]))
  )

  return { publishers, loadingPublishers, fetchPublishers, publisherById }
}

/** full_name ถูก trigger เขียนทับได้ จึงมี concat สำรองไว้เสมอ */
export function personDisplayName(p) {
  if (!p) return ''
  const full = String(p.full_name || '').trim()
  if (full) return full
  return [p.title, p.first_name, p.last_name].map(s => String(s || '').trim()).filter(Boolean).join(' ')
}

/** ตาราง library_items เก็บ year เป็น พ.ศ. อยู่แล้ว — ห้าม +543 ซ้ำ */
export const CURRENT_BE_YEAR = new Date().getFullYear() + 543
