# DVNex NEW 3 — base Ultimatum

## Decisão de arquitetura

O DVNex NEW 3 passa a usar como base o fork **Ultimatum**, que deriva do Chromium e contém alterações para WebExtensions no Android.

- Upstream: https://github.com/gonzazoid/Ultimatum
- Branch fixada para esta etapa: `ultimatum_android_147.0.7727.93`
- Arquitetura inicial: Android ARM64 (`arm64-v8a`)
- Alvo GN inicial: `chrome_public_apk`
- Pacote pretendido do DVNex: `com.browser.dvnexnew3`

A branch está fixada para que as instruções não mudem silenciosamente quando o upstream receber novos commits. Atualizações de Chromium serão avaliadas separadamente.

## O que esta etapa faz — e o que não faz

Esta etapa prepara a estratégia e os parâmetros de compilação. Ela **não** importa os aproximadamente 58 GB de repositório para dentro deste repositório DVNex, não executa uma compilação Chromium e não gera um APK.

O repositório Ultimatum é o código-fonte completo do Chromium forkado, não um módulo Android Studio. O checkout também precisa sincronizar dependências declaradas pelo Chromium com `depot_tools` / `gclient`.

## Argumentos GN ARM64

Use o arquivo [ultimatum-android-arm64.args.gn](../build/ultimatum-android-arm64.args.gn) como ponto de partida para `out/DVNex`.

Argumentos do upstream documentados no README do Ultimatum:

- `target_os = "android"`
- `target_cpu = "arm64"`
- `is_debug = false`
- `is_component_build = false`
- `symbol_level = 0`
- `blink_symbol_level = 0`
- `v8_symbol_level = 0`
- `ffmpeg_branding = "Chrome"`
- `proprietary_codecs = true`
- `enable_desktop_android_extensions = true`
- `enable_guest_view = true`
- `enable_platform_apps = false`

Não acrescente flags aleatórias para tentar acelerar a compilação. Primeiro gere e compile o alvo original com os argumentos suportados por esta revisão.

## Sequência de validação

1. Preparar um host Linux x86_64 com espaço em disco e memória suficientes.
2. Instalar `depot_tools`, dependências do Chromium e Android SDK/NDK conforme a documentação da revisão.
3. Fazer checkout da branch Ultimatum indicada acima e sincronizar as dependências com `gclient`.
4. Executar os hooks necessários.
5. Gerar `out/DVNex` com GN usando os argumentos deste repositório.
6. Compilar `chrome_public_apk` com `autoninja`.
7. Instalar o APK original de teste e validar navegação, abas, downloads e WebExtensions.
8. Só depois iniciar o rebranding DVNex.

**Não há garantia de build em 30 minutos.** A documentação oficial do Chromium informa que o checkout pode levar 30 minutos mesmo em conexão rápida, e pode levar muitas horas em conexões lentas. A compilação é uma etapa adicional.

## Rebranding — etapa posterior

Depois de um APK base funcional, mapear e alterar na revisão fixada:

- application ID / package;
- nome exibido e canais;
- ícones e recursos de marca;
- página Nova guia e página inicial;
- strings, menus e preferências;
- identificação de build e distribuição/atualização.

Não fazer substituições globais cegas de `Chrome`, `Chromium` ou `org.chromium`: isso pode quebrar dependências, componentes e serviços. Alterações devem ser feitas nos pontos de extensão corretos e testadas por etapa.

## WebExtensions

O Ultimatum lista extensões testadas no README, mas também documenta APIs incompletas e limitações. Suporte a extensões não significa compatibilidade universal. A lista de testes do DVNex deve ser construída com extensões específicas e casos reproduzíveis.

## Licenças

Preservar avisos de copyright, arquivos de licença e atribuições de Chromium, Ultimatum e dependências de terceiros. O fato de o repositório principal indicar BSD-3-Clause não substitui a revisão das licenças de todos os componentes incluídos no APK.

## Fontes primárias

- https://github.com/gonzazoid/Ultimatum/tree/ultimatum_android_147.0.7727.93
- https://github.com/gonzazoid/Ultimatum/blob/ultimatum_android_147.0.7727.93/README.md
- https://chromium.googlesource.com/chromium/src/+/main/docs/android_build_instructions.md
