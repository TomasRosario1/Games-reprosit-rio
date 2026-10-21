# Álbum Visual — Lisboa Noturna · Protótipo 02

Experiência **desktop, offline e em terceira pessoa**, em Godot 4 Compatibility, para o álbum de «Odio puro no meu peito». Esta revisão acrescenta uma praça inspirada no Saldanha, personagens articuladas, habitantes com reações, veículos conduzíveis, menus e um editor dentro do jogo. Continua a ser um protótipo com recursos provisórios.

## Descarregar e abrir no Windows

1. Abre [a versão 02 no GitHub](https://github.com/TomasRosario1/Games-reprosit-rio/tree/codex/album-visual-prototipo-02), com a tua conta ligada. Confirma a branch **codex/album-visual-prototipo-02**.
2. Clica no botão verde **Code → Download ZIP**. Não uses «Guardar como» sobre a página.
3. Na pasta Transferências, clica no ZIP com o botão direito → **Extrair tudo → Extrair**.
4. Abre o Godot → **Importar** → procura a pasta extraída → seleciona **project.godot → Importar e editar**.
5. Mantém o renderizador **Compatibility**. Aguarda a importação e carrega em **F5**.
6. Escolhe **Artista 01**, **02** ou **03** para começar no telhado.

Podes experimentar com o Godot 4.7.2 que tens; a versão validada neste ambiente foi **4.6.3, em Linux**. Se houver erro, o texto do erro permite identificar a incompatibilidade. Esta entrega é o projeto para abrir no Godot; ainda não inclui um executável Windows exportado.

Não precisas de Python, Blender, conta, Internet ou IA para jogar. Os GLB, texturas e áudios já estão incluídos.

## Primeiro percurso

**Telhado → escadas → pulseira → segurança → bar Lado B → atuação.**

- No telhado, segue a indicação **↓ RUA** até às escadas exteriores.
- Na rua, procura a pulseira vermelha perto do cruzamento. Aproxima-te e carrega em **E**.
- Leva-a ao segurança do Lado B e interage. A porta abre e o acesso fica guardado.
- Entra e aproxima-te da mesa de som. **E** abre a lista de músicas em papel, com pré-escuta e dificuldade.
- Durante a atuação, acerta **D F J K** na linha inferior. Acertos recuperam público; erros levam pessoas a caminhar até à saída.

As três faixas são **ensaios instrumentais sintetizados para testes**, não músicas da banda. Os nomes e modelos dos três protagonistas também são provisórios.

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

- **Cidade:** praça, monumento, fachadas e mobiliário inspirados no Saldanha; calçada e materiais urbanos texturados, luz quente, nevoeiro e limites reais de desenho. O percurso anterior continua acessível.
- **Pessoas:** catálogo original de **10 homens e 10 mulheres**, em GLB, com pele deformável, esqueleto, roupa de silhuetas diferentes e animações de locomoção, dança e reação. A passada acompanha a velocidade. Os modelos continuam a precisar de direção artística e afinação.
- **NPCs:** cinco perfis independentes da roupa; observação, desvio, encontrão, recuo/irritação e regresso ao percurso. O menu ajusta o orçamento de peões próximos para 6, 10 ou 16; clientes do bar, segurança e polícia são grupos adicionais.
- **Discoteca:** oito clientes persistentes circulam, dançam e atravessam a porta para sair/regressar. A recuperação do público reutiliza as mesmas pessoas. Luzes e néons respondem ao som.
- **Veículos:** carro, mota, bicicleta e trotinete estacionados junto da praça podem ser conduzidos. A mesma personagem aproxima-se, entra, assume uma pose articulada e sai; a bicicleta tem pedalada. A saída exige pouca velocidade e espaço livre. Impactos frontais fortes podem projetar o condutor da mota/bicicleta.
- **Polícia e combate secundário:** soco simples, dano, patrulha/perseguição por visão e pressão policial. Encontrões não aumentam a pressão. Agressões a civis observadas pela polícia e agressões à polícia podem aumentá-la. Ainda não há combos nem combate final.
- **HUD:** sempre visível durante exploração, com objeto/punho, barra de vida, dinheiro em **€000000000** e indicador policial contínuo de cinco partes que se preenche gradualmente e desaparece sem pressão.
- **Pausa:** menu escuro com brief, mapa esquemático, qualidade baixa/média/alta, população, legendas de diálogo, brilho, controlos, quatro volumes, guardar/carregar, editor e saída confirmada.
- **Editor:** câmara de voo, seleção, transformações, materiais/luzes, catálogo de peças, NPCs, missões simples e veículos, desfazer/refazer e ficheiro de mundo separado. Inclui cliente para IA local com proposta e pré-visualização; o modelo não está incluído.

Os veículos desta entrega são **modelos originais provisórios**. O SanAndreasUnity inclui sistemas de veículos, mas carrega os recursos visuais de uma instalação externa de GTA. Esses modelos não estão incluídos no repositório de referência nem neste projeto. A análise dos ficheiros consultados está em [Referências](docs/REFERENCIAS_NPCS.md).

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

Antes de limpar dados, fecha o jogo e copia os ficheiros para outra pasta. As edições do mundo são locais; não modificam automaticamente o código no GitHub.

Ainda faltam músicas e personagens definitivas da banda, animações de entrada/saída trabalhadas à mão, física/combate completos, combos, vocalizações, mais missões e interiores, efeitos de objetos e escalada completa. O editor altera propriedades e cria situações simples; não substitui o Godot ou o Blender. A cidade e a atmosfera ainda são estudos em desenvolvimento.

**60 FPS no HP EliteBook é um objetivo por medir no equipamento real.** Gaussian splatting não foi adicionado: nesta fase usamos geometria texturada, limites de desenho, nevoeiro e simulação por distância.

## Desenvolvimento e validação

- [Referência acrescentada pelo criador](<Ter como referencia>)
- [Auditoria das 19 etapas — 21 de outubro](docs/ESTADO_19_ETAPAS.md)
- [Plano técnico do mapa contínuo](docs/PLANO_MAPA_CONTINUO.md)
- [Design e decisões](docs/GDD.md)
- [Próximas etapas](docs/ROADMAP.md)
- [Resultados dos testes e capturas reais](docs/VALIDACAO.md)
- [Editor e instalação opcional da IA](docs/EDITOR.md)
- [Referências técnicas](docs/REFERENCIAS_NPCS.md)
- [Créditos dos recursos](assets/CREDITOS.md)

Com Godot no PATH, executa `./tools/run_checks.sh` em Linux. O script importa os recursos e verifica ritmo, persistência, personagens, movimento, mundo, NPCs, público, polícia, veículos, menus, editor, música e integração. As verificações de transformações MultiMesh exigem também execução com renderização nativa; o modo headless identifica as duas omissões explicitamente.

Para regenerar recursos opcionalmente: `tools/generate_assets.py` e `tools/generate_city_textures.py` usam Python, NumPy, Pillow e FFmpeg conforme o gerador; `tools/generate_characters.py` é executado pelo Blender. O jogo usa os recursos já exportados, sem executar estes geradores.
