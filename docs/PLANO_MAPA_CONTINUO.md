# Plano técnico — Lisboa compacta e contínua

Análise de 21 de outubro de 2026, a partir de [Ter como referencia](<../Ter como referencia>) e do protótipo 02. Este documento propõe a migração; **nenhum sistema de streaming, mapa OSM ou bairro novo foi implementado nesta revisão documental**.

**Atualização posterior:** o criador enviou `Maps.rar`, contendo dois ficheiros OSM. A primeira integração dos três recortes, setores, ligações e ponte estilizada já está no código. Consultar [mapas recebidos e limitações](ENTREGAR_MAPAS.md) e [validação](VALIDACAO_MAPAS.md). O restante texto conserva o diagnóstico e plano inicial; não é uma afirmação de que todas as etapas tenham sido concluídas.

## Decisões confirmadas pelo criador

- «GTA LISBOA» expande o **Álbum Visual**. A música, a história do álbum e a exploração mantêm a prioridade; veículos, polícia e combate são sistemas de apoio.
- O mapa será **compacto**, com edifícios, veículos e pessoas em proporções realistas. Não reproduzirá as distâncias reais entre Saldanha, Bairro Alto e Cais do Sodré.
- Saldanha, Bairro Alto e Pink Street/Cais do Sodré devem ligar-se sem ecrãs de carregamento, preservando as funcionalidades existentes.
- Nesta primeira tarefa, analisar e documentar antes de alterar código. O editor já entregue mantém-se; a sua posição no fim da lista nova não implica removê-lo.

Lisboa real situa-se junto ao estuário do Tejo. Uma península delimitada por oceano e montanhas será uma composição geográfica fictícia inspirada em Lisboa, compatível com a opção por um mapa compacto. Essa distinção deve ficar clara no design; os contornos definitivos ainda não foram desenhados.

## Situação atual

Existe uma cena de entrada, `scenes/main.tscn`, cujo `main.gd` cria um `AlbumWorld`. O cenário é construído integralmente por `scripts/world.gd` ao arrancar. O Saldanha é uma interpretação própria, não uma importação de OpenStreetMap.

Os agrupamentos de 16 metros em `world.gd` reduzem o trabalho de desenho através de MultiMesh e visibilidade. **Não constituem streaming:** a geometria já está na memória. Esconder objetos ou acrescentar nevoeiro também não equivale a descarregá-los.

O jogo atual tem contratos dependentes do primeiro quarteirão:

| Área | Dependência observada | Preparação necessária |
| --- | --- | --- |
| Mundo e missões | Pontos fixos de telhado, pulseira, segurança, entrada e palco em `world.gd` | Marcadores estáveis identificados por bairro/setor; preservar os atuais durante a migração |
| Coordenadas | Posições e rotas usam o espaço atual; `npc.gd` combina colocação local com destinos globais | Definir e testar a transformação de cada setor, incluindo rotas, porta, pista e saídas |
| Editor | `configure()` indexa a árvore uma vez; IDs de base derivam de posição, geometria e textura | Registar/desregistar setores, usar IDs explícitos e migrar as edições antigas |
| Gravação | `_manual_load()` aceita apenas `abs(x/z) < 100`, altura entre -5 e 60 | Validar posições pelo manifesto do mundo e por ponto seguro, em vez dos limites do quarteirão |
| Edições | Coordenadas limitadas a 1000 por componente; ficheiro do mundo limitado a 4 MB | Rever limites segundo o tamanho real; persistência por setor sem perder edições de setores descarregados |
| População | Cada `AlbumPopulation` mantém catálogo/pool e orçamento próprios | Orçamento global próximo; evitar multiplicar 6/10/16 por cada setor |
| Veículos e polícia | Pontos de aparecimento e percursos fixos; registo de veículos sem ciclo completo de remoção por setor | Separar entidades persistentes dos pontos de criação; conservar veículo conduzido e pressão policial |
| Música | Uma zona principal de bar, um relógio virtual e uma reprodução de exploração | Emissores/relógios por zona; manter o andamento quando o setor deixa de estar carregado |
| Trânsito | Carros de cenário movem-se num eixo e reaparecem nas extremidades | Rede de vias, cruzamentos e condutores próprios; não tratar esse movimento como IA de trânsito |
| Mapa | Esquema fixo no menu de pausa | Dados comuns do mapa para menu e futuro minimapa |

Estes limites não demonstram um defeito no quarteirão atual. São dependências que têm de ser resolvidas antes de o expandir.

## Organização proposta

Manter uma raiz persistente de jogo e a cena existente. Separar progressivamente os seguintes elementos, sem criar outro projeto:

- **Sessão:** jogador, veículo ocupado, dinheiro/bolsa, progresso, estado policial e relógios de música.
- **Mundo:** manifesto de bairros, setores, ligações, pontos seguros e recursos.
- **Setor:** geometria, colisões estáticas, marcadores e pontos de criação locais.
- **Estado guardado:** edições por ID/setor e estado das entidades que precisam de sobreviver ao descarregamento.

Um manifesto deverá identificar cada setor, origem em metros, limites, vizinhos, recurso visual, colisões, vias, zonas sonoras e pontos de missão. IDs como `saldanha/setor_01/porta_02` devem permanecer iguais após ajustes visuais. Não usar apenas ordem de criação ou um hash da posição para identificar objetos editados.

### Escala e origem

Adotar **1 unidade Godot = 1 metro** como convenção de trabalho, com Y vertical e uma origem comum documentada. Antes de mover o cenário existente, medir portas, degraus, passeios e alturas de personagens; ter GLB em metros não garante que todos os modelos estejam à escala correta.

Os três recortes reais podem inspirar bairros colocados mais perto uns dos outros. Nesse caso, cada bairro precisa de uma transformação documentada e de ligações redesenhadas. Não basta concatenar exportações com latitude/longitude originais: isso preservaria as distâncias reais que o criador decidiu comprimir. Se forem usados dados geográficos, projetá-los para coordenadas métricas locais durante a preparação, sem tratar graus como metros.

### Carregamento e continuidade

Usar setores suficientemente pequenos para limitar geometria/colisões, mas não tão pequenos que criem trabalho de carga constante. Ensaiar uma dimensão inicial, por exemplo 64–128 metros, e medir antes de fixar o tamanho.

Pré-carregar vizinhos antes de o jogador chegar, com margem baseada na velocidade do veículo e no tempo de carga medido. Usar histerese para evitar carregar/descarregar repetidamente na mesma fronteira. A API de carregamento em segundo plano do Godot pode preparar recursos; criação de nós e ativação de colisões têm de respeitar as regras de execução do motor e ter custo limitado por frame.

Não descarregar o chão sob o jogador, o veículo ocupado, uma transição de entrada/saída ou um interior em atuação. Se o setor vizinho ainda não estiver pronto, a passagem não pode deixar o jogador cair num vazio. O desenho das ruas e o orçamento de pré-carregamento devem prevenir essa situação; a exigência de continuidade depende de validação no equipamento alvo.

As ruas partilhadas precisam de limites coincidentes, cotas compatíveis e pontos de ligação comuns para peões e trânsito. Não criar duas estradas sobrepostas nem deixar colisões ou navegação a terminar numa linha arbitrária de exportação.

## Preparação OSM → modelo jogável

O objetivo é usar OSM como base de proporções, implantação e referências, conservando a autoria visual do projeto. O conversor não cria automaticamente materiais lisboetas finais, interiores, colisões adequadas, circulação ou missões.

1. Escolher **um pequeno recorte do Saldanha**, registar limites, data e origem dos dados e decidir o que se preserva/reinterpreta.
2. Fixar uma versão do OSM2World e verificar os seus requisitos e formatos de saída. Ainda não está instalado nem foi executado neste ambiente; não há conversão OSM validada nesta entrega.
3. Exportar num formato suportado pela versão escolhida. Se necessário, converter no Blender para GLB/GLTF e verificar unidades, eixos e materiais. Não assumir que qualquer versão exporta diretamente o formato pretendido.
4. Retocar geometria e fachadas, simplificar materiais, criar atlas/LODs quando necessário e preservar silhuetas reconhecíveis de Lisboa.
5. Preparar colisões simples, estradas/passeios e pontos de circulação separadamente da malha visual.
6. Importar o recorte junto da base existente, comparar escala e percorrer a pé/de veículo antes de substituir qualquer parte funcional.
7. Só depois repetir o processo nos outros bairros e ligar as ruas redesenhadas.

Fontes técnicas: [OSM2World](https://github.com/tordanik/OSM2World), [carregamento em segundo plano do Godot](https://github.com/godotengine/godot-docs/blob/stable/tutorials/io/background_loading.rst) e [atribuição/licença OpenStreetMap](https://www.openstreetmap.org/copyright). O código do conversor, os dados geográficos e os modelos/texturas externos têm condições próprias; registar versões, créditos e obrigações aplicáveis antes de distribuir recursos derivados. Nesta revisão, o README do conversor e a documentação Godot foram consultados; a página OSM bloqueou o acesso pela rede do ambiente. Não se declara uma auditoria concluída das licenças de toda a cadeia.

## Sequência mínima de implementação proposta

| Passo futuro | Resultado verificável |
| --- | --- |
| 1. Contrato de setor | Encapsular a área atual mantendo origem, marcadores, percurso do bar e gravações compatíveis |
| 2. Fronteira piloto | Ligar apenas um setor vizinho simples e percorrê-lo repetidamente a pé e nos quatro veículos |
| 3. Persistência e serviços | Guardar/carregar edições, veículo, missões, polícia e áudio sem duplicação ao entrar/sair de setores |
| 4. Recorte OSM do Saldanha | Validar escala, materiais, colisões, créditos e custo do primeiro recorte importado |
| 5. Ligações dos bairros | Adicionar gradualmente Bairro Alto e Pink Street com ruas/cotas e acessos coerentes |
| 6. Expansão dos sistemas | Evoluir trânsito, comportamentos e três missões iniciais na ordem aprovada, preservando música/exploração |

Estes passos são uma proposta técnica para a etapa do mapa, não autorização para implementar todos de uma vez. A importação depende de preparar dados e validar o contrato do setor. Não é preciso adiar ou reconstruir o editor e o áudio que já existem.

## Critérios de aceitação

- Travessia repetida de fronteiras sem buracos, colisões duplicadas ou perda de entidades.
- Entrada/saída de veículos segura e manutenção do veículo ocupado durante a carga.
- Um orçamento próximo de NPCs/trânsito para o mundo, com identidades persistentes quando necessário.
- Pressão policial, objetivos, recompensa única e progresso conservados entre bairros.
- Retomar o loop musical na posição correta depois de afastar/descarregar/regressar; manter entradas/saídas físicas do público nos interiores ativos.
- Editar, descarregar e voltar a carregar um setor sem perder alterações; migrar dados da versão anterior com backup.
- Medir memória, tempo de frame e pausas de carga no ASUS e no HP, indicando resolução e qualidade. **Não garantir 60 FPS por existir nevoeiro, OSM ou streaming.**

## Correções técnicas sugeridas à referência PS2

Separar a lista de 74 itens em técnicas úteis hoje, efeitos visuais opcionais e técnicas específicas do hardware antigo. Gaussian splatting é uma técnica moderna, não uma técnica PS2 nem uma otimização garantida. Motion blur, bloom, profundidade de campo e transparências podem aumentar o custo; nevoeiro reduz trabalho apenas quando acompanhado por descarte/LOD.

Field blending, half-pixel offset entrelaçado e microprogramas VU não são funcionalidades a transpor diretamente para um jogo PC em Godot. Há entradas duplicadas de Vertex Colors (17/18), Desaturation (46/47) e partículas 2D (55/56). Recursos como bloom e efeitos de ecrã também precisam de alternativa/validação no renderizador Compatibility escolhido para o portátil HP. Para começar, priorizar mipmaps, atlas, materiais reutilizados, colisões simples, descarte por distância, geometria legível e medição real.

Os nomes «Godot Easy Vehicle Physics», «Godot 4 Vehicle Framework» e «Pedestrian AI System Godot» não identificam por si só um repositório e versão únicos. Precisam de URLs exatos antes da seleção e revisão de licença; essa falta não impede a análise do projeto atual.
