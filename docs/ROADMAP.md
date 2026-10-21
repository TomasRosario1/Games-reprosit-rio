# Plano de desenvolvimento — Álbum Visual

Este plano distingue a base implementada, a revisão do protótipo 02 e o trabalho seguinte. «Implementado» significa que existe código e uma experiência de teste; não significa recurso artístico definitivo, exportação Windows validada ou desempenho garantido no HP. O README e o registo de validação acompanham a versão entregue.

Após a auditoria, o criador autorizou avançar: motion blur foi acrescentado como efeito artístico regulável e o editor recebeu manipulação por eixos, grelha, foco, vistas, prédio-base e proteção das alterações por guardar. A [validação desta atualização](VALIDACAO_EDITOR.md) regista os testes. A prioridade geográfica passa a ser **receber e recortar os mapas próprios** de Saldanha, Pink Street e Bairro Alto indicados pelo criador; OSM/OSM2World poderá complementar o processo depois da inspeção, não substituir automaticamente esses mapas. A Ponte 25 de Abril junto ao Tejo será dimensionada e colocada a partir deles; consultar [entrega dos mapas](ENTREGAR_MAPAS.md).

Em 21 de outubro de 2026, o criador acrescentou [Ter como referencia](<../Ter como referencia>) com uma sequência de 19 etapas. A [auditoria dessa sequência](ESTADO_19_ETAPAS.md) preserva a ordem e identifica sistemas existentes; o [plano do mapa contínuo](PLANO_MAPA_CONTINUO.md) descreve dependências antes da expansão. As próximas tarefas devem seguir essa referência, mantendo o Álbum Visual como prioridade e um mapa compacto. Não remover editor, áudio ou funcionalidades existentes apenas por surgirem mais tarde na sequência nova.

## 1. Base da primeira experiência — implementada

**Percurso:** telhado → rua → pulseira → segurança → Lado B → escolha de faixa → atuação.

- Aplicação Godot 4 desktop, offline, com renderizador Compatibility.
- Exploração em terceira pessoa, andar/correr/agachar/saltar, colisões e câmara com recentramento.
- Missão curta de acesso ao bar e fonte musical com aproximação/afastamento suaves e relógio virtual.
- Repertório com pré-escuta, três dificuldades e quatro teclas de ritmo.
- Público recuperável, falha sem pagamento e dinheiro entregue uma única vez no fim de uma atuação bem-sucedida.
- Bolsa de oito espaços, objeto equipado separado, gravação local e backup.
- Morte com distorção e funil, regresso a ponto seguro próximo, perda do dinheiro e do objeto equipado e preservação da bolsa.
- Ao reabrir, início no telhado com o progresso conservado.

A música continua a ser de ensaio sintetizado. Os ficheiros definitivos do álbum e a caracterização final dos três protagonistas ainda não foram integrados.

## 2. Protótipo 02 — revisão implementada

### Lisboa, profundidade e personagens

- Praça e ruas inspiradas no Saldanha, com continuidade do telhado, escadas, missão e bar.
- Fachadas, iluminação quente, materiais e profundidade atmosférica orientados pela imagem fornecida e pela leitura low-poly de GTA III.
- Nevoeiro simples associado a limites reais de detalhe e visibilidade; três perfis de qualidade.
- Vinte adultos originais, dez homens e dez mulheres, com malhas humanas articuladas e texturas próprias.
- Variação de anatomia, altura, cabelo, roupa e silhueta: saias, calças de cortes diferentes, camisolas, sweats e casacos.
- Estilos beto, alternativo, chunga, emo, normal, indie e combinações, separados dos parâmetros de personalidade.
- Animações de estudo com flexão de joelhos/cotovelos e movimento coordenado de bacia, peito e braços. Continuam a precisar de afinação artística, de transições e de contacto com o chão.

### Peões e vida do clube

- Passeio, espera, olhar, desvio, perceção por campo de visão e linha de visão, encontrão e recuperação do percurso.
- Perfis calmo, alcoolizado, distraído, tímido e segurança, sem ligar agressividade ao guarda-roupa.
- Catálogo estável de vinte variantes, com população próxima ajustável a seis, dez ou dezasseis peões de rua e suspensão à distância.
- Clube com DJ/pista e público que dança e caminha pela entrada real ao sair ou regressar; preservação dos acessos ao jogador.
- Manutenção das regras de atuação, pagamento, inventário, morte e gravação.

A circulação e as animações são uma base funcional, não uma multidão urbana ou coreografia final. As vocalizações próprias dos arquétipos ainda precisam de produção e integração.

### Condução e pressão policial

- Carro, mota, bicicleta e trotinete provisórios conduzíveis, com aproximação ao acesso, poses e transições de entrada/saída, travão e buzina.
- Resposta a impactos e danos para experimentar acidentes; controlos e física de estilo arcade sujeitos a afinação.
- Soco simples desarmado e reação aos danos; combate mantém-se secundário.
- Dois agentes locais, com perceção, patrulha, perseguição, aviso e bastão, sem atacar por um encontrão normal.
- Pressão contínua que aumenta pelos eventos configurados e reduz quando o jogador fica fora de vista, após o período de espera. A morte do jogador limpa a pressão.
- Crimes de civis e acidentes dependem da política configurada e de testemunho; não confundir isto com uma simulação policial completa de GTA.

### HUD e pausa

- HUD de estado com euros a nove algarismos, vida, punhos/objeto equipado e pressão policial numa barra contínua dividida em cinco partes; nome sobre a personagem.
- Nove separadores de pausa: Jogo/Brief, Mapa, Qualidade, HUD, Controlos, Áudio, Guardar/Carregar, Editor e Sair.
- Mapa esquemático, população independente da qualidade, volumes por canal, brilho, legendas, redefinição de controlos e confirmação de saída.
- Definições do menu guardadas separadamente do progresso do jogador.

### Editor e ligação local à IA

- Acesso dentro do jogo por F10 ou pelo menu, com palavra-passe criada localmente na primeira utilização.
- Câmara de voo, seleção na cena/lista e inspetor de transformações, materiais, luzes e propriedades expostas dos NPCs.
- Catálogo de objetos, NPCs, luzes, portas, quatro veículos e marcadores de missão; instância de GLB/GLTF já integrados no projeto.
- Duplicar/remover, Desfazer/Refazer e mundo em JSON com escrita temporária, validação e backup.
- Missões simples de visita/encontro/recolha com título e recompensa, conclusão guardada e pagamento único.
- Scene Graph e ligação HTTP ao Ollama local, com proposta JSON sobre IDs existentes, pré-visualização, Aplicar, Cancelar e Desfazer.

**Limite da IA nesta entrega:** não há modelo incluído nem inferência com modelo real validada neste ambiente. O editor manual não depende do Ollama. O painel não é ainda uma IA geral capaz de criar qualquer modelo, animação, missão ou mecânica, nem executa código arbitrário devolvido pelo modelo.

## 3. Próxima etapa — afinação visual e de utilização

1. Experimentar o protótipo no ASUS com Windows e recolher exemplos concretos de movimentos, roupas, enquadramentos e acessos a melhorar.
2. Afinar passada, apoio dos pés, transições, mãos, postura, casaco, poses de condução e entrada/saída dos quatro veículos.
3. Refinar rostos, anatomia e guarda-roupa do catálogo; construir as identidades e diferenças finais dos três protagonistas.
4. Ajustar densidade de peões, percursos, filas, dança e circulação do clube através de sessões de jogo.
5. Trabalhar a coerência de Lisboa: arquitetura, sinalética, calçada, iluminação e ligação dos espaços, em vez de apenas aumentar o mapa.
6. Melhorar legibilidade, navegação por comando e controlo de volume/brilho do HUD e da pausa com o criador.
7. Testar edição, gravação, recuperação e retomada do jogo após aplicar mudanças no cenário.

**Critério de conclusão:** o percurso é compreensível e consistente, as pessoas têm silhuetas humanas e movimento legível, e o criador consegue alterar o cenário sem perder o estado correto.

## 4. Ampliar o editor com IA offline

1. Instalar e iniciar Ollama no computador de desenvolvimento, descarregar um modelo adequado e testar a resposta real.
2. Medir memória, tempo de resposta e compatibilidade no equipamento com RX 7600 XT; manter o HP apenas como máquina de jogo.
3. Avaliar propostas sobre objetos identificados, rejeição de dados inválidos, ambiguidade, pré-visualização e Desfazer com pedidos reais em português.
4. Ampliar gradualmente o esquema para operações novas, mantendo validação, limites e versões recuperáveis do mundo.
5. Só depois acrescentar alterações de comportamento e scripts com verificações e recuperação próprias.
6. Separar a ferramenta de edição do pacote mínimo para jogar, sem tornar o modelo um requisito de execução do jogo.

**Critério de conclusão:** um pedido real produz uma proposta pertinente, verificável e reversível no mundo correto. A existência de um painel ou de uma resposta HTTP não comprova a qualidade geral da IA.

## 5. Expandir o álbum, a progressão e a cidade

- Integrar músicas autorizadas da banda, mapear as notas e afinar a análise de graves e a mistura sonora com essas faixas.
- Criar a sequência visual da história, missões principais/secundárias, transporte, recuperação de objetos e favores com condições reais de acesso.
- Implementar os cinco minutos de indisponibilidade das missões secundárias, contados com a aplicação ligada, sem contagem visível.
- Expandir o catálogo simples de missões do editor para condições, diálogos e cadeias narrativas, sem pagamentos duplicados.
- Produzir vocalizações e comportamentos característicos dos habitantes, seguranças e polícias.
- Desenvolver combos, bosses de acesso e consequências de combate sem substituir a exploração e a música como prioridades.
- Completar recuperação de vida, objetos, efeitos temporários de álcool/drogas e opções para reduzir efeitos desconfortáveis.
- Expandir ruas, bares e interiores estilizados, incluindo Pink Street e Galito, mantendo escala e orçamento de desempenho controlados.
- Afinar trânsito, colisões, acidentes e controlo próprio de cada veículo.

## 6. Desempenho e distribuição

- Medir no ASUS e no **HP EliteBook 745 G2 real**, com resolução, perfil de qualidade e cenário registados. A meta de 60 FPS no HP continua **não medida e não garantida**.
- Começar por 720p, Compatibility e qualidade leve; verificar ruas, clube, multidão e trânsito nas situações de maior carga.
- Confirmar redução efetiva de detalhe, objetos desenhados e simulação à distância, com o nevoeiro a disfarçar as transições.
- Afinar luzes estáticas/dinâmicas, sombras, transparências, animação e áudio conforme os resultados medidos.
- Gaussian splatting permanece investigação opcional, sujeita a recursos próprios, colisões separadas e comparação de memória/tempo de frame. Não foi implementado nem assumido como mais leve.
- Testar comando físico, mistura de áudio por audição e utilização sem Internet no computador do criador.
- Preparar e validar uma exportação Windows com créditos, licenças e indicação dos recursos provisórios que ainda existam.

## Verificações a manter

| Sistema | Evidência útil |
| --- | --- |
| Personagens e movimento | Catálogo humano variado, locomoção ligada à velocidade, articulações, transições, colisões e queda/renascimento. |
| Peões | Visão com obstáculos, desvio, contacto real, recuperação, orçamento e suspensão distante. |
| Clube | Porta e circulação, dança, saída por falha e regresso por recuperação sem aparecimento no meio da sala. |
| Veículos | Entrada/saída, avatar, comandos, travagem, colisão e local seguro de saída. |
| Polícia | Contacto sem crime, testemunhos, aumento/decadência de pressão, perseguição e proteção durante atuação. |
| HUD e menu | Estado correto, nove separadores, redefinição, gravação de definições e navegação por teclado/comando. |
| Música e economia | Pré-escuta, loop virtual, relógio da atuação, dificuldades, público, pagamento correto e único. |
| Progresso | Bolsa/equipamento, perdas por morte, backup e restauro sem misturar dados do mundo. |
| Editor | Seleção, catálogo, edição, Desfazer/Refazer, gravação/carregamento e missões sem recompensa repetida. |
| IA | Schema restrito e pré-visualização, mais testes reais de inferência quando o modelo estiver disponível. |
| Equipamento alvo | Medições no computador especificado e exportação Windows efetivamente executada. |

As referências estudadas estão em `REFERENCIAS_NPCS.md`, com fontes e limites de licença. Nenhum modelo, textura, música ou código não licenciado de GTA foi copiado para esta implementação. Arquivos de referência não equivalem a jogos instalados ou executados.
