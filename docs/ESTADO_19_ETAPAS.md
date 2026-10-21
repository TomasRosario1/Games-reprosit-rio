# Estado do projeto face às 19 etapas

Auditoria de **21 de outubro de 2026**, a partir do protótipo 02 (`402151c`) e do documento acrescentado pelo criador em `main` (`d18cd31`), [Ter como referencia](<../Ter como referencia>). Esta primeira tarefa é uma análise e documentação: **não altera scripts, cenas ou mecânicas do jogo**.

O novo documento acrescenta uma visão de três bairros ligados, geografia, trânsito e streaming. Isso não significa que estes sistemas já estejam implementados. Os recursos e sistemas funcionais do protótipo continuam a ser a base de trabalho.

Este relatório retrata a auditoria inicial dos commits indicados acima. Posteriormente o criador autorizou alterações de código, incluindo motion blur e melhorias no editor; consultar [a atualização e respetiva validação](VALIDACAO_EDITOR.md). Os mapas locais e a ponte continuam dependentes da [entrega dos ficheiros](ENTREGAR_MAPAS.md).

**Decisões confirmadas pelo criador em 21 de outubro:** a referência «GTA LISBOA» expande o **Álbum Visual**; música e exploração continuam no centro. O mapa será **compacto**, com dimensões proporcionais e realistas de personagens e edifícios, sem exigir as distâncias reais de Lisboa à escala 1:1.

## Estrutura encontrada

| Área | Ficheiros principais | Estado observado |
| --- | --- | --- |
| Entrada da aplicação | [project.godot](../project.godot), [main.tscn](../scenes/main.tscn), [main.gd](../scripts/main.gd) | Projeto desktop Godot 4 Compatibility. A cena principal instancia os sistemas por código. |
| Mundo | [world.gd](../scripts/world.gd) | Praça inspirada no Saldanha, telhado, escadas, ruas e Lado B construídos proceduralmente. Não é uma importação geográfica. |
| Personagens | [player.gd](../scripts/player.gd), [character_visual.gd](../scripts/character_visual.gd), [catálogo](../assets/characters/catalog.json) | Três escolhas provisórias de protagonista e vinte GLB humanos originais. |
| Habitantes e clube | [npc.gd](../scripts/npc.gd), [npc_population.gd](../scripts/npc_population.gd), [club_crowd.gd](../scripts/club_crowd.gd) | Perfis, perceção, percursos, população próxima e público que entra/sai pela porta. |
| Condução e polícia | [vehicle.gd](../scripts/vehicle.gd), [vehicle_manager.gd](../scripts/vehicle_manager.gd), [wanted_system.gd](../scripts/wanted_system.gd), [police_manager.gd](../scripts/police_manager.gd) | Quatro veículos originais de teste, soco simples, agentes locais e pressão policial. |
| Música e progresso | [rhythm_game.gd](../scripts/rhythm_game.gd), [rhythm_view.gd](../scripts/rhythm_view.gd), [save_store.gd](../scripts/save_store.gd) | Atuação, pagamentos, bolsa, perdas por morte e persistência. |
| Interface e ferramentas | [game_menu.gd](../scripts/game_menu.gd), [game_hud.gd](../scripts/game_hud.gd), [world_editor.gd](../scripts/world_editor.gd) | Pausa, HUD e editor integrado com gravação separada e cliente local Ollama. |

Não foram encontrados dados `.osm`, `.pbf` ou `.geojson`, setores geográficos exportados nem uma ferramenta OSM2World integrada no projeto. Os GLB existentes são as vinte personagens; os veículos e o cenário atuais são gerados em GDScript. A importação genérica de GLB no editor não fornece, por si só, estradas navegáveis, tráfego ou pontos de entrada de um veículo.

## Cobertura das etapas do criador

**Base disponível** significa que a função principal existe no protótipo, podendo ainda necessitar de afinação. **Parcial** significa que só parte do resultado descrito existe. **Por iniciar** significa que não foi encontrado o sistema pedido; elementos decorativos ou ferramentas genéricas não contam como essa implementação.

| Nº | Etapa, pela ordem do documento | Estado | Evidência e trabalho em falta |
| ---: | --- | --- | --- |
| 1 | Organizar o projeto Godot, GitHub e Codex | Base disponível | Projeto Godot, [instruções](../README.md), [AGENTS.md](../AGENTS.md), scripts e testes organizados. Preservar a sincronização da branch de trabalho e informar o link exato; atualizar uma branch não equivale a integrar `main`. |
| 2 | Importar o Saldanha | Parcial | [world.gd](../scripts/world.gd) já cria uma interpretação da praça. Faltam a delimitação geográfica, os dados OSM e a conversão/preparação do mapa real ou adaptado. |
| 3 | Desenvolver física de veículos e entrada/saída | Parcial | [vehicle.gd](../scripts/vehicle.gd) e [vehicle_manager.gd](../scripts/vehicle_manager.gd): quatro tipos conduzíveis, aceleração, marcha-atrás, travagem, direção, colisão e transições com o mesmo avatar. Faltam suspensão, derrapagem/travão de mão próprios, dano completo e animações finais. |
| 4 | Adicionar Pink Street e Bairro Alto e preparar as ligações | Por iniciar | Não existem esses bairros, ligações geográficas ou streaming entre setores. Requer delimitar os setores do mapa compacto e estabelecer um sistema de coordenadas comum. |
| 5 | Consolidar movimentação da personagem | Parcial | [player.gd](../scripts/player.gd): caminhar, correr, agachar, saltar, colisões e câmara. As animações de estudo existem; apoio dos pés, transições, escalada e sensação de controlo ainda precisam de afinação. |
| 6 | Importar modelos 3D de veículos | Por iniciar | Os quatro veículos atuais são modelos próprios gerados em [vehicle.gd](../scripts/vehicle.gd), não modelos externos importados. É necessário fornecer ou produzir modelos com licença, preparar materiais, rodas, portas e pontos de acesso e ligá-los ao controlador. |
| 7 | Investigar e integrar referências de código aberto | Parcial | [REFERENCIAS_NPCS.md](REFERENCIAS_NPCS.md) documenta cinco projetos estudados, ficheiros e limites de licença. O código desta base é próprio. As novas referências com nomes genéricos exigem identificação do repositório/versão antes de qualquer incorporação. |
| 8 | Criar sistema policial e cinco níveis de procura | Parcial | [wanted_system.gd](../scripts/wanted_system.gd) calcula pressão contínua 0–100, separável em cinco níveis; [police_manager.gd](../scripts/police_manager.gd) faz patrulha e perseguição local por visão. Não existem cinco respostas policiais distintas, viaturas policiais ou perseguição de crimes cometidos por NPCs. |
| 9 | Desenvolver movimentação básica de NPCs | Base disponível | [npc.gd](../scripts/npc.gd) e [npc_population.gd](../scripts/npc_population.gd): percursos, espera, desvio, colisões e orçamento por distância. Ainda não há rede urbana de passadeiras, destinos entre bairros ou rotinas de cidade completa. |
| 10 | Desenvolver reações e interações dos NPCs | Parcial | Há aproximação, olhar, encontrão, susto, irritação/recuo e recuperação, com cinco perfis. [club_crowd.gd](../scripts/club_crowd.gd) mantém clientes persistentes. Faltam conversas entre NPCs, pedidos de ajuda, resposta a todos os acidentes, entrada/saída de veículos e personalidades dos condutores. |
| 11 | Criar trânsito e condutores autónomos | Por iniciar | Os cinco carros decorativos de [world.gd](../scripts/world.gd) seguem trajetos retos e reaparecem no extremo do percurso. Não têm condutor, decisões em cruzamentos, semáforos funcionais ou ligação à física dos veículos conduzíveis. Não constituem o trânsito autónomo pedido. |
| 12 | Aperfeiçoar a estética GTA III | Parcial | Materiais urbanos texturados, nevoeiro, luz quente, catálogo humano articulado e guarda-roupa próprio já existem. A leitura de Lisboa, anatomia, fachadas, iluminação e continuidade artística continuam a precisar de revisão visual. |
| 13 | Desenvolver três missões iniciais e preparar dez | Parcial | Há o favor da pulseira para abrir o bar e a atividade musical, em [main.gd](../scripts/main.gd). O editor cria marcadores simples com recompensa única. Ainda não existem três missões narrativas completas, duas missões iniciais disponíveis em simultâneo, dez missões ou condições distintas de sucesso/falha para cada tipo. |
| 14 | Implementar HUD personalizado | Parcial | [game_hud.gd](../scripts/game_hud.gd): dinheiro a nove algarismos, vida, objeto/punho e indicador policial contínuo de cinco partes. [game_menu.gd](../scripts/game_menu.gd) tem mapa esquemático na pausa; falta o minimapa durante a exploração e os marcadores de toda a cidade. |
| 15 | Desenvolver combate | Parcial | Soco simples e dano em [main.gd](../scripts/main.gd), [punch_modifier.gd](../scripts/punch_modifier.gd), NPCs e polícia. Faltam combos, armas, combate entre NPCs e consequências completas. Continua a ser um sistema secundário: a expansão mantém música e exploração como centro. |
| 16 | Integrar animações das personagens | Parcial | Vinte GLB com rig e clips de locomoção/reação/dança; poses de condução e pedalada em [character_visual.gd](../scripts/character_visual.gd). Falta afinar contactos, transições, mãos, casaco e animações específicas de interação/entrada/saída. |
| 17 | Adicionar áudio e música | Parcial | Três ensaios sintetizados, ambiente de cidade, aproximação suave, loop virtual, pré-escuta, atuação e luz reativa já funcionam na base. Faltam as músicas autorizadas da banda, mapas de notas finais, mistura, vocalizações e sons específicos de Lisboa. Não remover o áudio existente por aparecer tarde na nova sequência. |
| 18 | Otimizar, testar e expandir a cidade | Parcial | Limites reais de desenho, geometria agrupada, população suspensa à distância e perfis de qualidade. Há testes e validação anteriores; falta streaming de setores, expansão da cidade, perfis no hardware real e exportação Windows validada. Os 60 FPS no HP continuam por medir. |
| 19 | Criar editor integrado no jogo | Base disponível | [world_editor.gd](../scripts/world_editor.gd) e [guia](EDITOR.md): voo, seleção, transformações, materiais/luzes, catálogo, NPCs, veículos, missões simples, desfazer/refazer e JSON com backup. Preservar este trabalho. A ligação Ollama não inclui modelo e não foi validada com inferência real; editar toda a lógica por IA continua futuro. |

## Dependências e imprecisões a resolver

1. **Identidade e prioridade — resolvido.** «GTA LISBOA» é referência técnica e expansão do Álbum Visual de «Odio puro no meu peito». Conservar música, bar, personagens e regras existentes; a nova visão não autoriza transformá-lo num projeto separado ou substituir a prioridade musical por combate.
2. **Escala — resolvido.** Usar um mapa compacto, com personagens, portas, veículos e edifícios proporcionais, mas ligações entre bairros adaptadas. Não reproduzir vários quilómetros de distâncias reais apenas por o documento dizer «escala real». Os limites e percursos concretos dos setores continuam um trabalho de desenho do mapa.
3. **Geografia.** Lisboa confronta com o Tejo/estuário. Uma península envolvida por oceano e limitada a norte por montanhas é uma adaptação fictícia, não uma descrição literal dos três bairros. O mapa pode ser estilizado, mas deve distinguir esta opção de uma reprodução geográfica real.
4. **Ferramentas e recursos.** A lista OSM/OSM2World descreve ferramentas pretendidas, não dependências já configuradas nem modelos entregues. A base geográfica precisa de fonte, área, data, atribuição e preparação para jogabilidade. Uma licença do código de um importador não abrange automaticamente os dados visuais que ele importa de GTA.
5. **Ordem de implementação.** Editor, HUD, áudio e animação já existem parcialmente ou como base funcional. A nova ordem orienta o trabalho que falta; não justifica apagá-los e refazê-los para voltar à etapa 1. Com a escala compacta decidida, a integração entre bairros depende de coordenadas, ligações e limites dos setores.
6. **Missões.** Os tipos «visitar», «encontro» e «recolher» do editor são rótulos de marcadores simples nesta base; não equivalem a três missões distintas com regras de recolha e falha já implementadas. As três missões iniciais ainda precisam de desenho concreto.

### Lista de técnicas visuais

- Gaussian splatting é uma técnica moderna, não uma técnica usada na PS2, e não garante menor custo no PC alvo. Mantém-se como investigação opcional.
- Nevoeiro e escuridão ajudam a composição e escondem transições; só reduzem trabalho quando associados a limites de desenho, LOD, iluminação e simulação efetivos.
- Motion blur, bloom, profundidade de campo, transparências e múltiplas passagens podem aumentar o custo. Devem ser opções artísticas medidas, não uma lista de otimizações a ativar por inteiro.
- Field blending e offsets de apresentação entrelaçada respondem a limitações de vídeo da época. Microprogramas VU são específicos do hardware PS2. Não são requisitos para reproduzir a estética em Godot num ecrã progressivo de PC.
- Mipmaps, filtragem, atlas, luz pré-calculada, culling e detalhe controlado são referências úteis, escolhidas consoante o renderer Compatibility e medições reais.
- Existem repetições na lista: Vertex Colors nos pontos 17/18, Desaturation em 46/47 e partículas 2D em 55/56. Não representam funcionalidades diferentes.

## Validação e próximo passo

Esta auditoria é uma leitura do código, recursos e documentação, não uma nova execução de cada funcionalidade nem uma certificação visual. O [registo de validação do protótipo 02](VALIDACAO.md) documenta as 824 verificações anteriores, Godot 4.6.3 em Linux e os limites de Windows, comando físico, modelo local e desempenho no HP.

Como verificação de arranque nesta sessão, a cópia recebida do GitHub foi importada de novo com Godot 4.6.3 e `tests/features_test.gd` passou **62 verificações, sem falhas**, com dados locais isolados. Não se repetiram as 14 suites completas nesta tarefa documental. Nenhum script, cena, recurso de jogo ou teste foi alterado.

O [plano do mapa contínuo](PLANO_MAPA_CONTINUO.md) propõe integrar a geografia por setores no projeto existente, preservando o percurso jogável e aplicando as decisões de identidade e escala já confirmadas. A próxima implementação deve ser uma tarefa pequena de validação do primeiro setor; esta auditoria não constrói toda a península nem modifica o código nesta primeira tarefa.
