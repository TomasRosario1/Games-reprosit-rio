# Emmet — revisão das entradas após feedback

Esta revisão corrige **carro, mota e bicicleta**. A animação da **trotinete foi aprovada pelo criador e permanece intacta**, nos ficheiros da revisão 04. As revisões anteriores ficam preservadas para comparação.

[**Ver/descarregar os quatro veículos — 32 segundos**](https://github.com/TomasRosario1/Games-reprosit-rio/raw/refs/heads/main/arquivo/personagens/emmet/revisao_05/00_quatro_veiculos.mp4)

| Veículo | Vídeo | Alteração |
| --- | --- | --- |
| Carro | [01_carro.mp4](01_carro.mp4) | Começa junto da porta, atrás do arco de abertura. Pés e raiz ficam parados enquanto abre a porta; depois há dois ajustes de apoio para entrar, recolher as pernas, sentar e fechar. Foi removido o ciclo de andar à volta da porta e suavizado o apoio da mão no pilar. |
| Mota | [02_mota.mp4](02_mota.mp4) | A mota inclina 10° e a personagem usa o pousa-pés próximo como apoio. A anca sobe antes da passagem e o joelho abre para a perna atravessar por cima da traseira, em vez de cortar a estrutura. Assenta no banco e a mota regressa à vertical. |
| Bicicleta | [03_bicicleta.mp4](03_bicicleta.mp4) | Inclinação de 10°, apoio no pedal próximo, elevação da anca e passagem da perna por cima do selim. O pedaleiro começa rodado meia volta para disponibilizar o apoio alto. |
| Trotinete — aprovada | [Vídeo preservado](../revisao_04/05_subir_trotinete.mp4) | Sem alterações à animação, vídeo, GLB ou Blender. |

O vídeo completo apresenta carro **0–8 s**, mota **8–16 s**, bicicleta **16–24 s** e trotinete **24–32 s**. Todos os vídeos estão em 720p, 24 fps. O segmento da trotinete conserva a identificação da revisão 04.

No GitHub, usa **View raw / Download raw file** para abrir os MP4, com a tua conta ligada. Depois de descarregar e extrair o ZIP do repositório, podes abrir [ver_videos.html](ver_videos.html) no navegador para comparar os quatro vídeos e usar reprodução lenta.

## Fontes editáveis

| Veículo | Blender | GLB com animação |
| --- | --- | --- |
| Carro | [01_carro.blend](01_carro.blend) | [01_carro.glb](01_carro.glb) |
| Mota | [02_mota.blend](02_mota.blend) | [02_mota.glb](02_mota.glb) |
| Bicicleta | [03_bicicleta.blend](03_bicicleta.blend) | [03_bicicleta.glb](03_bicicleta.glb) |
| Trotinete | [Fonte aprovada](../revisao_04/05_subir_trotinete.blend) | [GLB aprovado](../revisao_04/05_subir_trotinete.glb) |

No Blender, **Numpad 0 → Espaço** mostra a câmara de revisão e reproduz a animação. Os GLB têm uma animação por ficheiro, com os movimentos do veículo e da personagem juntos; conservar a amostragem de 24 fps ao importar.

## Ajustes de malha e articulação

As posições dos **21 ossos aprovados**, a geometria em repouso, as proporções e as UVs da personagem foram conservadas. A abertura dos joelhos e a rotação das coxas são poses de animação.

Os antigos assentos retangulares ocupavam o espaço entre as coxas. Nesta revisão de arquivo, os assentos da mota e da bicicleta têm a frente mais estreita, como selins, preservando a largura traseira. As cópias anteriores dos veículos não foram alteradas.

Para as calças largas e as abas inferiores não atravessarem o banco ou o quadro ao sentar, há **seis correções de pose da roupa** em cada cena de duas rodas. São morph targets animados, guardados no Blender e GLB. A forma em repouso permanece no `Basis`; apenas vértices da parte inferior do corpo recebem a correção durante a pose sentada. Não é uma simulação de tecido em tempo real nem uma alteração do esqueleto aprovado.

## Verificação

- [Relatório completo](validacao.json), incluindo integridade da trotinete aprovada e descodificação dos MP4.
- [Catálogo dos quatro veículos](veiculos.json), com caminhos para os vídeos e fontes atuais.
- [Importação nativa no Godot](validacao_godot.json): contactos de mãos e pés em todos os fotogramas; pés parados ao abrir a porta; abertura/fecho da porta; inclinação e regresso à vertical; correções de roupa realmente presentes e animadas nos GLB.
- [Malha das pernas versus as partes principais da mota e bicicleta](geometria.json): interseções entre triângulos verificadas em cada um dos 192 fotogramas de cada cena. Inclui assentos, quadros, depósito/motor e rodas; não equivale a testar todas as peças do corpo contra todos os acessórios.
- No carro, o mesmo relatório verifica 65 fotogramas da abertura parada: corpo, cabeça e pernas contra o veículo e a porta, excluindo os braços que interagem com o puxador.
- [Contactos por fotograma](contactos.json): alvos, posições efetivas, raiz e inclinação.
- [Correções da roupa](roupa.json) e [fontes Blender verificadas](fontes_validadas.json).

Os vídeos são renderizações das animações reais guardadas nos ficheiros. Estas verificações técnicas não substituem a avaliação visual do ritmo, da postura e das dobras da roupa.

## Reproduzir

Na raiz do projeto:

```sh
blender -t 4 -b --python-exit-code 1 --python arquivo/personagens/ferramentas/rever_entradas_veiculos.py -- --render
blender -t 1 -b --python-exit-code 1 --python arquivo/personagens/ferramentas/validar_fontes_revisao05.py
python3 arquivo/personagens/ferramentas/codificar_revisao05.py
godot --headless --path . --script arquivo/personagens/ferramentas/validar_revisao05.gd
python3 arquivo/personagens/ferramentas/validar_arquivo_revisao05.py
```

Na nuvem, usar diretórios XDG graváveis. Os fotogramas temporários ficam em `/tmp/emmet-review-05`. `--preview` gera amostras de revisão; `--probe` verifica as poses sem guardar novas fontes nem renderizar.

O arquivo continua separado do jogo pelo `.gdignore`. Estas animações aguardam o teu feedback antes da integração; as variantes de cor/forma e a quarta personagem jogável continuam na etapa seguinte combinada.
