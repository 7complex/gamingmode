# GamingMode
## PROJETO 100% BRASILEIRO

Script em Bash para otimizar o desempenho do Debian durante jogos.

O objetivo é reduzir processos desnecessários e aplicar ajustes temporários no sistema para diminuir a latência e aproveitar melhor o hardware enquanto você joga.

Todos os ajustes são reversíveis. Ao finalizar a jogatina, basta restaurar as configurações originais com `--disable`.

---

## Funcionalidades

- Diagnóstico completo do sistema antes da otimização.
- Identificação dos processos que mais consomem CPU, memória e I/O.
- Encerramento automático de processos configurados como bloat.
- Lista de processos protegidos que nunca são finalizados.
- Ajuste automático do governor da CPU.
- Ajuste de parâmetros do kernel (`sysctl`).
- Otimização de memória (swappiness, cache, dirty ratios).
- Otimização do scheduler de I/O.
- Ajustes de rede para reduzir latência.
- Priorização automática de jogos (`nice` e `ionice`).
- Backup automático de todas as configurações alteradas.
- Restauração completa das configurações originais.
- Modo High Performance (`--high`).
- Modo Automático (`--auto`).

---

## Requisitos

- Debian 12 ou superior (também pode funcionar em distribuições derivadas).
- Bash.
- Permissões de administrador (`sudo`).

Alguns recursos utilizam ferramentas opcionais como:

- lm-sensors
- util-linux
- powertop
- nvidia-smi (NVIDIA)
- rocm-smi (AMD)

---

## Instalação

Clone o repositório:

```bash
git clone https://github.com/7complex/gamingmode.git
```

Entre na pasta:

```bash
cd gamingmode
```

Dê permissão de execução:

```bash
chmod +x gamingmode.sh
```

---

## Uso

Ativar o modo padrão:

```bash
sudo ./gamingmode.sh --enable
```

Ativar o modo High Performance:

```bash
sudo ./gamingmode.sh --enable --high
```

Modo automático:

```bash
sudo ./gamingmode.sh --auto
```

Modo automático com High Performance:

```bash
sudo ./gamingmode.sh --auto --high
```

Modo silencioso:

```bash
sudo ./gamingmode.sh --enable --silent
```

Restaurar todas as configurações:

```bash
sudo ./gamingmode.sh --disable
```

---

## Como funciona

Quando ativado, o script:

1. Faz backup das configurações atuais.
2. Executa um diagnóstico completo do sistema.
3. Finaliza processos considerados desnecessários.
4. Aplica otimizações no kernel.
5. Ajusta CPU, memória e I/O.
6. Prioriza automaticamente processos de jogos.
7. Para serviços que não são necessários durante a jogatina.

Ao executar `--disable`, todas as configurações salvas são restauradas.

---

## Segurança

O script:

- nunca modifica arquivos permanentemente;
- faz backup antes de alterar qualquer configuração;
- restaura todas as alterações quando desativado;
- possui uma lista de processos protegidos que nunca são encerrados.

---

## Documentação

A documentação completa pode ser encontrada em:

**[DOCUMENTATION.md](DOCUMENTATION.md)**

Lá estão descritos todos os parâmetros, modos de funcionamento, processos protegidos, otimizações aplicadas e detalhes técnicos.

---

## Licença

Este projeto está distribuído sob a licença MIT.

Veja o arquivo **LICENSE** para mais informações.
