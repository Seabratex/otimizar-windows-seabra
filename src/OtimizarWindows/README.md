# Otimizar Windows — migração C#

Este projeto é a reconstrução gradual do aplicativo original em Batch/PowerShell.

## Diretrizes

- Preservar a interface gráfica e a identidade visual azul-marinho/prata.
- Reimplementar as operações em C#; não executar nem extrair o arquivo BAT/PowerShell original.
- Manter as 10 etapas e as opções correspondentes.
- Publicar como executável Windows x64, self-contained e single-file.
- Exigir elevação administrativa por manifesto.

## Estado

A primeira entrega contém a estrutura WinForms e a reprodução da interface. O botão Executar permanece desabilitado intencionalmente até que as rotinas sejam migradas e testadas; esta versão ainda não deve ser distribuída como substituta do aplicativo original.

## Publicação (em ambiente Windows com .NET 8 SDK)

```powershell
dotnet publish .\OtimizarWindows.csproj -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true
```

A saída será gerada em `bin\Release\net8.0-windows\win-x64\publish\`.
