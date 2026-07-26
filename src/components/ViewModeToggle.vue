<script setup>
/** ViewModeToggle — สลับมุมมองการ์ด/รายการ ใช้ร่วมกันในหน้าคลังสื่อและหน้าผลงาน */
defineProps({
  modelValue: { type: String, required: true },   // 'card' | 'list'
})
defineEmits(['update:modelValue'])
</script>

<template>
  <div class="flex items-center gap-1 bg-white/70 backdrop-blur border border-white/80 p-1 rounded-xl">
    <button type="button" @click="$emit('update:modelValue', 'card')"
      :title="'มุมมองการ์ด'" :aria-pressed="modelValue === 'card'"
      :class="['flex items-center gap-1.5 px-2.5 py-1.5 text-xs font-bold rounded-lg transition-colors',
        modelValue === 'card' ? 'bg-primary text-white shadow-sm' : 'text-slate-500 hover:text-slate-700']">
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round"
          d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z"/>
      </svg>
      <span class="hidden sm:inline">การ์ด</span>
    </button>
    <button type="button" @click="$emit('update:modelValue', 'list')"
      :title="'มุมมองรายการ'" :aria-pressed="modelValue === 'list'"
      :class="['flex items-center gap-1.5 px-2.5 py-1.5 text-xs font-bold rounded-lg transition-colors',
        modelValue === 'list' ? 'bg-primary text-white shadow-sm' : 'text-slate-500 hover:text-slate-700']">
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round"
          d="M8.25 6.75h12M8.25 12h12m-12 5.25h12M3.75 6.75h.007v.008H3.75V6.75zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zM3.75 12h.007v.008H3.75V12zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zM3.75 17.25h.007v.008H3.75v-.008zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"/>
      </svg>
      <span class="hidden sm:inline">รายการ</span>
    </button>
  </div>
</template>
