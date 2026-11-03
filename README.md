# DVNex NEW for Android

Projeto para desenvolver o **DVNex NEW como navegador Android completo**, baseado no código-fonte Chromium e nas modificações do projeto Thorium.

> **Estado atual:** estrutura inicial e planejamento técnico. Ainda não existe APK próprio nem pipeline de compilação validado.

## Objetivo

- Navegador Android independente, não um aplicativo baseado em Android WebView.
- Base Chromium/Thorium, com interface e identidade visual DVNex.
- Primeiro alvo de validação: **Android ARM64**.
- Depois de validar o build ARM64, avaliar ARM32 e x86_64 e decidir entre APK universal e distribuição por variantes.

## Repositórios de referência

- [Thorium (código-fonte e patches)](https://github.com/Alex313031/thorium)
- [Thorium Android (distribuição Android)](https://github.com/Alex313031/Thorium-Android)

Este repositório contém a integração e as personalizações do DVNex; ele não replica o enorme checkout completo do Chromium.

## Plano de desenvolvimento

1. Validar o ambiente Linux de compilação e a revisão Chromium usada pelo Thorium.
2. Sincronizar Chromium + depot_tools + Thorium e preparar a configuração Android.
3. Compilar o APK ARM64 sem alterações de marca.
4. Instalar e testar em dispositivo real e emulador.
5. Aplicar package ID, nome, ícones, recursos e interface DVNex.
6. Repetir testes e planejar as variantes de arquitetura.

## Requisitos de compilação

A compilação Chromium/Thorium não é uma compilação Android Studio comum. Consulte [docs/BUILD_STRATEGY.md](docs/BUILD_STRATEGY.md) antes de configurar uma máquina.

## Licenças e atribuições

Chromium e Thorium possuem componentes e avisos de licença próprios. As modificações deste projeto deverão preservar os avisos de copyright, as licenças de terceiros e as atribuições exigidas. Consulte também os arquivos de licença nos repositórios de origem.

## Aviso

Não use este repositório como se já fosse um navegador pronto. O primeiro marco é obter um APK ARM64 reproduzível; interface, sincronização e distribuição vêm depois.
