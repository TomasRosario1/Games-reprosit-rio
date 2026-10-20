# Desenvolvimento e sincronização

- Trabalhar no checkout existente. O ambiente na nuvem já é isolado; não criar worktrees sem pedido explícito.
- Preferência do criador: manter o código no GitHub atualizado juntamente com o trabalho local. Depois de cada conjunto coerente de alterações validado, criar um commit e fazer push da branch de trabalho, verificando que o SHA remoto corresponde ao local. Não deixar uma entrega concluída apenas no ambiente da nuvem.
- Usar o remoto HTTPS existente e a autenticação fornecida pelo ambiente. Nunca guardar credenciais no projeto. Não fazer force-push nem substituir alterações do utilizador.
- Comunicar a branch e o link exatos da versão entregue. Um push para uma branch de trabalho não significa merge em `main`.
- Preservar os dados locais do jogador e as edições do mundo. Não versionar `.godot/`, exportações ou backups do Blender.
- Abrir `README.md`, `docs/GDD.md` e `docs/VALIDACAO.md` para contexto. Testar com Godot 4 Compatibility, usando verificações apropriadas à alteração; `tools/run_checks.sh` executa o conjunto completo com dados isolados.
- Em Linux com pasta pessoal só de leitura, usar diretórios XDG graváveis. Verificações MultiMesh dependentes do renderer exigem janela nativa; não converter omissões headless em resultados passados.
- Distinguir protótipos de funcionalidades finais, referências de recursos incluídos, e testes da nuvem de desempenho no portátil HP. A IA local é opcional e não deve ser requisito para jogar.
