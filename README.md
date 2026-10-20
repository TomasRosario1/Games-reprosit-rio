# Álbum Visual — Lisboa Noturna

Primeiro protótipo **desktop, offline e em terceira pessoa** do álbum visual de «Odio puro no meu peito». Criado em Godot 4, com renderizador Compatibility. Não é um website.

## Experimentar no Windows

1. Descomprime a pasta do projeto num local do teu computador.
2. Abre o **Godot 4.6.3**, escolhe **Importar** e seleciona o ficheiro `project.godot` desta pasta. Usa o renderizador **Compatibility**.
3. Aguarda a importação das texturas e dos áudios e carrega em **F5**. Escolhe uma das personagens provisórias.

Não precisas de Python, Blender, Internet, conta ou IA para jogar esta versão. O projeto foi testado em Godot 4.6.3; outras versões não foram verificadas. A entrega é o projeto para abrir no Godot, ainda sem executável Windows exportado.

## O primeiro percurso

**Telhado → rua → pulseira → segurança → bar → atuação.**

- No telhado, procura a saída para as escadas no canto de trás à direita; há uma indicação «↓ RUA».
- Desce a escada exterior. A pulseira vermelha fica perto do cruzamento e só é destacada quando te aproximas.
- Apanha-a com **E**, aproxima-te do segurança do **Lado B** e volta a interagir. A pulseira é entregue e a porta abre.
- Entra no bar e aproxima-te do círculo luminoso perto do palco. Interage para abrir o repertório em papel.
- Seleciona uma faixa para ouvir uma prévia, escolhe a dificuldade e inicia a atuação.
- Acerta **D, F, J, K** quando as notas chegam à linha inferior. Os acertos recuperam público; os erros afastam-no.

As três faixas são **ensaios instrumentais sintetizados para testar o jogo**. Não são músicas da banda. Os modelos e as texturas também são provisórios.

## Controlos

| Ação | Teclado e rato | Comando padrão |
| --- | --- | --- |
| Andar | WASD / setas | Stick esquerdo |
| Câmara | Rato | Stick direito |
| Correr | Shift | LB / L1 |
| Saltar / ultrapassar obstáculos baixos | Espaço | A / cruz |
| Agachar, mantendo premido | Ctrl | R3 |
| Interagir | E | Y / triângulo |
| Bolsa de oito espaços | B ou Tab | View / Select |
| Pausa / voltar | Esc | Menu / Start |
| Notas musicais, da esquerda para a direita | D F J K | Cruz direcional: esquerda, cima, baixo, direita |
| Navegar nos menus | Rato ou setas + Enter | Cruz direcional + A / cruz |

O suporte a comando foi verificado com eventos de entrada simulados; o comando físico e eventuais diferenças de mapeamento precisam de teste no teu computador. Nas atuações, os botões da cruz direcional são independentes do teclado.

## Regras implementadas

- Câmara com colisão e recentramento depois de parar e deixar de a mover.
- Três escolhas de artista provisórias, com pequenas diferenças de velocidade; as identidades, animações e estilos musicais finais ainda estão por fazer.
- Música do bar com aproximação/afastamento suaves, panorama estéreo e relógio virtual quando a reprodução distante é suspensa. A pré-escuta é separada do loop da exploração.
- Análise de graves antes da atenuação, ligada à luz e emissão do néon.
- Três dificuldades: fácil/normal acumulam **10 € por acerto**, difícil **15 €**. Pontuação: 100 pontos por acerto.
- O dinheiro só é entregue no fim de uma atuação bem-sucedida. Se o público todo sair, ou se interromperes, não recebes o valor provisório.
- Animação provisória com microfone durante a atuação; movimento e interação ficam bloqueados. Ainda não existe combate nesta versão.
- Bolsa com oito espaços e objeto equipado separado. Selecionar um objeto na bolsa equipa-o; há uma opção para o voltar a guardar.
- Uma queda fatal ativa distorção de imagem e som, fechamento em funil e botão para voltar à vida num ponto seguro próximo.
- Ao morrer perdes o dinheiro e o objeto na mão. Conservas a bolsa e os acessos desbloqueados.
- Progresso gravado em JSON com escrita atómica e backup. Ao reabrir começas no telhado, mantendo o progresso.

## O que ainda não está nesta versão

**Editor dentro do jogo e IA offline** são a etapa seguinte: câmara de voo, seleção visual, alterações por texto, pré-visualização, Aplicar e Desfazer. O modelo local não está incluído neste protótipo.

Os carros em movimento e a bicicleta são cenário: **ainda não são conduzíveis**. Também faltam combate, personalidades e missões avançadas dos NPCs, vocalizações, efeitos de objetos, interiores adicionais, músicas da banda, personagens definitivas e escalada completa de muros. O casaco tem movimento secundário simples, não simulação de tecido.

A estética é um estudo inicial, não a direção artística final. A meta de 60 FPS no HP EliteBook ainda precisa de medição no equipamento real.

## Dados locais

No Windows, o progresso fica normalmente em:

```text
%APPDATA%\Godot\app_userdata\Álbum Visual — Lisboa Noturna\album_save.json
```

O backup é `album_save.json.bak`. Os dados do jogador são separados do código e, futuramente, dos ficheiros do mundo editado. Para recomeçar, com o jogo fechado, guarda cópias de ambos os ficheiros noutro local e retira-os da pasta de dados.

## Para continuar a desenvolver

- [Documento de design e decisões](docs/GDD.md)
- [Etapas seguintes](docs/ROADMAP.md)
- [Validação e limites dos testes](docs/VALIDACAO.md)
- [Origem dos recursos](assets/CREDITOS.md)

O cenário inicial é montado por `scripts/world.gd` ao executar o jogo. A personagem fica em `scripts/player.gd`; a integração em `scripts/main.gd`; as regras de ritmo em `scripts/rhythm_game.gd` e a persistência em `scripts/save_store.gd`.

### Verificação automática

Com Godot disponível no PATH, na pasta do projeto:

```sh
godot --headless --editor --import --quit
godot --headless --script tests/rhythm_test.gd
godot --headless --script tests/save_test.gd
godot --headless --script tests/player_test.gd
godot --headless --fixed-fps 60 --script tests/world_test.gd
godot --headless --script tests/music_flow_test.gd
godot --headless --script tests/integration_test.gd
```

Os testes usam nomes próprios de gravação. Em ambientes Linux com a pasta pessoal apenas de leitura, aponta `XDG_DATA_HOME`, `XDG_CONFIG_HOME` e `XDG_CACHE_HOME` para pastas graváveis. O script `tools/run_checks.sh` faz isso numa pasta temporária e valida os seis grupos.

As texturas e os ensaios já estão incluídos. `tools/generate_assets.py` permite regenerá-los opcionalmente com Python, NumPy, Pillow e FFmpeg; estas ferramentas não são dependências do jogo.
