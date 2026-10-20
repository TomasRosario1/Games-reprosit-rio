# Projeto Álbum Visual — documento de design

Este documento regista as decisões do criador. Descreve o jogo pretendido, não uma lista de funcionalidades já implementadas. A primeira experiência jogável está em desenvolvimento; consultar `ROADMAP.md` para o âmbito e as limitações dessa fase.

## Visão e prioridades

Aplicação desktop nativa, single-player e utilizável offline, desenvolvida em Godot 4. A história do álbum e a exploração são o centro da experiência. Combate, veículos, atividades musicais e personalidades dos habitantes dão vida à cidade e condicionam o acesso a alguns locais.

O universo aborda vida noturna, mulheres, dinheiro, drogas e álcool. Os protagonistas são inspirados nos autores da banda **«Odio puro no meu peito»**. O criador indica ter autorização da banda para usar as músicas; os ficheiros e recursos definitivos ainda têm de ser fornecidos e integrados.

Não há um fim obrigatório: começa-se num telhado e explora-se a cidade, descobrindo áreas, músicas e acontecimentos. A história é contada sobretudo por imagens, ambientes, comportamentos e música. Menus e missões podem ter texto; legendas são opcionais quando aplicáveis.

## Mundo e direção artística

- Lisboa atual, noturna e movimentada, com telhados, ruas, escadas, interiores e bares.
- Locais reais reinterpretados em low-poly; futuras áreas incluem Pink Street e o «Galito», associado ao after, comida e descontração.
- Primeira zona: um quarteirão fechado, compacto e explorável durante aproximadamente dez minutos.
- Referências principais: Matrix (jogo), Max Payne e Resident Evil 4.
- Proporções realistas, personagens com presença de action figure e vestuário com movimento secundário, incluindo o casaco.
- Todos os ativos 3D usam materiais texturados, com desgaste, humidade e sujidade. Evitar superfícies de cor lisa; usar PBR de custo adequado ao equipamento alvo.
- Modelos em GLB/GLTF, criados ou preparados no Blender. Recursos provisórios do protótipo devem ser identificados como tal.
- Iluminação de noite, néons e pontos de luz locais. Priorizar iluminação estática pré-calculada e limitar sombras dinâmicas.

## Personagens, movimento e veículos

Três homens adultos selecionáveis num menu inicial. Será possível trocar de personagem durante a exploração, possivelmente num ponto físico do mundo; a solução exata, os nomes e os modelos finais permanecem em aberto. Cada protagonista terá movimentos e uma atividade musical próprios, mantendo possibilidades de expansão.

Controlos pretendidos: WASD para andar, Shift para correr, Ctrl para agachar, salto e transposição de muros. Câmara em terceira pessoa, órbita pelo rato ou comando, colisão com o cenário e recentramento suave atrás da personagem depois de esta parar e não haver movimento da câmara durante algum tempo. Suporte a teclado/rato e comando.

Carros, motas, trotinetes e bicicletas devem ser conduzíveis no jogo pretendido. Entrar e sair utiliza interação contextual e animação, inspirado em GTA. Atropelamentos causam consequências; impactos frontais fortes podem projetar a personagem da bicicleta ou mota. Os quatro tipos fazem parte da visão final, ainda que a implementação seja repartida por fases.

## Cidade, NPCs e combate secundário

A cidade inclui peões, carros em circulação perto do jogador e som ambiente. Pelo menos cinco perfis de personalidade orientam os comportamentos:

1. Pessoa normal: reage sobretudo se for agredida.
2. Pessoa sob efeito de substâncias: postura mais parada e relaxada, olhos avermelhados, vocalização lenta e apontamentos sonoros locais.
3. Pessoa alcoolizada: pode irritar-se com encontrões; desequilíbrio, soluços e variações de volume nas vocalizações.
4. Segurança: observa, pode irritar-se após algum tempo, expulsar ou entrar em combate; também aceita pedidos e condições de acesso.
5. Polícia: há indivíduos tranquilos e uma pequena percentagem especialmente persistente e hostil. O comportamento não é idêntico em todos.

Alturas variadas. Polícias/bosses podem atingir cerca de 1,5 vezes a altura do protagonista; seguranças são ligeiramente mais pequenos. Bosses rondam ruas e bares e protegem acessos a novas áreas, festas e estabelecimentos.

Combate simples, inspirado na movimentação de GTA, com combinações curtas: por exemplo, três pressões produzem um golpe especial. A proposta inicial de quatro ataques por membro não é um requisito fechado após esta simplificação. Defesa, esquiva e detalhes dos golpes serão decididos nos testes de sensação de controlo.

Vozes são grunhidos e sons sem palavras claras: segurança com voz grossa e esforço físico; polícia com variação de tom e apitos semelhantes a sirenes; habitantes normais com fala inventada ao estilo de The Sims 1. As vocalizações são acompanhadas por texto quando comunicam uma missão. Sons locais não devem sobrepor-se continuamente à música do álbum.

## Missões, acessos e economia

Novos locais são desbloqueados através de missões, dinheiro entregue a um segurança, objetos como álcool ou droga e favores. Atividades possíveis: entregar ou transportar algo, encontrar pessoas, recuperar objetos e ajudar um bar a expulsar ou eliminar alguém. Há missões com habitantes, seguranças e polícias. Não assumir que todos os acessos exigem combate.

- Dinheiro obtido em missões e atuações musicais; outras fontes podem ser acrescentadas.
- Missão principal falhada pode ser repetida.
- Missão secundária falhada fica indisponível durante cinco minutos com a aplicação ligada. Não mostrar uma contagem: esconder a interação ou indicar indisponibilidade. Volta a estar disponível após esse tempo.
- Pessoas e objetos relevantes brilham apenas quando próximos: verde para droga, vermelho para objetos como pulseiras ou itens perdidos, azul para pessoas. Intensidade e alcance devem preservar a atmosfera.

## Música espacial e luz

Cada música ou conjunto do álbum pertence a um elemento, estabelecimento ou zona do mundo. A distribuição final das faixas ainda será desenhada. O som cresce e desaparece suavemente com a aproximação e afastamento; em bares, a saída é atenuada conforme o espaço, e música de rua pode estender-se por aproximadamente um quarteirão. Fora dessas áreas predomina o ambiente da cidade.

As faixas decorrem em loop mesmo sem o jogador perto. À distância, pode suspender-se a descodificação/reprodução para poupar recursos, mantendo um relógio virtual; ao regressar, retoma-se no ponto que corresponder ao tempo decorrido. Não reiniciar a música ao cruzar uma fronteira de zona nem aplicar cortes de volume.

Luzes são um sistema separado. Análise de frequências do áudio controla suavemente intensidade de luz e emissão dos materiais, sobretudo em resposta aos graves. A análise deve acontecer antes da atenuação causada pela distância. O protótipo pode usar uma aproximação rítmica identificada como provisória; análise de espectro real será validada com os ficheiros finais.

## Atuações musicais

Cantar, tocar ou fazer DJ, conforme a personagem. Uma interação abre uma lista de faixas apresentada como um papel, com pré-escuta da própria música. A atuação selecionada **recomeça do início**, ao contrário do loop da exploração.

- Minijogo de quatro teclas ou botões, com notas ao ritmo e animação da personagem.
- Três dificuldades. Fácil apresenta menos notas; normal e difícil aumentam o desafio e as oportunidades de pontuar.
- Cada acerto acumula 10 € em fácil/normal e 15 € em difícil. Uma faixa mais longa ou com mais notas oferece maior potencial de rendimento.
- Mostrar pontuação no canto superior esquerdo durante a atuação. O pagamento fica pendente até terminar com sucesso.
- Erros afastam o público. Acertos permitem recuperar o entusiasmo e algumas pessoas.
- Se todo o público sair, a atuação falha e não paga dinheiro.
- Enquanto atua, a personagem não pode atacar nem ser atacada.
- As notas têm de corresponder à música e à dificuldade; duração e ficheiro de áudio devem manter a sincronização.

## Vida, morte e persistência

A vida recupera após um minuto sem dano. Objetos de vida só são apanhados quando há vida em falta. Drogas e álcool têm efeitos temporários próprios: droga produz vinheta e ligeiro filtro esverdeado; embriaguez provoca balanço de câmara, desfoque e sensação de som mais distante. Implementar opções para reduzir efeitos desconfortáveis sem alterar as regras de jogo.

A morte apresenta a última música de cuja zona o jogador se aproximou, com distorção progressiva de som e imagem, até a imagem afunilar e desaparecer. Só depois surge um botão para voltar à vida.

- Renascimento num ponto seguro próximo do local da morte.
- Perda do dinheiro e do objeto que estava na mão.
- Bolsa com oito espaços: o conteúdo guardado permanece. Dinheiro é contabilizado à parte.
- O objeto equipado aparece na base do ecrã; a bolsa abre com uma tecla/botão próprio.
- Ao fechar e reabrir a aplicação, regressa-se ao telhado inicial, mantendo o restante progresso das sessões anteriores: dinheiro, inventário, missões e acessos.
- Gravação do jogador e gravação do mundo editado são conjuntos de dados separados.

## Interface

HUD discreto, com nome a flutuar sobre a personagem, sem moldura. Exceções funcionais: objeto equipado na base, bolsa aberta a pedido, indicação contextual de interação, texto de missão e interface temporária das atuações. Menus usam texto legível e símbolos. Separar narrativa visual de instruções necessárias para compreender a interação.

## Editor integrado e IA offline

**Requisito registado: a IA será integrada dentro do jogo, no modo de edição exclusivo do criador, com câmara de voo.** Atalho e palavra-passe evitam abertura acidental; não equivalem a uma barreira de segurança forte numa aplicação local.

Editor permite selecionar, instanciar e alterar objetos, luzes, materiais e transformações; a ambição futura inclui personagens, animações, áreas e mecânicas. Alterações persistem em dados locais, com IDs estáveis, cópias de segurança e desfazer/refazer.

A assistência recebe instruções por texto e contexto estruturado do Scene Graph, incluindo seleção, IDs, posições e propriedades editáveis próximas. Mostra a proposta e uma pré-visualização, com Aplicar, Cancelar e Desfazer. Pedidos ambíguos devem pedir esclarecimento.

Um modelo local, por exemplo Llama ou alternativa compatível, poderá ser executado através de llama.cpp ou Ollama. A ligação é local e pode funcionar offline depois da instalação inicial. A primeira integração deve produzir ações estruturadas e validadas; não executar texto arbitrário do modelo como código. Alterações de scripts exigem validação, testes e recuperação antes de serem aplicadas. Não prometer que qualquer pedido pode modificar o jogo instantaneamente.

O editor e a IA destinam-se à máquina de desenvolvimento. O jogo distribuído e o portátil HP não precisam de executar o modelo. A seleção final do modelo depende de medições reais de memória e desempenho.

## Equipamento e desempenho

| Uso | Equipamento | Diretriz |
| --- | --- | --- |
| Desenvolvimento portátil | Windows 10, ASUS VivoBook M513U, Ryzen 7 5700U com Radeon Graphics, 16 GB RAM | Godot e Blender, cenários compactos e modo Compatibility. |
| Tarefas pesadas e IA | Computador com RX 7600 XT e 16 GB RAM | Validar aceleração e modelo; não assumir compatibilidade de GPU sem teste. |
| Alvo para jogar | HP EliteBook 745 G2, AMD A8 PRO-7150B R5, 8 GB RAM | Objetivo de 60 FPS, inicialmente a 720p e qualidade baixa; **ainda não medido nem garantido**. |

Usar LOD, intervalos de visibilidade, carregamento por quarteirão, descarte de objetos ocultos e simulação de NPCs/trânsito por distância. Nevoeiro simples disfarça as distâncias curtas, mas só reduz trabalho quando acompanhado por limites reais de desenho. Controlar luzes, sombras, efeitos transparentes e sobreposição de áudio. Ruas com esquinas ajudam a limitar as vistas.

## Decisões ainda abertas

- Identidades finais, modelos e diferenças de movimento dos três protagonistas.
- Lista e duração das músicas, mapas de notas das atuações e distribuição das zonas sonoras.
- Nomes, sequência e escrita visual das missões principais e secundárias.
- Quantidade de interiores, trânsito e população simultânea compatível com o portátil alvo.
- Pormenores de inventário, dano de quedas e acidentes, e permanência de NPCs derrotados.
- Controlo exato de cada veículo e conjunto final de teclas/botões das atuações.
- Modelo local de IA e âmbito que cada etapa do editor poderá aplicar com segurança e qualidade.

Estas decisões não impedem o primeiro protótipo. Valores provisórios devem ser expostos para ajuste e não apresentados como escolhas definitivas do criador.
