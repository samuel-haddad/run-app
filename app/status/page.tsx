import { createClient } from '@/lib/supabase/server'
import { BottomNav } from '@/components/BottomNav'
import { StatusClient } from './StatusClient'

export default async function StatusPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  // Todos os treinos com seus registros
  const { data: treinos } = await supabase
    .from('treinos')
    .select('id, data_treino, prioridade_1, ciclo_id, registros(id)')
    .eq('user_id', user!.id)
    .order('data_treino', { ascending: true })

  const { data: ciclos } = await supabase
    .from('ciclos')
    .select('id, nome')
    .eq('user_id', user!.id)
    .order('created_at', { ascending: false })

  const total = treinos?.length ?? 0
  const concluidos = treinos?.filter((t) => t.registros && (t.registros as unknown[]).length > 0).length ?? 0
  const percentual = total > 0 ? Math.round((concluidos / total) * 100) : 0

  const pendentes = (treinos ?? [])
    .filter((t) => !(t.registros as unknown[]).length)
    .slice(0, 10)

  return (
    <>
      <StatusClient
        total={total}
        concluidos={concluidos}
        percentual={percentual}
        pendentes={pendentes}
        ciclos={ciclos ?? []}
      />
      <BottomNav />
    </>
  )
}
