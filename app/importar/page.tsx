'use client'

import { useState, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { parseFile, type TreinoRow } from '@/lib/parsers/csv'
import styles from './importar.module.css'

type FileState = {
  file: File | null
  name: string | null
  rows: TreinoRow[]
  error: string | null
}

export default function ImportarPage() {
  const router = useRouter()
  const supabase = createClient()

  const [nomeCiclo, setNomeCiclo] = useState('')
  const [csvState, setCsvState] = useState<FileState>({ file: null, name: null, rows: [], error: null })
  const [mdState, setMdState] = useState<{ file: File | null; name: string | null; content: string | null; error: string | null }>({
    file: null, name: null, content: null, error: null,
  })
  const [loading, setLoading] = useState(false)
  const [toast, setToast] = useState<{ msg: string; type: 'success' | 'error' } | null>(null)

  const csvInputRef = useRef<HTMLInputElement>(null)
  const mdInputRef = useRef<HTMLInputElement>(null)

  function showToast(msg: string, type: 'success' | 'error' = 'success') {
    setToast({ msg, type })
    setTimeout(() => setToast(null), 4000)
  }

  async function handleCsvChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    try {
      const rows = await parseFile(file)
      setCsvState({ file, name: file.name, rows, error: null })
      if (!nomeCiclo) {
        const baseName = file.name.replace(/\.(csv|xlsx|xls)$/i, '').replace(/_/g, ' ')
        setNomeCiclo(baseName)
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Erro ao ler arquivo'
      setCsvState({ file: null, name: file.name, rows: [], error: msg })
    }
  }

  async function handleMdChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    try {
      const content = await file.text()
      setMdState({ file, name: file.name, content, error: null })
    } catch {
      setMdState({ file: null, name: file.name, content: null, error: 'Erro ao ler o arquivo.' })
    }
  }

  async function handleImport() {
    if (!csvState.rows.length || !nomeCiclo.trim()) return
    setLoading(true)
    try {
      const { data: { user } } = await supabase.auth.getUser()

      // 1. Criar o ciclo
      const { data: ciclo, error: cicloError } = await supabase
        .from('ciclos')
        .insert({
          user_id: user!.id,
          nome: nomeCiclo.trim(),
          detalhamento_md: mdState.content ?? null,
        })
        .select('id')
        .single()

      if (cicloError) throw cicloError

      // 2. Inserir treinos em lote
      const treinosPayload = csvState.rows.map((row) => ({
        ciclo_id: ciclo.id,
        user_id: user!.id,
        dia_numero: row.dia_numero,
        dia_semana: row.dia_semana,
        data_treino: row.data_treino,
        prioridade_1: row.prioridade_1,
        prioridade_2: row.prioridade_2,
        terreno: row.terreno,
        duracao_total: row.duracao_total,
      }))

      const { error: treinosError } = await supabase
        .from('treinos')
        .insert(treinosPayload)

      if (treinosError) throw treinosError

      showToast(`${csvState.rows.length} treinos importados com sucesso! ✓`)
      // Reset
      setCsvState({ file: null, name: null, rows: [], error: null })
      setMdState({ file: null, name: null, content: null, error: null })
      setNomeCiclo('')
      setTimeout(() => router.push('/planejamento'), 1800)
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Erro na importação'
      showToast(msg, 'error')
    } finally {
      setLoading(false)
    }
  }

  const canImport = csvState.rows.length > 0 && nomeCiclo.trim().length > 0

  return (
    <div className="app-container">
      <header className="page-header" style={{ marginBottom: 28 }}>
        <div className="page-header-content">
          <h1 className="page-title">Importar</h1>
        </div>
      </header>

      {/* Nome do ciclo */}
      <section className="mb-24">
        <span className="section-label">Nome do Ciclo</span>
        <div className="input-group">
          <input
            id="nome-ciclo"
            type="text"
            className="input"
            placeholder="Ex: Ciclo 1 — Maio 2026"
            value={nomeCiclo}
            onChange={(e) => setNomeCiclo(e.target.value)}
          />
        </div>
      </section>

      {/* Upload Files */}
      <section className="mb-24">
        <span className="section-label">Upload de Arquivos</span>
        <div className={styles.uploadStack}>
          {/* CSV / XLSX */}
          <div
            className={`${styles.uploadCard}${csvState.rows.length ? ' ' + styles.uploadDone : ''}${csvState.error ? ' ' + styles.uploadError : ''}`}
            onClick={() => csvInputRef.current?.click()}
            role="button"
            tabIndex={0}
            onKeyDown={(e) => e.key === 'Enter' && csvInputRef.current?.click()}
            id="upload-csv-card"
          >
            <input
              ref={csvInputRef}
              type="file"
              accept=".csv,.xlsx,.xls"
              style={{ display: 'none' }}
              onChange={handleCsvChange}
              id="input-csv"
            />
            <div className={styles.uploadIcon}>
              {csvState.rows.length ? (
                <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
                  <polyline points="20 6 9 17 4 12" />
                </svg>
              ) : (
                <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
                  <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                  <polyline points="14 2 14 8 20 8" />
                  <line x1="16" y1="13" x2="8" y2="13" /><line x1="16" y1="17" x2="8" y2="17" />
                </svg>
              )}
            </div>
            <div className={styles.uploadInfo}>
              <h3>{csvState.name ?? 'Planilha de Treino'}</h3>
              <p>
                {csvState.error
                  ? csvState.error
                  : csvState.rows.length
                  ? `${csvState.rows.length} treinos encontrados`
                  : 'Calendário macro e ritmos sugeridos'}
              </p>
            </div>
            <span className={styles.fileType}>{csvState.rows.length ? '✓ PRONTO' : 'CSV / XLSX'}</span>
          </div>

          {/* Markdown */}
          <div
            className={`${styles.uploadCard}${mdState.content ? ' ' + styles.uploadDone : ''}${mdState.error ? ' ' + styles.uploadError : ''}`}
            onClick={() => mdInputRef.current?.click()}
            role="button"
            tabIndex={0}
            onKeyDown={(e) => e.key === 'Enter' && mdInputRef.current?.click()}
            id="upload-md-card"
          >
            <input
              ref={mdInputRef}
              type="file"
              accept=".md,.txt,.doc,.docx"
              style={{ display: 'none' }}
              onChange={handleMdChange}
              id="input-md"
            />
            <div className={styles.uploadIcon}>
              {mdState.content ? (
                <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
                  <polyline points="20 6 9 17 4 12" />
                </svg>
              ) : (
                <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
                  <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                  <polyline points="14 2 14 8 20 8" />
                  <line x1="16" y1="13" x2="8" y2="13" /><line x1="16" y1="17" x2="8" y2="17" />
                </svg>
              )}
            </div>
            <div className={styles.uploadInfo}>
              <h3>{mdState.name ?? 'Detalhes Técnicos'}</h3>
              <p>
                {mdState.error
                  ? mdState.error
                  : mdState.content
                  ? 'Detalhamento carregado'
                  : 'Guia de ritmos e descrição das séries'}
              </p>
            </div>
            <span className={styles.fileType}>{mdState.content ? '✓ PRONTO' : 'MD / TXT'}</span>
          </div>
        </div>
      </section>

      {/* Preview */}
      {csvState.rows.length > 0 && (
        <section className="mb-24">
          <span className="section-label">Preview — {csvState.rows.length} treinos</span>
          <div className={styles.previewList}>
            {csvState.rows.slice(0, 5).map((row, i) => (
              <div key={i} className={styles.previewItem}>
                <span className={`font-mono text-xs`} style={{ color: 'var(--accent)' }}>
                  Dia {row.dia_numero} · {row.dia_semana}
                </span>
                <span className={styles.previewTitle}>{row.prioridade_1}</span>
                {row.prioridade_2 && (
                  <span className="text-muted text-sm">{row.prioridade_2}</span>
                )}
              </div>
            ))}
            {csvState.rows.length > 5 && (
              <p className={`text-muted text-sm`} style={{ textAlign: 'center', padding: '8px 0' }}>
                + {csvState.rows.length - 5} treinos restantes
              </p>
            )}
          </div>
        </section>
      )}

      {/* CTA */}
      <div className={styles.footerAction}>
        <p>
          {canImport
            ? `Pronto para importar ${csvState.rows.length} treinos do ciclo "${nomeCiclo}".`
            : 'Selecione a planilha CSV e informe o nome do ciclo para importar.'}
        </p>
        <button
          className="btn btn-primary"
          onClick={handleImport}
          disabled={!canImport || loading}
          id="btn-confirm-import"
        >
          {loading ? (
            <><span className="spinner" style={{ borderTopColor: 'var(--bg)' }} />Importando…</>
          ) : (
            <>
              <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
                <polyline points="20 6 9 17 4 12" />
              </svg>
              Confirmar Importação
            </>
          )}
        </button>
      </div>

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
