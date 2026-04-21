import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  'https://hsozcqbisfcswfvjepqv.supabase.co',
  'sb_publishable_fLBBTFwj6wNiuYbEiW5Bwg_SFI66TwP'
)

function formatDate(iso) {
  const d = new Date(iso)
  return `${d.getFullYear()}.${String(d.getMonth()+1).padStart(2,'0')}.${String(d.getDate()).padStart(2,'0')}`
}

async function loadNews() {
  const container = document.getElementById('news-list')
  const { data, error } = await supabase
    .from('news_posts')
    .select('*')
    .order('created_at', { ascending: false })

  if (error || !data || !data.length) {
    container.innerHTML = '<p class="board-empty">등록된 소식이 없습니다.</p>'
    return
  }

  container.innerHTML = data.map(post => `
    <div class="board-card">
      ${post.image_url
        ? `<div class="board-card-img" style="background-image:url('${post.image_url}')"></div>`
        : ''}
      <div class="board-card-body">
        <p class="board-date">${formatDate(post.created_at)}</p>
        <h3>${post.title}</h3>
        <p>${post.content}</p>
      </div>
    </div>
  `).join('')
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

loadNews()
loadPrayer()
