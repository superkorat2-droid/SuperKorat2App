<script setup>
const props = defineProps({
  layout: { type: String, default: 'card' },
  items:  { type: Array,  default: () => [] },
  title:  { type: String, default: '' },
})

// ── โครงสร้างต่อ layout: ทุกแบบใช้ 1 ใน 4 pattern (card/plain/caption/list) ──
// ต่างกันแค่จำนวนคอลัมน์ (desktop) กับสัดส่วนภาพ — กันโค้ดซ้ำ 9 รอบ
const LAYOUT_META = {
  'card':                    { pattern: 'card',    cols: 'grid-cols-1 sm:grid-cols-2 md:grid-cols-4', aspect: 'aspect-video' },
  'rect-landscape-below':    { pattern: 'card',    cols: 'grid-cols-2 sm:grid-cols-3 md:grid-cols-4', aspect: 'aspect-[4/3]' },

  'square-3':                { pattern: 'plain',   cols: 'grid-cols-1 sm:grid-cols-2 md:grid-cols-3', aspect: 'aspect-square' },
  'square-4':                { pattern: 'plain',   cols: 'grid-cols-2 sm:grid-cols-3 md:grid-cols-4', aspect: 'aspect-square' },
  'rect-landscape':          { pattern: 'plain',   cols: 'grid-cols-1 sm:grid-cols-2 md:grid-cols-3', aspect: 'aspect-[4/3]' },
  'rect-portrait':           { pattern: 'plain',   cols: 'grid-cols-2 sm:grid-cols-3 md:grid-cols-4', aspect: 'aspect-[3/4]' },

  'square-caption':          { pattern: 'caption', cols: 'grid-cols-1 sm:grid-cols-2 md:grid-cols-3', aspect: 'aspect-square' },
  'rect-landscape-caption':  { pattern: 'caption', cols: 'grid-cols-1 sm:grid-cols-2 md:grid-cols-3', aspect: 'aspect-[4/3]' },

  'list':                    { pattern: 'list' },
}
function meta(layout) { return LAYOUT_META[layout] || LAYOUT_META.card }

function itemHref(item) {
  return item.link_type === 'external' ? item.link_url : undefined
}
function itemTo(item) {
  if (item.link_type !== 'internal' || !item.link_url) return undefined
  return item.link_url.startsWith('#') ? item.link_url.slice(1) : item.link_url
}
function itemTag(item) {
  if (!item.link_type || item.link_type === 'none' || !item.link_url) return 'div'
  return item.link_type === 'external' ? 'a' : 'router-link'
}
</script>

<template>
  <div class="font-sarabun">
    <h3 v-if="title" class="text-xl font-extrabold text-slate-800 dark:text-slate-100 mb-4">{{ title }}</h3>

    <!-- Pattern: card (ภาพ + หัวข้อใต้ภาพ เสมอ) -->
    <div v-if="meta(layout).pattern === 'card'" class="grid gap-5" :class="meta(layout).cols">
      <component :is="itemTag(item)" v-for="item in items" :key="item.id"
        :href="itemHref(item)" :to="itemTo(item)"
        :target="item.link_type === 'external' ? '_blank' : undefined"
        :rel="item.link_type === 'external' ? 'noopener' : undefined"
        class="group block bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm overflow-hidden transition-all hover:shadow-lg hover:-translate-y-1">
        <div :class="['bg-slate-100 dark:bg-slate-700 overflow-hidden', meta(layout).aspect]">
          <img v-if="item.image_url" :src="item.image_url" :alt="item.title"
            class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"/>
        </div>
        <div class="p-4">
          <p v-if="item.title" class="font-bold text-slate-800 dark:text-slate-100 group-hover:text-primary transition-colors leading-snug break-words">{{ item.title }}</p>
          <p v-if="item.caption" class="text-xs text-slate-400 mt-1 break-words">{{ item.caption }}</p>
        </div>
      </component>
    </div>

    <!-- Pattern: plain (ภาพล้วน ไม่มีข้อความเลย) -->
    <div v-else-if="meta(layout).pattern === 'plain'" class="grid gap-3" :class="meta(layout).cols">
      <component :is="itemTag(item)" v-for="item in items" :key="item.id"
        :href="itemHref(item)" :to="itemTo(item)"
        :target="item.link_type === 'external' ? '_blank' : undefined"
        :rel="item.link_type === 'external' ? 'noopener' : undefined"
        :class="['group relative block bg-slate-100 dark:bg-slate-700 rounded-2xl overflow-hidden shadow-sm hover:shadow-lg transition-all', meta(layout).aspect]">
        <img v-if="item.image_url" :src="item.image_url" :alt="item.title"
          class="w-full h-full object-cover group-hover:scale-110 transition-transform duration-300"/>
      </component>
    </div>

    <!-- Pattern: caption (ภาพ + ข้อความซ้อนทับ แสดงตอน hover) -->
    <div v-else-if="meta(layout).pattern === 'caption'" class="grid gap-3" :class="meta(layout).cols">
      <component :is="itemTag(item)" v-for="item in items" :key="item.id"
        :href="itemHref(item)" :to="itemTo(item)"
        :target="item.link_type === 'external' ? '_blank' : undefined"
        :rel="item.link_type === 'external' ? 'noopener' : undefined"
        :class="['group relative block bg-slate-100 dark:bg-slate-700 rounded-2xl overflow-hidden shadow-sm hover:shadow-lg transition-all', meta(layout).aspect]">
        <img v-if="item.image_url" :src="item.image_url" :alt="item.title"
          class="w-full h-full object-cover group-hover:scale-110 transition-transform duration-300"/>
        <div v-if="item.title" class="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/70 to-transparent p-3 opacity-0 group-hover:opacity-100 transition-opacity">
          <p class="text-white text-xs font-bold truncate">{{ item.title }}</p>
        </div>
      </component>
    </div>

    <!-- Pattern: list (ภาพสี่เหลี่ยมซ้าย + ข้อความขวา) -->
    <div v-else class="space-y-3">
      <component :is="itemTag(item)" v-for="item in items" :key="item.id"
        :href="itemHref(item)" :to="itemTo(item)"
        :target="item.link_type === 'external' ? '_blank' : undefined"
        :rel="item.link_type === 'external' ? 'noopener' : undefined"
        class="group flex items-center gap-4 bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm p-3 transition-all hover:shadow-md hover:border-primary/30">
        <div class="w-16 h-16 flex-shrink-0 bg-slate-100 dark:bg-slate-700 rounded-xl overflow-hidden">
          <img v-if="item.image_url" :src="item.image_url" :alt="item.title" class="w-full h-full object-cover"/>
        </div>
        <div class="flex-1 min-w-0">
          <p v-if="item.title" class="font-bold text-slate-800 dark:text-slate-100 group-hover:text-primary transition-colors break-words">{{ item.title }}</p>
          <p v-if="item.caption" class="text-xs text-slate-400 mt-0.5 break-words">{{ item.caption }}</p>
        </div>
      </component>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
