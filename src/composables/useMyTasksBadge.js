// useMyTasksBadge — จุดแดงแจ้งเตือนงานเอกสารค้างของศึกษานิเทศก์ (นับ assigned/in_progress ของตัวเอง)
import { ref } from 'vue'
import { supabase } from '../supabase'

const pendingCount = ref(0)
const loaded       = ref(false)

export function useMyTasksBadge() {
  const fetchPendingCount = async (force = false) => {
    if (loaded.value && !force) return
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { loaded.value = true; return }
    const { count } = await supabase
      .from('document_tasks')
      .select('id', { count: 'exact', head: true })
      .eq('assigned_to', user.id)
      .in('status', ['assigned', 'in_progress'])
    pendingCount.value = count || 0
    loaded.value = true
  }

  return { pendingCount, fetchPendingCount }
}
