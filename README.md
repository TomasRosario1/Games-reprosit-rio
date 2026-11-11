# Álbum Visual — Lisboa Noturna

Jogo **desktop, offline e em terceira pessoa**, em Godot 4 Compatibility, para o álbum de «Odio puro no meu peito». Exploração e música continuam no centro, numa Lisboa noturna compacta.

**Revisão de 22 de outubro:** mapa contínuo em forma de península, com **Saldanha, Bairro Alto e Pink Street**, ruas alternativas, margem do rio e Ponte 25 de Abril estilizada. A sessão começa no telhado de um prédio do Saldanha com escadas interiores de madeira. Há **18 estabelecimentos com interiores**, três prédios com pisos e terraços acessíveis, e uma atuação de DJ na discoteca da Pink Street. [Alterações e capturas desta revisão](docs/REVISAO_LISBOA.md).

O `Maps.rar` enviado pelo criador fornece os **598 contornos OSM** dos três bairros. A composição acrescenta **290 edifícios próprios**, terreno com desníveis, arquitetura, texturas e interiores produzidos para o jogo. A península ocupa cerca de **0,77 km²**, repartida em **191 setores de construções**; os setores próximos carregam à medida que o jogador se desloca. As distâncias, a costa e o relevo são adaptações de desenho, não uma reprodução geográfica de Lisboa à escala 1:1. [Origem dos dados e validação](docs/VALIDACAO_MAPAS.md).

O editor continua disponível em **F10 → Ir para… → bairro → Testar neste bairro**. Conserva as alterações ao descarregar setores; o mapa da pausa mostra a península, ruas, bairros, ponte e posição do jogador. A versão para descarregar está na branch **main**.

## Arquivo de personagens e revisão em vídeo

Os vinte modelos atuais e o Emmet enviado estão organizados no [arquivo de personagens](arquivo/personagens/README.md), separado do jogo. A [revisão 06 do Emmet](arquivo/personagens/emmet/revisao_06/README.md) revê a montagem na mota e na bicicleta: a mão esquerda agarra primeiro, o veículo inclina e só depois a perna passa por cima. O carro da revisão 05 e a trotinete da revisão 04 permanecem intactos. Há vídeos individuais e uma sequência de 32 segundos; a caminhada da revisão 03 continua preservada. As novas animações aguardam feedback antes das variantes e integração.

## Descarregar e abrir no Windows

1. Abre [o projeto no GitHub](https://github.com/TomasRosario1/Games-reprosit-rio/tree/main), com a tua conta ligada. Confirma a branch **main**.
2. Clica no botão verde **Code → Download ZIP**. Não uses «Guardar como» sobre a página.
3. Na pasta Transferências, clica no ZIP com o botão direito → **Extrair tudo → Extrair**.
4. Abre o Godot → **Importar** → procura a pasta extraída → seleciona **project.godot → Importar e editar**.
5. Mantém o renderizador **Compatibility**. Aguarda a importação e carrega em **F5**.
6. Escolhe **Artista 01**, **02** ou **03** para começar no telhado do Saldanha.

Podes experimentar com o Godot 4.7.2 que tens; a versão validada neste ambiente foi **4.6.3, em Linux**. Se houver erro, o texto do erro permite identificar a incompatibilidade. Esta entrega é o projeto para abrir no Godot; ainda não inclui um executável Windows exportado.

Não precisas de Python, Blender, conta, Internet ou IA para jogar. Os GLB, texturas e áudios já estão incluídos.

## Primeiro percurso

**Telhado do Saldanha → escadas de madeira → rua → explorar os três bairros → discoteca da Pink Street.**

- Desce pelo vão de escadas do prédio inicial até à entrada alta para a rua.
- Experimenta o carro, a mota, a bicicleta ou a trotinete estacionados junto da frente do quarteirão. **E** permite entrar e sair depois de abrandar.
- Usa as ruas do mapa para chegar ao Bairro Alto e à Pink Street. Os bares e restaurantes têm portas e interiores; três prédios permitem subir até ao terraço.
- Na discoteca da Pink Street, aproxima-te da mesa do DJ e carrega em **E** para abrir as músicas em papel, com pré-escuta e dificuldade. Esta atuação não exige desbloquear o Lado B.
- Durante a atuação, acerta **D F J K** na linha inferior. Acertos recuperam público; erros levam pessoas a caminhar até à saída.

O percurso anterior **pulseira → segurança → Lado B** permanece acessível na praça da Madrugada, a poente do Saldanha. A pulseira vermelha abre esse bar e o acesso fica guardado.

As três faixas incluídas são **ensaios instrumentais sintetizados**, não as músicas da banda. Os vinte modelos de habitantes são originais; os três protagonistas ainda precisam das identidades e recursos finais dos músicos.

## Controlos iniciais

| Ação | Teclado e rato | Comando padrão |
| --- | --- | --- |
| Andar / conduzir | WASD / setas | Stick esquerdo |
| Câmara | Rato | Stick direito |
| Correr | Shift | LB / L1 |
| Saltar / obstáculo baixo | Espaço | A / cruz |
| Agachar, mantendo premido | Ctrl | R3 |
| Interagir / entrar ou sair de veículo | E | Y / triângulo |
| Soco simples | Botão esquerdo do rato | X / quadrado |
| Travar veículo | Espaço | B / círculo; A também aceite inicialmente |
| Buzina | H | RB / R1 |
| Bolsa de oito espaços | B ou Tab | View / Select |
| Pausa / voltar | Esc | Menu / Start |
| Notas musicais, da esquerda para a direita | D F J K | Cruz direcional: esquerda, cima, baixo, direita |
| Modo criador | F10 ou menu Editor | Menu Editor |
| Navegar nos menus | Rato ou setas + Enter | Cruz direcional + A / cruz |

Em **Esc → Controlos**, podes redefinir teclas, botões do rato e botões do comando. O remapeamento preserva os eixos dos sticks. Os textos de ajuda apresentam os controlos iniciais; consulta o menu para as tuas alterações. O comando foi testado com eventos simulados; falta experimentar um comando físico no teu computador.

## O que mudou nesta revisão

- **Cidade:** terreno contínuo, costa, rio, desníveis, rotunda e ruas dos três bairros. Fachadas com janelas, molduras, varandas apoiadas, telhas, portas e letreiros; restaurantes portugueses, franceses e italianos, kebabs, conveniências, fado, bares e discoteca, com esplanadas. O percurso anterior continua acessível.
- **Pessoas:** catálogo original de **10 homens e 10 mulheres**, em GLB, com pele deformável, esqueleto e roupa de silhuetas diferentes. Esta revisão corrige os pés virados para trás e o agachar: a bacia baixa, os joelhos dobram na direção certa e a cápsula acompanha a postura. A personagem sobe degraus baixos sem ter de saltar; a passada acompanha a velocidade real.
- **NPCs:** cinco perfis independentes da roupa; observação, desvio, encontrão, recuo/irritação e regresso ao percurso. O menu ajusta o orçamento de peões próximos para 6, 10 ou 16; clientes do bar, segurança e polícia são grupos adicionais.
- **Discoteca:** o DJ funciona na Pink Street e no Lado B. Cada pista tem oito clientes persistentes que dançam, visitam o balcão e atravessam a porta para sair/regressar. Recuperar público traz de volta as mesmas pessoas, caminhando. Luzes e néons respondem ao som.
- **Veículos:** carro, mota, bicicleta e trotinete disponíveis junto do prédio inicial, com entrada/saída, poses articuladas e pedalada. Rodas acompanham inclinações e ressaltos baixos; impactos fortes deformam a carroçaria e danificam elementos visuais. A saída exige pouca velocidade e espaço livre. O trânsito usa os mesmos veículos físicos, com condutores e orçamento próximo por qualidade.
- **Polícia e combate secundário:** soco simples, dano, patrulha/perseguição por visão e pressão policial. Encontrões não aumentam a pressão. Agressões a civis observadas pela polícia e agressões à polícia podem aumentá-la. Ainda não há combos nem combate final.
- **HUD:** sempre visível durante exploração, com objeto/punho, barra de vida, dinheiro em **€000000000** e indicador policial contínuo de cinco partes que se preenche gradualmente e desaparece sem pressão.
- **Pausa:** menu escuro com brief, mapa esquemático, qualidade baixa/média/alta, população, legendas de diálogo, brilho, controlos, quatro volumes, guardar/carregar, editor e saída confirmada.
- **Editor:** câmara de voo, seleção, transformações, materiais/luzes, catálogo de peças, NPCs, missões simples e veículos, desfazer/refazer e ficheiro de mundo separado. Inclui cliente para IA local com proposta e pré-visualização; o modelo não está incluído.

Os veículos e personagens desta entrega são **modelos originais do projeto**. O SanAndreasUnity foi estudado como referência de sistemas; os modelos GTA que ele carrega dependem de uma instalação externa do jogo e não fazem parte desta entrega. [Ficheiros e versões consultados](docs/REFERENCIAS_NPCS.md).

## Editor e IA local

Carrega em **F10**, fora de um veículo, ou usa **Esc → Editor**. Na primeira utilização defines uma palavra-passe local com pelo menos quatro caracteres. Não existe uma palavra-passe universal.

Mantém o **botão direito do rato** para orientar a câmara e usa **WASD**, **Q/E** para descer/subir e **Shift** para acelerar. Seleciona um objeto por clique ou pela lista; altera posição, rotação, escala, material ou luz no painel. **Guardar** grava o mundo, **Desfazer/Refazer** recuperam alterações. Consulta [o guia passo a passo](docs/EDITOR.md).

A IA está preparada para o **Ollama local**, por exemplo `qwen2.5:3b` ou um modelo Llama compatível já instalado. Recebe IDs e propriedades da seleção/vizinhança e propõe alterações de objetos e luzes. **A ligação ainda não foi validada com um modelo real instalado.** As operações estruturadas, rejeição de propostas inválidas, pré-visualização, Aplicar, Cancelar e Desfazer foram testadas. Esta versão não gera animações, modelos ou código arbitrário por texto.

## Regras preservadas

- Música espacial com aproximação/afastamento suaves e relógio virtual quando o áudio distante é suspenso. A pré-escuta é separada; a atuação reinicia a faixa selecionada.
- Luzes reativas aos graves, analisados antes da atenuação por distância.
- Fácil/normal acumulam **10 € por acerto**, difícil **15 €**. O pagamento acontece uma única vez no fim de uma atuação bem-sucedida. Falhar ou interromper não paga.
- Durante a atuação, o jogador não ataca nem recebe ataques.
- Bolsa de oito espaços e objeto equipado separado. A morte perde dinheiro e o objeto na mão; preserva a bolsa e os acessos.
- Queda fatal, distorção de imagem/som, fecho em funil e botão de renascimento perto do último ponto seguro.
- Progresso automático em JSON com backup. Reabrir a aplicação começa no telhado; **Carregar** no menu recupera também a posição e vida do espaço manual.

## Dados locais e limites

No Windows, os dados ficam normalmente em:

```text
%APPDATA%\Godot\app_userdata\Álbum Visual — Lisboa Noturna\
```

| Ficheiro | Conteúdo |
| --- | --- |
| `album_save.json` e `.bak` | Progresso automático, dinheiro, bolsa e acessos |
| `manual_save.json` e `.bak` | Espaço de gravação manual |
| `manual_position.json` | Posição e vida da gravação manual |
| `world_edits.json` e `.bak` | Mundo criado/alterado no editor |
| `menu_settings.cfg` | Qualidade, áudio, brilho e controlos |
| `editor_access.cfg` | Verificação da palavra-passe local |

Antes de limpar dados, fecha o jogo e copia os ficheiros para outra pasta. As edições do mundo são locais; não modificam automaticamente o código no GitHub. A revisão conserva os IDs dos edifícios importados e migra a altura das edições antigas do Bairro Alto para acompanhar o novo patamar.

Ainda faltam músicas e personagens definitivas da banda, animações de interação trabalhadas à mão, combos, vocalizações, expansão das missões, efeitos dos consumíveis e escalada completa. Os 18 interiores entregues não tornam todos os edifícios visitáveis, e o trânsito não é ainda uma simulação completa de semáforos e cruzamentos. O editor altera propriedades e cria situações simples; não substitui o Godot ou o Blender. A avaliação artística continua a depender do criador.

**60 FPS no HP EliteBook é um objetivo por medir no equipamento real.** Gaussian splatting não foi adicionado: nesta fase usamos geometria texturada, limites de desenho, nevoeiro e simulação por distância.

## Desenvolvimento e validação

- [Referência acrescentada pelo criador](<Ter como referencia>)
- [Auditoria das 19 etapas — 21 de outubro](docs/ESTADO_19_ETAPAS.md)
- [Plano técnico do mapa contínuo](docs/PLANO_MAPA_CONTINUO.md)
- [Design e decisões](docs/GDD.md)
- [Próximas etapas](docs/ROADMAP.md)
- [Resultados dos testes e capturas reais](docs/VALIDACAO.md)
- [Editor e instalação opcional da IA](docs/EDITOR.md)
- [Validação da atualização do editor e motion blur](docs/VALIDACAO_EDITOR.md)
- [Entrega e recorte dos mapas do criador](docs/ENTREGAR_MAPAS.md)
- [Revisão da península, interiores e movimento](docs/REVISAO_LISBOA.md)
- [Referências técnicas](docs/REFERENCIAS_NPCS.md)
- [Créditos dos recursos](assets/CREDITOS.md)

Com Godot no PATH, executa `./tools/run_checks.sh` em Linux. O script importa os recursos e verifica ritmo, persistência, personagens, movimento, mundo, NPCs, público, polícia, veículos, menus, editor, música e integração. As verificações de transformações MultiMesh exigem também execução com renderização nativa; o modo headless identifica as duas omissões explicitamente.

Para regenerar recursos opcionalmente: `tools/generate_assets.py` e `tools/generate_city_textures.py` usam Python, NumPy, Pillow e FFmpeg conforme o gerador; `tools/generate_characters.py` é executado pelo Blender. O jogo usa os recursos já exportados, sem executar estes geradores.
