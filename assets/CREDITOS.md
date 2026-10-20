# Recursos do protótipo — revisão 2

Os recursos visuais e sonoros abaixo são estudos provisórios para o Álbum Visual. A direção artística segue as referências fornecidas pelo criador; ainda precisa da sua avaliação visual e de afinação.

## Personagens e animações

- `characters/person_00.glb` a `person_19.glb`: vinte adultos low-poly originais, dez homens e dez mulheres, criados com o gerador Blender [generate_characters.py](../tools/generate_characters.py). Incluem malhas com pesos, rig humano de dezoito ossos, roupa com silhuetas diferentes e clips de locomoção/dança criados para o projeto. Não são captura de movimento nem modelos GTA convertidos.
- Os atlas `characters/person_*_atlas.png` são texturas originais geradas pelo mesmo script, com tecido, costuras, desgaste, pele e cabelo. Os nomes de guarda-roupa do catálogo descrevem o aspeto; não determinam a personalidade ou hostilidade do NPC.
- `characters/source/human_source.blend` guarda o primeiro corpo e rig para edição no Blender. Os restantes GLB também podem ser importados. Instruções de regeneração em [characters/README.md](characters/README.md).

## Cidade, veículos e interface

- As texturas `textures/city_*` de pedra, reboco, calçada, asfalto, telhas e folhagem, os mapas de normais/rugosidade e a máscara de brilho foram gerados por [generate_city_textures.py](../tools/generate_city_textures.py). As restantes texturas procedurais do primeiro protótipo vêm de [generate_assets.py](../tools/generate_assets.py).
- A geometria da cidade e do bar é construída no projeto. A praça é uma interpretação estilizada inspirada em Saldanha, sem reprodução exata dos edifícios. A imagem fornecida pelo criador serviu de referência visual; não foi aplicada como textura ou fundo do jogo.
- Carro, mota, bicicleta e trotinete são modelos originais provisórios construídos em [vehicle.gd](../scripts/vehicle.gd), com materiais do projeto. Não foram importados veículos de GTA ou de outro jogo.
- O desenho do menu, o mapa esquemático, o ícone do punho e o indicador policial foram criados no projeto. As referências GTA orientam a apresentação; não foram usadas fontes, ícones ou imagens de interface desses jogos.

## Som e fontes

- As três faixas `audio/demo_*.ogg` e `audio/city.ogg` são sintetizadas pelo gerador [generate_assets.py](../tools/generate_assets.py), sem gravações externas. São material de teste: não representam o álbum, o som final da banda ou uma gravação de Lisboa. Os efeitos sintetizados do protótipo também são provisórios.
- `fonts/Interface.ttf`: DejaVu Sans. `fonts/Editorial.ttf`: DejaVu Serif. `fonts/Menu.ttf`: DejaVu Sans Condensed Bold. Licença Bitstream Vera, avisos e atribuições em [fonts/LICENSE-DejaVu.txt](fonts/LICENSE-DejaVu.txt); projeto [DejaVu Fonts](https://dejavu-fonts.github.io/).

## Referências e conteúdos por fornecer

As referências a Lisboa e à banda “Odio puro no meu peito” vêm do documento de design do criador. As faixas do álbum, identidades finais dos três protagonistas e outros recursos finais ainda precisam de ser fornecidos ou produzidos. O protótipo não inclui pesos de modelos de IA; a ligação local do editor depende de Ollama e de um modelo instalado no computador do criador.

Nenhum código, modelo, textura, esqueleto ou clip dos repositórios de jogos estudados foi incorporado nesta implementação. A análise e as licenças observadas estão em [REFERENCIAS_NPCS.md](../docs/REFERENCIAS_NPCS.md), incluindo a dependência de dados GTA no SanAndreasUnity. Essas referências permanecem separadas dos recursos originais do Álbum Visual.
