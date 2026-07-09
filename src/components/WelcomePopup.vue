<script setup>
import { ref, computed, watch } from 'vue'
import { useAreaConfig } from '../composables/useAreaConfig'

const SESSION_KEY = 'welcome_popup_shown'

const { config, loaded, fetchConfig } = useAreaConfig()
const visible = ref(false)

const imageUrl = computed(() => config.value?.welcome_popup_image_url || '')
const linkUrl  = computed(() => config.value?.welcome_popup_link_url || '')

fetchConfig()

watch(loaded, (isLoaded) => {
  if (!isLoaded) return
  if (!config.value?.welcome_popup_enabled || !imageUrl.value) return
  if (sessionStorage.getItem(SESSION_KEY)) return
  sessionStorage.setItem(SESSION_KEY, '1')
  requestAnimationFrame(() => { visible.value = true })
}, { immediate: true })

function close() { visible.value = false }
</script>

<template>
  <Teleport to="body">
    <Transition enter-active-class="transition duration-300 ease-out" enter-from-class="opacity-0"
      leave-active-class="transition duration-200 ease-in" leave-to-class="opacity-0">
      <div v-if="visible" class="fixed inset-0 z-[200] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm"
        @click.self="close">
        <Transition appear enter-active-class="transition duration-300 ease-out" enter-from-class="opacity-0 scale-90"
          leave-active-class="transition duration-200 ease-in" leave-to-class="opacity-0 scale-90">
          <div v-if="visible" class="relative max-w-lg w-full">
            <button @click="close" aria-label="ปิด"
              class="absolute -top-3 -right-3 w-9 h-9 rounded-full bg-white text-slate-700 shadow-lg flex items-center justify-center hover:bg-slate-100 hover:scale-105 transition-all z-10">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
            <component :is="linkUrl ? 'a' : 'div'" :href="linkUrl || undefined" :target="linkUrl ? '_blank' : undefined"
              :rel="linkUrl ? 'noopener' : undefined"
              class="block rounded-2xl overflow-hidden shadow-2xl bg-white">
              <img :src="imageUrl" alt="" class="w-full h-auto block"/>
            </component>
          </div>
        </Transition>
      </div>
    </Transition>
  </Teleport>
</template>
