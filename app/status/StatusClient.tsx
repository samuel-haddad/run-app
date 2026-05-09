'use client'

import { useEffect, useRef } from 'react'
import Link from 'next/link'
import styles from './status.module.css'

type Pendente = {
  id: string
  data_treino: string
  prioridade_1: string | null
}

type Ciclo = { id: string; nome: string }

function formatDate(dateStr: string) {
  const d = new Date(dateStr + 'T12:00:00')
  return d.toLocaleDateString('pt-BR', { weekday: 'long', day: '2-digit', month: '2-digit' })
}

const CIRCUMFERENCE = 2 * Math.PI * 70 // ~440

export function StatusClient({
  total,
  concluidos,
  percentual,
  pendentes,
  ciclos,
}: {
  total: number
  concluidos: number
  percentual: number
  pendentes: Pendente[]
  ciclos: Ciclo[]
}) {
  const circleRef = useRef<SVGCircleElement>(null)

  useEffect(() => {
    // Animar o gráfico ao montar
    if (circleRef.current) {
      const offset = CIRCUMFERENCE * (1 - percentual / 100)
      circleRef.current.style.strokeDashoffset = String(offset)
    }
  }, [percentual])

  return (
    <div className="app-container">
      <header className="page-header" style={{ marginBottom: 28 }}>
        <div className="page-header-content">
          <h1 className="page-title">Status</h1>
        </div>
      </header>

      {/* KPIs */}
      <section className="mb-32">
        <span className="section-label">Visão Geral</span>
        <div className="stats-grid">
          <div className="stat-card">
            <span className="stat-value">{total}</span>
            <span className="stat-label">Treinos</span>
          </div>
          <div className="stat-card">
            <span className="stat-value">{concluidos}</span>
            <span className="stat-label">Concluídos</span>
          </div>
          <div className="stat-card">
            <span className="stat-value">{percentual}%</span>
            <span className="stat-label">Adesão</span>
          </div>
        </div>
      </section>

      {/* Gráfico circular */}
      {total > 0 && (
        <section className="mb-32">
          <span className="section-label">Performance</span>
          <div className={styles.chartContainer}>
            <svg
              className={styles.chartSvg}
              viewBox="0 0 160 160"
              aria-label={`${percentual}% concluído`}
            >
              <circle className={styles.chartBg} cx="80" cy="80" r="70" />
              <circle
                ref={circleRef}
                className={styles.chartProgress}
                cx="80"
                cy="80"
                r="70"
                style={{ strokeDashoffset: CIRCUMFERENCE }}
              />
            </svg>
            <div className={styles.chartInfo}>
              <span className={styles.chartPercent}>{percentual}%</span>
              <span className={styles.chartSub}>Concluído</span>
            </div>
          </div>
        </section>
      )}

      {/* Ciclos ativos */}
      {ciclos.length > 0 && (
        <section className="mb-32">
          <span className="section-label">Ciclos</span>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {ciclos.map((c) => (
              <div key={c.id} className="card" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <span style={{ fontWeight: 600, fontSize: 15 }}>{c.nome}</span>
                <span className="badge badge-accent">Ativo</span>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* Pendentes */}
      {pendentes.length > 0 && (
        <section>
          <span className="section-label">Próximos Pendentes</span>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {pendentes.map((t) => (
              <Link key={t.id} href={`/treino/${t.id}`} className={styles.pendingItem}>
                <div>
                  <p className={styles.pendingTitle}>{t.prioridade_1}</p>
                  <span className={`font-mono text-xs text-muted`}>{formatDate(t.data_treino)}</span>
                </div>
                <span className="badge badge-muted">Pendente</span>
              </Link>
            ))}
          </div>
        </section>
      )}

      {total === 0 && (
        <div className="empty-state">
          <svg className="empty-state-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
            <path d="M12 20v-6M6 20V10M18 20V4" />
          </svg>
          <p className="empty-state-title">Sem dados ainda</p>
          <p className="empty-state-desc">Importe seus treinos para ver as estatísticas.</p>
        </div>
      )}
    </div>
  )
}
