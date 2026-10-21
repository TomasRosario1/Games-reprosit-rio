# Mapas do criador — entrega e recorte

O criador indicou uma pasta `Maps` no seu computador Windows. Este ambiente na nuvem não tem acesso ao disco desse computador. Até os ficheiros serem anexados ou disponibilizados por uma ligação acessível, não é possível medir, recortar ou importar esses mapas. Nenhum deles foi substituído por uma alegada importação OSM nesta atualização.

## Enviar os ficheiros

1. No Explorador do Windows, abre a pasta `Maps` indicada no chat.
2. Identifica os mapas de **Saldanha**, **Pink Street/Cais do Sodré** e **Bairro Alto**.
3. Compacta cada mapa num ZIP, incluindo as texturas e outros ficheiros associados. Num glTF, inclui também o `.bin` e a pasta de imagens; num projeto Blender, inclui ou empacota os recursos externos.
4. Anexa os ZIP nesta conversa, ou coloca os ficheiros no GitHub/num local de descarga e envia a ligação. Um caminho começado por `C:\` não é uma ligação acessível a este ambiente.
5. Se os ficheiros forem grandes, começa apenas pelo **Saldanha**. Não precisas de recortar os originais antes de enviar; o recorte será feito numa cópia.

Não basta enviar um atalho do Windows. Os ficheiros de geometria e os recursos de que dependem têm de acompanhar o mapa. GLB/GLTF, Blender e dados OSM têm preparações diferentes; a primeira inspeção determinará o processo adequado.

## O que preservar

| Mapa | Elementos prioritários |
| --- | --- |
| Saldanha | Praça/avenida ampla, faixa de circulação, passeios e fachadas que definem o local |
| Pink Street / Cais do Sodré | Rua dos bares, entradas/interiores úteis, espaço para pessoas e ligações pedonais |
| Bairro Alto | Ruas estreitas, subidas/descidas, fachadas e bares, privilegiando circulação de peões |

O criador autorizou cortar as áreas em excesso. A decisão concreta deve preservar ruas de ligação, acessos e edifícios reconhecíveis; cortar o resto sem deixar buracos, fachadas abertas para o jogador ou colisões desligadas nas fronteiras.

## Inspeção e integração previstas

Depois de receber os ficheiros: verificar formato e integridade, dimensões/eixos, texturas, hierarquia, número de polígonos, materiais e dependências; guardar a origem e créditos aplicáveis; recortar numa cópia; preparar colisões e detalhe à distância; e testar primeiro um pequeno recorte do Saldanha com o jogador e os veículos atuais.

O mapa final continua **compacto, com proporções realistas**. Os recortes serão ligados por ruas adaptadas, sem obrigação de reproduzir as distâncias reais de Lisboa. A Ponte 25 de Abril será uma interpretação proporcional junto ao Tejo, cuja posição e escala finais dependem dos limites e cotas dos mapas recebidos. Não foi ainda colocada nem validada.

Gaussian splatting é admitido como recurso opcional para planos/fundos específicos. A escolha depende de existir um recurso adequado e de comparar qualidade, custo e integração no renderer Compatibility; não é necessário converter toda a cidade nem substituir geometria de colisão ou personagens por splats.
