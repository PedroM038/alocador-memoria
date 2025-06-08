# Nome do executável final
EXEC = main

# Arquivos fonte
SRC = avalia.c
ALLOC_SRC = meuAlocador.c

# Objeto do alocador
ALLOC_OBJ = meuAlocador.o

# Compilador
CC = gcc -g

# Regras
all: $(EXEC)

$(ALLOC_OBJ): $(ALLOC_SRC)
	$(CC) -c $(ALLOC_SRC)

$(EXEC): $(SRC) $(ALLOC_OBJ)
	$(CC) -o $(EXEC) $(SRC) $(ALLOC_OBJ)

clean:
	rm -f $(EXEC) $(ALLOC_OBJ)
