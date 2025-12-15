const std = @import("std");

// DEFINICIONES DE TOKENS
// Un token es la unidad minima de significado en el lenguaje
// Por ejemplo: "make", "5", "+", ";" son todos tokens diferentes
// El lexer convierte texto plano en una lista de estos tokens

// TokenType es un enum que representa todos los tipos de tokens posibles
// Usamos un enum porque:
// 1. Es type-safe: no podemos usar un valor invalido por accidente
// 2. Es eficiente: se almacena como un entero internamente
// 3. Es claro: podemos ver todos los tokens posibles de un vistazo
pub const TokenType = enum {
    // LITERALES
    // Representan valores directos en el codigo
    INTEGER, // Numeros enteros: 5, 42, 100
    FLOAT, // Numeros decimales: 3.14, 2.5
    STRING, // Cadenas de texto: "hola", "mundo"
    TRUE, // Booleano verdadero
    FALSE, // Booleano falso

    // IDENTIFICADORES Y PALABRAS RESERVADAS
    // IDENTIFIER es para nombres de variables, funciones, etc.
    // El resto son palabras clave del lenguaje
    IDENTIFIER, // nombres: x, contador, miVariable
    LET, // palabra clave para variables mutables (como TypeScript)
    CONST, // palabra clave para constantes inmutables (como TypeScript)
    FN, // palabra clave para declarar funciones
    RETURN, // palabra clave para retornar valores
    IF, // condicional if
    ELSE, // condicional else
    WHILE, // bucle while
    FOR, // bucle for
    IN, // palabra clave para for-in loops
    PRINT, // funcion de salida incorporada

    // TIPOS DE DATOS
    // Estos tokens representan los tipos que pueden tener las variables
    // Los separamos de las palabras clave para facilitar el parsing
    TYPE_INT, // tipo entero
    TYPE_FLOAT, // tipo decimal
    TYPE_STRING, // tipo cadena
    TYPE_BOOL, // tipo booleano

    // OPERADORES
    // Simbolos que realizan operaciones
    PLUS, // suma: +
    MINUS, // resta: -
    STAR, // multiplicacion: *
    SLASH, // division: /
    ASSIGN, // asignacion: =
    EQ, // igualdad: ==
    NEQ, // desigualdad: !=
    LT, // menor que: <
    GT, // mayor que: >
    LTE, // menor o igual: <=
    GTE, // mayor o igual: >=

    // DELIMITADORES
    // Simbolos que estructuran el codigo
    LPAREN, // parentesis izquierdo: (
    RPAREN, // parentesis derecho: )
    LBRACE, // llave izquierda: {
    RBRACE, // llave derecha: }
    LBRACKET, // corchete izquierdo: [ (para arrays)
    RBRACKET, // corchete derecho: ] (para arrays)
    SEMICOLON, // punto y coma: ;
    COLON, // dos puntos: :
    COMMA, // coma: ,
    DOT, // punto: . (para member access)

    // ESPECIALES
    // Tokens que tienen significado especial
    EOF, // End Of File: indica el fin del archivo
    ILLEGAL, // Token no reconocido o invalido
};

// ESTRUCTURA TOKEN
// Un Token almacena toda la informacion necesaria sobre un pedazo de codigo
// No solo guardamos QUE tipo de token es, sino tambien:
// - El texto original (lexeme)
// - Donde se encuentra en el archivo (line, column)
// Esto es crucial para dar buenos mensajes de error al usuario
pub const Token = struct {
    // Tipo de token: MAKE, INTEGER, PLUS, etc.
    type: TokenType,

    // El texto original del codigo fuente
    // Por ejemplo: si encontramos el numero 42, lexeme seria "42"
    // Si encontramos la palabra "make", lexeme seria "make"
    // Usamos []const u8 porque es una referencia al codigo original
    // no hacemos una copia para ser eficientes con la memoria
    lexeme: []const u8,

    // Numero de linea donde aparece el token (para mensajes de error)
    line: usize,

    // Numero de columna donde aparece el token (para mensajes de error)
    column: usize,

    // Constructor para crear un token facilmente
    // En lugar de escribir Token{ .type = ..., .lexeme = ..., etc }
    // podemos escribir Token.init(tipo, lexeme, linea, columna)
    pub fn init(token_type: TokenType, lexeme: []const u8, line: usize, column: usize) Token {
        return Token{
            .type = token_type,
            .lexeme = lexeme,
            .line = line,
            .column = column,
        };
    }

    // Funcion format: permite imprimir el token con std.debug.print
    // Esto es util para debugging y ver que tokens estamos generando
    // El _ = ignora parametros que no necesitamos pero son requeridos por la interfaz
    pub fn format(self: Token, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        // Imprime en formato: Token(MAKE, "make", 1:5)
        // Esto nos dice: tipo MAKE, texto "make", linea 1, columna 5
        try writer.print("Token({s}, \"{s}\", {}:{})", .{ @tagName(self.type), self.lexeme, self.line, self.column });
    }
};

// MAPA DE PALABRAS RESERVADAS
// Este es un mapa que se construye en tiempo de compilacion (compile-time)
// Mapea strings (palabras) a tipos de tokens
//
// Por que usamos ComptimeStringMap?
// 1. Se construye en compile-time: cero costo en runtime
// 2. Es mas rapido que un hashmap normal: usa perfect hashing
// 3. Es inmutable: las palabras reservadas nunca cambian
//
// Esto nos permite distinguir entre:
// - "let" -> palabra reservada LET
// - "miVariable" -> identificador IDENTIFIER
pub const keywords = std.StaticStringMap(TokenType).initComptime(.{
    // Palabras reservadas para declaraciones
    .{ "let", .LET },
    .{ "const", .CONST },
    .{ "fn", .FN },
    .{ "return", .RETURN },

    // Palabras reservadas para control de flujo
    .{ "if", .IF },
    .{ "else", .ELSE },
    .{ "while", .WHILE },
    .{ "for", .FOR },
    .{ "in", .IN }, // para for-in loops

    // Funciones incorporadas
    .{ "print", .PRINT },

    // Literales booleanos
    .{ "true", .TRUE },
    .{ "false", .FALSE },

    // Tipos de datos
    .{ "int", .TYPE_INT },
    .{ "float", .TYPE_FLOAT },
    .{ "string", .TYPE_STRING },
    .{ "bool", .TYPE_BOOL },
});

// LOOKUP DE IDENTIFICADORES
// Esta funcion decide si una palabra es una keyword o un identificador
//
// Como funciona:
// 1. Busca la palabra en el mapa de keywords
// 2. Si la encuentra, retorna el tipo de token correspondiente (LET, IF, etc)
// 3. Si no la encuentra, es un identificador de variable/funcion
//
// Ejemplo:
// lookupIdentifier("let") -> LET (es una keyword)
// lookupIdentifier("x") -> IDENTIFIER (es un nombre de variable)
// lookupIdentifier("miFunc") -> IDENTIFIER (es un nombre de funcion)
pub fn lookupIdentifier(ident: []const u8) TokenType {
    // Intentamos obtener el token del mapa
    // El |token_type| captura el valor si existe
    if (keywords.get(ident)) |token_type| {
        return token_type;
    }
    // Si no esta en el mapa, es un identificador normal
    return .IDENTIFIER;
}
