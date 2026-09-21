<script setup>
/**
 * CertificateCard — การ์ดปกเกียรติบัตร กดแล้วเปิดลิงก์จริงในแท็บใหม่เลย
 * (ต่างจาก VideoCard ที่เป็น <button> เล่นในหน้าเดิม — นี่คือ <a> ออกนอกเว็บ)
 */
import { ref, watch } from 'vue'
import { supabase } from '../supabase'
import { certCoverSrc, fmtDate } from '../composables/useCertificates'

const props = defineProps({
  item: { type: Object, required: true },
  groupLabel: { type: Function, default: null },
})

const failed = ref(false)
watch(() => props.item?.id, () => { failed.value = false })

// กันนับซ้ำแบบหยาบตอนคลิกซ้ำ/รีเฟรชในแท็บเดียวกัน — ไม่มีตาราง dedup ฝั่ง DB
function onOpen() {
  const key = `co_${props.item.id}`
  if (sessionStorage.getItem(key)) return
  sessionStorage.setItem(key, '1')
  supabase.rpc('increment_certificate_open', { p_id: props.item.id }).then(() => {}, () => {})
}
</script>

<template>
  <a :href="item.link_url" target="_blank" rel="noopener" @click="onOpen"
    class="glass-card glass-card-hover overflow-hidden text-left group block">
    <div class="relative aspect-[4/3] bg-slate-900 overflow-hidden">
      <img v-if="!failed && certCoverSrc(item)" :src="certCoverSrc(item)" :alt="item.title"
        :class="['w-full h-full object-cover group-hover:scale-105 transition-transform duration-300',
                 item.cover_source === 'drive' ? 'object-top' : 'object-center']"
        loading="lazy" @error="failed = true"/>
      <div v-else class="w-full h-full flex items-center justify-center text-white/40 text-3xl">📜</div>
    </div>

    <div class="p-3 space-y-1.5">
      <span v-if="groupLabel && item.group_key"
        class="inline-block text-[10px] font-bold px-2 py-0.5 rounded-full bg-primary/10 text-primary">
        {{ groupLabel(item.group_key) }}
      </span>
      <h3 class="text-sm font-bold text-slate-700 leading-snug line-clamp-2 group-hover:text-primary transition-colors">
        {{ item.title }}
      </h3>
      <div class="flex items-center gap-2 text-[11px] text-slate-400">
        <span class="truncate">{{ item.responsible_names || '' }}</span>
        <span v-if="item.cert_date" class="flex-shrink-0">{{ fmtDate(item.cert_date) }}</span>
        <span class="ml-auto flex-shrink-0">👁 {{ item.open_count || 0 }}</span>
      </div>
    </div>
  </a>
</template>
