# Estratégia de compilação Android

## Por que não começar pelo Android Studio

O Thorium não é um SDK pequeno que possa ser adicionado como dependência Gradle. O objetivo é compilar o alvo de navegador Android do Chromium, e depois personalizar a aplicação Android resultante. Isso exige o checkout Chromium completo, ferramentas do projeto Chromium e os patches do Thorium.

Referências oficiais do projeto:

- [Thorium build instructions](https://github.com/Alex313031/thorium/blob/main/docs/BUILDING.md)
- [Thorium Android build script](https://github.com/Alex313031/thorium/blob/main/build_android.sh)
- [Thorium source repository](https://github.com/Alex313031/thorium)

## Recursos

A documentação de build do Thorium lista como referência:

- Host Linux x86_64.
- Pelo menos 8 GB de RAM; 16 GB ou mais são recomendados.
- Pelo menos 75 GB livres em disco.
- Git e Python 3.8 ou superior.
- Ubuntu 22.04 é a plataforma principal de desenvolvimento indicada.

Esses valores são um mínimo documentado, não uma garantia de que qualquer máquina com esses recursos concluirá a compilação. Mais RAM, armazenamento e CPU reduzem o risco de falha.

## Fluxo de alto nível

1. Instalar e configurar depot_tools.
2. Clonar o repositório Thorium com submódulos.
3. Fazer o checkout Chromium com fetch --nohooks chromium.
4. Instalar dependências do host e executar gclient runhooks.
5. Executar os scripts Thorium na ordem documentada para sincronizar a revisão Chromium e aplicar os patches.
6. Preparar a configuração GN Android apropriada.
7. Gerar o alvo Android com GN e compilar com autoninja.
8. Localizar, assinar quando necessário, instalar e testar o APK gerado.

**Atenção:** a ordem exata e os argumentos Android devem acompanhar a revisão específica do Thorium que for fixada neste projeto. Não se deve misturar scripts de uma revisão com patches ou argumentos de outra.

## Primeiro alvo: ARM64

O script Android do Thorium define, para ARM64, os alvos:

- chrome_public_apk
- content_shell_apk
- system_webview_64_apk

O primeiro artefato de navegador a validar é chrome_public_apk. Os demais alvos são auxiliares e não substituem o navegador.

## GitHub Actions e custo de infraestrutura

GitHub Actions pode automatizar etapas, armazenar logs e publicar artefatos. Isso não torna a compilação Chromium leve. O checkout e a compilação consomem muito armazenamento, memória, CPU e tempo; um runner hospedado gratuito padrão não deve ser tratado como ambiente garantido para compilar Chromium completo.

A estratégia inicial deve usar um host Linux x86_64 com recursos suficientes (por exemplo, uma máquina própria ou runner dedicado). O workflow automatizado só deve ser ativado depois de validar manualmente o processo e confirmar a capacidade do runner. Não colocar chaves de assinatura, tokens ou credenciais no código.

## APK universal: decisão posterior

Um APK universal precisa incluir as bibliotecas nativas de todas as arquiteturas suportadas. Isso aumenta o tamanho e exige que cada ABI esteja realmente compilada e testada. O fato de um projeto gerar APK ARM64 não significa que ele funcionará em ARM32 ou x86.

A ordem correta é:

1. Validar ARM64.
2. Adicionar e testar outras ABIs, se forem viáveis.
3. Comparar APK universal com APKs separados ou Android App Bundle.
4. Escolher o formato de distribuição.

## Rebranding DVNex

A personalização só começa depois do APK Thorium/Chromium original funcionar. As mudanças deverão incluir, conforme os pontos de extensão disponíveis na revisão escolhida:

- Application ID próprio.
- Nome e ícones DVNex.
- Recursos e identidade visual.
- Interface e páginas internas.
- Configurações de distribuição e atualização.

Não remover avisos de licença nem atribuições do Chromium, Thorium ou dependências de terceiros.
