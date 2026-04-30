import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  'https://hsozcqbisfcswfvjepqv.supabase.co',
  'sb_publishable_fLBBTFwj6wNiuYbEiW5Bwg_SFI66TwP'
)

const HIDE_PREFIX = 'popup_hide_'
const MAX_SHOW = 2

function todayStr() {
  const d = new Date()
  return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`
}

function isHiddenToday(id) {
  return localStorage.getItem(HIDE_PREFIX + id) === todayStr()
}

function hideToday(id) {
  localStorage.setItem(HIDE_PREFIX + id, todayStr())
}

function injectStyles() {
  if (document.getElementById('popup-styles')) return
  const s = document.createElement('style')
  s.id = 'popup-styles'
  s.textContent = `
    #popup-root {
      position: fixed;
      inset: 0;
      z-index: 9000;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
      background: rgba(0,0,0,0.52);
    }
    .popup-group {
      display: flex;
      gap: 16px;
      align-items: flex-start;
      max-width: 880px;
      width: 100%;
      justify-content: center;
    }
    .popup-card {
      background: #fff;
      border-radius: 12px;
      overflow: hidden;
      width: 100%;
      max-width: 420px;
      box-shadow: 0 8px 32px rgba(0,0,0,0.22);
      position: relative;
      font-family: 'Noto Sans KR', sans-serif;
    }
    .popup-close {
      position: absolute;
      top: 10px;
      right: 12px;
      background: rgba(0,0,0,0.38);
      color: #fff;
      border: none;
      border-radius: 50%;
      width: 28px;
      height: 28px;
      font-size: 14px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 1;
      line-height: 1;
    }
    .popup-close:hover { background: rgba(0,0,0,0.6); }
    .popup-img {
      width: 100%;
      max-height: 320px;
      object-fit: contain;
      display: block;
      background: #faf8f5;
    }
    .popup-notice-header {
      background: #4a5240;
      color: #fff;
      padding: 13px 20px;
      font-family: 'Noto Serif KR', serif;
      font-size: 12px;
      letter-spacing: 0.08em;
      font-weight: 600;
    }
    .popup-body {
      padding: 22px 24px 18px;
    }
    .type-image .popup-body { padding: 14px 20px 18px; }
    .popup-title {
      font-family: 'Noto Serif KR', serif;
      font-size: 16px;
      font-weight: 600;
      color: #1a1a1a;
      margin-bottom: 10px;
      line-height: 1.45;
    }
    .popup-content {
      font-size: 13px;
      color: #555;
      line-height: 1.75;
      white-space: pre-wrap;
    }
    .popup-link-btn {
      display: inline-block;
      margin-top: 16px;
      padding: 8px 18px;
      background: #4a5240;
      color: #fff;
      border-radius: 6px;
      font-size: 13px;
      text-decoration: none;
      font-family: 'Noto Sans KR', sans-serif;
    }
    .popup-link-btn:hover { background: #3a4132; }
    .popup-footer {
      border-top: 1px solid #f0ece4;
      padding: 10px 20px;
      display: flex;
      justify-content: flex-end;
    }
    .popup-hide-btn {
      background: none;
      border: none;
      font-size: 12px;
      color: #bbb;
      cursor: pointer;
      font-family: inherit;
      padding: 4px 0;
    }
    .popup-hide-btn:hover { color: #888; text-decoration: underline; }
    @media (max-width: 768px) {
      .popup-group { flex-direction: column; align-items: center; }
      .popup-card { max-width: 100%; }
    }
  `
  document.head.appendChild(s)
}

function removePopup(id) {
  const card = document.querySelector(`.popup-card[data-popup-id="${id}"]`)
  if (card) card.remove()
  const root = document.getElementById('popup-root')
  if (root && !root.querySelector('.popup-card')) root.remove()
}

function buildCard(popup) {
  const card = document.createElement('div')
  card.className = `popup-card type-${popup.type}`
  card.dataset.popupId = popup.id

  const closeBtn = document.createElement('button')
  closeBtn.className = 'popup-close'
  closeBtn.innerHTML = '✕'
  closeBtn.setAttribute('aria-label', '닫기')
  closeBtn.addEventListener('click', () => removePopup(popup.id))
  card.appendChild(closeBtn)

  if (popup.type === 'image' && popup.image_url) {
    const img = document.createElement('img')
    img.className = 'popup-img'
    img.src = popup.image_url
    img.alt = popup.title
    img.onerror = () => img.style.display = 'none'
    card.appendChild(img)
  }

  if (popup.type === 'notice') {
    const header = document.createElement('div')
    header.className = 'popup-notice-header'
    header.textContent = '공지사항'
    card.appendChild(header)
  }

  const body = document.createElement('div')
  body.className = 'popup-body'

  const titleEl = document.createElement('div')
  titleEl.className = 'popup-title'
  titleEl.textContent = popup.title
  body.appendChild(titleEl)

  if (popup.content) {
    const contentEl = document.createElement('div')
    contentEl.className = 'popup-content'
    contentEl.textContent = popup.content
    body.appendChild(contentEl)
  }

  if (popup.link_url) {
    const linkBtn = document.createElement('a')
    linkBtn.className = 'popup-link-btn'
    linkBtn.href = popup.link_url
    linkBtn.target = '_blank'
    linkBtn.rel = 'noopener noreferrer'
    linkBtn.textContent = '자세히 보기'
    body.appendChild(linkBtn)
  }

  card.appendChild(body)

  const footer = document.createElement('div')
  footer.className = 'popup-footer'
  const hideBtn = document.createElement('button')
  hideBtn.className = 'popup-hide-btn'
  hideBtn.textContent = '오늘 하루 보지 않기'
  hideBtn.addEventListener('click', () => {
    hideToday(popup.id)
    removePopup(popup.id)
  })
  footer.appendChild(hideBtn)
  card.appendChild(footer)

  return card
}

async function init() {
  const { data, error } = await supabase
    .from('popups')
    .select('*')
    .eq('is_active', true)
    .order('created_at', { ascending: false })
    .limit(20)

  if (error || !data?.length) return

  const now = Date.now()
  const visible = data
    .filter(p => {
      const start = p.starts_at ? new Date(p.starts_at).getTime() : 0
      const end = p.ends_at ? new Date(p.ends_at).getTime() : Infinity
      return now >= start && now <= end
    })
    .filter(p => !isHiddenToday(p.id))
    .slice(0, MAX_SHOW)

  if (!visible.length) return

  injectStyles()

  const root = document.createElement('div')
  root.id = 'popup-root'
  root.addEventListener('click', e => {
    if (e.target === root) root.remove()
  })

  const group = document.createElement('div')
  group.className = 'popup-group'
  visible.forEach(p => group.appendChild(buildCard(p)))
  root.appendChild(group)
  document.body.appendChild(root)
}

init()
