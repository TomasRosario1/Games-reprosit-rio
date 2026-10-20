# Referências para a revisão de Lisboa e dos NPCs

Análise feita em 20 de outubro de 2026. Os links foram fornecidos pelo criador; os parâmetros de rastreio foram removidos. Foram consultados os ficheiros indicados abaixo, nos commits registados. Nenhum jogo de referência foi compilado ou executado e nenhum recurso de GTA foi integrado no Álbum Visual.

Esta análise orienta uma implementação própria em Godot. A presença pública de um repositório não significa que todos os seus ficheiros, ou os recursos do jogo que ele consegue carregar, tenham uma licença permissiva.

## O que cada projeto oferece

| Referência | Commit consultado | Licença/alcance observado | Utilidade nesta revisão |
| --- | --- | --- | --- |
| [OpenSAMP](https://github.com/bssth/opensamp) | `a05717eeab2de65d1def7e7725dc1985198400f7` | GPL v3, com dependências de licenças próprias. README: cliente multiplayer em alpha para GTA SA original. | Referência secundária para separar estados e temporizadores; não contém uma implementação completa de reações de peões civis. Não foi incorporado código. |
| [SanAndreasUnity](https://github.com/in0finite/SanAndreasUnity) | `f685c437f48721afc0787f27d22c85d96e8684c7` | MIT no `LICENSE`, Copyright 2015 James King. Necessita dos ficheiros do GTA SA do utilizador para executar. | Referência principal de organização da IA, perceção, transições de movimento e gestão da população. |
| [OpenLiberty](https://github.com/openfw-game/OpenLiberty) | `b2fcfd2b4c7cdd8d72f066178b9310c8e3c8a5a0` | MIT no `LICENCE`, Copyright 2023 JeanKouss. README indica não incluir ficheiros GTA3 e ainda lista NPCs/animações como tarefas futuras. | Referência Godot para intervalos de visibilidade, LOD, cache de texturas e redução de luzes distantes. Não é uma biblioteca pronta de NPCs. |
| [re3-vc](https://github.com/iika18/re3-vc) | `6b0e67a2baa4adde1cdd6c45029650acfccd750d` | README, secção License: os autores dizem não estar em posição de atribuir uma licença e indicam estudo/documentação/modding. Não há licença principal permissiva verificada. | Estudo descritivo de prioridades, reações temporizadas, população e streaming. Código não copiado nem transposto. O HEAD consultado corresponde ao código GTA III descrito pelo README; o nome do fork não prova que HEAD seja a variante Vice City. |
| [lcs-recomp](https://github.com/elmasas/lcs-recomp) | `1132a76e59a29d7395635a5239a0d4aadd948385` | MIT do projeto PSPRecomp, com avisos próprios de terceiros. Recompilação/port que exige o executável e dados de uma cópia do jogo. | Referência para separar resolução interna, distância de visão e filtragem. Não fornece modelos humanos originais para reutilização. |

Não foram encontrados ficheiros `AGENTS.md` nas árvores dos cinco commits consultados. As cópias de referência foram mantidas fora do projeto principal; não são dependências do jogo.

A [página de tópicos liberty-city-stories](https://github.com/topics/liberty-city-stories) também foi consultada. É um índice variável de projetos — na consulta surgiram ferramentas, ports e importadores —, não um pacote de personagens com uma licença única. Não foram descarregados modelos ou texturas dessa página.

## Os modelos no SanAndreasUnity

O projeto inclui código para construir e animar personagens na Unity. As personagens GTA que aparecem nas suas imagens são carregadas a partir dos dados do jogo original. Esta dependência foi confirmada no commit `f685c437f48721afc0787f27d22c85d96e8684c7`:

- O [README, linha 24](https://github.com/in0finite/SanAndreasUnity/blob/f685c437f48721afc0787f27d22c85d96e8684c7/README.md#L24) diz: “When running for the first time, the game will ask you for path to GTA installation. You need to own GTA in order to play it.” A [linha 31](https://github.com/in0finite/SanAndreasUnity/blob/f685c437f48721afc0787f27d22c85d96e8684c7/README.md#L31) também exige copiar a versão PC de GTA SA para o dispositivo de destino.
- [`PedModel.cs`, linha 203](https://github.com/in0finite/SanAndreasUnity/blob/f685c437f48721afc0787f27d22c85d96e8684c7/Assets/Scripts/Behaviours/PedModel.cs#L203) chama `LoadModel` com os nomes da malha e do dicionário de texturas; a [linha 250](https://github.com/in0finite/SanAndreasUnity/blob/f685c437f48721afc0787f27d22c85d96e8684c7/Assets/Scripts/Behaviours/PedModel.cs#L250) encaminha-os para `Geometry.Load`.
- [`Conversion/Geometry.cs`, linha 572](https://github.com/in0finite/SanAndreasUnity/blob/f685c437f48721afc0787f27d22c85d96e8684c7/Assets/Scripts/Importing/Conversion/Geometry.cs#L572) lê `modelName + ".dff"` através de `ArchiveManager`. [`TextureDictionary.cs`, linha 264](https://github.com/in0finite/SanAndreasUnity/blob/f685c437f48721afc0787f27d22c85d96e8684c7/Assets/Scripts/Importing/Conversion/TextureDictionary.cs#L264) lê `.txd`, e [`Animation.cs`, linha 186](https://github.com/in0finite/SanAndreasUnity/blob/f685c437f48721afc0787f27d22c85d96e8684c7/Assets/Scripts/Importing/Conversion/Animation.cs#L186) abre os pacotes de animação `.ifp`.

Por isso, o código aberto e os componentes Unity permitem **carregar** os modelos GTA quando existem esses dados; não fornecem uma licença para redistribuir as personagens Rockstar no Álbum Visual. A licença MIT do código continua útil para estudar o carregamento e a IA. Os vinte GLB desta revisão, os seus atlas, rigs e animações foram criados para este projeto, sem extração de uma instalação GTA.

## Reações dos NPCs: fonte e tradução para Godot

### SanAndreasUnity

Ficheiros efetivamente consultados, relativos ao commit acima:

- [`Assets/Scripts/Behaviours/PedAI/PedAI.cs`](https://github.com/in0finite/SanAndreasUnity/blob/f685c437f48721afc0787f27d22c85d96e8684c7/Assets/Scripts/Behaviours/PedAI/PedAI.cs): regista estados `Idle`, `WalkAround`, `Escape`, `Chase` e `Follow`; encaminha eventos para o estado atual; distingue atualização corrente de atualização espaçada a dois segundos.
- [`PedAI/BaseState.cs`](https://github.com/in0finite/SanAndreasUnity/blob/f685c437f48721afc0787f27d22c85d96e8684c7/Assets/Scripts/Behaviours/PedAI/BaseState.cs): entrada/saída, instante de ativação e eventos separados da locomoção.
- [`PedAI/IdleState.cs`](https://github.com/in0finite/SanAndreasUnity/blob/f685c437f48721afc0787f27d22c85d96e8684c7/Assets/Scripts/Behaviours/PedAI/IdleState.cs), `HandleOnMyPedDamaged`: interpreta quem atacou e o papel do NPC para escolher fuga ou perseguição. Serve para estudar a separação entre acontecimento, personalidade e resposta. O pedido posterior do criador alargou a revisão a socos e resposta policial; estes sistemas têm implementação própria no Álbum Visual.
- [`PedAI/WalkAroundState.cs`](https://github.com/in0finite/SanAndreasUnity/blob/f685c437f48721afc0787f27d22c85d96e8684c7/Assets/Scripts/Behaviours/PedAI/WalkAroundState.cs): conserva percurso e destino, reutiliza os tratamentos de eventos e contém reações com duração definida.
- [`PedAI/EscapeState.cs`](https://github.com/in0finite/SanAndreasUnity/blob/f685c437f48721afc0787f27d22c85d96e8684c7/Assets/Scripts/Behaviours/PedAI/EscapeState.cs) e [`PedAI/ChaseState.cs`](https://github.com/in0finite/SanAndreasUnity/blob/f685c437f48721afc0787f27d22c85d96e8684c7/Assets/Scripts/Behaviours/PedAI/ChaseState.cs): destino e direção desejada separados do movimento; limpeza de destino ao sair do estado; procura de novo alvo em atualização lenta.
- `PedAI.FindClosestWalkableNode`: limita a procura de nó a uma tentativa por dois segundos. `GetMoveDestinationBasedOnTargetNode` varia o destino dentro da largura do percurso. `PedSeesHeadOfAnotherPed` verifica primeiro o ângulo e depois a linha de visão através de raycast.
- [`Assets/Scripts/Behaviours/NPCPedSpawner.cs`](https://github.com/in0finite/SanAndreasUnity/blob/f685c437f48721afc0787f27d22c85d96e8684c7/Assets/Scripts/Behaviours/NPCPedSpawner.cs): limites de população global/perto do jogador, criação e remoção espaçadas, zonas de interesse e banda de distância para aparecer.
- [`Ped/States/BaseMovementState.cs`](https://github.com/in0finite/SanAndreasUnity/blob/f685c437f48721afc0787f27d22c85d96e8684c7/Assets/Scripts/Behaviours/Ped/States/BaseMovementState.cs): intervalo mínimo de permanência/retorno ao alternar estados de movimento, evitando mudanças demasiado rápidas.

Aplicação própria: cada pedestre tem percurso, personalidade e estado transitório. Aproximação pode provocar olhar; aproximação em trajetória de colisão pode provocar desvio; encontrão pode provocar recuo ou irritação; um temporizador devolve o NPC ao passeio ou à vigilância. Visão e distância filtram a perceção. Permanências mínimas e tempos de recuperação evitam alternar de resposta a cada frame.

A revisão inclui também dano por socos e perseguição policial com pressão gradual, testemunhas, linha de visão e intervalos entre golpes. Encontrões comuns não aumentam a pressão policial; a atuação musical protege o jogador e impede ataques. Os resultados de verificação destes comportamentos estão em [VALIDACAO.md](VALIDACAO.md).

A roupa e os arquétipos visuais não devem determinar automaticamente hostilidade. A personalidade é um conjunto de parâmetros separado, para permitir duas pessoas com aparência semelhante reagirem de formas diferentes.

### OpenSAMP e re3

Em OpenSAMP, [`native/net/netgame.h`](https://github.com/bssth/opensamp/blob/a05717eeab2de65d1def7e7725dc1985198400f7/native/net/netgame.h) e `native/net/netgame.cpp` definem a máquina de estados da **ligação de rede**, com entrada/saída e tempo no estado. Não são um sistema de personalidade de NPCs. O Álbum Visual continua single-player; não incorpora a DLL, os hooks nem a rede.

No re3-vc foram consultados `src/peds/CivilianPed.cpp`, `src/peds/PedAI.cpp`, `src/peds/Population.cpp` e `src/core/Streaming.cpp`. `CCivilianPed::CivilianAI` relaciona acontecimentos percebidos com medo, temperamento, objetivo atual e temporizadores de olhar/fuga; `ProcessControl` coordena estas tarefas com a locomoção. `CPopulation::ManagePopulation` distribui trabalho por fatias e verifica distância/visibilidade antes de retirar peões. `CStreaming::Update` separa pedidos, objetos distantes, população por zona e carregamento. São observações de arquitetura, não algoritmos copiados.

## Ambiente, LOD e distância

O ficheiro [`OpenLiberty/scripts/core/resources/map_data.gd`](https://github.com/openfw-game/OpenLiberty/blob/b2fcfd2b4c7cdd8d72f066178b9310c8e3c8a5a0/scripts/core/resources/map_data.gd) é a referência diretamente aplicável ao Godot:

- `instantiate()` atribui `visibility_range_end` aos modelos e `visibility_range_begin` aos seus LODs.
- `_load_texture_dictionary()` mantém uma cache de recursos já carregados.
- `_spawn_light()` usa redução de luz por distância e máscaras de iluminação.

A proposta do Álbum Visual é manter materiais e silhuetas lisboetas legíveis perto do jogador, retirar pormenores pequenos a distâncias maiores e conservar volumes mais simples para o horizonte. O nevoeiro disfarça a transição; a redução efetiva do trabalho vem da visibilidade, do LOD, da iluminação e da simulação por distância.

Em SanAndreasUnity, `World/Cell.cs` tem distâncias por camada, atualização de áreas ordenada por proximidade, orçamento por frame e fade. Em lcs-recomp foram consultados `README.md`, `lcs/README.md` e `lcs/config/LCSNative.ini`: distinguem resolução da janela, resolução interna, distância de visão e escolha de mipmaps. Estes controlos resolvem problemas diferentes e devem continuar separados.

**Gaussian splatting fica como investigação opcional.** Splats não trazem automaticamente um ganho no portátil alvo: exigem dados próprios, memória, ordenação e mistura de transparências; não substituem colisões nem personagens animadas. O primeiro caminho verificável para esta cidade é geometria low-poly texturada, LOD, nevoeiro e limites de população/luzes. Qualquer alternativa precisa de comparação no mesmo cenário e equipamento.

## Personagens e animação

Os projetos que importam GTA carregam os esqueletos, malhas, texturas e animações fornecidos pelo utilizador. Estudar o carregador não fornece esses recursos ao Álbum Visual. Nesta revisão, as personagens e a roupa são próprias: silhuetas humanas, articulação em quadris/joelhos/ombros/cotovelos e variedade de corpo, rosto, cabelo e vestuário.

Movimento orgânico exige relacionar deslocação e passada: alternância de apoio, flexão do joelho/cotovelo, contrarrotação de bacia e peito, transferência de peso e braços em oposição às pernas. A malha deve conservar volume anatómico e evitar membros com secções retangulares. A referência GTA III orienta proporções, leitura da silhueta e texturas; não significa copiar as suas personagens ou o HUD.

O catálogo de pelo menos dez homens e dez mulheres é distinto da população simultaneamente ativa. Limites próximos, animação mais simples à distância e atualização de IA espaçada têm de ser verificados no portátil HP antes de afirmar 60 FPS.

## Limites da análise

Esta documentação não certifica a qualidade, completude ou desempenho dos projetos externos. Não foram usados ficheiros de uma instalação de GTA. O código do jogo continua a poder executar sem os repositórios de referência e sem Internet. As funcionalidades efetivamente entregues e os resultados de testes pertencem ao README e ao registo de validação da revisão.
