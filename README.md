# Implementação de API Genérica de Alocação de Memória na Heap em C

## Descrição do Projeto

Este projeto implementa um alocador de memória personalizado para a heap em C, utilizando syscalls `brk` para gerenciamento de memória.

## Funções a Implementar

### Funções Principais

- **`void iniciaAlocador()`**: Executa syscall `brk` para obter o endereço do topo corrente da heap e o armazena em uma variável global `topoInicialHeap`.

- **`void finalizaAlocador()`**: Executa syscall `brk` para restaurar o valor original da heap contido em `topoInicialHeap`.

- **`int liberaMem(void* bloco)`**: Indica que o bloco está livre para reutilização.

- **`void* alocaMem(int num_bytes)`**: 
    1. Procura um bloco livre com tamanho maior ou igual a `num_bytes`
    2. Se encontrar, marca o bloco como ocupado e retorna o endereço inicial
    3. Se não encontrar, aloca espaço para um novo bloco usando syscall `brk`, marca como ocupado e retorna o endereço inicial

### Variações a Implementar

1. **Fusão de nós livres**: Implementar coalescência de blocos adjacentes livres
2. **Duas listas separadas**: Uma lista para nós livres e outra para nós ocupados
3. **Mapa de memória**: Procedimento que imprime o estado da heap:
   - `#` para bytes da parte gerencial do nó
   - `+` para bytes de blocos ocupados
   - `-` para bytes de blocos livres

## Exemplo de Uso

```c
#include <stdio.h>
#include "meuAlocador.h"

int main(long int argc, char** argv) {
    void *a, *b;

    iniciaAlocador();               // Impressão esperada
    imprimeMapa();                  // <vazio>

    a = (void *) alocaMem(10);
    imprimeMapa();                  // ################++++++++++

    b = (void *) alocaMem(4);
    imprimeMapa();                  // ################++++++++++##############++++

    liberaMem(a);
    imprimeMapa();                  // ################----------##############++++

    liberaMem(b);
    imprimeMapa();                  // ################----------------------------
                                    // ou
                                    // <vazio>
    finalizaAlocador();
    
    return 0;
}
```

---

## Roteiro de Avaliação

### Parte 1 (40 pontos)
Verificação se a implementação atende à especificação apresentada.

**Observações importantes:**
- A especificação original pedia blocos de 4096 bytes. Para facilitar a visualização, altere para **32 bytes**
- Programa de teste disponível em: https://www.inf.ufpr.br/bmuller/assets/ci1064/avalia.c
- O programa gera uma saída correspondente ao mapa do espaço alocado
- Será avaliado se a saída corresponde ao resultado correto

### Parte 2
Modificação do algoritmo de alocação:
- **Alteração**: Mudar de **Best Fit** para **Worst Fit**
- **Objetivo**: Escolher o segmento livre com maior tamanho disponível

### Parte 3 (3 pontos)
Três perguntas sobre o trabalho:

1. **(0.5 ponto)** Se você pudesse voltar no tempo, o que recomendaria ao "você do primeiro dia de aula" para minimizar o sofrimento no desenvolvimento?

2. **(0.5 ponto)** O que recomendaria ao professor para o próximo semestre remoto para aumentar a absorção do conteúdo?

3. **(2 pontos)** Explique os trechos de código e principais alterações feitas para a segunda parte funcionar, ou indique o motivo de não ter conseguido terminar a alteração.

## Estrutura do Projeto

```
TrabalhoSB/
├── README.md
├── meuAlocador.h
├── meuAlocador.c
├── teste.c
└── Makefile
```