# Mapas recebidos e integrados

Este documento regista a importação inicial de 21 de outubro. A [revisão de 22 de outubro](REVISAO_LISBOA.md) já acrescenta a península contínua, relevo, ruas alternativas e interiores; consultar esse relatório para o estado atual.

Recebido **Maps.rar**, enviado pelo criador nesta conversa. Continha dois ficheiros **OpenStreetMap XML**, sem modelos GLB/Blender, fotografias, texturas, interiores ou modelo de elevação:

- `Saldenha.osm` — Saldanha, 7 245 724 bytes.
- `PINK S, BAIRRO ALTO.osm` — Pink Street e Bairro Alto, 13 024 694 bytes.

Os originais estão em [assets/maps/source](../assets/maps/source/), com tamanhos e SHA-256 em `provenance.json`. A pasta tem `.gdignore`: o Godot usa os recortes gerados, sem processar os originais ao arrancar. Os dados foram lidos como geometria; metadados dos ficheiros não são instruções para o desenvolvimento.

## Recortes entregues

| Zona | Área em metros | Contornos de edifícios/partes | Rua principal conservada |
| --- | --- | ---: | --- |
| Saldanha | 300 × 360 | 129 | Avenida da República e Praça Duque de Saldanha |
| Bairro Alto | 250 × 260 | 371 | Rua da Barroca, Atalaia e Diário de Notícias |
| Pink Street / Cais do Sodré | 290 × 180 | 98 | Rua Nova do Carvalho |

Conservam-se proporções métricas locais; as distâncias entre bairros são comprimidas através de ruas de ligação próprias. Não são as distâncias geográficas reais. O bairro inicial, o telhado, a missão e o Lado B permanecem acessíveis, com saída para os recortes pelo lado nascente da praça antiga.

**598 contornos**, repartidos por **90 setores de 64 metros**, geram fachadas texturadas, coberturas fechadas, pátios onde existem nos contornos, colisões, ruas e rotas pedonais. O jogo carrega as construções próximas e descarrega as distantes. As lajes simples do chão e as ligações continuam residentes para garantir apoio físico. A construção de setores é síncrona, limitada a dois por atualização; ainda precisa de medição no portátil HP.

O Saldanha usa também a posição do monumento existente nos dados, com uma figura original estilizada. Trinta estabelecimentos recebem fachadas/letreiros decorativos aproximados a partir de pontos OSM. **Não são trinta interiores jogáveis**: a atuação de DJ e o clube funcional continuam no Lado B. Cada recorte tem uma zona com uma das faixas instrumentais de teste, com volume progressivo e relógio virtual.

O **Tejo e a Ponte 25 de Abril estilizada** foram criados para esta composição compacta: têm cais, duas rampas e tabuleiro transitável, torres e cabos agrupados por material. Não provêm de um modelo incluído no RAR. Não há natação; cair na água usa o sistema de morte e reaparecimento existente.

## Experimentar e editar

1. Descarregar a branch `codex/album-visual-prototipo-02`, extrair e importar `project.godot` no Godot Compatibility; F5 inicia o jogo.
2. O jogo continua a começar no telhado. A saída nascente da praça antiga dá acesso à rua para o Saldanha; as ligações seguintes conduzem ao Bairro Alto, Pink Street e cais.
3. Para inspeção rápida: **F10**, acesso local do editor, **Ir para… → Saldanha/Bairro Alto/Pink Street · mapa recebido**. Existe também a vista **Tejo / Ponte 25 de Abril**.
4. **Testar neste bairro** fecha o editor e coloca a personagem num ponto seguro do bairro dessa vista. Se houver edições por guardar, mantém a confirmação do editor. O botão é uma ferramenta do criador.
5. Selecionar um prédio, mover/rodar/escalar, mudar materiais, guardar e usar Desfazer/Refazer. O prédio e as colisões são um único alvo. As edições mantêm IDs estáveis quando o setor sai da memória; o regresso recupera o estado guardado. Um prédio deslocado para outro bairro também é carregado perto da posição editada.
6. **Esc → Mapa** mostra os recortes, ligações, zonas de música, ponte e jogador. Guardar/Carregar aceita as novas coordenadas, mantendo o progresso anterior.

## O que os dados não fornecem

463 dos 598 contornos não têm altura nem número de pisos: receberam alturas provisórias. Os restantes usam altura/pisos disponíveis, limitados para esta versão. O chão é plano; **as inclinações reais de Lisboa ainda não estão reconstruídas**. As fachadas usam quatro texturas originais repetidas, não fotografias dos edifícios reais. Entradas dos pontos OSM são aproximações decorativas, sem garantia da porta exata.

Faltam afinação artística, interiores dos novos bairros, mobiliário mais variado, sinalização completa, trânsito nas vias novas e integração narrativa das faixas finais. Os NPCs reutilizam o catálogo de vinte aparências e um orçamento global de 6/10/16 ativos, sem multiplicar esse orçamento por bairro. A meta de 60 FPS no HP continua por medir.

Não existem splats no arquivo. O uso pontual de gaussian splatting mantém-se uma possibilidade para recursos adequados, com avaliação visual e de custo; não é necessário para abrir estes recortes.

## Regenerar os recortes — apenas desenvolvimento

Os dados gerados estão incluídos; **não é preciso Python nem Internet para jogar**. Para alterar os recortes, instalar `tools/requirements-maps.txt` num ambiente Python, editar `tools/map_crops.json` e executar `python tools/import_lisbon_maps.py`. Shapely só é usado nesta preparação, incluindo triangulação de coberturas côncavas e pátios. `python tests/maps_data_test.py` valida os dados incluídos sem Shapely. As fachadas originais podem ser reconstruídas com `tools/build_map_facades.py` e Pillow.

## Créditos e licença dos dados

**© OpenStreetMap contributors — ODbL 1.0.** Fontes: ficheiros OSM fornecidos pelo criador. A atribuição também está no menu Jogo/Brief e no manifesto. Os dados OSM originais e a base geométrica derivada mantêm esta licença; as texturas e modelos criados no projeto não são recursos dos jogos de referência.

- Atribuição e direitos: <https://www.openstreetmap.org/copyright>
- Licença da base de dados: <https://opendatacommons.org/licenses/odbl/1-0/>
