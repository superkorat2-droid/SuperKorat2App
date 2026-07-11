// useMyTasksBadge — จุดแดงแจ้งเตือนงานเอกสารค้างของศึกษานิเทศก์ (นับ assigned/in_progress ของตัวเอง)
import { ref } from 'vue'
import { supabase } from '../supabase'

const pendingCount  = ref(0)
const loadedForUser = ref(null) // user id ที่ fetch ล่าสุด (ป้องกันค่าค้างข้ามบัญชีเมื่อ logout/login ในแท็บเดียวกัน)

export function useMyTasksBadge() {
  const fetchPendingCount = async (force = false) => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { pendingCount.value = 0; loadedForUser.value = null; return }
    if (loadedForUser.value === user.id && !force) return
    const { count } = await supabase
      .from('document_tasks')
      .select('id', { count: 'exact', head: true })
      .eq('assigned_to', user.id)
      .in('status', ['assigned', 'in_progress'])
    pendingCount.value = count || 0
    loadedForUser.value = user.id
  }

  return { pendingCount, fetchPendingCount }
}
