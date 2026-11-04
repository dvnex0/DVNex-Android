# Estratégia de compilação Android — Ultimatum

## Base e revisão

O DVNex NEW 3 usa o fork completo [gonzazoid/Ultimatum](https://github.com/gonzazoid/Ultimatum), na revisão fixada:

`ultimatum_android_147.0.7727.93`

O Ultimatum é um fork do Chromium com alterações para WebExtensions no Android. Não é uma biblioteca Gradle nem um projeto Android Studio convencional.

Consulte [docs/ULTIMATUM_BASE.md](ULTIMATUM_BASE.md) para a decisão de arquitetura e a sequência de validação.

## Requisitos do host

A documentação oficial do Chromium para Android exige um host Linux x86_64. Ela indica pelo menos 8 GB de RAM, recomenda mais de 16 GB e exige pelo menos 100 GB livres em disco. Windows e macOS não são plataformas suportadas para compilar o cliente Android do Chromium.

Referência: [Chromium — Android build instructions](https://chromium.googlesource.com/chromium/src/+/main/docs/android_build_instructions.md).

Esses valores são requisitos mínimos documentados, não garantia de sucesso. Um checkout completo e a compilação podem consumir muito mais tempo e recursos.

## Ferramentas

- Linux x86_64 (Ubuntu é a plataforma mais comum).
- Git e Python.
- `depot_tools` (inclui `fetch`, `gclient`, `gn` e ferramentas de build).
- Android SDK/NDK e dependências instaladas pelos scripts Chromium.
- GN e Ninja/autoninja.
- Espaço de armazenamento suficiente para checkout, dependências, cache e diretório de build.

## Configuração GN inicial

O arquivo [../build/ultimatum-android-arm64.args.gn](../build/ultimatum-android-arm64.args.gn) contém os argumentos indicados pelo README do Ultimatum para Android ARM64, incluindo:

- `target_os = "android"`
- `target_cpu = "arm64"`
- build release não componentizado;
- símbolos reduzidos;
- `enable_desktop_android_extensions = true`;
- `enable_guest_view = true`;
- `enable_platform_apps = false`.

Use essa configuração como ponto de partida para `out/DVNex/args.gn`. Não misture flags de outras versões do Chromium sem validar a compatibilidade.

## Fluxo de build

1. Preparar o host Linux e instalar `depot_tools`.
2. Fazer checkout da revisão exata do Ultimatum.
3. Configurar o checkout como solução do `gclient` e sincronizar as dependências definidas pelo arquivo `DEPS`.
4. Instalar dependências do host e executar os hooks Chromium.
5. Criar `out/DVNex/args.gn` usando o arquivo de argumentos deste repositório.
6. Gerar os arquivos de build com GN.
7. Compilar primeiro o alvo `chrome_public_apk` com `autoninja`.
8. Instalar e validar o APK original antes de modificar marca ou recursos.
9. Somente após o build base funcionar, iniciar o rebranding DVNex.

A forma exata de configurar o checkout e sincronizar dependências deve seguir as instruções Chromium aplicáveis à revisão fixada. Não usar um script de Thorium: a base agora é Ultimatum.

## Tempo e infraestrutura

O checkout pode levar pelo menos dezenas de minutos mesmo em uma conexão rápida; a documentação Chromium informa que pode levar muitas horas em conexões lentas. A compilação vem depois do checkout e dos hooks.

GitHub Actions e CircleCI não tornam o Chromium leve. Um runner hospedado gratuito padrão não deve ser tratado como ambiente garantido para compilar o Chromium completo. Primeiro validar a build num host Linux com recursos suficientes; depois automatizar num runner compatível.

## Rebranding

Depois do APK base validado, mapear os pontos corretos da revisão para alterar:

- application ID para `com.browser.dvnexnew3`;
- nome exibido, ícones e recursos;
- strings e identidade visual;
- página Nova guia e página inicial;
- preferências e distribuição.

Não fazer substituições globais cegas de `Chrome`, `Chromium` ou `org.chromium`: isso pode quebrar dependências e serviços.

## Arquitetura

A primeira meta é ARM64. ARM32, x86_64 e APK universal só devem ser considerados depois que ARM64 estiver compilado e testado. Um APK ARM64 não funciona automaticamente em todas as arquiteturas.

## Licenças

Preservar avisos de copyright, arquivos de licença e atribuições do Chromium, Ultimatum e dependências de terceiros. Revisar todas as licenças antes de distribuir o APK.
