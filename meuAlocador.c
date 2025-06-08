#include "meuAlocador.h"
#include <stdio.h>
#include <sys/mman.h>

// Estrutura do nó para gerenciar blocos de memória
typedef struct No {
    int tamanho;        // Tamanho do bloco de dados
    int livre;          // 1 se livre, 0 se ocupado
    struct No* proximo; // Ponteiro para o próximo nó
} No;

// Variáveis globais
static void* topoInicialHeap = NULL;
static No* listaHeap = NULL;
static const int TAMANHO_BLOCO = 32; // Tamanho mínimo do bloco

void iniciaAlocador() {
    // Obtém o topo atual da heap
    topoInicialHeap = sbrk(0);
    listaHeap = NULL;
}

void finalizaAlocador() {
    // Restaura o heap para o estado inicial
    if (topoInicialHeap != NULL) {
        brk(topoInicialHeap);
        listaHeap = NULL;
    }
}

void* alocaMem(int num_bytes) {
    if (num_bytes <= 0) {
        return NULL;
    }

    int tamanho_real = num_bytes;
    No* atual = listaHeap;
    No* melhor = NULL;
    
    // Procura por um bloco livre (Best Fit)
    while (atual != NULL) {
        if (atual->livre && atual->tamanho >= tamanho_real) {
            if (melhor == NULL || atual->tamanho < melhor->tamanho) {
                melhor = atual;
            }
        }
        atual = atual->proximo;
    }
    
    int tamanhoNodo = sizeof(No);
    
    // Se encontrou um bloco adequado
    if (melhor != NULL) {
        melhor->livre = 0;
        
        int espacoSobra = melhor->tamanho - tamanho_real;
        
        if (espacoSobra > 0) {
            // Reduz o tamanho do bloco atual
            melhor->tamanho = tamanho_real;
            int tamanhoNovoNo = espacoSobra;
            
            // Se não há espaço suficiente para o cabeçalho, expande a heap
            if (espacoSobra < tamanhoNodo) {
                int expansaoNecessaria = tamanhoNodo - espacoSobra;
                if (sbrk(expansaoNecessaria) == (void*)-1) {
                    // Erro na expansão, reverte a mudança
                    melhor->tamanho += espacoSobra;
                    return (void*)((char*)melhor + tamanhoNodo);
                }
                tamanhoNovoNo = espacoSobra; // Dados disponíveis para o novo nó
            } else {
                // Se há espaço suficiente, desconta o cabeçalho
                tamanhoNovoNo = espacoSobra - tamanhoNodo;
            }
            
            // Cria um novo nó para o espaço restante
            No* novo_livre = (No*)((char*)melhor + tamanhoNodo + tamanho_real);
            novo_livre->tamanho = tamanhoNovoNo;
            novo_livre->livre = 1;
            novo_livre->proximo = melhor->proximo;
            
            // Atualiza o ponteiro do bloco atual
            melhor->proximo = novo_livre;
        }

        return (void*)((char*)melhor + tamanhoNodo);
    }
    
    // Não encontrou bloco livre, precisa alocar novo
    No* novo_no = (No*)sbrk(tamanhoNodo + tamanho_real);
    if (novo_no == (void*)-1) {
        return NULL;
    }
    
    novo_no->tamanho = tamanho_real;
    novo_no->livre = 0;
    novo_no->proximo = NULL;
    
    // Adiciona o novo nó no final da lista
    if (listaHeap == NULL) {
        listaHeap = novo_no;
    } else {
        atual = listaHeap;
        while (atual->proximo != NULL) {
            atual = atual->proximo;
        }
        atual->proximo = novo_no;
    }
    
    return (void*)((char*)novo_no + tamanhoNodo);
}

void fusaoNosLivres() {
    No* atual = listaHeap;
    
    while (atual != NULL && atual->proximo != NULL) {
        // Verifica se o nó atual e o próximo são livres e adjacentes
        if (atual->livre && atual->proximo->livre) {
            char* fim_atual = (char*)atual + sizeof(No) + atual->tamanho;
            char* inicio_proximo = (char*)atual->proximo;
            
            // Se são adjacentes, faz a fusão
            if (fim_atual == inicio_proximo) {
                atual->tamanho += sizeof(No) + atual->proximo->tamanho;
                No* temp = atual->proximo;
                atual->proximo = atual->proximo->proximo;
                continue; // Verifica novamente a parada do mesmo nó
            }
        }
        atual = atual->proximo;
    }
}

int liberaMem(void* bloco) {
    if (bloco == NULL) {
        return -1;
    }
    
    // Obtém o nó a partir do endereço do bloco
    No* no = (No*)((char*)bloco - sizeof(No));
    
    // Verifica se o nó está na nossa lista
    No* atual = listaHeap;
    while (atual != NULL) {
        if (atual == no) {
            atual->livre = 1;
            
            // fusão de nós livres adjacentes
            fusaoNosLivres();
            return 0;
        }
        atual = atual->proximo;
    }
    
    return -1; // Bloco não encontrado
}

void imprimeMapa() {
    if (listaHeap == NULL) {
        printf("<vazio>\n");
        return;
    }
    
    No* atual = listaHeap;
    
    while (atual != NULL) {
        // Imprime bytes da parte gerencial (cabeçalho do nó)
        for (int i = 0; i < sizeof(No); i++) {
            printf("#");
        }
        
        // Imprime bytes do bloco de dados
        char caractere = atual->livre ? '-' : '+';
        for (int i = 0; i < atual->tamanho; i++) {
            printf("%c", caractere);
        }
        
        atual = atual->proximo;
    }
    printf("\n");
}

void ocupados() {
    printf("Blocos ocupados:\n");
    No* atual = listaHeap;
    int contador = 0;
    
    while (atual != NULL) {
        if (!atual->livre) {
            printf("Bloco %d: Endereço = %p, Tamanho = %d bytes\n", 
                   contador++, (void*)((char*)atual + sizeof(No)), atual->tamanho);
        }
        atual = atual->proximo;
    }
    
    if (contador == 0) {
        printf("Nenhum bloco ocupado.\n");
    }
}

void livres() {
    printf("Blocos livres:\n");
    No* atual = listaHeap;
    int contador = 0;
    
    while (atual != NULL) {
        if (atual->livre) {
            printf("Bloco %d: Endereço = %p, Tamanho = %d bytes\n", 
                   contador++, (void*)((char*)atual + sizeof(No)), atual->tamanho);
        }
        atual = atual->proximo;
    }
    
    if (contador == 0) {
        printf("Nenhum bloco livre.\n");
    }
}