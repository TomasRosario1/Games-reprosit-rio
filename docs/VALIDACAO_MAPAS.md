# Validação — península, bairros e interiores

Revisão de **22 de outubro de 2026**, na branch existente `codex/album-visual-prototipo-02`. A implementação conserva os mapas enviados, o percurso da praça da Madrugada/Lado B, as gravações e o editor. O novo início é o prédio visitável do Saldanha. [Alterações e capturas](REVISAO_LISBOA.md).

## Dados e geometria entregues

- Dois OSM originais de `Maps.rar` preservados em `assets/maps/source`, com SHA-256 e tamanhos registados em `provenance.json`.
- Três recortes: Saldanha, Bairro Alto e Pink Street. Os **598 contornos de edifícios de origem** conservam IDs e coordenadas; **463 alturas são inferidas**, porque os OSM não as indicam.
- Composição contínua com **771 500 m²**, **290 edifícios próprios**, **888 construções no total**, **191 setores** e **29 ruas próprias**, além das ruas OSM. A costa, o relevo e as ligações compactas entre bairros são autorais, não levantamento geográfico real.
- Chão do Saldanha à cota zero até à frente do seu novo quarteirão; subida para o patamar de oito metros do Bairro Alto e descida para a Pink Street. Os mesmos perfis de altura orientam terreno, ruas e percursos dos habitantes.
- Dezoito interiores com portas físicas; três prédios com três pisos, escadas de madeira e terraços. Pisos e soleiras ficam acima do terreno, evitando ocultar o interior sob a calçada.
- Os dados OSM e a base geográfica derivada conservam atribuição **© OpenStreetMap contributors / ODbL 1.0**, também presente no menu. Contactos comerciais dos OSM não são propagados para os metadados de execução.

O jogo usa os JSON e recursos já exportados. Não precisa de Python, Shapely, Blender ou rede para abrir o mapa.

## Verificações físicas e de integração

As verificações específicas executadas nesta revisão incluem:

| Verificação | Resultado confirmado |
| --- | --- |
| Dados dos mapas — `maps_data_test.py` | 5 testes passaram: originais, contornos/triangulação, IDs, metadados e área/perfil contínuo do terreno. |
| Mapas — `maps_test.gd` | 79 verificações passaram, incluindo chão/coberturas, streaming, edições persistentes, música, posição manual e travessia da ponte. |
| Arquitetura — `lisbon_architecture_test.gd` | 473 verificações passaram: entradas dos 18 estabelecimentos, subida/descida dos três prédios com o controlador real e acesso à mesa do DJ. |
| Percursos — `revision_visual_test.gd -- --walkthrough` | 6 percursos completos, sem falhas: ligações entre zonas e escadarias. |
| Integração da revisão — `revision_integration_test.gd` | 27 verificações passaram: início no telhado do Saldanha, quatro veículos próximos, DJ/câmara/áudio da Pink Street e conservação de edições e gravações antigas. |
| Público da Pink Street — `venue_crowd_test.gd` | 60 verificações passaram em duas execuções isoladas: entrada/saída pela porta, regresso à pista, visitas ao balcão, subida da soleira e oito fases de dança distintas com BPM comum. |
| Poses — `locomotion_pose_test.gd` | 28 verificações passaram: direção dos pés/joelhos, agachar, escadas e contactos de condução nas vinte aparências. |
| Terreno e danos — `vehicle_terrain_test.gd` | 43 verificações headless passaram; a execução nativa passou 46, incluindo três verificações de imagem. |

Os percursos expuseram três bloqueios que foram corrigidos: terreno sobre a entrada do Saldanha, uma ligação ao Bairro Alto que atravessava uma nova tasca e uma construção própria sobre a rampa de acesso à ponte. O gerador reserva agora o corredor da ponte, com verificação de regressão nos dados, para impedir que nova densificação volte a ocupar a passagem. A deslocação das personagens é feita pelo controlador e colisões do jogo; colocar a câmara num local não conta como testar o acesso.

O conjunto completo é executado por `./tools/run_checks.sh`, com diretórios de dados isolados. Inclui as suites anteriores e novas verificações de poses, terreno dos veículos, arquitetura, público da nova discoteca e integração do novo início/DJ/migração de edições. O script rejeita erros de compilação e de execução mesmo quando o Godot devolve código de saída zero.

A execução final passou os cinco testes Python e as 21 suites GDScript, sem falhas ou erros de execução. As duas verificações MultiMesh e as três comparações de imagem omitidas em headless foram executadas nas suites nativas descritas abaixo.

## Persistência e circulação

- IDs estáveis preservam edições de prédios quando o setor está descarregado. Transformações e colisões são repostas quando regressa; a posição editada também participa na decisão de carregar o setor.
- `world_edits.json` conserva o esquema anterior e acrescenta `map_revision: 2`. O carregamento adapta edições antigas do Bairro Alto ao novo patamar; gravar e carregar novamente não repete a subida.
- O catálogo de vinte aparências é reutilizado em habitantes persistentes. O orçamento global de peões próximos continua separado dos clientes de clube, segurança e polícia.
- A Pink Street expõe uma mesa de DJ real ao sistema principal: interação, seleção de música, câmara, ritmo e público próprios. O Lado B mantém a missão e atuação anteriores.
- Os clientes percorrem a porta e o passeio, em vez de mudar de visibilidade conforme a pontuação. As identidades são conservadas na saída e na recuperação do público.
- Quatro veículos conduzíveis estão estacionados junto do início; o trânsito usa percursos e os mesmos corpos físicos, com limite próximo por qualidade. A cidade ainda não tem uma simulação completa de cruzamentos e semáforos.

## Renderização e evidência visual

Godot **4.6.3**, Compatibility, **1280 × 720**, Xvfb/Mesa llvmpipe em Linux. O renderer é por software: estes resultados não medem o desempenho do ASUS ou HP.

Foram capturados os três bairros, interiores, escadas, telhados e poses do protagonista na aplicação nativa. A revisão visual identificou e levou à correção dos pisos ocultos, dos pés invertidos, do agachar e de apoios de condução. As capturas atuais estão em [Revisão de Lisboa](REVISAO_LISBOA.md).

O editor passou **52 verificações com renderer nativo**, incluindo as duas leituras MultiMesh que o renderer dummy omite. A apresentação passou **44 verificações nativas**: com a câmara em movimento, o motion blur alterou a imagem; com a câmara parada, a comparação encontrou **zero píxeis diferentes**. Comparações de imagem e leituras dependentes de GPU não são contadas como passadas em headless. Contagens de execuções repetidas da mesma suite não devem ser somadas como testes independentes.

A captura aérea de diagnóstico carrega os 191 setores e desliga o nevoeiro para mostrar a continuidade; não representa o orçamento normal de execução. Durante o jogo, carregam-se construções próximas e conservam-se volumes simplificados do horizonte.

## Limites da validação

A continuidade do terreno, entradas, escadas e DJ está implementada. Isto não torna cada prédio da cidade visitável nem valida todos os trajetos possíveis de condução. A construção de setores ainda é síncrona e pode causar pausas em hardware lento. A estética deve continuar a ser avaliada em jogo pelo criador; testes passados não equivalem a aprovação artística.

Windows 10/Godot 4.7.2, comando físico e o objetivo de 720p/60 FPS no HP A8 PRO-7150B continuam por testar no equipamento real. A IA requer Ollama/modelo e não foi executada nesta máquina. As faixas incluídas são instrumentais sintetizadas; os recursos finais da banda continuam por integrar.

A integração inicial de 21 de outubro passou 942 verificações GDScript e quatro testes Python. Esse registo correspondia aos 90 setores e ao terreno plano anteriores; não descreve o mapa desta revisão. A [validação original](VALIDACAO.md) e a [validação do editor/motion blur](VALIDACAO_EDITOR.md) mantêm o histórico respetivo.
