# Desenvolvimento e sincronização

- Trabalhar no checkout existente. O ambiente na nuvem já é isolado; não criar worktrees sem pedido explícito.
- Preferência do criador: manter o código no GitHub atualizado juntamente com o trabalho local. Depois de cada conjunto coerente de alterações validado, criar um commit e fazer push da branch de trabalho, verificando que o SHA remoto corresponde ao local. Não deixar uma entrega concluída apenas no ambiente da nuvem.
- Usar o remoto HTTPS existente e a autenticação fornecida pelo ambiente. Nunca guardar credenciais no projeto. Não fazer force-push nem substituir alterações do utilizador.
- Comunicar a branch e o link exatos da versão entregue. Um push para uma branch de trabalho não significa merge em `main`.
- Preservar os dados locais do jogador e as edições do mundo. Não versionar `.godot/`, exportações ou backups do Blender.
- Abrir `README.md`, `docs/GDD.md` e `docs/VALIDACAO.md` para contexto. Testar com Godot 4 Compatibility, usando verificações apropriadas à alteração; `tools/run_checks.sh` executa o conjunto completo com dados isolados.
- Consultar também `Ter como referencia`, `docs/ESTADO_19_ETAPAS.md` e `docs/PLANO_MAPA_CONTINUO.md`. A auditoria inicial pedida na secção 17 foi documentada em 21 de outubro de 2026, sem alterar código. Novas implementações dependem da tarefa seguinte do criador; não executar automaticamente as 19 etapas de uma vez.
- Decisões confirmadas: a expansão mantém o Álbum Visual centrado em música e exploração; a cidade será compacta, com edifícios e personagens proporcionais, sem distâncias geográficas de Lisboa à escala 1:1. Preservar editor, áudio e sistemas existentes.
- Após a auditoria de 21 de outubro, o criador autorizou avançar no código: motion blur desejado, editor melhorado, Ponte 25 de Abril junto ao Tejo e uso pontual de splats quando adequado. Indicou mapas locais para recortar Saldanha, Pink Street e Bairro Alto; usar esses ficheiros quando enviados. Um caminho Windows no chat não dá acesso aos ficheiros a partir da nuvem. Ver `docs/ENTREGAR_MAPAS.md` e não apresentar a integração dos mapas/ponte como concluída antes de a executar.
- Em Linux com pasta pessoal só de leitura, usar diretórios XDG graváveis. Verificações MultiMesh dependentes do renderer exigem janela nativa; não converter omissões headless em resultados passados.
- Distinguir protótipos de funcionalidades finais, referências de recursos incluídos, e testes da nuvem de desempenho no portátil HP. A IA local é opcional e não deve ser requisito para jogar.
