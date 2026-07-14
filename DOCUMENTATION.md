# Documentação do GamingMode

## Índice

1. Introdução
2. Requisitos
3. Instalação
4. Uso
5. Modos de operação
6. Fluxo interno
7. Otimizações aplicadas
8. Processos protegidos
9. Processos bloat
10. Backup e restauração
11. Modo automático
12. Logs
13. Personalização
14. Solução de problemas
15. Limitações
16. Licença

---

## Introdução

GamingMode é um script em Bash voltado para reduzir processos desnecessários e aplicar otimizações temporárias no sistema durante sessões de jogos. Todas as alterações são reversíveis por meio do comando `--disable`.

## Requisitos

- Debian 12+ (ou derivados compatíveis)
- Bash
- sudo

Recursos opcionais:

- lm-sensors
- powertop
- util-linux
- nvidia-smi
- rocm-smi

## Instalação

```bash
git clone https://github.com/7complex/gamingmode.git
cd gamingmode
chmod +x gamingmode.sh
```

## Uso

```bash
sudo ./gamingmode.sh --enable
sudo ./gamingmode.sh --enable --high
sudo ./gamingmode.sh --auto
sudo ./gamingmode.sh --disable
```

## Modos de operação

| Opção | Descrição |
|-------|-----------|
| --enable | Ativa o modo de otimização. |
| --disable | Restaura todas as configurações salvas. |
| --high | Aplica otimizações adicionais. |
| --silent | Reduz a saída no terminal. |
| --auto | Ativa/desativa automaticamente ao detectar um jogo. |

## Fluxo interno

1. Cria backup das configurações.
2. Executa diagnóstico.
3. Finaliza processos classificados como bloat.
4. Aplica ajustes de CPU, memória, I/O e rede.
5. Prioriza processos de jogos.
6. Interrompe serviços configurados.
7. No `--disable`, restaura tudo a partir do backup.

## Otimizações aplicadas

### CPU

- Governor `performance`
- Priorização com `nice` e `ionice`

### Memória

- Ajuste de `vm.swappiness`
- Ajuste de `vm.vfs_cache_pressure`
- Ajuste de `dirty_ratio`
- Ajuste de `dirty_background_ratio`

### I/O

- Scheduler adequado ao tipo de disco.

### Rede

- Ajustes em buffers e backlog para reduzir latência.

### GPU (modo high)

- NVIDIA: persistência via `nvidia-smi`, quando disponível.
- AMD: perfil de desempenho via `rocm-smi`, quando disponível.

## Processos protegidos

Os processos definidos em `PROTECTED_PROCS` nunca são encerrados.

## Processos bloat

Os processos definidos em `BLOAT_PROCS` podem ser encerrados durante a ativação.

## Backup e restauração

Os backups são armazenados em `BACKUP_DIR`. Caso existam, o comando `--disable` restaura todos os parâmetros salvos.

## Modo automático

O modo automático monitora periodicamente os processos em execução. Ao detectar um jogo compatível, ativa o GamingMode. Quando o jogo é encerrado, restaura as configurações originais.

## Logs

Quando habilitado, o script registra suas ações em `LOG_FILE`.

## Personalização

As principais variáveis ficam no início do script:

- PROTECTED_PROCS
- BLOAT_PROCS
- BACKUP_DIR
- LOG_FILE

## Solução de problemas

### sensors não encontrado

```bash
sudo apt install lm-sensors
sudo sensors-detect --auto
```

### swapon não encontrado

```bash
sudo apt install util-linux
```

### GPU NVIDIA

Verifique se os drivers proprietários estão instalados.

## Limitações

- Não realiza overclock.
- Não altera BIOS.
- Não substitui drivers atualizados.
- Os ganhos de desempenho dependem do hardware e da carga do sistema.

## Licença

Distribuído sob a licença MIT.
