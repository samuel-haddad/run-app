import Papa from 'papaparse'
import * as XLSX from 'xlsx'

export interface TreinoRow {
  dia_numero: number
  dia_semana: string
  data_treino: string   // YYYY-MM-DD
  prioridade_1: string
  prioridade_2: string
  terreno: string
  duracao_total: string
}

function inferYear(dateStr: string): string {
  // Formato esperado: "DD/MM" — inferimos o ano atual ou próximo
  const now = new Date()
  const currentYear = now.getFullYear()
  const [day, month] = dateStr.split('/').map(Number)

  // Se o mês já passou, assume próximo ano
  const candidate = new Date(currentYear, month - 1, day)
  if (candidate < new Date(now.getFullYear(), now.getMonth() - 1, 1)) {
    return `${currentYear + 1}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`
  }
  return `${currentYear}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`
}

function parseDiaSemana(diaStr: string): { diaNumero: number; diaSemana: string } {
  // "1 (Seg)" → { diaNumero: 1, diaSemana: "Seg" }
  const match = diaStr.match(/^(\d+)\s*\(([^)]+)\)/)
  if (match) {
    return { diaNumero: parseInt(match[1]), diaSemana: match[2].trim() }
  }
  return { diaNumero: 0, diaSemana: diaStr }
}

function rowsToTreinos(rows: Record<string, string>[]): TreinoRow[] {
  return rows
    .filter((row) => row['Data'] && row['Data'].trim())
    .map((row) => {
      const diaCol = row['Dia'] || ''
      const { diaNumero, diaSemana } = parseDiaSemana(diaCol)
      const rawDate = (row['Data'] || '').trim()
      const dataTreino = rawDate.includes('/') ? inferYear(rawDate) : rawDate

      return {
        dia_numero: diaNumero,
        dia_semana: diaSemana,
        data_treino: dataTreino,
        prioridade_1: (row['1º (Prioridade)'] || row['Prioridade 1'] || '').trim(),
        prioridade_2: (row['2º (Complemento)'] || row['Prioridade 2'] || '').trim(),
        terreno: (row['Terreno'] || '').trim(),
        duracao_total: (row['Duração Total'] || row['Duracao Total'] || '').trim(),
      }
    })
}

export async function parseCSV(file: File): Promise<TreinoRow[]> {
  return new Promise((resolve, reject) => {
    Papa.parse(file, {
      header: true,
      skipEmptyLines: true,
      complete: (results) => {
        try {
          resolve(rowsToTreinos(results.data as Record<string, string>[]))
        } catch (e) {
          reject(e)
        }
      },
      error: reject,
    })
  })
}

export async function parseXLSX(file: File): Promise<TreinoRow[]> {
  const buffer = await file.arrayBuffer()
  const workbook = XLSX.read(buffer, { type: 'array' })
  const sheetName = workbook.SheetNames[0]
  const worksheet = workbook.Sheets[sheetName]
  const rows = XLSX.utils.sheet_to_json<Record<string, string>>(worksheet, {
    defval: '',
    raw: false,
  })
  return rowsToTreinos(rows)
}

export async function parseFile(file: File): Promise<TreinoRow[]> {
  const ext = file.name.split('.').pop()?.toLowerCase()
  if (ext === 'csv') return parseCSV(file)
  if (ext === 'xlsx' || ext === 'xls') return parseXLSX(file)
  throw new Error('Formato não suportado. Use CSV ou XLSX.')
}
