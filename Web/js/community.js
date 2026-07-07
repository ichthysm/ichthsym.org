import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { marked } from 'https://esm.sh/marked@12'

const supabase = createClient(
  'https://hsozcqbisfcswfvjepqv.supabase.co',
  'sb_publishable_fLBBTFwj6wNiuYbEiW5Bwg_SFI66TwP'
)

function formatDate(iso) {
  const d = new Date(iso)
  return `${d.getFullYear()}.${String(d.getMonth()+1).padStart(2,'0')}.${String(d.getDate()).padStart(2,'0')}`
}

const NEWS_PAGE_SIZE = 4
let newsOffset = 0
let newsExhausted = false

function renderNewsCards(posts) {
  const container = document.getElementById('news-list')
  const cardCount = container.querySelectorAll('.board-card').length

  posts.forEach((post, j) => {
    const i = cardCount + j
    let imgs = []
    if (post.image_url) {
      try { imgs = JSON.parse(post.image_url) } catch { imgs = [post.image_url] }
      if (!Array.isArray(imgs)) imgs = [imgs]
    }
    const imgStrip = imgs.length
      ? `<div class="board-card-imgs">${imgs.map(u => `<img src="${u}" alt="" loading="lazy" />`).join('')}</div>`
      : ''
    const card = document.createElement('div')
    card.className = 'board-card'
    card.innerHTML = `
      ${imgStrip}
      <div class="board-card-body">
        <p class="board-date">${formatDate(post.created_at)}</p>
        <h3>${post.title}</h3>
        <div class="board-card-content" data-id="${i}">${marked.parse(post.content || '')}</div>
        <button class="board-more-btn" data-target="${i}">더보기 ▾</button>
      </div>`
    card.querySelector('.board-more-btn').addEventListener('click', function () {
      const content = card.querySelector(`.board-card-content[data-id="${this.dataset.target}"]`)
      content.classList.toggle('expanded')
      this.textContent = content.classList.contains('expanded') ? '접기 ▴' : '더보기 ▾'
    })
    container.appendChild(card)
  })
}

async function loadNews(initial = false) {
  const container = document.getElementById('news-list')
  const loadMoreBtn = document.getElementById('news-load-more')

  if (initial) {
    container.innerHTML = ''
    newsOffset = 0
    newsExhausted = false
  }

  const { data, error } = await supabase
    .from('news_posts')
    .select('*')
    .order('created_at', { ascending: false })
    .range(newsOffset, newsOffset + NEWS_PAGE_SIZE - 1)

  if (error) {
    if (initial) container.innerHTML = '<p class="board-empty">소식을 불러오지 못했습니다.</p>'
    return
  }

  if (initial && (!data || !data.length)) {
    container.innerHTML = '<p class="board-empty">등록된 소식이 없습니다.</p>'
    if (loadMoreBtn) loadMoreBtn.style.display = 'none'
    return
  }

  if (data && data.length) {
    renderNewsCards(data)
    newsOffset += data.length
  }

  if (!data || data.length < NEWS_PAGE_SIZE) {
    newsExhausted = true
    if (loadMoreBtn) loadMoreBtn.style.display = 'none'
  } else {
    if (loadMoreBtn) loadMoreBtn.style.display = 'block'
  }
}

async function loadPrayer() {
  const container = document.getElementById('prayer-list')
  const { data, error } = await supabase
    .from('prayer_posts')
    .select('*')
    .order('created_at', { ascending: false })

  if (error || !data || !data.length) {
    container.innerHTML = '<p class="board-empty">등록된 기도 제목이 없습니다.</p>'
    return
  }

  container.innerHTML = data.map(post => `
    <div class="prayer-item">
      <div class="prayer-item-header">
        <h3>${post.title}</h3>
        <span class="board-date">${formatDate(post.created_at)}</span>
      </div>
      <p>${post.content}</p>
    </div>
  `).join('')
}

loadNews(true)
loadPrayer()

document.getElementById('news-load-more')?.addEventListener('click', () => loadNews())
