<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import PageHero from '../components/PageHero.vue'
import MonthCalendar from '../components/calendar/MonthCalendar.vue'
import { supabase } from '../supabase'
import { TYPE_LABEL, TYPE_COLOR, formatEventDateRange, formatResponsible } from '../composables/useNithetEventMeta'

const { config, fetchConfig } = useAreaConfig()
onMounted(fetchConfig)
const header = usePageHeader('nithet', { icon: 'eye', title: 'กลุ่มนิเทศ ติดตามและประเมินผล' })

function groupLabel(key) { return config.value?.personnel_groups?.find(g => g.key === key)?.label || key }
function responsibleText(event) {
  return formatResponsible(event.responsible_names || [], event.responsible_group ? groupLabel(event.responsible_group) : '')
}

const events        = ref([])
const loadingEvents = ref(true)
const viewMode      = ref('list')
const currentYear   = ref(new Date().getFullYear())
const currentMonth  = ref(new Date().getMonth())
const selectedEvent = ref(null)

const sortedEvents = computed(() => {
  const today = new Date().toISOString().slice(0, 10)
  return events.value
    .filter(e => e.end_date >= today)
    .sort((a, b) => a.start_date.localeCompare(b.start_date) || (a.start_time || '').localeCompare(b.start_time || ''))
})

function onSelectEvent(ev) { selectedEvent.value = ev }

onMounted(async () => {
  const { data } = await supabase.rpc('get_nithet_events_public')
  events.value = data || []
  loadingEvents.value = false
})
</script>

<template>
  <div class="font-sarabun min-h-[60vh] bg-slate-50 dark:bg-slate-950">
    <PageHero :title="header.title"
      :subtitle="header.subtitle || config?.area_name || 'สำนักงานเขตพื้นที่การศึกษา'"
      :mode="header.mode" :icon="header.icon"
      :media-url="header.mediaUrl" :media-type="header.mediaType" :aspect-ratio="header.aspectRatio"/>

    <!-- แยกจาก hero เสมอ ไม่ว่าจะใช้ไอคอนหรือรูป/วิดีโอ -->
    <div class="max-w-4xl mx-auto px-4 py-8 space-y-5">
      <div class="flex items-center justify-between">
        <h2 class="text-xl font-extrabold text-slate-800 dark:text-slate-100">ปฏิทินนิเทศ</h2>
        <div class="flex gap-1 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 p-1 rounded-xl">
          <button @click="viewMode = 'list'"
            :class="['px-4 py-1.5 text-sm font-bold rounded-lg transition-colors',
              viewMode === 'list' ? 'bg-primary text-white shadow-sm' : 'text-slate-500 dark:text-slate-400 hover:text-slate-700']">
            รายการ
          </button>
          <button @click="viewMode = 'month'"
            :class="['px-4 py-1.5 text-sm font-bold rounded-lg transition-colors',
              viewMode === 'month' ? 'bg-primary text-white shadow-sm' : 'text-slate-500 dark:text-slate-400 hover:text-slate-700']">
            ปฏิทิน
          </button>
        </div>
      </div>

      <!-- Loading -->
      <div v-if="loadingEvents" class="flex justify-center py-16">
        <div class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
      </div>

      <!-- Month view -->
      <MonthCalendar v-else-if="viewMode === 'month'" :events="events" v-model:year="currentYear" v-model:month="currentMonth"
        @select-event="onSelectEvent"/>

      <!-- Empty -->
      <div v-else-if="sortedEvents.length === 0"
        class="text-center py-16 bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700 text-slate-400">
        <svg class="w-12 h-12 mx-auto mb-3 opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5m-9-6h.008v.008H12v-.008z"/>
        </svg>
        <p class="font-medium">ยังไม่มีกำหนดการในขณะนี้</p>
      </div>

      <!-- List view -->
      <div v-else class="space-y-3">
        <button v-for="event in sortedEvents" :key="event.id" @click="selectedEvent = event" type="button"
          class="w-full text-left bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700 shadow-sm p-4 hover:shadow-md transition-shadow">
          <div class="flex flex-wrap items-center gap-2 mb-1.5">
            <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full', TYPE_COLOR[event.type]?.bg, TYPE_COLOR[event.type]?.text]">
              {{ TYPE_LABEL[event.type] }}
            </span>
            <span class="text-xs text-slate-400">{{ formatEventDateRange(event) }}</span>
          </div>
          <h3 class="font-bold text-slate-800 dark:text-slate-100">{{ event.title }}</h3>
          <div class="flex flex-wrap gap-3 mt-1 text-xs text-slate-400">
            <span v-if="event.schools?.length">โรงเรียน: {{ event.schools.map(s => s.name).join(', ') }}</span>
            <span v-if="event.location">สถานที่: {{ event.location }}</span>
            <span v-if="event.responsible_group || event.responsible_names?.length">ผู้รับผิดชอบ: {{ responsibleText(event) }}</span>
          </div>
        </button>
      </div>
    </div>

    <!-- Detail Modal (read-only) -->
    <Teleport to="body">
      <Transition enter-active-class="transition duration-200 ease-out" enter-from-class="opacity-0 scale-95"
        leave-active-class="transition duration-150 ease-in" leave-to-class="opacity-0 scale-95">
        <div v-if="selectedEvent" class="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm"
          @click.self="selectedEvent = null">
          <div class="bg-white dark:bg-slate-900 rounded-3xl shadow-2xl w-full max-w-md overflow-hidden">
            <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 dark:border-slate-800">
              <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full', TYPE_COLOR[selectedEvent.type]?.bg, TYPE_COLOR[selectedEvent.type]?.text]">
                {{ TYPE_LABEL[selectedEvent.type] }}
              </span>
              <button @click="selectedEvent = null"
                class="w-8 h-8 flex items-center justify-center rounded-xl hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-400 transition-colors">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>
            <div class="px-6 py-5 space-y-3">
              <h2 class="text-lg font-extrabold text-slate-900 dark:text-slate-50 leading-snug">{{ selectedEvent.title }}</h2>
              <p v-if="selectedEvent.description" class="text-sm text-slate-600 dark:text-slate-300">{{ selectedEvent.description }}</p>
              <div class="border-t border-slate-100 dark:border-slate-800 pt-3 space-y-2 text-sm text-slate-600 dark:text-slate-300">
                <p>📅 {{ formatEventDateRange(selectedEvent) }}</p>
                <p v-for="s in (selectedEvent.schools || [])" :key="s.id">🏫 {{ s.name }} <span class="text-slate-400">(อ.{{ s.district }})</span></p>
                <p v-if="selectedEvent.location">📍 {{ selectedEvent.location }}</p>
                <p v-if="selectedEvent.responsible_group || selectedEvent.responsible_names?.length">👤 {{ responsibleText(selectedEvent) }}</p>
              </div>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
