# Emmet — animações dos quatro veículos

O arquivo cobre agora **carro, mota, bicicleta e trotinete**, os quatro tipos de veículos que existem no projeto. Esta etapa acrescenta a montagem na bicicleta e a subida para a trotinete. Os vídeos e fontes do carro e da mota da revisão 03 foram preservados, sem alterações.

## Ver os vídeos

[**Descarregar o vídeo com os quatro veículos — 32 segundos**](https://github.com/TomasRosario1/Games-reprosit-rio/raw/refs/heads/main/arquivo/personagens/emmet/revisao_04/00_todos_os_veiculos.mp4)

| Veículo | Vídeo individual | O que observar | No vídeo completo |
| --- | --- | --- | --- |
| Carro | [Entrar no carro](../revisao_03/02_entrar_carro.mp4) | Aproximar, abrir a porta, baixar o corpo, recolher as pernas, sentar e fechar a porta. | 0–8 s |
| Mota | [Montar a mota](../revisao_03/03_montar_mota.mp4) | Apoiar a mão, passar a perna sobre o banco e ajustar a posição no guiador e apoios. | 8–16 s |
| Bicicleta — novo | [Montar a bicicleta](04_montar_bicicleta.mp4) | Apoiar no guiador, levantar a perna acima do selim, apoiar no pedal e sentar. Os pés terminam nos dois pedais, que estão a alturas diferentes. | 16–24 s |
| Trotinete — novo | [Subir para a trotinete](05_subir_trotinete.mp4) | Agarrar o guiador, apoiar o primeiro pé na plataforma, transferir o peso e subir o outro pé. Termina com os pés desencontrados sobre a plataforma. | 24–32 s |

Cada vídeo individual tem oito segundos, em **720p a 24 fps**. No GitHub, usa **View raw / Download raw file** para abrir ou descarregar os MP4, com a tua conta ligada ao repositório privado. Depois de extrair o ZIP do projeto, também podes abrir [ver_videos.html](ver_videos.html) no navegador, sem Internet: inclui os quatro vídeos e reprodução a 0,25×, 0,5× ou 1×.

## Ficheiros editáveis

| Veículo | Blender | GLB com a animação |
| --- | --- | --- |
| Carro | [Fonte preservada](../revisao_03/02_entrar_carro.blend) | [GLB](../revisao_03/02_entrar_carro.glb) |
| Mota | [Fonte preservada](../revisao_03/03_montar_mota.blend) | [GLB](../revisao_03/03_montar_mota.glb) |
| Bicicleta | [04_montar_bicicleta.blend](04_montar_bicicleta.blend) | [04_montar_bicicleta.glb](04_montar_bicicleta.glb) |
| Trotinete | [05_subir_trotinete.blend](05_subir_trotinete.blend) | [05_subir_trotinete.glb](05_subir_trotinete.glb) |

No Blender, **Numpad 0 → Espaço** mostra a câmara preparada e reproduz o movimento. Cada GLB tem uma única animação, com deslocação da raiz e o respetivo veículo. Conserva a amostragem de **24 fps** ao importar.

Os dois novos movimentos usam as posições dos 21 ossos aprovadas na revisão 02 e os pesos de pele da revisão 03. Não alteram as proporções, as mãos ou a textura do modelo original. A bicicleta e a trotinete foram exportadas dos veículos do próprio projeto; as [cópias originais e os metadados](veiculos/) ficam guardados. Acrescentou-se um descanso visível em cada cena de revisão para manter o veículo apoiado enquanto a personagem sobe. Os dedos continuam sem articulação individual.

## Validação

- [Catálogo dos quatro veículos](veiculos.json): vídeos, fontes, GLB e intervalos no vídeo completo.
- [Relatório de validação](validacao.json): cobertura dos quatro tipos, integridade dos modelos, contactos e descodificação dos vídeos.
- [Validação nativa no Godot](validacao_godot.json): importação dos dois novos GLB a 24 fps e comparação de mãos/pés em todos os 192 fotogramas de cada animação.
- [Verificação dos ficheiros Blender](fontes_validadas.json): ossos e geometria em repouso, UVs, pesos normalizados e câmaras.
- [Contactos por fotograma](contactos.json): posições pedidas e efetivas das mãos e pés, apoio das solas, altura final do assento e posição da raiz.

Os vídeos foram renderizados a partir das animações reais guardadas nos ficheiros 3D. A verificação técnica não substitui o teu feedback sobre ritmo, postura ou deformação da roupa.

## Reproduzir a preparação

Na raiz do projeto, com Godot, Blender e FFmpeg disponíveis:

```sh
godot --headless --path . --script arquivo/personagens/ferramentas/exportar_veiculos_leves.gd
blender -t 4 -b --python arquivo/personagens/ferramentas/animar_veiculos_leves.py -- --render
blender -t 1 -b --python arquivo/personagens/ferramentas/validar_fontes_revisao04.py
python3 arquivo/personagens/ferramentas/codificar_veiculos_revisao04.py
godot --headless --path . --script arquivo/personagens/ferramentas/validar_veiculos_revisao04.gd
python3 arquivo/personagens/ferramentas/validar_revisao04.py
```

Na nuvem, usar pastas XDG graváveis. Os fotogramas temporários ficam em `/tmp/emmet-review-04`; não entram no GitHub. O exportador abre um processo novo por GLB e conserva apenas a ação pedida, para evitar misturar animações antigas.

Esta pasta continua **separada do jogo atual** pelo `.gdignore` do arquivo. Nesta etapa preparamos entradas/montagens para revisão; não foram acrescentadas saídas, condução animada ou a quarta personagem jogável. O próximo passo depende do feedback sobre estas animações, antes das variantes de cor/forma e da integração combinada.
