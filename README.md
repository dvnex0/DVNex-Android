# DVNex NEW 3 para Android

Projeto para desenvolver o **DVNex NEW 3 como navegador Android completo**, usando o Chromium nativo por meio do fork **Ultimatum**.

> **Estado desta branch:** base técnica selecionada, revisão fixada e parâmetros GN ARM64 adicionados. Ainda não existe APK DVNex compilado nem build validado de ponta a ponta.

## Base do navegador

- Projeto upstream: [gonzazoid/Ultimatum](https://github.com/gonzazoid/Ultimatum)
- Revisão fixada: `ultimatum_android_147.0.7727.93`
- Motor: Chromium nativo, sem Android WebView e sem GeckoView.
- Primeiro alvo: Android ARM64 (`arm64-v8a`).
- Alvo de compilação inicial: `chrome_public_apk`.
- Application ID pretendido: `com.browser.dvnexnew3`.

O Ultimatum adiciona suporte a WebExtensions no Android. Esse suporte tem limitações documentadas; não significa que todas as extensões de desktop funcionarão.

## Arquivos desta branch

- [docs/ULTIMATUM_BASE.md](docs/ULTIMATUM_BASE.md) — arquitetura, revisão fixada e sequência de validação.
- [build/ultimatum-android-arm64.args.gn](build/ultimatum-android-arm64.args.gn) — argumentos GN iniciais para ARM64.
- [docs/BUILD_STRATEGY.md](docs/BUILD_STRATEGY.md) — requisitos e estratégia de compilação.

## Etapas

1. Preparar host Linux x86_64 e ferramentas Chromium.
2. Fazer checkout da revisão Ultimatum e sincronizar dependências.
3. Gerar e compilar o APK base ARM64 sem rebranding.
4. Testar navegação, abas, downloads e extensões.
5. Alterar package ID, nome, ícones, página inicial e interface para DVNex.
6. Recompilar e testar o APK DVNex.

## Importante

Este repositório DVNex contém configuração e documentação de integração; ele **não contém o checkout completo do Chromium**. Chromium não é um projeto Gradle pequeno para abrir e compilar diretamente no Android Studio. A compilação Android exige Linux, `depot_tools`, GN, Ninja/autoninja, dependências e espaço em disco substancial.

O workflow antigo de Thorium e os scripts associados ainda existem nesta branch como histórico de trabalho, mas **não devem ser executados para compilar Ultimatum**. O pipeline de Ultimatum ainda precisa ser implementado e validado.

Não há promessa de build em 30 minutos. O primeiro marco é uma compilação ARM64 reproduzível.

## Licenças

Preservar avisos de copyright, licenças de terceiros e atribuições de Chromium, Ultimatum e demais dependências. Consulte os arquivos de licença upstream antes de distribuir APKs.
