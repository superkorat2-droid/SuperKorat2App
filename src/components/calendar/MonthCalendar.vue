<script setup>
import { computed } from 'vue'
import { buildMonthWeeks, toDateKey, WEEKDAY_LABELS, MONTH_LABELS } from '../../composables/useCalendarGrid'
import { TYPE_COLOR } from '../../composables/useNithetEventMeta'

const props = defineProps({
  events: { type: Array, default: () => [] }, // [{ id, type, title, start_date, end_date }]
  year:   { type: Number, required: true },
  month:  { type: Number, required: true }, // 0-indexed
})
const emit = defineEmits(['update:year', 'update:month', 'select-event', 'select-day'])

const MAX_PILLS = 3

const weeks = computed(() => buildMonthWeeks(props.year, props.month))
const todayKey = toDateKey(new Date())

function eventsForDay(dateKey) {
  return props.events.filter(e => e.start_date <= dateKey && dateKey <= e.end_date)
}

function goToday() {
  const now = new Date()
  emit('update:year', now.getFullYear())
  emit('update:month', now.getMonth())
}
function goPrev() {
  const m = props.month - 1
  if (m < 0) { emit('update:year', props.year - 1); emit('update:month', 11) }
  else emit('update:month', m)
}
function goNext() {
  const m = props.month + 1
  if (m > 11) { emit('update:year', props.year + 1); emit('update:month', 0) }
  else emit('update:month', m)
}
</script>

<template>
  <div class="bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700 overflow-hidden">
    <!-- Header -->
    <div class="flex items-center justify-between px-4 py-3 border-b border-slate-100 dark:border-slate-700">
      <button @click="goPrev" type="button" class="w-8 h-8 flex items-center justify-center rounded-lg text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5"/></svg>
      </button>
      <div class="flex items-center gap-3">
        <p class="font-extrabold text-slate-800 dark:text-slate-100">{{ MONTH_LABELS[month] }} {{ year + 543 }}</p>
        <button @click="goToday" type="button" class="px-2.5 py-1 text-xs font-bold bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 rounded-lg hover:bg-slate-200 dark:hover:bg-slate-600 transition-colors">
          วันนี้
        </button>
      </div>
      <button @click="goNext" type="button" class="w-8 h-8 flex items-center justify-center rounded-lg text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5"/></svg>
      </button>
    </div>

    <!-- Weekday row -->
    <div class="grid grid-cols-7 border-b border-slate-100 dark:border-slate-700">
      <div v-for="w in WEEKDAY_LABELS" :key="w" class="text-center text-[11px] font-bold text-slate-400 py-2">{{ w }}</div>
    </div>

    <!-- Weeks -->
    <div class="grid grid-cols-7">
      <template v-for="(week, wi) in weeks" :key="wi">
        <div v-for="cell in week" :key="toDateKey(cell.date)"
          @click="emit('select-day', toDateKey(cell.date))"
          :class="['min-h-[86px] p-1.5 border-b border-r border-slate-100 dark:border-slate-700 cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700/40 transition-colors',
            !cell.inMonth && 'bg-slate-50/50 dark:bg-slate-900/30']">
          <p :class="['text-xs font-bold w-5 h-5 flex items-center justify-center rounded-full mb-1',
            toDateKey(cell.date) === todayKey ? 'bg-primary text-white' : (cell.inMonth ? 'text-slate-600 dark:text-slate-300' : 'text-slate-300 dark:text-slate-600')]">
            {{ cell.date.getDate() }}
          </p>
          <div class="space-y-0.5">
            <button v-for="ev in eventsForDay(toDateKey(cell.date)).slice(0, MAX_PILLS)" :key="ev.id"
              @click.stop="emit('select-event', ev)" type="button"
              :class="['w-full text-left px-1.5 py-0.5 rounded text-[10px] font-bold truncate block', TYPE_COLOR[ev.type]?.bg, TYPE_COLOR[ev.type]?.text]">
              {{ ev.title }}
            </button>
            <p v-if="eventsForDay(toDateKey(cell.date)).length > MAX_PILLS" class="text-[10px] text-slate-400 pl-1.5">
              +{{ eventsForDay(toDateKey(cell.date)).length - MAX_PILLS }} เพิ่มเติม
            </p>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>
