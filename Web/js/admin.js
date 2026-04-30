import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  'https://hsozcqbisfcswfvjepqv.supabase.co',
  'sb_publishable_fLBBTFwj6wNiuYbEiW5Bwg_SFI66TwP'
)

// ── 상태 ──────────────────────────────────────────
let currentUser = null
let currentProfile = null
let editingNewsId = null
let editingPrayerId = null
let editingPopupId = null

// ── 유틸 ──────────────────────────────────────────
function formatDate(iso) {
  const d = new Date(iso)
  return `${d.getFullYear()}.${String(d.getMonth()+1).padStart(2,'0')}.${String(d.getDate()).padStart(2,'0')}`
}

function showLoginScreen() {
  document.getElementById('login-screen').style.display = 'flex'
  document.getElementById('dashboard').style.display = 'none'
}

function showDashboard() {
  document.getElementById('login-screen').style.display = 'none'
  document.getElementById('dashboard').style.display = 'block'
}

function showStep(step) {
  document.getElementById('step-password').style.display = 'none'
  document.getElementById('step-totp').style.display = 'none'
  document.getElementById('step-totp-enroll').style.display = 'none'
  document.getElementById(`step-${step}`).style.display = 'block'
}

function setError(id, msg) {
  document.getElementById(id).textContent = msg
}

// ── 초기화 ──────────────────────────────────────────
async function init() {
  const { data: { session } } = await supabase.auth.getSession()
  if (session) {
    currentUser = session.user
    await loadProfile()

    if (currentProfile?.mfa_required) {
      const { data: aalData } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel()
      if (aalData?.currentLevel !== 'aal2') {
        showLoginScreen()
        const { data: factors } = await supabase.auth.mfa.listFactors()
        const totpFactor = factors?.totp?.find(f => f.status === 'verified')
        if (totpFactor) {
          showStep('totp')
        } else {
          await startTotpEnroll()
        }
        return
      }
    }

    showDashboard()
    setupDashboard()
  } else {
    showLoginScreen()
    showStep('password')
  }
}

// ── 인증: 이메일 + 패스워드 ──────────────────────────
document.getElementById('btn-login').addEventListener('click', async () => {
  const email = document.getElementById('input-email').value.trim()
  const password = document.getElementById('input-password').value
  setError('login-error', '')

  if (!email || !password) { setError('login-error', '이메일과 패스워드를 입력하세요.'); return }

  const btn = document.getElementById('btn-login')
  btn.disabled = true
  btn.textContent = '로그인 중...'

  const { data, error } = await supabase.auth.signInWithPassword({ email, password })

  btn.disabled = false
  btn.textContent = '로그인'

  if (error) { setError('login-error', '이메일 또는 패스워드가 올바르지 않습니다.'); return }

  currentUser = data.user

  // admin_profiles 확인
  const { data: profile } = await supabase
    .from('admin_profiles')
    .select('*')
    .eq('id', currentUser.id)
    .single()

  if (!profile) {
    await supabase.auth.signOut()
    setError('login-error', '관리자 권한이 없습니다. 담당자에게 문의하세요.')
    return
  }

  currentProfile = profile

  if (profile.mfa_required) {
    // TOTP 등록 여부 확인
    const { data: factors } = await supabase.auth.mfa.listFactors()
    const totpFactor = factors?.totp?.find(f => f.status === 'verified')

    if (totpFactor) {
      // 등록된 기기 있음 → TOTP 코드 입력
      showStep('totp')
    } else {
      // 미등록 → QR 코드 등록 화면
      await startTotpEnroll()
    }
  } else {
    await loadProfile()
    showDashboard()
    setupDashboard()
  }
})

// Enter 키 로그인
document.getElementById('input-password').addEventListener('keydown', e => {
  if (e.key === 'Enter') document.getElementById('btn-login').click()
})

// ── TOTP 코드 검증 ──────────────────────────────────
document.getElementById('btn-totp').addEventListener('click', async () => {
  const code = document.getElementById('input-totp').value.trim()
  setError('totp-error', '')

  if (code.length !== 6) { setError('totp-error', '6자리 코드를 입력하세요.'); return }

  const { data: factors } = await supabase.auth.mfa.listFactors()
  const totpFactor = factors?.totp?.find(f => f.status === 'verified')
  if (!totpFactor) { setError('totp-error', '등록된 인증 기기가 없습니다.'); return }

  const { data: challenge } = await supabase.auth.mfa.challenge({ factorId: totpFactor.id })
  const { error } = await supabase.auth.mfa.verify({
    factorId: totpFactor.id,
    challengeId: challenge.id,
    code
  })

  if (error) { setError('totp-error', '코드가 올바르지 않거나 만료되었습니다.'); return }

  showDashboard()
  setupDashboard()
})

document.getElementById('input-totp').addEventListener('keydown', e => {
  if (e.key === 'Enter') document.getElementById('btn-totp').click()
})

// ── TOTP 등록 ──────────────────────────────────────
async function startTotpEnroll() {
  const { data, error } = await supabase.auth.mfa.enroll({ factorType: 'totp', issuer: 'ICHTHYS SOLACE' })
  if (error) { setError('login-error', 'TOTP 등록을 시작할 수 없습니다.'); return }

  // QR 코드 이미지 표시
  const qrContainer = document.getElementById('totp-qr')
  qrContainer.innerHTML = ''
  const img = document.createElement('img')
  img.src = data.totp.qr_code
  img.alt = 'QR Code'
  img.style.cssText = 'width:200px;height:200px;border-radius:8px;border:1px solid #e8e4dc;padding:8px;background:#fff;'
  qrContainer.appendChild(img)
  qrContainer.dataset.factorId = data.id

  showStep('totp-enroll')
}

document.getElementById('btn-enroll').addEventListener('click', async () => {
  const code = document.getElementById('input-enroll-code').value.trim()
  const factorId = document.getElementById('totp-qr').dataset.factorId
  setError('enroll-error', '')

  if (code.length !== 6) { setError('enroll-error', '6자리 코드를 입력하세요.'); return }

  const { data: challenge } = await supabase.auth.mfa.challenge({ factorId })
  const { error } = await supabase.auth.mfa.verify({ factorId, challengeId: challenge.id, code })

  if (error) { setError('enroll-error', '코드가 올바르지 않습니다. 다시 시도하세요.'); return }

  showDashboard()
  setupDashboard()
})

// ── 프로필 로드 ──────────────────────────────────────
async function loadProfile() {
  const { data } = await supabase
    .from('admin_profiles')
    .select('*')
    .eq('id', currentUser.id)
    .single()
  currentProfile = data
}

// ── 로그아웃 ──────────────────────────────────────────
document.getElementById('btn-logout').addEventListener('click', async () => {
  await supabase.auth.signOut()
  localStorage.clear()
  sessionStorage.clear()
  location.href = 'admin.html'
})

// ── 대시보드 설정 ──────────────────────────────────────
function setupDashboard() {
  document.getElementById('header-username').textContent =
    currentProfile?.name || currentUser?.email || ''

  // 슈퍼어드민만 관리자 관리 탭 표시
  if (currentProfile?.role === 'super') {
    document.getElementById('sidebar-admin-section').style.display = 'block'
  }

  // 사이드바 탭 전환
  document.querySelectorAll('.sidebar-btn[data-panel]').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.sidebar-btn').forEach(b => b.classList.remove('active'))
      document.querySelectorAll('.admin-panel').forEach(p => p.classList.remove('active'))
      btn.classList.add('active')
      document.getElementById(`panel-${btn.dataset.panel}`).classList.add('active')

      if (btn.dataset.panel === 'news') loadNews()
      if (btn.dataset.panel === 'prayer') loadPrayer()
      if (btn.dataset.panel === 'popup') loadPopups()
      if (btn.dataset.panel === 'admins') loadAdmins()
    })
  })

  loadNews()
}

// ── 선교지 소식 CRUD ──────────────────────────────────

async function loadNews() {
  const wrap = document.getElementById('news-table-wrap')
  wrap.innerHTML = '<p class="loading-msg">불러오는 중...</p>'

  const { data, error } = await supabase
    .from('news_posts')
    .select('*')
    .order('created_at', { ascending: false })

  if (error) { wrap.innerHTML = '<p class="loading-msg">불러오기 실패</p>'; return }
  if (!data.length) { wrap.innerHTML = '<p class="empty-state">등록된 소식이 없습니다.</p>'; return }

  wrap.innerHTML = `
    <table class="post-table">
      <thead><tr><th>제목</th><th>날짜</th><th>관리</th></tr></thead>
      <tbody>
        ${data.map(p => `
          <tr>
            <td class="post-title-cell"><span class="post-title-text">${p.title}</span></td>
            <td class="post-date">${formatDate(p.created_at)}</td>
            <td>
              <button class="btn-edit" data-id="${p.id}" data-action="edit-news">수정</button>
              <button class="btn-delete" data-id="${p.id}" data-action="delete-news">삭제</button>
            </td>
          </tr>
        `).join('')}
      </tbody>
    </table>`

  wrap.querySelectorAll('[data-action]').forEach(btn => {
    btn.addEventListener('click', async () => {
      if (btn.dataset.action === 'edit-news') {
        const post = data.find(p => p.id == btn.dataset.id)
        openNewsModal(post)
      }
      if (btn.dataset.action === 'delete-news') {
        if (!confirm('이 소식을 삭제하시겠습니까?')) return
        await supabase.from('news_posts').delete().eq('id', btn.dataset.id)
        loadNews()
      }
    })
  })
}

function openNewsModal(post = null) {
  editingNewsId = post?.id || null
  document.getElementById('modal-news-title').textContent = post ? '소식 수정' : '소식 작성'
  document.getElementById('news-input-title').value = post?.title || ''
  document.getElementById('news-input-content').value = post?.content || ''
  document.getElementById('news-input-image').value = post?.image_url || ''
  document.getElementById('news-form-error').textContent = ''
  document.getElementById('modal-news').classList.add('open')
}

document.getElementById('btn-add-news').addEventListener('click', () => openNewsModal())
document.getElementById('modal-news-cancel').addEventListener('click', () => {
  document.getElementById('modal-news').classList.remove('open')
})

document.getElementById('modal-news-save').addEventListener('click', async () => {
  const title = document.getElementById('news-input-title').value.trim()
  const content = document.getElementById('news-input-content').value.trim()
  const image_url = document.getElementById('news-input-image').value.trim() || null
  setError('news-form-error', '')

  if (!title || !content) { setError('news-form-error', '제목과 본문을 입력하세요.'); return }

  const payload = { title, content, image_url }
  let error

  if (editingNewsId) {
    ({ error } = await supabase.from('news_posts').update(payload).eq('id', editingNewsId))
  } else {
    ({ error } = await supabase.from('news_posts').insert(payload))
  }

  if (error) { setError('news-form-error', '저장에 실패했습니다: ' + error.message); return }

  document.getElementById('modal-news').classList.remove('open')
  loadNews()
})

// ── 정기 기도 모임 CRUD ──────────────────────────────

async function loadPrayer() {
  const wrap = document.getElementById('prayer-table-wrap')
  wrap.innerHTML = '<p class="loading-msg">불러오는 중...</p>'

  const { data, error } = await supabase
    .from('prayer_posts')
    .select('*')
    .order('created_at', { ascending: false })

  if (error) { wrap.innerHTML = '<p class="loading-msg">불러오기 실패</p>'; return }
  if (!data.length) { wrap.innerHTML = '<p class="empty-state">등록된 기도 제목이 없습니다.</p>'; return }

  wrap.innerHTML = `
    <table class="post-table">
      <thead><tr><th>제목</th><th>날짜</th><th>관리</th></tr></thead>
      <tbody>
        ${data.map(p => `
          <tr>
            <td class="post-title-cell"><span class="post-title-text">${p.title}</span></td>
            <td class="post-date">${formatDate(p.created_at)}</td>
            <td>
              <button class="btn-edit" data-id="${p.id}" data-action="edit-prayer">수정</button>
              <button class="btn-delete" data-id="${p.id}" data-action="delete-prayer">삭제</button>
            </td>
          </tr>
        `).join('')}
      </tbody>
    </table>`

  wrap.querySelectorAll('[data-action]').forEach(btn => {
    btn.addEventListener('click', async () => {
      if (btn.dataset.action === 'edit-prayer') {
        const post = data.find(p => p.id == btn.dataset.id)
        openPrayerModal(post)
      }
      if (btn.dataset.action === 'delete-prayer') {
        if (!confirm('이 기도 제목을 삭제하시겠습니까?')) return
        await supabase.from('prayer_posts').delete().eq('id', btn.dataset.id)
        loadPrayer()
      }
    })
  })
}

function openPrayerModal(post = null) {
  editingPrayerId = post?.id || null
  document.getElementById('modal-prayer-title').textContent = post ? '기도 제목 수정' : '기도 제목 작성'
  document.getElementById('prayer-input-title').value = post?.title || ''
  document.getElementById('prayer-input-content').value = post?.content || ''
  document.getElementById('prayer-form-error').textContent = ''
  document.getElementById('modal-prayer').classList.add('open')
}

document.getElementById('btn-add-prayer').addEventListener('click', () => openPrayerModal())
document.getElementById('modal-prayer-cancel').addEventListener('click', () => {
  document.getElementById('modal-prayer').classList.remove('open')
})

document.getElementById('modal-prayer-save').addEventListener('click', async () => {
  const title = document.getElementById('prayer-input-title').value.trim()
  const content = document.getElementById('prayer-input-content').value.trim()
  setError('prayer-form-error', '')

  if (!title || !content) { setError('prayer-form-error', '제목과 본문을 입력하세요.'); return }

  const payload = { title, content }
  let error

  if (editingPrayerId) {
    ({ error } = await supabase.from('prayer_posts').update(payload).eq('id', editingPrayerId))
  } else {
    ({ error } = await supabase.from('prayer_posts').insert(payload))
  }

  if (error) { setError('prayer-form-error', '저장에 실패했습니다: ' + error.message); return }

  document.getElementById('modal-prayer').classList.remove('open')
  loadPrayer()
})

// ── 관리자 관리 (슈퍼어드민 전용) ────────────────────────

async function loadAdmins() {
  const wrap = document.getElementById('admins-list-wrap')
  wrap.innerHTML = '<p class="loading-msg">불러오는 중...</p>'

  const { data, error } = await supabase
    .from('admin_profiles')
    .select('*')
    .order('created_at', { ascending: true })

  if (error) { wrap.innerHTML = '<p class="loading-msg">불러오기 실패</p>'; return }

  wrap.innerHTML = `<div class="admin-card-list">
    ${data.map(admin => `
      <div class="admin-card">
        <div class="admin-card-info">
          <div class="admin-avatar">${admin.name?.charAt(0) || '?'}</div>
          <div>
            <div class="admin-name">${admin.name}</div>
            <div class="admin-email">${admin.email || ''}</div>
          </div>
        </div>
        <div class="admin-card-actions">
          <span class="role-badge ${admin.role}">${admin.role === 'super' ? '관리자' : '편집자'}</span>
          <label class="mfa-toggle">
            <span>MFA 필수</span>
            <label class="toggle-switch">
              <input type="checkbox" ${admin.mfa_required ? 'checked' : ''} data-admin-id="${admin.id}" data-action="toggle-mfa" />
              <span class="toggle-slider"></span>
            </label>
          </label>
          ${admin.id !== currentUser.id
            ? `<button class="btn-delete" data-admin-id="${admin.id}" data-admin-name="${admin.name}" data-action="delete-admin">삭제</button>`
            : ''}
        </div>
      </div>
    `).join('')}
  </div>`

  wrap.querySelectorAll('[data-action="toggle-mfa"]').forEach(checkbox => {
    checkbox.addEventListener('change', async () => {
      const { error } = await supabase
        .from('admin_profiles')
        .update({ mfa_required: checkbox.checked })
        .eq('id', checkbox.dataset.adminId)
      if (error) {
        alert('MFA 설정 변경에 실패했습니다.')
        checkbox.checked = !checkbox.checked
      }
    })
  })

  wrap.querySelectorAll('[data-action="delete-admin"]').forEach(btn => {
    btn.addEventListener('click', async () => {
      if (!confirm(`'${btn.dataset.adminName}' 사용자를 삭제하시겠습니까?\n관리자 권한이 제거됩니다.`)) return
      const { error } = await supabase
        .from('admin_profiles')
        .delete()
        .eq('id', btn.dataset.adminId)
      if (error) { alert('삭제 실패: ' + error.message); return }
      loadAdmins()
    })
  })
}

document.getElementById('btn-add-admin').addEventListener('click', () => {
  document.getElementById('admin-input-name').value = ''
  document.getElementById('admin-input-email').value = ''
  document.getElementById('admin-input-password').value = ''
  document.getElementById('admin-input-role').value = 'editor'
  document.getElementById('admin-input-mfa').checked = false
  document.getElementById('admin-form-error').textContent = ''
  document.getElementById('modal-admin').classList.add('open')
})

document.getElementById('modal-admin-cancel').addEventListener('click', () => {
  document.getElementById('modal-admin').classList.remove('open')
})

document.getElementById('modal-admin-save').addEventListener('click', async () => {
  const name = document.getElementById('admin-input-name').value.trim()
  const email = document.getElementById('admin-input-email').value.trim()
  const password = document.getElementById('admin-input-password').value.trim()
  const role = document.getElementById('admin-input-role').value
  const mfa_required = document.getElementById('admin-input-mfa').checked
  setError('admin-form-error', '')

  if (!name || !email || !password) { setError('admin-form-error', '모든 필드를 입력하세요.'); return }
  if (password.length < 8) { setError('admin-form-error', '패스워드는 8자 이상이어야 합니다.'); return }

  const btn = document.getElementById('modal-admin-save')
  btn.disabled = true
  btn.textContent = '처리 중...'

  // 현재 슈퍼어드민 세션 저장 (signUp 후 세션이 신규 유저로 전환되므로)
  const { data: { session: originalSession } } = await supabase.auth.getSession()

  // Supabase Auth 계정 생성
  const { data: signUpData, error: signUpError } = await supabase.auth.signUp({ email, password })

  btn.disabled = false
  btn.textContent = '추가'

  if (signUpError) { setError('admin-form-error', '계정 생성 실패: ' + signUpError.message); return }

  const newUserId = signUpData.user?.id
  if (!newUserId) { setError('admin-form-error', '계정 생성 후 ID를 가져오지 못했습니다.'); return }

  // 슈퍼어드민 세션 복원
  await supabase.auth.setSession({
    access_token: originalSession.access_token,
    refresh_token: originalSession.refresh_token
  })

  // admin_profiles 등록
  const { error: profileError } = await supabase
    .from('admin_profiles')
    .insert({ id: newUserId, name, email, role, mfa_required })

  if (profileError) { setError('admin-form-error', '프로필 등록 실패: ' + profileError.message); return }

  document.getElementById('modal-admin').classList.remove('open')
  loadAdmins()
})

// ── 비밀번호 변경 ──────────────────────────────────────────
document.getElementById('btn-my-account').addEventListener('click', () => {
  document.getElementById('pw-input-new').value = ''
  document.getElementById('pw-input-confirm').value = ''
  document.getElementById('pw-form-error').textContent = ''
  document.getElementById('pw-form-success').textContent = ''
  document.getElementById('modal-password').classList.add('open')
})

document.getElementById('modal-password-cancel').addEventListener('click', () => {
  document.getElementById('modal-password').classList.remove('open')
})

document.getElementById('modal-password-save').addEventListener('click', async () => {
  const newPw = document.getElementById('pw-input-new').value
  const confirm = document.getElementById('pw-input-confirm').value
  document.getElementById('pw-form-error').textContent = ''
  document.getElementById('pw-form-success').textContent = ''

  if (newPw.length < 8) { document.getElementById('pw-form-error').textContent = '비밀번호는 8자 이상이어야 합니다.'; return }
  if (newPw !== confirm) { document.getElementById('pw-form-error').textContent = '비밀번호가 일치하지 않습니다.'; return }

  const { error } = await supabase.auth.updateUser({ password: newPw })

  if (error) { document.getElementById('pw-form-error').textContent = '변경 실패: ' + error.message; return }

  document.getElementById('pw-form-success').textContent = '비밀번호가 변경되었습니다.'
  setTimeout(() => document.getElementById('modal-password').classList.remove('open'), 1500)
})

// ── 팝업 관리 ──────────────────────────────────────────

function getPopupStatus(popup) {
  if (!popup.is_active) return { label: '비활성', cls: 'inactive' }
  const now = Date.now()
  const start = popup.starts_at ? new Date(popup.starts_at).getTime() : 0
  const end = popup.ends_at ? new Date(popup.ends_at).getTime() : Infinity
  if (now < start) return { label: '예약', cls: 'scheduled' }
  if (now > end) return { label: '만료', cls: 'expired' }
  return { label: '게시 중', cls: 'live' }
}

function formatDateRange(starts_at, ends_at) {
  const fmt = iso => {
    if (!iso) return ''
    const d = new Date(iso)
    return `${d.getFullYear()}.${String(d.getMonth()+1).padStart(2,'0')}.${String(d.getDate()).padStart(2,'0')}`
  }
  if (!starts_at && !ends_at) return '상시'
  if (!starts_at) return `~ ${fmt(ends_at)}`
  if (!ends_at) return `${fmt(starts_at)} ~`
  return `${fmt(starts_at)} ~ ${fmt(ends_at)}`
}

function toDatetimeLocal(iso) {
  if (!iso) return ''
  const d = new Date(iso)
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

async function loadPopups() {
  const wrap = document.getElementById('popup-table-wrap')
  wrap.innerHTML = '<p class="loading-msg">불러오는 중...</p>'

  const { data, error } = await supabase
    .from('popups')
    .select('*')
    .order('created_at', { ascending: false })

  if (error) { wrap.innerHTML = '<p class="loading-msg">불러오기 실패</p>'; return }
  if (!data.length) { wrap.innerHTML = '<p class="empty-state">등록된 팝업이 없습니다.</p>'; return }

  const typeLabel = { image: '이미지형', text: '텍스트형', notice: '공지형' }

  wrap.innerHTML = `
    <table class="post-table">
      <thead><tr><th>제목</th><th>유형</th><th>상태</th><th>기간</th><th>관리</th></tr></thead>
      <tbody>
        ${data.map(p => {
          const status = getPopupStatus(p)
          return `
            <tr>
              <td class="post-title-cell"><span class="post-title-text">${p.title}</span></td>
              <td><span class="popup-type-badge ${p.type}">${typeLabel[p.type] || p.type}</span></td>
              <td><span class="popup-status ${status.cls}">${status.label}</span></td>
              <td class="post-date">${formatDateRange(p.starts_at, p.ends_at)}</td>
              <td>
                <button class="btn-edit" data-id="${p.id}" data-action="edit-popup">수정</button>
                <button class="btn-delete" data-id="${p.id}" data-action="delete-popup">삭제</button>
              </td>
            </tr>`
        }).join('')}
      </tbody>
    </table>`

  wrap.querySelectorAll('[data-action]').forEach(btn => {
    btn.addEventListener('click', async () => {
      if (btn.dataset.action === 'edit-popup') {
        const popup = data.find(p => p.id === btn.dataset.id)
        openPopupModal(popup)
      }
      if (btn.dataset.action === 'delete-popup') {
        if (!confirm('이 팝업을 삭제하시겠습니까?')) return
        await supabase.from('popups').delete().eq('id', btn.dataset.id)
        loadPopups()
      }
    })
  })
}

function toggleImageField() {
  const type = document.getElementById('popup-input-type').value
  document.getElementById('popup-image-group').style.display = type === 'image' ? 'block' : 'none'
}

function openPopupModal(popup = null) {
  editingPopupId = popup?.id || null
  document.getElementById('modal-popup-title').textContent = popup ? '팝업 수정' : '팝업 추가'
  document.getElementById('popup-input-type').value = popup?.type || 'text'
  document.getElementById('popup-input-title').value = popup?.title || ''
  document.getElementById('popup-input-content').value = popup?.content || ''
  document.getElementById('popup-input-image').value = popup?.image_url || ''
  document.getElementById('popup-input-link').value = popup?.link_url || ''
  document.getElementById('popup-input-starts').value = toDatetimeLocal(popup?.starts_at)
  document.getElementById('popup-input-ends').value = toDatetimeLocal(popup?.ends_at)
  document.getElementById('popup-input-active').checked = popup ? popup.is_active : true
  document.getElementById('popup-form-error').textContent = ''
  toggleImageField()
  document.getElementById('modal-popup').classList.add('open')
}

document.getElementById('popup-input-type').addEventListener('change', toggleImageField)
document.getElementById('btn-add-popup').addEventListener('click', () => openPopupModal())
document.getElementById('modal-popup-cancel').addEventListener('click', () => {
  document.getElementById('modal-popup').classList.remove('open')
})

document.getElementById('modal-popup-save').addEventListener('click', async () => {
  const type = document.getElementById('popup-input-type').value
  const title = document.getElementById('popup-input-title').value.trim()
  const content = document.getElementById('popup-input-content').value.trim() || null
  const image_url = document.getElementById('popup-input-image').value.trim() || null
  const link_url = document.getElementById('popup-input-link').value.trim() || null
  const starts_raw = document.getElementById('popup-input-starts').value
  const ends_raw = document.getElementById('popup-input-ends').value
  const is_active = document.getElementById('popup-input-active').checked
  setError('popup-form-error', '')

  if (!title) { setError('popup-form-error', '제목을 입력하세요.'); return }
  if (type === 'image' && !image_url) { setError('popup-form-error', '이미지형 팝업은 이미지 URL이 필요합니다.'); return }
  if (link_url && !/^https?:\/\/|^\//.test(link_url)) {
    setError('popup-form-error', '링크 URL은 https:// 또는 /로 시작해야 합니다.'); return
  }

  const starts_at = starts_raw ? new Date(starts_raw).toISOString() : null
  const ends_at = ends_raw ? new Date(ends_raw).toISOString() : null
  if (starts_at && ends_at && new Date(starts_at) >= new Date(ends_at)) {
    setError('popup-form-error', '종료일은 시작일 이후여야 합니다.'); return
  }

  const payload = { type, title, content, image_url, link_url, starts_at, ends_at, is_active, updated_at: new Date().toISOString() }
  let error

  if (editingPopupId) {
    ;({ error } = await supabase.from('popups').update(payload).eq('id', editingPopupId))
  } else {
    payload.created_by = currentUser.id
    ;({ error } = await supabase.from('popups').insert(payload))
  }

  if (error) { setError('popup-form-error', '저장에 실패했습니다: ' + error.message); return }

  document.getElementById('modal-popup').classList.remove('open')
  loadPopups()
})

// ── 모달 외부 클릭으로 닫기 (팝업 모달 제외 — 필드 많아 오클릭 위험) ──────────────────────
document.querySelectorAll('.modal-overlay').forEach(overlay => {
  if (overlay.id === 'modal-popup') return
  overlay.addEventListener('click', e => {
    if (e.target === overlay) overlay.classList.remove('open')
  })
})

// ── 시작 ──────────────────────────────────────────────
init()
