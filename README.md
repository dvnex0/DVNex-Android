# DVNex NEW 3 — protótipo Chromium Android

Esta branch contém uma base experimental para compilar um **navegador Android real baseado em Chromium**, usando a série de patches Cromite como ponto de partida. Não usa Android WebView nem GeckoView.

> **Estado:** script de preparação/compilação criado; ainda não existe APK gerado ou build integral validado. O primeiro alvo é ARM64.

## O que está nesta branch

- Script: [scripts/build-dvnex-cromium-arm64.sh](scripts/build-dvnex-cromium-arm64.sh)
- Guia técnico e pins exatos: [docs/CROMIUM_CROMITE_153_ALPHA.md](docs/CROMIUM_CROMITE_153_ALPHA.md)
- Alvo GN: `chrome_public_apk`
- Application ID: `com.browser.dvnexnew3`
- Nome do aplicativo: `DVNex NEW 3`

## Atenção à versão

Esta branch fixa Chromium **153.0.8010.37** para corresponder ao conjunto de patches Cromite que foi inspecionado. Em 4 de novembro de 2026, Chrome Stable para Android já está na versão **157.0.8103.38**. Portanto, esta branch é apenas para validar a cadeia de compilação e testar o aplicativo; não deve ser usada como navegador diário nem distribuída publicamente.

A etapa de lançamento exigirá portar e validar os patches para o Chromium estável atual.

## Como compilar

A compilação completa exige Linux x86_64, bastante armazenamento e memória. Consulte o guia antes de executar:

```bash
chmod +x scripts/build-dvnex-cromium-arm64.sh
./scripts/build-dvnex-cromium-arm64.sh
```

O script baixa Chromium e suas dependências. O repositório Git contém apenas scripts e configuração, não uma cópia do checkout completo do Chromium.

## Histórico

A branch `main` e o pipeline anterior baseado em Thorium foram preservados. Esta branch é uma linha separada de experimentação com Cromite/Chromium 153.
