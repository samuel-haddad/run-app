'use client'

import { useState, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import styles from './planejamento.module.css'

type Treino = {
  id: string
  dia_numero: number | null
  dia_semana: string | null
  data_treino: string
  prioridade_1: string | null
  prioridade_2: string | null
  terreno: string | null
  duracao_total: string | null
  ciclos: { id: string; nome: string } | null
  registros: { id: string; concluido_em: string }[] | null
}

function formatDate(dateStr: string) {
  const d = new Date(dateStr + 'T12:00:00')
  return d.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' })
}

function isToday(dateStr: string) {
  const today = new Date()
  const d = new Date(dateStr + 'T12:00:00')
  return (
    d.getDate() === today.getDate() &&
    d.getMonth() === today.getMonth() &&
    d.getFullYear() === today.getFullYear()
  )
}

function isConcluido(treino: Treino) {
  return !!treino.registros && treino.registros.length > 0
}

export function PlanejamentoClient({ treinos }: { treinos: Treino[] }) {
  const router = useRouter()
  const supabase = createClient()
  const [editMode, setEditMode] = useState(false)
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [swipedId, setSwipedId] = useState<string | null>(null)
  const [deleteTarget, setDeleteTarget] = useState<string[] | null>(null)
  const [deleting, setDeleting] = useState(false)
  const touchStartX = useRef<number>(0)

  const today = treinos.find((t) => isToday(t.data_treino))

  function toggleEditMode() {
    setEditMode((v) => !v)
    setSelected(new Set())
    setSwipedId(null)
  }

  function toggleSelect(id: string) {
    setSelected((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  function selectAll() {
    if (selected.size === treinos.length) setSelected(new Set())
    else setSelected(new Set(treinos.map((t) => t.id)))
  }

  async function confirmDelete() {
    if (!deleteTarget) return
    setDeleting(true)
    await supabase.from('treinos').delete().in('id', deleteTarget)
    setDeleteTarget(null)
    setDeleting(false)
    setSelected(new Set())
    setEditMode(false)
    router.refresh()
  }

  function handleCardClick(treino: Treino) {
    if (editMode) {
      toggleSelect(treino.id)
      return
    }
    if (swipedId === treino.id) {
      setSwipedId(null)
      return
    }
    router.push(`/treino/${treino.id}`)
  }

  function handleTouchStart(e: React.TouchEvent, id: string) {
    if (editMode) return
    touchStartX.current = e.touches[0].clientX
    // Fechar outros swipes
    if (swipedId !== id) setSwipedId(null)
  }

  function handleTouchEnd(e: React.TouchEvent, id: string) {
    if (editMode) return
    const diff = touchStartX.current - e.changedTouches[0].clientX
    if (diff > 50) setSwipedId(id)
    else if (diff < -20) setSwipedId(null)
  }

  const selectedCount = selected.size

  return (
    <div className="app-container">
      {/* Header */}
      <header className="page-header">
        <div className="page-header-content">
          <span className="page-subtitle">
            {new Date().toLocaleDateString('pt-BR', { weekday: 'long', day: 'numeric', month: 'long' })}
          </span>
          <h1 className="page-title">Planejamento</h1>
        </div>
        <div className={styles.headerActions}>
          {editMode && (
            <button className="btn btn-ghost btn-sm" onClick={selectAll} id="btn-select-all">
              {selected.size === treinos.length ? 'Nenhum' : 'Tudo'}
            </button>
          )}
          <button
            className={`btn btn-ghost btn-sm${editMode ? ' ' + styles.editActive : ''}`}
            onClick={toggleEditMode}
            id="btn-edit-toggle"
          >
            {editMode ? 'Cancelar' : 'Editar'}
          </button>
        </div>
      </header>

      {/* Hoje em destaque */}
      {today && !editMode && (
        <div className={styles.todayBanner}>
          <span className="ciclo-tag">{today.ciclos?.nome ?? 'Ciclo'}</span>
          <p className={styles.todayLabel}>Treino de hoje</p>
          <p className={styles.todayTitle}>{today.prioridade_1}</p>
          {today.prioridade_2 && (
            <p className={styles.todayFocus}>{today.prioridade_2}</p>
          )}
          <button
            className={`btn btn-primary ${styles.todayBtn}`}
            onClick={() => router.push(`/treino/${today.id}`)}
            id="btn-today-treino"
          >
            Ver treino de hoje
            <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2.5">
              <polyline points="9 18 15 12 9 6" />
            </svg>
          </button>
        </div>
      )}

      {/* Lista */}
      {treinos.length === 0 ? (
        <div className="empty-state">
          <svg className="empty-state-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
            <rect x="3" y="4" width="18" height="18" rx="2" />
            <line x1="3" y1="10" x2="21" y2="10" />
          </svg>
          <p className="empty-state-title">Nenhum treino importado</p>
          <p className="empty-state-desc">Vá em Upload para importar seu plano de treino.</p>
        </div>
      ) : (
        <div className={styles.weekList}>
          {treinos.map((treino) => {
            const done = isConcluido(treino)
            const hoje = isToday(treino.data_treino)
            const swiped = swipedId === treino.id
            const sel = selected.has(treino.id)

            return (
              <div
                key={treino.id}
                className={`${styles.swipeContainer}${editMode ? ' ' + styles.editModeContainer : ''}${sel ? ' ' + styles.selectedContainer : ''}`}
                onTouchStart={(e) => handleTouchStart(e, treino.id)}
                onTouchEnd={(e) => handleTouchEnd(e, treino.id)}
              >
                {/* Seleção (edit mode) */}
                <div className={`${styles.selectionIndicator}${editMode ? ' ' + styles.selectionVisible : ''}${sel ? ' ' + styles.selectionChecked : ''}`} />

                {/* Swipe delete action */}
                {!editMode && (
                  <button
                    className={styles.swipeAction}
                    onClick={(e) => { e.stopPropagation(); setDeleteTarget([treino.id]) }}
                    id={`btn-delete-${treino.id}`}
                  >
                    Excluir
                  </button>
                )}

                {/* Card */}
                <div
                  className={`${styles.workoutCard}${swiped && !editMode ? ' ' + styles.swiped : ''}${hoje ? ' ' + styles.today : ''}${done ? ' ' + styles.done : ''}${sel ? ' ' + styles.selectedCard : ''}`}
                  onClick={() => handleCardClick(treino)}
                  role="button"
                  tabIndex={0}
                  onKeyDown={(e) => e.key === 'Enter' && handleCardClick(treino)}
                >
                  <div className={styles.cardTop}>
                    <div className={styles.dayInfo}>
                      <span className={styles.dayName}>{treino.dia_semana}</span>
                      <span className={`${styles.dayDate} font-mono`}>{formatDate(treino.data_treino)}</span>
                    </div>
                    <div className={styles.cardBadges}>
                      {hoje && <span className="badge badge-accent">Hoje</span>}
                      {done && <span className="badge badge-success">✓ Feito</span>}
                    </div>
                  </div>

                  <div className={styles.workoutMain}>
                    <span className="ciclo-tag">{treino.ciclos?.nome}</span>
                    <p className={styles.workoutTitle}>{treino.prioridade_1}</p>
                    {treino.prioridade_2 && (
                      <p className={styles.workoutFocus}>{treino.prioridade_2}</p>
                    )}
                  </div>

                  <div className={styles.workoutMeta}>
                    {treino.duracao_total && (
                      <div>
                        <span className="meta-label">Duração</span>
                        <span className="meta-value">{treino.duracao_total}</span>
                      </div>
                    )}
                    {treino.terreno && (
                      <div>
                        <span className="meta-label">Terreno</span>
                        <span className="meta-value">{treino.terreno}</span>
                      </div>
                    )}
                  </div>

                  {!editMode && (
                    <div className={`${styles.btnView}${hoje ? ' ' + styles.btnViewToday : ''}`}>
                      <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.5">
                        <polyline points="9 18 15 12 9 6" />
                      </svg>
                    </div>
                  )}
                </div>
              </div>
            )
          })}
        </div>
      )}

      {/* Bulk Action Bar */}
      {editMode && selectedCount > 0 && (
        <div className={styles.bulkBar}>
          <span className={styles.bulkCount}>{selectedCount} selecionado{selectedCount !== 1 ? 's' : ''}</span>
          <button
            className="btn btn-sm"
            style={{ background: 'var(--danger)', color: 'white', border: 'none' }}
            onClick={() => setDeleteTarget([...selected])}
            id="btn-bulk-delete"
          >
            Excluir
          </button>
        </div>
      )}

      {/* Delete Modal */}
      {deleteTarget && (
        <div className="modal-overlay active" onClick={() => setDeleteTarget(null)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <p style={{ fontSize: 18, fontWeight: 700, marginBottom: 8 }}>Confirmar exclusão</p>
            <p style={{ fontSize: 14, color: 'var(--muted)', marginBottom: 24 }}>
              {deleteTarget.length === 1
                ? 'Deletar este treino permanentemente?'
                : `Deletar ${deleteTarget.length} treinos permanentemente?`}
            </p>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              <button className="btn btn-danger" onClick={confirmDelete} disabled={deleting} id="btn-confirm-delete">
                {deleting ? 'Deletando…' : 'Deletar'}
              </button>
              <button className="btn btn-secondary" onClick={() => setDeleteTarget(null)}>
                Cancelar
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
