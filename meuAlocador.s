# ========================================
# ALOCADOR DE MEMÓRIA EM ASSEMBLY x86-64
# ========================================

.file "meuAlocador.c"
.intel_syntax noprefix

# ========================================
# SEÇÃO DE DADOS
# ========================================
.section .data
    topoInicialHeap: .quad 0        # static void* topoInicialHeap = NULL
    listaHeap: .quad 0              # static No* listaHeap = NULL

.section .rodata
    TAMANHO_BLOCO: .long 32         # const int TAMANHO_BLOCO = 32

# ========================================
# SEÇÃO DE CÓDIGO
# ========================================
.text

# ========================================
# void iniciaAlocador()
# Inicializa o alocador, salvando o topo atual da heap
# ========================================
.globl iniciaAlocador
.type iniciaAlocador, @function
iniciaAlocador:
    # Prólogo da função (alinha stack para System V ABI)
    sub rsp, 8
    
    # topoInicialHeap = sbrk(0) - obtém topo atual da heap
    xor edi, edi                    # edi = 0 (mais eficiente que mov edi, 0)
    call sbrk@PLT                   # chama sbrk(0)
    mov QWORD PTR topoInicialHeap[rip], rax  # salva o resultado
    
    # listaHeap = NULL - inicializa lista vazia
    mov QWORD PTR listaHeap[rip], 0
    
    # Epílogo da função
    add rsp, 8
    ret
.size iniciaAlocador, .-iniciaAlocador

# ========================================
# void finalizaAlocador()  
# Restaura a heap para o estado inicial, liberando toda memória alocada
# ========================================
.globl finalizaAlocador
.type finalizaAlocador, @function
finalizaAlocador:
    # Prólogo da função
    sub rsp, 8
    
    # if (topoInicialHeap != NULL)
    mov rax, QWORD PTR topoInicialHeap[rip]  # Carrega topoInicialHeap
    test rax, rax                            # Verifica se é NULL
    je finaliza_fim                          # Pula para o fim se for NULL
    
    # brk(topoInicialHeap) - restaura heap para estado inicial
    mov rdi, rax                             # rdi = topoInicialHeap (parâmetro para brk)
    call brk@PLT                             # Chama brk(topoInicialHeap)
    
    # listaHeap = NULL - limpa a lista
    mov QWORD PTR listaHeap[rip], 0

finaliza_fim:
    # Epílogo da função
    add rsp, 8
    ret
.size finalizaAlocador, .-finalizaAlocador

# ========================================
# void* alocaMem(int num_bytes)
# Aloca um bloco de memória usando algoritmo Best Fit
# Parâmetros: edi = num_bytes
# Retorno: rax = ponteiro para o bloco alocado ou NULL
# ========================================
.globl alocaMem
.type alocaMem, @function
alocaMem:
    # Prólogo da função - reserva espaço para variáveis locais
    sub rsp, 88
    
    # Salva parâmetro num_bytes
    mov DWORD PTR 12[rsp], edi      # [12] = num_bytes
    
    # if (num_bytes <= 0) return NULL
    cmp DWORD PTR 12[rsp], 0
    jg aloca_continua
    xor eax, eax                    # return NULL (mais eficiente que mov eax, 0)
    jmp aloca_fim

aloca_continua:
    # Inicializa variáveis locais
    mov eax, DWORD PTR 12[rsp]      
    mov DWORD PTR 56[rsp], eax      # [56] = tamanho_real = num_bytes
    mov rax, QWORD PTR listaHeap[rip]
    mov QWORD PTR 72[rsp], rax      # [72] = atual = listaHeap
    mov QWORD PTR 64[rsp], 0        # [64] = melhor = NULL
    mov DWORD PTR 52[rsp], 16       # [52] = tamanhoNodo = sizeof(No) = 16
    jmp busca_bloco_teste

# ========================================
# LOOP BEST FIT - Procura pelo menor bloco que cabe
# ========================================
busca_bloco_inicio:
    mov rax, QWORD PTR 72[rsp]      # rax = atual
    
    # if (!atual->livre) continue
    mov eax, DWORD PTR 4[rax]       # eax = atual->livre
    test eax, eax
    je proximo_bloco
    
    # if (atual->tamanho < tamanho_real) continue  
    mov rax, QWORD PTR 72[rsp]
    mov eax, DWORD PTR [rax]        # eax = atual->tamanho
    cmp DWORD PTR 56[rsp], eax      # compara tamanho_real com atual->tamanho
    jg proximo_bloco                # pula se tamanho_real > atual->tamanho
    
    # Verifica se é melhor que o atual melhor (Best Fit)
    cmp QWORD PTR 64[rsp], 0        # melhor == NULL?
    je set_melhor_bloco
    
    # Compara tamanhos: atual->tamanho < melhor->tamanho?
    mov rax, QWORD PTR 72[rsp]      # rax = atual
    mov edx, DWORD PTR [rax]        # edx = atual->tamanho
    mov rax, QWORD PTR 64[rsp]      # rax = melhor  
    mov eax, DWORD PTR [rax]        # eax = melhor->tamanho
    cmp edx, eax                    # atual->tamanho >= melhor->tamanho?
    jge proximo_bloco

set_melhor_bloco:
    mov rax, QWORD PTR 72[rsp]
    mov QWORD PTR 64[rsp], rax      # melhor = atual

proximo_bloco:
    # atual = atual->proximo
    mov rax, QWORD PTR 72[rsp]
    mov rax, QWORD PTR 8[rax]       # atual->proximo
    mov QWORD PTR 72[rsp], rax

busca_bloco_teste:
    cmp QWORD PTR 72[rsp], 0        # atual != NULL?
    jne busca_bloco_inicio

# ========================================
# BLOCO ENCONTRADO - Reutiliza bloco existente
# ========================================
    cmp QWORD PTR 64[rsp], 0        # melhor != NULL?
    je aloca_novo_bloco
    
    # melhor->livre = 0 (marca como ocupado)
    mov rax, QWORD PTR 64[rsp]
    mov DWORD PTR 4[rax], 0
    
    # espacoSobra = melhor->tamanho - tamanho_real
    mov rax, QWORD PTR 64[rsp]
    mov eax, DWORD PTR [rax]        # eax = melhor->tamanho
    sub eax, DWORD PTR 56[rsp]      # eax -= tamanho_real
    mov DWORD PTR 36[rsp], eax      # [36] = espacoSobra
    
    # if (espacoSobra <= 0) goto retorna_bloco
    cmp DWORD PTR 36[rsp], 0
    jle retorna_bloco_encontrado
    
    # melhor->tamanho = tamanho_real (reduz tamanho do bloco)
    mov rax, QWORD PTR 64[rsp]
    mov edx, DWORD PTR 56[rsp]
    mov DWORD PTR [rax], edx
    
    # Inicializa tamanhoNovoNo = espacoSobra
    mov eax, DWORD PTR 36[rsp]
    mov DWORD PTR 60[rsp], eax      # [60] = tamanhoNovoNo
    
    # if (espacoSobra < tamanhoNodo) - precisa expandir heap
    mov eax, DWORD PTR 36[rsp]
    cmp eax, DWORD PTR 52[rsp]
    jge espaco_suficiente
    
    # Expande heap: sbrk(tamanhoNodo - espacoSobra)
    mov eax, DWORD PTR 52[rsp]
    sub eax, DWORD PTR 36[rsp]      # expansaoNecessaria
    mov DWORD PTR 32[rsp], eax      # [32] = expansaoNecessaria
    cdqe                            # converte int para long
    mov rdi, rax
    call sbrk@PLT
    cmp rax, -1                     # sbrk falhou?
    jne expansao_ok
    
    # Erro na expansão - reverte mudança
    mov rax, QWORD PTR 64[rsp]
    mov edx, DWORD PTR [rax]        # melhor->tamanho atual
    add edx, DWORD PTR 36[rsp]      # + espacoSobra
    mov DWORD PTR [rax], edx        # restaura tamanho original
    jmp retorna_bloco_encontrado

expansao_ok:
    mov eax, DWORD PTR 36[rsp]
    mov DWORD PTR 60[rsp], eax      # tamanhoNovoNo = espacoSobra
    jmp criar_novo_no_livre

espaco_suficiente:
    # tamanhoNovoNo = espacoSobra - tamanhoNodo
    mov eax, DWORD PTR 36[rsp]
    sub eax, DWORD PTR 52[rsp]
    mov DWORD PTR 60[rsp], eax

criar_novo_no_livre:
    # Cria novo nó livre no espaço restante
    # novo_livre = (No*)((char*)melhor + tamanhoNodo + tamanho_real)
    mov eax, DWORD PTR 52[rsp]      # tamanhoNodo
    mov edx, DWORD PTR 56[rsp]      # tamanho_real
    add eax, edx                    # tamanhoNodo + tamanho_real
    cdqe
    mov rdx, rax
    mov rax, QWORD PTR 64[rsp]      # melhor
    add rax, rdx                    # melhor + offset
    mov QWORD PTR 24[rsp], rax      # [24] = novo_livre
    
    # Inicializa novo nó livre
    mov rax, QWORD PTR 24[rsp]
    mov edx, DWORD PTR 60[rsp]      # tamanhoNovoNo
    mov DWORD PTR [rax], edx        # novo_livre->tamanho = tamanhoNovoNo
    mov DWORD PTR 4[rax], 1         # novo_livre->livre = 1
    
    # novo_livre->proximo = melhor->proximo
    mov rax, QWORD PTR 64[rsp]      # melhor
    mov rdx, QWORD PTR 8[rax]       # melhor->proximo
    mov rax, QWORD PTR 24[rsp]      # novo_livre
    mov QWORD PTR 8[rax], rdx       # novo_livre->proximo = melhor->proximo
    
    # melhor->proximo = novo_livre
    mov rax, QWORD PTR 64[rsp]      # melhor
    mov rdx, QWORD PTR 24[rsp]      # novo_livre
    mov QWORD PTR 8[rax], rdx       # melhor->proximo = novo_livre

retorna_bloco_encontrado:
    # return (void*)((char*)melhor + tamanhoNodo)
    mov eax, DWORD PTR 52[rsp]      # tamanhoNodo
    cdqe
    mov rdx, rax
    mov rax, QWORD PTR 64[rsp]      # melhor
    add rax, rdx                    # melhor + tamanhoNodo
    jmp aloca_fim

# ========================================
# NOVO BLOCO - Não encontrou bloco adequado
# ========================================
aloca_novo_bloco:
    # novo_no = (No*)sbrk(tamanhoNodo + tamanho_real)
    mov edx, DWORD PTR 52[rsp]      # tamanhoNodo
    mov eax, DWORD PTR 56[rsp]      # tamanho_real
    add eax, edx                    # tamanhoNodo + tamanho_real
    cdqe
    mov rdi, rax
    call sbrk@PLT
    mov QWORD PTR 40[rsp], rax      # [40] = novo_no
    
    # if (novo_no == (void*)-1) return NULL
    cmp QWORD PTR 40[rsp], -1
    jne inicializa_novo_no
    xor eax, eax                    # return NULL
    jmp aloca_fim

inicializa_novo_no:
    # Inicializa novo nó
    mov rax, QWORD PTR 40[rsp]
    mov edx, DWORD PTR 56[rsp]      # tamanho_real
    mov DWORD PTR [rax], edx        # novo_no->tamanho = tamanho_real
    mov DWORD PTR 4[rax], 0         # novo_no->livre = 0
    mov QWORD PTR 8[rax], 0         # novo_no->proximo = NULL
    
    # Adiciona à lista - verifica se lista está vazia
    mov rax, QWORD PTR listaHeap[rip]
    test rax, rax
    jne adiciona_no_final
    
    # Lista vazia - novo nó vira o primeiro
    mov rax, QWORD PTR 40[rsp]
    mov QWORD PTR listaHeap[rip], rax
    jmp retorna_novo_bloco

adiciona_no_final:
    # Percorre até o final da lista
    mov rax, QWORD PTR listaHeap[rip]
    mov QWORD PTR 72[rsp], rax      # [72] = atual = listaHeap
    jmp busca_final_teste

busca_final_loop:
    mov rax, QWORD PTR 72[rsp]
    mov rax, QWORD PTR 8[rax]       # atual->proximo
    mov QWORD PTR 72[rsp], rax      # atual = atual->proximo

busca_final_teste:
    mov rax, QWORD PTR 72[rsp]
    mov rax, QWORD PTR 8[rax]       # atual->proximo
    test rax, rax                   # atual->proximo != NULL?
    jne busca_final_loop
    
    # atual->proximo = novo_no
    mov rax, QWORD PTR 72[rsp]      # atual
    mov rdx, QWORD PTR 40[rsp]      # novo_no
    mov QWORD PTR 8[rax], rdx       # atual->proximo = novo_no

retorna_novo_bloco:
    # return (void*)((char*)novo_no + tamanhoNodo)
    mov eax, DWORD PTR 52[rsp]      # tamanhoNodo
    cdqe
    mov rdx, rax
    mov rax, QWORD PTR 40[rsp]      # novo_no
    add rax, rdx                    # novo_no + tamanhoNodo

aloca_fim:
    # Epílogo da função
    add rsp, 88
    ret
.size alocaMem, .-alocaMem

# ========================================
# void fusaoNosLivres()
# Percorre a lista e funde nós livres adjacentes na memória
# ========================================
.globl fusaoNosLivres
.type fusaoNosLivres, @function
fusaoNosLivres:
    # Prólogo da função
    sub rsp, 40
    
    # Inicializa atual = listaHeap
    mov rax, QWORD PTR listaHeap[rip]
    mov QWORD PTR 32[rsp], rax      # [32] = atual = listaHeap
    jmp loop_fusao_teste

# ========================================
# LOOP PRINCIPAL - Percorre lista procurando nós adjacentes
# ========================================
loop_fusao_inicio:
    mov rax, QWORD PTR 32[rsp]      # rax = atual
    
    # if (!atual->livre) continue
    mov eax, DWORD PTR 4[rax]       # eax = atual->livre
    test eax, eax
    je proximo_no_fusao
    
    # if (!atual->proximo->livre) continue
    mov rax, QWORD PTR 32[rsp]
    mov rax, QWORD PTR 8[rax]       # rax = atual->proximo
    mov eax, DWORD PTR 4[rax]       # eax = atual->proximo->livre
    test eax, eax
    je proximo_no_fusao
    
    # Calcula endereço esperado do próximo nó
    # endereco_esperado = atual + sizeof(No) + atual->tamanho
    mov rax, QWORD PTR 32[rsp]      # rax = atual
    mov eax, DWORD PTR [rax]        # eax = atual->tamanho
    cdqe                            # converte para 64 bits
    lea rdx, 16[rax]                # rdx = sizeof(No) + atual->tamanho
    mov rax, QWORD PTR 32[rsp]      # rax = atual
    add rax, rdx                    # rax = atual + offset
    mov QWORD PTR 24[rsp], rax      # [24] = endereco_esperado
    
    # Obtém endereço real do próximo nó
    mov rax, QWORD PTR 32[rsp]
    mov rax, QWORD PTR 8[rax]       # rax = atual->proximo
    mov QWORD PTR 16[rsp], rax      # [16] = proximo_real
    
    # if (endereco_esperado != proximo_real) continue
    mov rax, QWORD PTR 24[rsp]      # endereco_esperado
    cmp rax, QWORD PTR 16[rsp]      # proximo_real
    jne proximo_no_fusao
    
# ========================================
# FUSÃO DE NÓS - Nós são adjacentes, pode fundir
# ========================================
fusiona_nos:
    # Calcula novo tamanho: atual->tamanho + proximo->tamanho + sizeof(No)
    mov rax, QWORD PTR 32[rsp]      # atual
    mov eax, DWORD PTR [rax]        # atual->tamanho
    mov edx, eax                    # edx = atual->tamanho
    
    mov rax, QWORD PTR 32[rsp]
    mov rax, QWORD PTR 8[rax]       # atual->proximo
    mov eax, DWORD PTR [rax]        # atual->proximo->tamanho
    add eax, edx                    # atual->tamanho + proximo->tamanho
    add eax, 16                     # + sizeof(No)
    
    # Atualiza tamanho do nó atual
    mov edx, eax
    mov rax, QWORD PTR 32[rsp]      # atual
    mov DWORD PTR [rax], edx        # atual->tamanho = novo_tamanho
    
    # Salva referência do nó que será removido
    mov rax, QWORD PTR 32[rsp]
    mov rax, QWORD PTR 8[rax]       # atual->proximo
    mov QWORD PTR 8[rsp], rax       # [8] = no_removido = atual->proximo
    
    # Atualiza ponteiro: atual->proximo = proximo->proximo
    mov rax, QWORD PTR 32[rsp]
    mov rax, QWORD PTR 8[rax]       # atual->proximo
    mov rdx, QWORD PTR 8[rax]       # atual->proximo->proximo
    mov rax, QWORD PTR 32[rsp]      # atual
    mov QWORD PTR 8[rax], rdx       # atual->proximo = proximo->proximo
    
    # Reinicia o loop (pode haver mais fusões)
    jmp loop_fusao_teste

proximo_no_fusao:
    # atual = atual->proximo
    mov rax, QWORD PTR 32[rsp]
    mov rax, QWORD PTR 8[rax]       # atual->proximo
    mov QWORD PTR 32[rsp], rax      # atual = atual->proximo

loop_fusao_teste:
    # while (atual != NULL && atual->proximo != NULL)
    cmp QWORD PTR 32[rsp], 0        # atual != NULL?
    je fusao_fim
    
    mov rax, QWORD PTR 32[rsp]
    mov rax, QWORD PTR 8[rax]       # atual->proximo
    test rax, rax                   # atual->proximo != NULL?
    jne loop_fusao_inicio

fusao_fim:
    # Epílogo da função
    add rsp, 40
    ret
.size fusaoNosLivres, .-fusaoNosLivres

# ========================================
# int liberaMem(void* bloco)
# Libera um bloco de memória previamente alocado
# Parâmetros: rdi = bloco (ponteiro para o bloco a ser liberado)
# Retorno: rax = 0 se sucesso, -1 se erro
# ========================================
.globl liberaMem
.type liberaMem, @function
liberaMem:
    # Prólogo da função
    sub rsp, 24
    
    # Salva parâmetro bloco
    mov QWORD PTR [rsp], rdi        # [0] = bloco
    
    # if (bloco == NULL) return -1
    cmp QWORD PTR [rsp], 0
    jne libera_continua
    mov eax, -1                     # return -1 (erro)
    jmp libera_fim

libera_continua:
    # Obtém o nó a partir do endereço do bloco
    # no = (No*)((char*)bloco - sizeof(No))
    mov rax, QWORD PTR [rsp]        # rax = bloco
    sub rax, 16                     # rax = bloco - sizeof(No)
    mov QWORD PTR 8[rsp], rax       # [8] = no
    
    # Inicializa busca na lista: atual = listaHeap
    mov rax, QWORD PTR listaHeap[rip]
    mov QWORD PTR 16[rsp], rax      # [16] = atual = listaHeap
    jmp busca_no_teste

# ========================================
# LOOP DE BUSCA - Procura o nó na lista
# ========================================
busca_no_inicio:
    # if (atual == no) - encontrou o nó
    mov rax, QWORD PTR 16[rsp]      # atual
    cmp rax, QWORD PTR 8[rsp]       # atual == no?
    jne proximo_no_busca
    
    # Marca nó como livre
    mov rax, QWORD PTR 16[rsp]      # atual
    mov DWORD PTR 4[rax], 1         # atual->livre = 1
    
    # Chama fusão de nós livres adjacentes
    xor eax, eax                    # parâmetro 0 (sem parâmetros)
    call fusaoNosLivres
    
    # return 0 (sucesso)
    xor eax, eax
    jmp libera_fim

proximo_no_busca:
    # atual = atual->proximo
    mov rax, QWORD PTR 16[rsp]      # atual
    mov rax, QWORD PTR 8[rax]       # atual->proximo
    mov QWORD PTR 16[rsp], rax      # atual = atual->proximo

busca_no_teste:
    # while (atual != NULL)
    cmp QWORD PTR 16[rsp], 0        # atual != NULL?
    jne busca_no_inicio
    
    # Bloco não encontrado na lista
    mov eax, -1                     # return -1 (erro)

libera_fim:
    # Epílogo da função
    add rsp, 24
    ret
.size liberaMem, .-liberaMem

# ========================================
# AS FUNÇÕES ABAIXO NÃO SÃO AUXILIARES 
# NÃO SENDO NECESSÁRIAS PARA O ALOCADOR
# ========================================

.LC0:
	.string	"<vazio>"
	.text
	.globl	imprimeMapa
	.type	imprimeMapa, @function
imprimeMapa:
	sub	rsp, 40
	mov	rax, QWORD PTR listaHeap[rip]
	test	rax, rax
	jne	.L36
	lea	rax, .LC0[rip]
	mov	rdi, rax
	call	puts@PLT
	jmp	.L35
.L36:
	mov	rax, QWORD PTR listaHeap[rip]
	mov	QWORD PTR 24[rsp], rax
	jmp	.L38
.L45:
	mov	DWORD PTR 20[rsp], 0
	jmp	.L39
.L40:
	mov	edi, 35
	call	putchar@PLT
	add	DWORD PTR 20[rsp], 1
.L39:
	mov	eax, DWORD PTR 20[rsp]
	cmp	eax, 15
	jbe	.L40
	mov	rax, QWORD PTR 24[rsp]
	mov	eax, DWORD PTR 4[rax]
	test	eax, eax
	je	.L41
	mov	eax, 45
	jmp	.L42
.L41:
	mov	eax, 43
.L42:
	mov	BYTE PTR 15[rsp], al
	mov	DWORD PTR 16[rsp], 0
	jmp	.L43
.L44:
	movsx	eax, BYTE PTR 15[rsp]
	mov	edi, eax
	call	putchar@PLT
	add	DWORD PTR 16[rsp], 1
.L43:
	mov	rax, QWORD PTR 24[rsp]
	mov	eax, DWORD PTR [rax]
	cmp	DWORD PTR 16[rsp], eax
	jl	.L44
	mov	rax, QWORD PTR 24[rsp]
	mov	rax, QWORD PTR 8[rax]
	mov	QWORD PTR 24[rsp], rax
.L38:
	cmp	QWORD PTR 24[rsp], 0
	jne	.L45
	mov	edi, 10
	call	putchar@PLT
.L35:
	add	rsp, 40
	ret
	.size	imprimeMapa, .-imprimeMapa
	.section	.rodata
.LC1:
	.string	"Blocos ocupados:"
	.align 8
.LC2:
	.string	"Bloco %d: Endere\303\247o = %p, Tamanho = %d bytes\n"
.LC3:
	.string	"Nenhum bloco ocupado."
	.text
	.globl	ocupados
	.type	ocupados, @function
ocupados:
	sub	rsp, 24
	lea	rax, .LC1[rip]
	mov	rdi, rax
	call	puts@PLT
	mov	rax, QWORD PTR listaHeap[rip]
	mov	QWORD PTR 8[rsp], rax
	mov	DWORD PTR 4[rsp], 0
	jmp	.L47
.L49:
	mov	rax, QWORD PTR 8[rsp]
	mov	eax, DWORD PTR 4[rax]
	test	eax, eax
	jne	.L48
	mov	rax, QWORD PTR 8[rsp]
	mov	edx, DWORD PTR [rax]
	mov	rax, QWORD PTR 8[rsp]
	lea	rsi, 16[rax]
	mov	eax, DWORD PTR 4[rsp]
	lea	ecx, 1[rax]
	mov	DWORD PTR 4[rsp], ecx
	mov	ecx, edx
	mov	rdx, rsi
	mov	esi, eax
	lea	rax, .LC2[rip]
	mov	rdi, rax
	mov	eax, 0
	call	printf@PLT
.L48:
	mov	rax, QWORD PTR 8[rsp]
	mov	rax, QWORD PTR 8[rax]
	mov	QWORD PTR 8[rsp], rax
.L47:
	cmp	QWORD PTR 8[rsp], 0
	jne	.L49
	cmp	DWORD PTR 4[rsp], 0
	jne	.L51
	lea	rax, .LC3[rip]
	mov	rdi, rax
	call	puts@PLT
.L51:
	nop
	add	rsp, 24
	ret
	.size	ocupados, .-ocupados
	.section	.rodata
.LC4:
	.string	"Blocos livres:"
.LC5:
	.string	"Nenhum bloco livre."
	.text
	.globl	livres
	.type	livres, @function
livres:
	sub	rsp, 24
	lea	rax, .LC4[rip]
	mov	rdi, rax
	call	puts@PLT
	mov	rax, QWORD PTR listaHeap[rip]
	mov	QWORD PTR 8[rsp], rax
	mov	DWORD PTR 4[rsp], 0
	jmp	.L53
.L55:
	mov	rax, QWORD PTR 8[rsp]
	mov	eax, DWORD PTR 4[rax]
	test	eax, eax
	je	.L54
	mov	rax, QWORD PTR 8[rsp]
	mov	edx, DWORD PTR [rax]
	mov	rax, QWORD PTR 8[rsp]
	lea	rsi, 16[rax]
	mov	eax, DWORD PTR 4[rsp]
	lea	ecx, 1[rax]
	mov	DWORD PTR 4[rsp], ecx
	mov	ecx, edx
	mov	rdx, rsi
	mov	esi, eax
	lea	rax, .LC2[rip]
	mov	rdi, rax
	mov	eax, 0
	call	printf@PLT
.L54:
	mov	rax, QWORD PTR 8[rsp]
	mov	rax, QWORD PTR 8[rax]
	mov	QWORD PTR 8[rsp], rax
.L53:
	cmp	QWORD PTR 8[rsp], 0
	jne	.L55
	cmp	DWORD PTR 4[rsp], 0
	jne	.L57
	lea	rax, .LC5[rip]
	mov	rdi, rax
	call	puts@PLT
.L57:
	nop
	add	rsp, 24
	ret
	.size	livres, .-livres
	.align 8
	.long	1f - 0f
	.long	4f - 1f
	.long	5
0:
	.string	"GNU"
1:
	.align 8
	.long	0xc0000002
	.long	3f - 2f
2:
	.long	0x3
3:
	.align 8
4: