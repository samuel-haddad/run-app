export interface SecaoTreino {
  id: string          // "A", "B", "C", etc.
  titulo: string      // "Treino A: Core & Superior"
  subtitulo?: string  // "Realizar logo após a corrida na academia."
  exercicios: string[]
}

export interface GuiaRitmos {
  ritmos: { nome: string; valor: string }[]
  descricao: string
}

export interface Detalhamento {
  guiaRitmos: GuiaRitmos | null
  secoes: SecaoTreino[]
  rawMd: string
}

export function parseMarkdown(rawMd: string): Detalhamento {
  const lines = rawMd.split('\n')
  const secoes: SecaoTreino[] = []
  let guiaRitmos: GuiaRitmos | null = null

  let currentSecao: SecaoTreino | null = null
  let inGuiaRitmos = false
  const guiaLines: string[] = []

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim()

    // Detecta seção de Guia de Ritmos
    if (/guia de ritmos/i.test(line)) {
      inGuiaRitmos = true
      currentSecao = null
      continue
    }

    // Detecta "Treino X:" em h4 ou h3
    const secaoMatch = line.match(/^#{3,4}\s+\*{0,2}(Treino\s+([A-Z])[\s:][^*]*)\*{0,2}/)
    if (secaoMatch) {
      if (currentSecao) secoes.push(currentSecao)
      inGuiaRitmos = false
      const id = secaoMatch[2]
      const titulo = secaoMatch[1]
        .replace(/\*+/g, '')
        .replace(/\\/g, '')
        .trim()
      currentSecao = { id, titulo, exercicios: [] }
      continue
    }

    // Subtítulo em itálico
    if (currentSecao && /^\*[^*]/.test(line)) {
      currentSecao.subtitulo = line.replace(/^\*|\*$/g, '').replace(/\\/g, '').trim()
      continue
    }

    // Exercícios em lista numerada
    if (currentSecao && /^\d+\./.test(line)) {
      currentSecao.exercicios.push(
        line.replace(/^\d+\.\s*/, '').replace(/\*\*/g, '').replace(/\\/g, '').trim()
      )
      continue
    }

    // Linhas do Guia de Ritmos
    if (inGuiaRitmos && line.startsWith('*')) {
      guiaLines.push(line)
    }
  }

  if (currentSecao) secoes.push(currentSecao)

  // Parseia guia de ritmos
  if (guiaLines.length > 0) {
    const ritmos: { nome: string; valor: string }[] = []
    let descricao = ''
    for (const gl of guiaLines) {
      const clean = gl.replace(/^\*+\s*/, '').replace(/\\/g, '').trim()
      const match = clean.match(/^\*\*([^*]+)\*\*[:\s]+(.+)$/)
      if (match) {
        ritmos.push({ nome: match[1].trim(), valor: match[2].trim() })
      } else {
        descricao += clean + ' '
      }
    }
    guiaRitmos = { ritmos, descricao: descricao.trim() }
  }

  return { guiaRitmos, secoes, rawMd }
}

export function findSecaoForTreino(detalhamento: Detalhamento, prioridade: string): SecaoTreino | null {
  // Procura "Treino A", "Treino B", "Treino C" na string de prioridade
  const match = prioridade.match(/Treino\s+([A-Z])/i)
  if (!match) return null
  const id = match[1].toUpperCase()
  return detalhamento.secoes.find((s) => s.id === id) || null
}
