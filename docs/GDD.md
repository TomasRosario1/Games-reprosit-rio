# Projeto Álbum Visual — documento de design

Este documento regista as decisões do criador e o âmbito implementado. A revisão de 22 de outubro de 2026 desenvolve o mapa contínuo dos três bairros, interiores visitáveis, movimento das personagens, veículos e DJ na Pink Street. Os resultados concretos e a evidência visual estão em [Revisão de Lisboa](REVISAO_LISBOA.md); a visão completa do jogo continua mais ampla do que esta entrega.

## Visão e prioridades

O criador autorizou avançar no código, confirmou **motion blur** como escolha artística e admitiu Gaussian splatting em planos específicos quando houver dados e vantagem demonstrada. Os mapas foram depois enviados em `Maps.rar`: os dois OSM originais estão preservados no projeto e deram origem aos recortes de Saldanha, Bairro Alto e Pink Street. O motion blur é regulável e o editor dispõe de eixos arrastáveis, grelha e vistas rápidas; consultar [a validação dessas ferramentas](VALIDACAO_EDITOR.md).

A referência «GTA LISBOA», em [Ter como referencia](<../Ter como referencia>), expande o Álbum Visual: música e exploração continuam no centro. O mapa é compacto, com edifícios e pessoas proporcionais, sem reproduzir as distâncias reais entre bairros. A península, a sua costa e os desníveis são uma composição própria inspirada em Lisboa; os recortes OSM conservam o desenho e os IDs de origem. A [auditoria das 19 etapas](ESTADO_19_ETAPAS.md) e o [plano do mapa contínuo](PLANO_MAPA_CONTINUO.md) registam o estado anterior à implementação, não o estado atual.

Aplicação desktop nativa, single-player e utilizável offline, desenvolvida em Godot 4. A história do álbum e a exploração são o centro da experiência. Combate, veículos, atividades musicais e personalidades dos habitantes dão vida à cidade e condicionam o acesso a alguns locais.

O universo aborda vida noturna, mulheres, dinheiro, drogas e álcool. Os protagonistas são inspirados nos autores da banda **«Odio puro no meu peito»**. O criador indica ter autorização da banda para usar as músicas; os ficheiros e recursos definitivos ainda têm de ser fornecidos e integrados.

Não há um fim obrigatório: começa-se num telhado e explora-se a cidade, descobrindo áreas, músicas e acontecimentos. A história é contada sobretudo por imagens, ambientes, comportamentos e música. Menus e missões podem ter texto; legendas são opcionais quando aplicáveis.

## Âmbito implementado na revisão atual

- Península contínua de cerca de 0,77 km² com Saldanha, Bairro Alto e Pink Street, ruas alternativas, terreno com desníveis, cais, rio e Ponte 25 de Abril estilizada. Os 598 contornos OSM conservados juntam-se a 290 edifícios próprios, distribuídos por 191 setores de construções. Alturas em falta são inferidas; a costa e o relevo são autorais.
- Dezoito estabelecimentos com interiores e portas físicas, incluindo restaurantes, conveniências, bares, fado, kebabs e discoteca. Três prédios têm três pisos, escadas de madeira e terraços acessíveis. Cada estabelecimento tem nome, configuração e mobiliário próprios; isto não implica já um sistema de compras ou missões diferente em cada loja.
- A sessão começa no telhado do prédio do Saldanha e permite descer pelo interior até à rua. A praça da Madrugada e o Lado B anteriores continuam acessíveis.
- Catálogo original de vinte adultos, dez homens e dez mulheres, com malhas humanas, esqueleto, texturas e guarda-roupa variado. A revisão corrige orientação dos pés, flexão dos joelhos e abaixamento da bacia ao agachar; a cápsula segue a postura. Passada ligada à velocidade real, subida de degraus baixos e câmara suavizada.
- Peões com passeio, olhar, desvio e respostas distintas a encontrões. A população próxima é ajustável entre seis, dez e dezasseis peões de rua; o catálogo completo não exige vinte simulações completas em permanência.
- Atuação disponível no Lado B e na discoteca da Pink Street. Os oito clientes de cada pista persistem, dançam, visitam o balcão e percorrem a porta real para sair ou regressar conforme a atuação.
- Carro, mota, bicicleta e trotinete conduzíveis, disponíveis perto do prédio inicial. Há aproximação, entrada/saída, poses articuladas, travagem, buzina, contacto com inclinações e superação de ressaltos baixos. Os acidentes fortes provocam dano visual; o trânsito usa os mesmos veículos físicos e condutores, com um orçamento próximo separado dos peões.
- Ataque simples desarmado e polícia local com perceção, perseguição, aviso e bastão. A pressão policial sobe pelos crimes configurados e desce gradualmente quando o jogador deixa de ser visto; um encontrão normal não aumenta a pressão.
- HUD persistente com dinheiro em euros a nove algarismos, vida, indicador de punhos/objeto equipado e pressão numa barra contínua dividida em cinco partes. O nome permanece sobre a personagem.
- Menu de pausa com nove separadores, opções de qualidade/população, mapa esquemático, controlos, áudio, brilho, legendas, guardar/carregar, editor e saída com confirmação.
- Editor dentro do jogo com acesso por F10 ou pelo menu, palavra-passe local, câmara de voo, seleção e inspetor, catálogo, desfazer/refazer e mundo guardado em JSON separado do progresso do jogador.
- Painel de ligação ao Ollama local para propostas estruturadas sobre objetos existentes, com pré-visualização, Aplicar, Cancelar e Desfazer. Nenhum modelo é incluído; a inferência com um modelo real ainda não foi validada neste ambiente.

## Mundo e direção artística

- Lisboa atual, noturna e movimentada, com telhados, ruas, escadas, interiores e bares.
- Locais reais reinterpretados em low-poly; Saldanha, Bairro Alto e Pink Street integram o mapa atual. O «Galito», associado ao after, comida e descontração, continua uma área narrativa por desenvolver.
- Exploração contínua entre praça, ruas, telhados, interiores e rio, com saídas alternativas em cada bairro. Os três recortes não devem funcionar como ruas isoladas, e os edifícios e estabelecimentos próprios completam a ligação. A primeira exploração deve ser legível sem obrigar a usar o editor para encontrar os locais.
- A fotografia fornecida pelo criador orienta a revisão: fachadas urbanas de Lisboa, proporções humanas, noite escura, janelas iluminadas e candeeiros de luz quente. GTA III é a referência principal de leitura low-poly desta fase; Matrix, Max Payne e Resident Evil 4 continuam como referências complementares.
- Proporções adultas realistas, com volume anatómico em ombros, peito, bacia, braços e pernas. Evitar o aspeto de blocos, prismas ou membros retangulares apenas unidos para formar uma pessoa. A presença de action figure não significa anatomia de brinquedo em blocos.
- Personagens com malhas articuladas por esqueleto e pele deformável, silhuetas legíveis e vestuário com movimento secundário, incluindo o casaco. O tratamento permanece low-poly e texturado.
- Roupa varia a silhueta além da cor: saias de comprimentos e cortes diferentes, calças estreitas/largas, camisolas, sweats, casacos e outras peças adequadas à noite lisboeta. Cor, tecido, cabelo, rosto, altura e constituição completam a variedade.
- Todos os ativos 3D usam materiais texturados, com desgaste, humidade e sujidade. Evitar superfícies de cor lisa; usar PBR de custo adequado ao equipamento alvo.
- Personagens em GLB/GLTF, criadas no Blender; edifícios e veículos próprios usam também geometria gerada pelo jogo. Distinguir estes recursos incluídos de músicas e identidades finais da banda ainda por integrar.
- Iluminação de noite, néons e pontos de luz locais. Priorizar iluminação estática pré-calculada e limitar sombras dinâmicas.

## Personagens, movimento e veículos

Três homens adultos selecionáveis num menu inicial. Será possível trocar de personagem durante a exploração, possivelmente num ponto físico do mundo; a solução exata, os nomes e os modelos finais permanecem em aberto. Cada protagonista terá movimentos e uma atividade musical próprios, mantendo possibilidades de expansão.

A animação deve acompanhar o deslocamento: passada proporcional à velocidade, flexão de joelhos e cotovelos, alternância de apoio, transferência de peso e contrarrotação da bacia e do peito. Braços, pernas e tronco formam uma ação coordenada, com transições suaves entre parado, andar, correr e agachar. Evitar deslizar sobre o chão, braços rígidos ou balanço isolado de membros sem reação do corpo.

Controlos pretendidos: WASD para andar, Shift para correr, Ctrl para agachar, salto e transposição de muros. Câmara em terceira pessoa, órbita pelo rato ou comando, colisão com o cenário e recentramento suave atrás da personagem depois de esta parar e não haver movimento da câmara durante algum tempo. Suporte a teclado/rato e comando.

A revisão disponibiliza carro, mota, trotinete e bicicleta conduzíveis. A interação aproxima o avatar do acesso e usa poses e transições para entrar, conduzir e sair. O movimento é arcade, com rodas a acompanhar inclinações, limites de subida próprios de cada veículo e dano visível após impactos fortes. A bicicleta relaciona a pedalada com os pedais do veículo. As animações de interação ainda precisam de acabamento artístico; não são extraídas de GTA. Atropelamentos e projeção após impactos frontais fortes nos veículos de duas rodas continuam a exigir afinação própria de cada tipo.

## Cidade, NPCs e combate secundário

**Revisão atual:** aproximação, olhar, desvio, reação a encontrões e retoma do percurso formam a base dos peões. A revisão também inclui um soco simples, danos e resposta policial próxima para experimentar a pressão policial pedida. O combate continua secundário; combos completos, arsenal e bosses narrativos não estão concluídos.

O catálogo deve conter pelo menos **dez homens e dez mulheres adultos**, com modelos e combinações de roupa suficientemente distintos para serem reconhecíveis. Inclui estilos beto, alternativo, chunga, emo, normal, indie e misturas entre eles. Estes estilos são referências visuais de roupa e postura; os parâmetros comportamentais permanecem independentes, para evitar que uma determinada roupa produza sempre a mesma reação.

Catálogo e população ativa são conjuntos diferentes: distribuir as vinte variantes pelo bairro com uma quantidade próxima ajustável. Não exigir que os vinte modelos tenham sempre física, animação e perceção completas simultaneamente. O limite final depende de medição no portátil alvo.

As reações usam distância e perceção do jogador, orientação/linha de visão quando aplicável, velocidade de aproximação, tolerância pessoal e tempos de recuperação. Uma aproximação normal pode provocar um olhar ou um desvio; um encontrão pode provocar susto, recuo ou irritação. A reação deve terminar de forma legível e permitir regressar à caminhada, espera ou vigilância. Não alternar entre reações a cada frame nem deixar um NPC preso num ciclo de protesto.

A cidade inclui peões, carros em circulação perto do jogador e som ambiente. Pelo menos cinco perfis de personalidade orientam os comportamentos:

1. Pessoa normal: reage sobretudo se for agredida.
2. Pessoa sob efeito de substâncias: postura mais parada e relaxada, olhos avermelhados, vocalização lenta e apontamentos sonoros locais.
3. Pessoa alcoolizada: pode irritar-se com encontrões; desequilíbrio, soluços e variações de volume nas vocalizações.
4. Segurança: observa, pode irritar-se após algum tempo, expulsar ou entrar em combate; também aceita pedidos e condições de acesso.
5. Polícia: há indivíduos tranquilos e uma pequena percentagem especialmente persistente e hostil. O comportamento não é idêntico em todos.

Alturas variadas. Polícias/bosses podem atingir cerca de 1,5 vezes a altura do protagonista; seguranças são ligeiramente mais pequenos. Bosses rondam ruas e bares e protegem acessos a novas áreas, festas e estabelecimentos.

O ataque atual é um soco desarmado acionado pelo botão esquerdo do rato ou X/quadrado no comando, com alcance, orientação e intervalo entre golpes. Os agentes próximos podem perseguir e usar o bastão depois de um aviso; o jogador fica protegido durante a atuação. O acesso da primeira missão não deve ser bloqueado pela remoção do segurança. A visão final mantém combinações curtas inspiradas em GTA, por exemplo três pressões para um golpe especial; defesa, esquiva e o conjunto final de golpes continuam por desenvolver.

As vocalizações finais ainda precisam de produção e integração. A direção pretendida usa grunhidos e sons sem palavras claras: segurança com voz grossa e esforço físico; polícia com variação de tom e apitos semelhantes a sirenes; habitantes normais com fala inventada ao estilo de The Sims 1. As vocalizações são acompanhadas por texto quando comunicam uma missão. Sons locais não devem sobrepor-se continuamente à música do álbum.

## Missões, acessos e economia

Novos locais são desbloqueados através de missões, dinheiro entregue a um segurança, objetos como álcool ou droga e favores. Atividades possíveis: entregar ou transportar algo, encontrar pessoas, recuperar objetos e ajudar um bar a expulsar ou eliminar alguém. Há missões com habitantes, seguranças e polícias. Não assumir que todos os acessos exigem combate.

- Dinheiro obtido em missões e atuações musicais; outras fontes podem ser acrescentadas.
- Missão principal falhada pode ser repetida.
- Missão secundária falhada fica indisponível durante cinco minutos com a aplicação ligada. Não mostrar uma contagem: esconder a interação ou indicar indisponibilidade. Volta a estar disponível após esse tempo.
- Pessoas e objetos relevantes brilham apenas quando próximos: verde para droga, vermelho para objetos como pulseiras ou itens perdidos, azul para pessoas. Intensidade e alcance devem preservar a atmosfera.

O editor já permite colocar marcadores simples de missão de visita, encontro ou recolha, editar título e recompensa e concluí-los por interação. A recompensa é entregue uma só vez e o estado de conclusão é guardado com o mundo editado. Isto não equivale ainda a um sistema completo de missões com transporte, diálogos ramificados, condições de acesso e a sequência narrativa do álbum.

## Música espacial e luz

Cada música ou conjunto do álbum pertence a um elemento, estabelecimento ou zona do mundo. A distribuição final das faixas ainda será desenhada. O som cresce e desaparece suavemente com a aproximação e afastamento; em bares, a saída é atenuada conforme o espaço, e música de rua pode estender-se por aproximadamente um quarteirão. Fora dessas áreas predomina o ambiente da cidade.

As faixas decorrem em loop mesmo sem o jogador perto. À distância, pode suspender-se a descodificação/reprodução para poupar recursos, mantendo um relógio virtual; ao regressar, retoma-se no ponto que corresponder ao tempo decorrido. Não reiniciar a música ao cruzar uma fronteira de zona nem aplicar cortes de volume.

Luzes são um sistema separado. Análise de frequências do áudio controla suavemente intensidade de luz e emissão dos materiais, sobretudo em resposta aos graves. A análise deve acontecer antes da atenuação causada pela distância. O protótipo analisa o espectro das faixas de ensaio e suaviza a reação das luzes. É necessário afinar e validar esta resposta com as músicas finais da banda.

## Atuações musicais

Cantar, tocar ou fazer DJ, conforme a personagem. O bar/club da revisão aproxima-se da atmosfera de uma atuação de DJ de The Ballad of Gay Tony: pista, luzes de clube, pessoas a dançar, circulação e presença do DJ. A direção mantém recursos originais, low-poly e a identidade lisboeta; a referência não autoriza copiar personagens, música ou modelos do jogo.

O público tem presença física coerente. Pessoas entram e saem pela porta real, percorrem o espaço e acedem à pista; não aparecem no chão nem desaparecem instantaneamente no meio da sala. Quando a atuação perde público, as pessoas deixam a dança e caminham para a saída; quando recupera, podem regressar caminhando. Filas, pontos de espera e circulação devem manter livres a porta, o balcão e o percurso do jogador. O protótipo já implementa dança e percursos físicos de entrada/saída; os gestos, a densidade, o ritmo de circulação e a coreografia final continuam sujeitos a afinação visual.

Uma interação abre uma lista de faixas apresentada como um papel, com pré-escuta da própria música. A atuação selecionada **recomeça do início**, ao contrário do loop da exploração.

- Minijogo de quatro teclas ou botões, com notas ao ritmo e animação da personagem.
- Três dificuldades. Fácil apresenta menos notas; normal e difícil aumentam o desafio e as oportunidades de pontuar.
- Cada acerto acumula 10 € em fácil/normal e 15 € em difícil. Uma faixa mais longa ou com mais notas oferece maior potencial de rendimento.
- Mostrar pontuação no canto superior esquerdo durante a atuação. O pagamento fica pendente até terminar com sucesso.
- Erros afastam o público. Acertos permitem recuperar o entusiasmo e algumas pessoas.
- Se todo o público sair, a atuação falha e não paga dinheiro.
- Enquanto atua, a personagem não pode atacar nem ser atacada.
- As notas têm de corresponder à música e à dificuldade; duração e ficheiro de áudio devem manter a sincronização.

## Vida, morte e persistência

Na visão final, a vida recupera após um minuto sem dano e os objetos de vida só são apanhados quando há vida em falta. Os efeitos completos de objetos e a sua afinação continuam planeados. Drogas e álcool terão efeitos temporários próprios: droga produz vinheta e ligeiro filtro esverdeado; embriaguez provoca balanço de câmara, desfoque e sensação de som mais distante. Implementar opções para reduzir efeitos desconfortáveis sem alterar as regras de jogo.

A morte apresenta a última música de cuja zona o jogador se aproximou, com distorção progressiva de som e imagem, até a imagem afunilar e desaparecer. Só depois surge um botão para voltar à vida.

- Renascimento num ponto seguro próximo do local da morte.
- Perda do dinheiro e do objeto que estava na mão; a pressão policial é limpa.
- Bolsa com oito espaços: o conteúdo guardado permanece. Dinheiro é contabilizado à parte.
- O objeto equipado aparece na base do ecrã; a bolsa abre com uma tecla/botão próprio.
- Ao fechar e reabrir a aplicação, regressa-se ao telhado inicial, mantendo o restante progresso das sessões anteriores: dinheiro, inventário, missões e acessos.
- Gravação do jogador e gravação do mundo editado são conjuntos de dados separados.

## Interface

A especificação atual usa HUD persistente de estado: dinheiro em euros formatado com nove algarismos, vida, indicador de punhos/objeto equipado e pressão policial. A pressão tem um preenchimento contínuo suavizado de zero a cem, dividido visualmente em cinco partes, sem substituir a regra contínua por cinco saltos discretos. O ícone de arma é uma indicação de estado; o protótipo só entrega combate desarmado. O nome flutua sobre a personagem, sem fundo.

A bolsa de oito espaços abre a pedido; interação, texto de missão e interface de atuação aparecem no respetivo contexto. Os menus usam texto legível e símbolos. A pausa tem nove separadores: Jogo/Brief, Mapa, Qualidade, HUD, Controlos, Áudio, Guardar/Carregar, Editor e Sair. Inclui redefinição de teclas/botões, três perfis de qualidade, população separada da qualidade, volumes por canal, brilho, legendas e confirmação de saída. O mapa é esquemático e usa os limites/avenidas/ligações dos recortes, com jogador, zonas de música e ponte; não é ainda um minimapa detalhado de navegação.

Definições do menu, progresso do jogador e mundo editado são dados locais separados. A narrativa permanece predominantemente visual, mantendo as instruções necessárias para compreender a interação.

## Editor integrado e IA offline

O editor já está dentro da aplicação, exclusivo do criador. Abre com **F10** ou pelo separador Editor da pausa. Na primeira utilização define-se uma palavra-passe local; o acesso mantém-se desbloqueado na sessão. O ficheiro local guarda salt e hash, não a palavra-passe em claro. Este mecanismo evita abertura casual e não constitui uma barreira forte contra alguém que controla o computador.

A câmara de voo é independente da personagem. Permite selecionar objetos na cena ou na lista, alterar posição, rotação, escala, cor e materiais predefinidos, ajustar propriedades das luzes e escolher aparência/personalidade dos NPCs. O catálogo inclui peças, paredes, portas, luzes, NPCs, marcadores de missão e os quatro tipos de veículo. Modelos GLB/GLTF já integrados no projeto podem ser instanciados. Há duplicação, remoção, Desfazer e Refazer.

As alterações são guardadas em `world_edits.json`, separadas do progresso do jogador. A gravação usa um ficheiro temporário e backup; o carregamento valida os dados e pode recorrer ao backup. Os IDs dos edifícios importados são estáveis e as edições de setores descarregados são conservadas. A revisão 2 do mapa adapta as edições antigas do Bairro Alto ao novo patamar de oito metros, sem repetir o ajuste no carregamento seguinte. Os marcadores de missão guardam a conclusão e evitam repetir a recompensa. Cadeias narrativas, condições complexas e edição geral de comportamentos continuam futuras.

O painel de assistência envia texto e um Scene Graph com IDs e propriedades ao **Ollama em `127.0.0.1:11434`**. O criador precisa de instalar e iniciar o Ollama e descarregar previamente um modelo adequado; não há um modelo incluído. A ligação pode operar sem Internet depois dessa preparação. A inferência com um modelo real não foi validada neste ambiente, pelo que não se declara o assistente local integralmente pronto.

A integração aceita propostas JSON limitadas sobre IDs existentes, para transformações, cores, materiais predefinidos e luzes. Valida campos, limites e objetos antes da pré-visualização. O criador pode Aplicar, Cancelar ou Desfazer. A proposta não é executada como código arbitrário e não cria modelos, animações ou mecânicas completas por si só.

A ambição de editar visualmente e mecanicamente todo o jogo permanece no plano futuro: ampliar operações, pedir esclarecimento quando um pedido é ambíguo e testar alterações de scripts com recuperação. Não prometer que qualquer comando pode modificar o jogo instantaneamente.

O editor e o modelo local destinam-se à máquina de desenvolvimento, preferencialmente ao computador com RX 7600 XT para as tarefas mais pesadas. O jogo distribuído e o portátil HP não precisam de executar a IA. A seleção final do modelo depende de medições reais de memória, compatibilidade e desempenho.

## Equipamento e desempenho

| Uso | Equipamento | Diretriz |
| --- | --- | --- |
| Desenvolvimento portátil | Windows 10, ASUS VivoBook M513U, Ryzen 7 5700U com Radeon Graphics, 16 GB RAM | Godot e Blender, cenários compactos e modo Compatibility. |
| Tarefas pesadas e IA | Computador com RX 7600 XT e 16 GB RAM | Validar aceleração e modelo; não assumir compatibilidade de GPU sem teste. |
| Alvo para jogar | HP EliteBook 745 G2, AMD A8 PRO-7150B R5, 8 GB RAM | Objetivo de 60 FPS, inicialmente a 720p e qualidade baixa; **ainda não medido nem garantido**. |

Usar LOD, intervalos de visibilidade, carregamento por quarteirão, descarte de objetos ocultos e simulação de NPCs/trânsito por distância. A revisão deve associar nevoeiro de distância a redução real de detalhe e de objetos desenhados: pormenor legível perto, volumes mais simples longe e horizonte disfarçado pela névoa. O nevoeiro simples, inspirado na profundidade atmosférica de Shadow of the Colossus, só reduz trabalho quando acompanhado por esses limites; não basta baixar o contraste dos mesmos objetos.

Gaussian splatting fica como investigação opcional, não como técnica predefinida nem garantia de leveza. Uma experiência futura exige recursos próprios, integração compatível, colisões separadas e comparação de memória, transparências e tempo de frame no equipamento alvo.

Controlar luzes, sombras, efeitos transparentes e sobreposição de áudio. Ruas com esquinas ajudam a limitar as vistas.

## Revisão atual e fontes

A península, os três bairros, os 18 interiores, o novo percurso inicial, a atuação na Pink Street e as correções de movimento integram o projeto executável, juntamente com menus, condução, pressão policial e editor. Isto não conclui a visão final. Continuam em falta os recursos finais da banda, acabamento artístico e de animação, expansão narrativa, IA geral validada e medição no hardware alvo. As regras de música, economia, inventário, morte e gravação preservam os critérios da primeira entrega.

As referências pedidas foram analisadas em `REFERENCIAS_NPCS.md`, com commits, licenças e ficheiros concretos. SanAndreasUnity orienta a separação de estados/perceção/população; OpenLiberty orienta distâncias de visibilidade e recursos em cache. A implementação do Álbum Visual é própria, sem código não licenciado ou recursos GTA copiados.

## Decisões ainda abertas

- Identidades finais, modelos e diferenças de movimento dos três protagonistas.
- Lista e duração das músicas, mapas de notas das atuações e distribuição das zonas sonoras.
- Nomes, sequência e escrita visual das missões principais e secundárias.
- Quantidade de interiores, trânsito e população simultânea compatível com o portátil alvo.
- Pormenores de inventário, dano de quedas e acidentes, e permanência de NPCs derrotados.
- Controlo exato de cada veículo e conjunto final de teclas/botões das atuações.
- Modelo local de IA e âmbito que cada etapa do editor poderá aplicar com segurança e qualidade.

Estas decisões não impedem a revisão do protótipo. Valores provisórios devem ser expostos para ajuste e não apresentados como escolhas definitivas do criador.
