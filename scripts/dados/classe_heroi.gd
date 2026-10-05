class_name ClasseHeroi
extends Resource
## Dados de uma classe jogável. Cada classe é um arquivo .tres em recursos/classes/
## e pode ser editada direto no Inspetor, sem mexer no código.

enum Ataque { ESPADA, BOLA_DE_FOGO, FLECHA }
enum Poder { GIRO_DA_ESPADA, EXPLOSAO_ARCANA, CHUVA_DE_FLECHAS }

@export var id := "guerreiro"
@export var nome := "Guerreiro"
@export_multiline var descricao := ""
## Folha de sprites 4x3 (andar para baixo, para cima e para o lado).
@export var textura: Texture2D

@export_group("Atributos")
@export var vida_inicial := 4
@export var vida_maxima := 6
@export var velocidade := 80.0
@export var dano := 2
## Segundos entre um ataque e outro.
@export var cadencia := 0.35

@export_group("Ataque e poder")
@export var ataque: Ataque = Ataque.ESPADA
@export var poder: Poder = Poder.GIRO_DA_ESPADA
@export var nome_ataque := ""
@export var nome_poder := ""
@export_multiline var descricao_poder := ""
## Segundos para o poder especial recarregar.
@export var recarga_poder := 6.0
@export var icone_poder: Texture2D
