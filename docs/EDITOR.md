# Editor dentro do jogo

O modo criador desta revisão funciona manualmente sem Internet e sem modelo de IA. As alterações ficam no computador onde editas, em `user://world_edits.json`, com backup `.bak`. O progresso do jogador tem ficheiros separados.

## Primeira utilização

1. Abre o projeto e carrega em F5. Escolhe uma personagem.
2. Fora de um veículo, carrega em **F10**, ou abre **Esc → Editor → Abrir editor**.
3. Define uma palavra-passe de pelo menos quatro caracteres. Nas sessões seguintes usa a mesma palavra-passe.
4. Mantém o **botão direito do rato** para olhar e voar com **WASD**. **Q** desce, **E** sobe e **Shift** acelera. Solta o rato para usar os painéis.
5. Seleciona um elemento no cenário ou na lista. Edita **posição XYZ**, **rotação em graus** e **escala** no painel direito.
6. Usa a cor e os materiais disponíveis; luzes têm controlos de intensidade e alcance. As peças de construção mantêm as colisões associadas.
7. Usa **Desfazer/Refazer** ou **Ctrl+Z/Ctrl+Y**. Clica em **Guardar** ou usa **Ctrl+S** antes de sair.
8. **F10** volta ao jogo. As ferramentas também permitem carregar as edições guardadas.

O mundo fica parado durante a edição. A palavra-passe evita abertura acidental; numa aplicação local não constitui proteção contra alguém que controla os ficheiros do computador.

## Acrescentar peças, pessoas e veículos

O painel esquerdo contém paredes, portas, luzes, NPCs, missões, carro, mota, bicicleta, trotinete e peças simples. Depois de colocar um elemento, seleciona-o para ajustar as propriedades. A lista permite selecionar objetos que são pequenos ou difíceis de atingir por clique. Algumas peças repetidas do cenário são instâncias de MultiMesh e também podem ser alteradas individualmente.

Para uma fachada mais elaborada, combina paredes, portas e peças com posição/escala diferentes. Para arquitetura e roupa detalhadas, prepara o modelo no Blender e exporta **GLB/GLTF**. Copia-o para uma pasta em `assets/` através do Explorador do Windows, deixa o Godot importá-lo e indica no editor o caminho, por exemplo `res://assets/meu_predio.glb`. O campo não é um importador de ficheiros GTA `.dff`/`.txd` nem de projetos Unity.

Os NPCs do catálogo permitem escolher aparência e perfil; isso não cria animações novas. As missões são situações locais simples, com título, tipo e recompensa: a interação do jogador pode concluí-las e pagar uma vez. Campanhas com várias etapas e lógica livre continuam a exigir desenvolvimento no Godot.

## Preparar a IA local, opcionalmente

Esta ligação está implementada, mas **ainda não foi validada de ponta a ponta com um modelo real neste ambiente**. O editor manual e a validação de propostas foram testados. Instalar e descarregar o modelo requer Internet inicialmente; depois, o serviço local pode responder offline.

1. No computador de desenvolvimento, instala o [Ollama](https://ollama.com/download/windows).
2. Abre o PowerShell e descarrega um modelo, por exemplo:

   ```powershell
   ollama pull qwen2.5:3b
   ```

3. Mantém o Ollama aberto. Normalmente disponibiliza a API em `http://127.0.0.1:11434`. Se o serviço não estiver iniciado, `ollama serve` pode iniciá-lo; se já estiver aberto, não é necessário outro processo.
4. No editor do jogo, confirma o nome **qwen2.5:3b** no campo do modelo. Podes indicar outro modelo instalado que consiga produzir o JSON solicitado, incluindo uma variante Llama adequada à memória disponível. Não há um modelo descarregado automaticamente pelo jogo.
5. Seleciona uma luz ou objeto. Escreve, por exemplo: «muda a luz selecionada para rosa e aumenta a intensidade para 2».
6. Clica em **Pedir proposta à IA local**. A proposta deve usar os IDs existentes no Scene Graph enviado pelo jogo.
7. Se a proposta for válida, a cena mostra uma **pré-visualização**. Inspeciona-a e escolhe **Aplicar** ou **Cancelar**. Depois de aplicar podes **Desfazer**; usa **Guardar** para conservar o resultado.

O contexto inclui a seleção e até 24 objetos próximos. As ações aceites limitam-se a posição, rotação, escala, cor, materiais predefinidos e intensidade/alcance de luzes, em até 12 ações por proposta. Respostas com IDs ou propriedades inválidos são rejeitadas. Código produzido pelo modelo não é executado.

A IA desta etapa não consegue criar um personagem completo, gerar roupa, reprogramar o combate ou alterar todas as mecânicas. Essas capacidades continuam no plano do projeto. O desempenho do modelo e o uso de GPU no ASUS/RX 7600 XT precisam de teste; o HP destinado a jogar não precisa de executar IA.

## Recuperação de dados

No Windows, abre no Explorador:

```text
%APPDATA%\Godot\app_userdata\Álbum Visual — Lisboa Noturna\
```

Com o jogo fechado, copia `world_edits.json` e o backup para outra pasta antes de recomeçar. Para voltar ao cenário base, retira ambos da pasta de dados. Para definir outra palavra-passe local, retira `editor_access.cfg`; o jogo pedirá uma nova na próxima entrada. Não apagues os ficheiros do jogador se só queres limpar o mundo editado.
