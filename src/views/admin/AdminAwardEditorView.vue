<script setup>
/**
 * AdminAwardEditorView — ฟอร์มเพิ่ม/แก้ไขผลงานและรางวัล
 *
 * status / created_by ไม่ส่งจาก client — trigger ใน DB กำหนดเองตามบทบาท
 * (ส่งมาก็ถูกเขียนทับ) การอนุมัติทำผ่าน RPC review_award เท่านั้น
 */
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import EntityPicker from '../../components/awards/EntityPicker.vue'
import AwardIconPicker from '../../components/awards/AwardIconPicker.vue'
import {
  OWNER_KINDS, AWARD_LEVELS, AWARD_RANK_GROUPS,
  AWARD_AUTO_APPROVE_ROLES, currentAcademicYear,
} from '../../composables/useAwards'

const route  = useRoute()
const router = useRouter()
const isNew  = computed(() => !route.params.id)
const base = computed(() => route.path.startsWith('/school') ? '/school/awards' : '/dashboard/awards')

const loading = ref(true)
const saving  = ref(false)
const myRole  = ref('')
const canManageAll = ref(false)
const existing = ref(null)

const form = ref({
  owner_kind: 'school',
  owner: { label: '', school_id: null, profile_id: null },
  title: '', award_rank: 'cert_join', award_rank_other: '',
  level: 'area', issuer: '', awarded_date: '', academic_year: currentAcademicYear(),
  is_training: false, training_hours: '',
  is_group: false, members: [],
  icon: 'trophy', link_url: '', note: '',
})

const autoApprove = computed(() => canManageAll.value)

// เปลี่ยนชนิดรางวัลกลับไปที่ไม่ใช่ "อื่นๆ" ให้ล้างข้อความที่พิมพ์เองทิ้ง
watch(() => form.value.award_rank, v => { if (v !== 'other') form.value.award_rank_other = '' })
// ปิดโหมดอบรม/กลุ่ม ให้ล้างข้อมูลส่วนนั้น ไม่ให้ค้างไปตอนบันทึก
watch(() => form.value.is_training, v => { if (!v) form.value.training_hours = '' })
watch(() => form.value.is_group,    v => { if (!v) form.value.members = [] })

onMounted(async () => {
  const { data: { user } } = await supabase.auth.getUser()
  if (user?.id) {
    const { data: p } = await supabase.from('profiles')
      .select('role, can_manage_awards, school_id, school_name').eq('id', user.id).single()
    myRole.value = p?.role || ''
    canManageAll.value = AWARD_AUTO_APPROVE_ROLES.includes(p?.role) || p?.can_manage_awards === true
    // โรงเรียนกรอกของตัวเอง — เติมให้เลย ไม่ต้องพิมพ์ซ้ำ
    if (isNew.value && p?.role === 'school' && p?.school_id) {
      form.value.owner_kind = 'school'
      form.value.owner = { label: p.school_name || '', school_id: p.school_id, profile_id: null }
    }
  }

  if (!isNew.value) {
    const { data } = await supabase.from('awards').select('*').eq('id', route.params.id).single()
    if (!data) { router.push(base.value); return }
    existing.value = data
    form.value = {
      owner_kind: data.owner_kind,
      owner: { label: data.owner_label || '', school_id: data.school_id, profile_id: data.profile_id },
      title: data.title, award_rank: data.award_rank, award_rank_other: data.award_rank_other || '',
      level: data.level, issuer: data.issuer || '',
      awarded_date: data.awarded_date || '', academic_year: data.academic_year || '',
      is_training: data.is_training, training_hours: data.training_hours || '',
      is_group: data.is_group, members: [...(data.members || [])],
      icon: data.icon || 'trophy', link_url: data.link_url || '', note: data.note || '',
    }
  }
  loading.value = false
})

function addMember() { form.value.members.push({ name: '', org: '', profile_id: null }) }
function removeMember(i) { form.value.members.splice(i, 1) }

async function save() {
  if (!form.value.title.trim())
    return Swal.fire({ icon: 'warning', title: 'กรุณากรอกชื่อผลงาน/รางวัล' })
  if (!form.value.owner.label.trim())
    return Swal.fire({ icon: 'warning', title: 'กรุณาระบุเจ้าของรางวัล' })
  if (form.value.award_rank === 'other' && !form.value.award_rank_other.trim())
    return Swal.fire({ icon: 'warning', title: 'กรุณาระบุชื่อรางวัล' })
  if (form.value.link_url.trim() && !/^https?:\/\//i.test(form.value.link_url.trim()))
    return Swal.fire({ icon: 'warning', title: 'ลิงก์ต้องขึ้นต้นด้วย http:// หรือ https://' })

  saving.value = true
  const payload = {
    owner_kind: form.value.owner_kind,
    owner_label: form.value.owner.label.trim(),
    school_id:  form.value.owner.school_id,
    profile_id: form.value.owner.profile_id,
    title: form.value.title.trim(),
    award_rank: form.value.award_rank,
    award_rank_other: form.value.award_rank_other.trim(),
    level: form.value.level,
    issuer: form.value.issuer.trim(),
    awarded_date: form.value.awarded_date || null,
    academic_year: form.value.academic_year.trim(),
    is_training: form.value.is_training,
    training_hours: form.value.is_training ? Number(form.value.training_hours || 0) : 0,
    is_group: form.value.is_group,
    members: form.value.is_group
      ? form.value.members.filter(m => (m.name || '').trim()).map(m => ({ name: m.name.trim(), org: (m.org || '').trim(), profile_id: m.profile_id || null }))
      : [],
    icon: form.value.icon,
    link_url: form.value.link_url.trim(),
    note: form.value.note.trim(),
  }

  const { error } = isNew.value
    ? await supabase.from('awards').insert(payload)
    : await supabase.from('awards').update(payload).eq('id', route.params.id)
  saving.value = false
  if (error) return Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message })

  await Swal.fire({
    icon: 'success', title: 'บันทึกแล้ว',
    text: isNew.value && !autoApprove.value ? 'รายการถูกส่งเข้าคิวรออนุมัติแล้ว' : '',
    timer: isNew.value && !autoApprove.value ? 2200 : 900, showConfirmButton: false,
  })
  router.push(base.value)
}

const inputCls = 'w-full px-3 py-2 rounded-xl border border-slate-200 text-sm focus:outline-none focus:border-primary'
</script>

<template>
  <div class="font-sarabun space-y-5">
    <div class="flex items-center justify-between gap-3">
      <h1 class="text-2xl font-extrabold text-slate-800">{{ isNew ? 'เพิ่มรางวัล' : 'แก้ไขรางวัล' }}</h1>
      <button @click="router.push(base)" class="px-4 py-2 rounded-2xl text-sm font-bold bg-slate-100 text-slate-600 hover:bg-slate-200 transition-colors">← กลับ</button>
    </div>

    <div v-if="loading" class="text-center py-16 text-slate-400">กำลังโหลด…</div>

    <template v-else>
      <div v-if="isNew && !autoApprove" class="glass-tile px-4 py-3 text-sm text-amber-700 bg-amber-50/60">
        รายการที่คุณบันทึกจะเข้าคิวรอศึกษานิเทศก์ตรวจสอบก่อนแสดงบนเว็บ
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-5">
        <!-- ซ้าย -->
        <div class="lg:col-span-2 space-y-5">
          <div class="glass-card p-5 space-y-3">
            <span class="block font-bold text-slate-700 text-sm">1. เจ้าของรางวัล</span>
            <div>
              <label class="text-[11px] font-bold text-slate-500">ประเภท</label>
              <div class="grid grid-cols-2 sm:grid-cols-3 gap-1.5 mt-1">
                <button v-for="k in OWNER_KINDS" :key="k.value" type="button" @click="form.owner_kind = k.value"
                  :class="['px-2 py-2 rounded-xl text-xs font-bold border-2 transition-all',
                    form.owner_kind === k.value ? 'border-primary bg-primary text-white' : 'border-slate-200 text-slate-600 hover:border-primary/50']">
                  {{ k.icon }} {{ k.label }}
                </button>
              </div>
            </div>
            <div>
              <label class="text-[11px] font-bold text-slate-500">ชื่อเจ้าของรางวัล *</label>
              <EntityPicker v-model="form.owner" :kind="form.owner_kind"
                :placeholder="form.owner_kind === 'area' ? 'เช่น สพป.นครราชสีมา เขต 2' : 'พิมพ์เพื่อค้นหา หรือพิมพ์ชื่อเอง'"/>
            </div>
          </div>

          <div class="glass-card p-5 space-y-3">
            <span class="block font-bold text-slate-700 text-sm">2. ข้อมูลรางวัล</span>
            <div>
              <label class="text-[11px] font-bold text-slate-500">ชื่อผลงาน/รางวัล *</label>
              <input v-model="form.title" :class="inputCls" placeholder="เช่น การแข่งขันโครงงานวิทยาศาสตร์ ระดับ ป.4-6"/>
            </div>
            <div class="grid sm:grid-cols-2 gap-3">
              <div>
                <label class="text-[11px] font-bold text-slate-500">ชื่อรางวัลที่ได้รับ *</label>
                <select v-model="form.award_rank" :class="[inputCls, 'bg-white']">
                  <optgroup v-for="g in AWARD_RANK_GROUPS" :key="g.label" :label="g.label">
                    <option v-for="r in g.items" :key="r.value" :value="r.value">{{ r.label }}</option>
                  </optgroup>
                </select>
              </div>
              <div>
                <label class="text-[11px] font-bold text-slate-500">ระดับรางวัล</label>
                <select v-model="form.level" :class="[inputCls, 'bg-white']">
                  <option v-for="l in AWARD_LEVELS" :key="l.value" :value="l.value">{{ l.label }}</option>
                </select>
              </div>
            </div>
            <div v-if="form.award_rank === 'other'">
              <label class="text-[11px] font-bold text-slate-500">ระบุชื่อรางวัล *</label>
              <input v-model="form.award_rank_other" :class="inputCls" placeholder="พิมพ์ชื่อรางวัลตามที่ปรากฏในเกียรติบัตร"/>
            </div>
            <div class="grid sm:grid-cols-3 gap-3">
              <div class="sm:col-span-2">
                <label class="text-[11px] font-bold text-slate-500">หน่วยงานที่มอบ</label>
                <input v-model="form.issuer" :class="inputCls" placeholder="เช่น สพฐ. / สพป.นม.2 / มหาวิทยาลัย…"/>
              </div>
              <div>
                <label class="text-[11px] font-bold text-slate-500">ปีการศึกษา</label>
                <input v-model="form.academic_year" :class="inputCls" placeholder="2569"/>
              </div>
            </div>
            <div>
              <label class="text-[11px] font-bold text-slate-500">วันที่ได้รับ</label>
              <input v-model="form.awarded_date" type="date" :class="inputCls"/>
            </div>
          </div>

          <!-- อบรม -->
          <div class="glass-card p-5 space-y-3">
            <label class="flex items-center gap-2 cursor-pointer select-none">
              <input type="checkbox" v-model="form.is_training" class="w-4 h-4 rounded accent-[var(--color-primary)]"/>
              <span class="font-bold text-slate-700 text-sm">เป็นการอบรม/พัฒนาตนเอง</span>
            </label>
            <div v-if="form.is_training">
              <label class="text-[11px] font-bold text-slate-500">จำนวนชั่วโมงการอบรม</label>
              <input v-model="form.training_hours" type="number" min="0" step="0.5" :class="[inputCls, 'max-w-[180px]']" placeholder="เช่น 12"/>
              <span class="block text-[10px] text-slate-400 mt-1">ระบบจะรวมชั่วโมงให้อัตโนมัติในแดชบอร์ดและรายงาน</span>
            </div>
          </div>

          <!-- กลุ่ม -->
          <div class="glass-card p-5 space-y-3">
            <label class="flex items-center gap-2 cursor-pointer select-none">
              <input type="checkbox" v-model="form.is_group" class="w-4 h-4 rounded accent-[var(--color-primary)]"/>
              <span class="font-bold text-slate-700 text-sm">เป็นผลงานกลุ่ม/ทีม</span>
            </label>
            <template v-if="form.is_group">
              <span class="block text-[11px] text-slate-400">
                ใส่รายชื่อสมาชิกทุกคน — ช่องด้านบน "เจ้าของรางวัล" ใช้เป็นชื่อทีมหรือหัวหน้าทีม
              </span>
              <div v-for="(m, i) in form.members" :key="i" class="flex gap-2 items-start">
                <input v-model="m.name" :class="inputCls" placeholder="ชื่อ-นามสกุล"/>
                <input v-model="m.org" :class="[inputCls, 'max-w-[200px]']" placeholder="สังกัด (ถ้ามี)"/>
                <button type="button" @click="removeMember(i)"
                  class="px-3 py-2 text-xs font-bold text-red-500 bg-red-50 rounded-xl hover:bg-red-100 flex-shrink-0">ลบ</button>
              </div>
              <button type="button" @click="addMember"
                class="px-3 py-1.5 text-xs font-bold text-primary bg-primary/10 rounded-xl hover:bg-primary/20">+ เพิ่มสมาชิก</button>
            </template>
          </div>
        </div>

        <!-- ขวา -->
        <div class="space-y-5">
          <div class="glass-card p-5 space-y-3">
            <span class="block font-bold text-slate-700 text-sm">ไอคอนที่จะแสดง</span>
            <AwardIconPicker v-model="form.icon"/>
          </div>

          <div class="glass-card p-5 space-y-3">
            <span class="block font-bold text-slate-700 text-sm">ลิงก์ผลงาน / เกียรติบัตร</span>
            <input v-model="form.link_url" :class="[inputCls, 'font-mono']" placeholder="https://drive.google.com/…"/>
            <span class="block text-[10px] text-slate-400">
              แนะนำให้ใช้ลิงก์ Google Drive และตั้งการแชร์เป็น <b>“ทุกคนที่มีลิงก์”</b>
              ไม่งั้นคนอื่นจะเปิดไม่ได้ · ชื่อรางวัลในหน้ารายการจะกลายเป็นลิงก์กดเปิดได้ทันที
            </span>
          </div>

          <div class="glass-card p-5 space-y-2">
            <label class="text-[11px] font-bold text-slate-500">หมายเหตุ</label>
            <textarea v-model="form.note" rows="3" :class="[inputCls, 'resize-none']" placeholder="ข้อมูลเพิ่มเติม (ถ้ามี)"/>
          </div>

          <button @click="save" :disabled="saving"
            class="w-full py-3 rounded-2xl bg-primary text-white font-bold shadow-md hover:-translate-y-0.5 transition-all disabled:opacity-50">
            {{ saving ? 'กำลังบันทึก…' : (isNew ? 'บันทึกรางวัล' : 'บันทึกการแก้ไข') }}
          </button>
        </div>
      </div>
    </template>
  </div>
</template>
