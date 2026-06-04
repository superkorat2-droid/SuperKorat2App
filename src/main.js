import { createApp } from 'vue'
import { createPinia } from 'pinia'
import VueApexCharts from 'vue3-apexcharts'
import App from './App.vue'
import router from './router'
import SvgIcon from './components/SvgIcon.vue'
import './style.css'

const app = createApp(App)

app.use(createPinia())
app.use(router)
app.use(VueApexCharts)
app.component('SvgIcon', SvgIcon)

app.mount('#app')
