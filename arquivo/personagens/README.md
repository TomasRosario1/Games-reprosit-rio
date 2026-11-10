# Arquivo de personagens

Esta pasta guarda os modelos para consulta e trabalho posterior. Está excluída da importação e exportação automática do Godot por `.gdignore`; não substitui nem é carregada pelas personagens do jogo atual.

## Emmet — modelo enviado

- [Original intacto](emmet/original/gta_sa_emmet.glb).
- [Revisão 04 atual: animações dos quatro veículos — carro, mota, bicicleta e trotinete](emmet/revisao_04/README.md).
- [Revisão 03: andar, entrar no carro e montar a mota — preservada](emmet/revisao_03/README.md).
- [Revisão 02: articulação aprovada, preservada](emmet/revisao_02/README.md).
- [Revisão 01 anterior: preservada para comparação](emmet/revisao_01/README.md).
- [Metadados do ficheiro original](emmet/original/metadados.json).

O Emmet **ainda não é a quarta personagem jogável**. A articulação da revisão 02 foi aprovada. Agora revemos as animações de locomoção e entrada nos veículos; a seguir as variantes de cor/forma. Cada etapa aguarda o feedback do criador. Só uma versão aprovada será integrada no jogo.

## Personagens já existentes — cópia de arquivo

Vinte GLB completos, copiados sem alteração dos recursos do jogo no commit `60a593be2a7c248aecc5c77507b906782196b8cc`. Incluem as texturas, esqueletos e animações que já tinham; não são uma nova revisão desses modelos. Os três artistas usam aparências deste catálogo, não modelos adicionais separados.

| ID | Nome | Guarda-roupa | Altura | Utilização atual | Ficheiro arquivado |
| --- | --- | --- | --- | --- | --- |
| 00 | Camisa e malha | beto | 1.83 m | Artista 01 / NPC | [GLB](jogo_atual/person_00.glb) |
| 01 | Casaco comprido | alternativo | 1.86 m | NPC | [GLB](jogo_atual/person_01.glb) |
| 02 | Fato de treino | chunga | 1.77 m | NPC | [GLB](jogo_atual/person_02.glb) |
| 03 | T-shirt e jeans justos | emo | 1.74 m | Artista 02 / NPC | [GLB](jogo_atual/person_03.glb) |
| 04 | Blusão e ganga | normal | 1.80 m | NPC | [GLB](jogo_atual/person_04.glb) |
| 05 | Camisa aberta | indie | 1.88 m | NPC | [GLB](jogo_atual/person_05.glb) |
| 06 | Casaco técnico | alternativo | 1.79 m | Artista 03 / NPC | [GLB](jogo_atual/person_06.glb) |
| 07 | Sweat e calças largas | normal | 1.72 m | NPC | [GLB](jogo_atual/person_07.glb) |
| 08 | Polo e chinos | beto | 1.85 m | NPC | [GLB](jogo_atual/person_08.glb) |
| 09 | Blusão de ganga | indie | 1.81 m | NPC | [GLB](jogo_atual/person_09.glb) |
| 10 | Gabardina e saia reta | beto | 1.72 m | NPC | [GLB](jogo_atual/person_10.glb) |
| 11 | Casaco e saia rodada | alternativo | 1.69 m | NPC | [GLB](jogo_atual/person_11.glb) |
| 12 | Sweat e cargo | chunga | 1.67 m | NPC | [GLB](jogo_atual/person_12.glb) |
| 13 | T-shirt e saia plissada | emo | 1.65 m | NPC | [GLB](jogo_atual/person_13.glb) |
| 14 | Malha e jeans | normal | 1.73 m | NPC | [GLB](jogo_atual/person_14.glb) |
| 15 | Camisa e saia longa | indie | 1.76 m | NPC | [GLB](jogo_atual/person_15.glb) |
| 16 | Blusão e calças largas | alternativo | 1.70 m | NPC | [GLB](jogo_atual/person_16.glb) |
| 17 | Casaco curto e saia | normal | 1.62 m | NPC | [GLB](jogo_atual/person_17.glb) |
| 18 | Malha e calças direitas | beto | 1.78 m | NPC | [GLB](jogo_atual/person_18.glb) |
| 19 | Casaco comprido e ganga | indie | 1.74 m | NPC | [GLB](jogo_atual/person_19.glb) |

O [catálogo JSON](catalogo.json) regista os caminhos e SHA-256 para conferir a integridade. Para recuperar um modelo, copia o GLB escolhido para uma pasta de recursos do teu projeto e importa-o no Blender/Godot. Não é necessário remover o `.gdignore` do arquivo inteiro.

Ferramentas de preparação e renderização: [ferramentas](ferramentas/). Não correm quando o jogo abre.
