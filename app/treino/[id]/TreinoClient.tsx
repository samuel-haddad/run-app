'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import { findSecaoForTreino, type Detalhamento } from '@/lib/parsers/markdown'
import styles from './treino.module.css'

type Treino = {
  id: string
  dia_semana: string | null
  data_treino: string
  prioridade_1: string | null
  prioridade_2: string | null
  terreno: string | null
  duracao_total: string | null
  ciclos: { id: string; nome: string; detalhamento_md: string | null } | null
}

type Registro = {
  id: string
  anotacao: string | null
  concluido_em: string
} | null

function formatFullDate(dateStr: string) {
  const d = new Date(dateStr + 'T12:00:00')
  return d.toLocaleDateString('pt-BR', { weekday: 'long', day: '2-digit', month: 'long' })
}

export function TreinoClient({
  treino,
  detalhamento,
  registroExistente,
}: {
  treino: Treino
  detalhamento: Detalhamento | null
  registroExistente: Registro
}) {
  const router = useRouter()
  const supabase = createClient()

  const [anotacao, setAnotacao] = useState(registroExistente?.anotacao ?? '')
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState(!!registroExistente)
  const [toast, setToast] = useState<{ msg: string; type: 'success' | 'error' } | null>(null)

  // Encontrar seções do detalhamento relacionadas ao treino
  const secao1 = detalhamento && treino.prioridade_2
    ? findSecaoForTreino(detalhamento, treino.prioridade_2)
    : null

  function showToast(msg: string, type: 'success' | 'error' = 'success') {
    setToast({ msg, type })
    setTimeout(() => setToast(null), 3000)
  }

  async function handleSave() {
    setSaving(true)
    try {
      const { data: { user } } = await supabase.auth.getUser()

      if (registroExistente) {
        // Atualizar registro existente
        const { error } = await supabase
          .from('registros')
          .update({ anotacao, concluido_em: new Date().toISOString() })
          .eq('id', registroExistente.id)
        if (error) throw error
      } else {
        // Criar novo registro
        const { error } = await supabase
          .from('registros')
          .insert({ treino_id: treino.id, user_id: user!.id, anotacao })
        if (error) throw error
      }

      setSaved(true)
      showToast('Treino salvo com sucesso! ✓')
      setTimeout(() => router.push('/planejamento'), 1500)
    } catch {
      showToast('Erro ao salvar. Tente novamente.', 'error')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="app-container">
      {/* Header */}
      <div className={styles.cicloTag + ' ciclo-tag'}>{treino.ciclos?.nome}</div>
      <header className={styles.header}>
        <div className={styles.headerLeft}>
          <Link href="/planejamento" className="back-btn" id="btn-back">
            <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <polyline points="15 18 9 12 15 6" />
            </svg>
          </Link>
          <h1 className={styles.title}>{formatFullDate(treino.data_treino)}</h1>
        </div>
      </header>

      {/* Guia de Ritmos */}
      {detalhamento?.guiaRitmos && (
        <section className={styles.section}>
          <span className="section-label">Guia de Ritmos</span>
          <div className={styles.rhythmCard}>
            <div className={styles.rhythmGrid}>
              {detalhamento.guiaRitmos.ritmos.map((r, i) => (
                <div key={i} className={styles.rhythmItem}>
                  <span className={styles.rhythmName}>{r.nome}</span>
                  <span className={styles.rhythmValue}>{r.valor}</span>
                </div>
              ))}
            </div>
            {detalhamento.guiaRitmos.descricao && (
              <p className={styles.rhythmDesc}>{detalhamento.guiaRitmos.descricao}</p>
            )}
          </div>
        </section>
      )}

      {/* Série Principal */}
      <section className={styles.section}>
        <span className="section-label">Série do Dia</span>

        {/* Prioridade 1 — corrida */}
        <div className={styles.seriesCard}>
          <div className={styles.seriesHeader}>
            <span className={styles.seriesTitle}>{treino.prioridade_1}</span>
            <span className="badge badge-accent">Principal</span>
          </div>
          <div className={styles.seriesMeta}>
            {treino.duracao_total && (
              <span className={styles.seriesMetaItem}>
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" strokeWidth="2">
                  <circle cx="12" cy="12" r="10" /><polyline points="12 6 12 12 16 14" />
                </svg>
                {treino.duracao_total}
              </span>
            )}
            {treino.terreno && (
              <span className={styles.seriesMetaItem}>
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M3 17l3-6 4 4 4-8 4 6" />
                </svg>
                {treino.terreno}
              </span>
            )}
          </div>
        </div>

        {/* Complemento — treino de força */}
        {secao1 && (
          <div className={styles.seriesCard} style={{ marginTop: 12 }}>
            <div className={styles.seriesHeader}>
              <span className={styles.seriesTitle}>{secao1.titulo}</span>
              <span className="badge badge-muted">Força</span>
            </div>
            {secao1.subtitulo && (
              <p className={styles.seriesSubtitulo}>{secao1.subtitulo}</p>
            )}
            <div className={styles.seriesList}>
              {secao1.exercicios.map((ex, i) => (
                <div key={i} className={styles.seriesItem}>
                  <span className={styles.seriesBullet} />
                  <span className={styles.seriesContent}>{ex}</span>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Fallback se não houver detalhamento */}
        {!secao1 && treino.prioridade_2 && (
          <div className={styles.seriesCard} style={{ marginTop: 12 }}>
            <div className={styles.seriesHeader}>
              <span className={styles.seriesTitle}>{treino.prioridade_2}</span>
              <span className="badge badge-muted">Complemento</span>
            </div>
          </div>
        )}
      </section>

      {/* Registro */}
      <section className={styles.section}>
        <span className="section-label">Registro</span>
        <div className={`card ${styles.feedbackCard}`}>
          {saved && (
            <div className={styles.savedBadge}>
              <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2.5">
                <polyline points="20 6 9 17 4 12" />
              </svg>
              Treino concluído
            </div>
          )}
          <label className="input-label" htmlFor="anotacao">Como foi o treino?</label>
          <textarea
            id="anotacao"
            className="input"
            rows={4}
            placeholder="Ex: Senti cansaço no final, mas o pace foi estável..."
            value={anotacao}
            onChange={(e) => setAnotacao(e.target.value)}
            style={{ marginBottom: 16, marginTop: 8 }}
          />
          <button
            className="btn btn-primary"
            onClick={handleSave}
            disabled={saving}
            id="btn-save-treino"
          >
            {saving ? (
              <><span className="spinner" style={{ borderTopColor: 'var(--bg)' }} />Salvando…</>
            ) : saved ? (
              'Atualizar Registro'
            ) : (
              'Salvar Resultado'
            )}
          </button>
        </div>
      </section>

      {/* Toast */}
      {toast && (
        <div className={`toast show ${toast.type}`} role="alert" aria-live="polite">
          {toast.type === 'success'
            ? <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.5"><polyline points="20 6 9 17 4 12" /></svg>
            : <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="10" /><line x1="12" y1="8" x2="12" y2="12" /><line x1="12" y1="16" x2="12.01" y2="16" /></svg>
          }
          {toast.msg}
        </div>
      )}
    </div>
  )
}
