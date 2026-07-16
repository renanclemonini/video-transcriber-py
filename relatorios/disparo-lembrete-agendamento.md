# Relatório: Disparo de Lembrete de Agendamento

## Visão Geral

Este vídeo documenta a configuração de um sistema automatizado de disparo de lembretes de consulta via WhatsApp, utilizando planilha Google Sheets, webhook e automação de mensagens. O sistema envia lembretes **um dia antes** e **no dia** da consulta, com suporte a confirmação e reagendamento.

## Fluxo Criado

### 1. Configuração do Webhook
- Foi criado um webhook na plataforma de automação para receber os dados da planilha.
- O webhook foi implantado com permissão de acesso público e configurado para aceitar disparos inseguros (unsafe).

### 2. Estrutura da Planilha (Google Sheets)
- Criada uma planilha chamada **"Disparos Bruno"** dentro de uma pasta com o mesmo nome no Google Drive.
- Colunas definidas:
  - Telefone
  - Nome do paciente
  - Consulta dia
  - Consulta horário
- A planilha é populada diariamente com os pacientes que têm consulta no dia seguinte.

### 3. Fluxo de Automação — Lembrete Um Dia Antes
- **Mensagem enviada**: 7h30 da manhã do dia anterior à consulta.
- A mensagem é um template de utilidade com botões **Confirmar** e **Reagendar**.
- Se o paciente responde com texto (em vez de clicar nos botões), o sistema captura a mensagem via campo oculto `last message` e usa um bloco de condição para interpretar a resposta.
- Palavras-chave reconhecidas como confirmação: `confirmar`, `confirmado`, `sim`, `ok`.
- Palavras-chave para reagendamento: `reagendar`, `não`.
- Respostas inválidas (áudio, figurinhas) geram mensagem de erro orientando o paciente a responder apenas em texto.

### 4. Fluxo de Automação — Lembrete No Dia
- Uma segunda sequência foi duplicada da primeira e ajustada para o disparo no dia da consulta.
- Envia mensagem informativa sobre o horário da consulta.
- Uma etiqueta **"janela aberta"** é adicionada ao contato para controle do fluxo e evitar reenvio desnecessário de templates (economia de custos).
- Se o paciente não respondeu ou respondeu com áudio, o sistema aguarda (com tentativa zero) e remove a etiqueta após o fluxo.

### 5. Sequências Criadas
- **Sequência "Lembrete Agendamento"** — dispara a mensagem um dia antes (7h30) e novamente no dia da consulta (7h30).
- Pacientes que reagendam são removidos da sequência para não receberem a mensagem do dia.

### 6. Disparo em Massa
- Desenvolvido um script App Script ([link do Sheet fornecido](https://script.google.com/...)) que envia os dados da planilha para o webhook.
- Fluxo: preencher planilha → Extensões → App Script → executar função `enviar dados` → todos os pacientes são inscritos na sequência automaticamente.
- Teste realizado com 24 envios sem erros.

## Próximos Passos (Pendências)
- **Aprovação do template de utilidade** — está em revisão na plataforma; sem aprovação, as mensagens não serão entregues.
- **Configurar as outras 3 unidades** — o mesmo fluxo precisa ser replicado para as demais clínicas/unidades.
- **Definir mensagens personalizadas** para confirmação e reagendamento (texto de agradecimento).
- **Compartilhar planilha com as secretárias** para que possam inserir os dados diariamente.

## Observações Técnicas
- O script App Script precisa ser executado manualmente todo dia após a planilha ser populada.
- O formato de data foi ajustado para `dd/mm/aaaa` com horário no formato `HH:MM` para evitar problemas de interpretação pelo webhook.
- O sistema usa campo `last message` (oculto) para capturar respostas textuais do paciente.
