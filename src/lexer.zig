const std = @import("std");
const token = @import("token.zig");
const Token = token.Token;
const TokenType = token.TokenType;

// LEXER - ANALIZADOR LEXICO
// El lexer es la primera fase del compilador
// Su trabajo es convertir texto plano en una secuencia de tokens
//
// Ejemplo: "make x: int = 5;" se convierte en:
// [MAKE, IDENTIFIER("x"), COLON, TYPE_INT, ASSIGN, INTEGER(5), SEMICOLON]
//
// El lexer lee caracter por caracter y agrupa caracteres en tokens
pub const Lexer = struct {
    // CAMPOS DEL LEXER

    // El codigo fuente completo como string
    source: []const u8,

    // Posicion actual en el codigo (el caracter que ya procesamos)
    position: usize,

    // Posicion de lectura (el siguiente caracter a leer)
    // Siempre es position + 1, esto nos permite "ver hacia adelante"
    read_position: usize,

    // Caracter actual que estamos examinando
    // Usamos u8 porque un caracter es un byte
    // 0 significa "fin del archivo"
    ch: u8,

    // Linea actual (empieza en 1, no en 0, porque asi lo ven los humanos)
    line: usize,

    // Columna actual (posicion horizontal en la linea)
    column: usize,

    // Allocador de memoria (por si necesitamos reservar memoria dinamica)
    allocator: std.mem.Allocator,

    // CONSTRUCTOR DEL LEXER
    // Inicializa un lexer con el codigo fuente
    pub fn init(allocator: std.mem.Allocator, source: []const u8) Lexer {
        var lexer = Lexer{
            .source = source,
            .position = 0,
            .read_position = 0,
            .ch = 0, // Temporal, se actualiza abajo
            .line = 1, // Empezamos en linea 1
            .column = 0, // Empezamos en columna 0
            .allocator = allocator,
        };
        // Leemos el primer caracter antes de empezar
        // Esto simplifica la logica: siempre tenemos un caracter cargado
        lexer.readChar();
        return lexer;
    }

    // LEER SIGUIENTE CARACTER
    // Avanza la posicion del lexer un caracter hacia adelante
    //
    // Por que necesitamos esto?
    // - Necesitamos avanzar por el codigo caracter por caracter
    // - Cuando llegamos al final, ch se vuelve 0 (marca de fin)
    //
    // La tecnica de "dos punteros" (position y read_position):
    // - position: donde estamos ahora
    // - read_position: donde estaremos despues
    // Esto nos permite "mirar hacia adelante" sin mover nuestra posicion real
    fn readChar(self: *Lexer) void {
        // Si llegamos al final del archivo
        if (self.read_position >= self.source.len) {
            self.ch = 0; // 0 significa EOF (End Of File)
        } else {
            // Leemos el siguiente caracter
            self.ch = self.source[self.read_position];
        }
        // Actualizamos las posiciones
        self.position = self.read_position;
        self.read_position += 1;
        self.column += 1;
    }

    // MIRAR HACIA ADELANTE (PEEK)
    // Retorna el siguiente caracter SIN avanzar la posicion
    //
    // Por que es util?
    // - Para reconocer tokens de dos caracteres como "==" o "!="
    // - Vemos si el siguiente es '=' antes de decidir si es ASSIGN o EQ
    //
    // Ejemplo:
    // Si ch = '=' y peekChar() = '=', sabemos que es "=="
    // Si ch = '=' y peekChar() = ' ', sabemos que es solo "="
    fn peekChar(self: *Lexer) u8 {
        if (self.read_position >= self.source.len) {
            return 0; // Retornamos EOF si no hay mas caracteres
        }
        return self.source[self.read_position];
    }

    // SALTAR ESPACIOS EN BLANCO
    // Los espacios, tabs, saltos de linea no son tokens significativos
    // Esta funcion los salta hasta encontrar algo importante
    //
    // Por que necesitamos esto?
    // - "make x=5;" y "make    x   =   5  ;" deben ser equivalentes
    // - Los espacios solo sirven para separar tokens, no son tokens en si
    //
    // Detalle importante: cuando encontramos '\n', incrementamos line
    // y reseteamos column a 0 para tracking correcto de posicion
    fn skipWhitespace(self: *Lexer) void {
        while (self.ch == ' ' or self.ch == '\t' or self.ch == '\n' or self.ch == '\r') {
            // Si es un salto de linea, actualizamos el contador de lineas
            if (self.ch == '\n') {
                self.line += 1;
                self.column = 0; // Nueva linea, columna vuelve a 0
            }
            self.readChar();
        }
    }

    // SALTAR COMENTARIOS
    // Los comentarios en Boemia Script empiezan con //
    // Esta funcion los ignora hasta el final de la linea
    //
    // Por que necesitamos esto?
    // - Los comentarios son para humanos, el compilador los ignora
    // - Debemos saltarlos como si fueran espacios en blanco
    //
    // Como funciona:
    // - Detecta "//" usando ch y peekChar()
    // - Lee caracteres hasta encontrar '\n' o EOF
    fn skipComment(self: *Lexer) void {
        // Verificamos si tenemos "//" (comentario de una linea)
        if (self.ch == '/' and self.peekChar() == '/') {
            // Saltamos todo hasta el final de la linea
            while (self.ch != '\n' and self.ch != 0) {
                self.readChar();
            }
        }
    }

    // LEER IDENTIFICADOR O PALABRA CLAVE
    // Lee una secuencia de letras, digitos y underscores
    // Esto puede ser: nombre de variable, funcion, o palabra reservada
    //
    // Reglas de identificadores en Boemia Script:
    // - Deben empezar con letra o underscore
    // - Pueden contener letras, digitos y underscores
    //
    // Ejemplos validos: x, contador, mi_variable, suma2
    // Esta funcion NO decide si es keyword o identificador
    // Eso lo hace lookupIdentifier() despues
    fn readIdentifier(self: *Lexer) []const u8 {
        const start = self.position; // Guardamos donde empieza
        // Leemos mientras sean letras, digitos o underscore
        while (isLetter(self.ch) or isDigit(self.ch) or self.ch == '_') {
            self.readChar();
        }
        // Retornamos un slice del codigo fuente original
        // No copiamos el string, solo retornamos una referencia
        return self.source[start..self.position];
    }

    // LEER NUMERO
    // Lee un numero entero o decimal
    //
    // Por que es complicado?
    // - Debemos distinguir entre enteros (42) y decimales (3.14)
    // - Debemos manejar el punto decimal correctamente
    // - No queremos confundir "42.toString()" con un numero decimal
    //
    // Como funciona:
    // 1. Leemos todos los digitos antes del punto
    // 2. Si encontramos '.' seguido de un digito, es float
    // 3. Si no, es un integer
    //
    // Nota: guardamos start_column porque cuando terminemos de leer
    // el numero, column habra avanzado
    fn readNumber(self: *Lexer) Token {
        const start = self.position;
        const start_column = self.column;
        var is_float = false;

        // Leemos la parte entera
        while (isDigit(self.ch)) {
            self.readChar();
        }

        // Verificamos si hay punto decimal
        // IMPORTANTE: usamos peekChar() para asegurarnos que despues
        // del punto viene un digito, no otra cosa
        if (self.ch == '.' and isDigit(self.peekChar())) {
            is_float = true;
            self.readChar(); // consumimos el '.'
            // Leemos la parte decimal
            while (isDigit(self.ch)) {
                self.readChar();
            }
        }

        const lexeme = self.source[start..self.position];
        const token_type = if (is_float) TokenType.FLOAT else TokenType.INTEGER;
        return Token.init(token_type, lexeme, self.line, start_column);
    }

    // LEER STRING
    // Lee una cadena de texto entre comillas dobles
    //
    // Desafios:
    // - Los strings pueden contener saltos de linea
    // - Debemos detectar strings sin cerrar (error)
    // - Debemos tracking de lineas correctamente
    //
    // Como funciona:
    // 1. Consumimos la " inicial
    // 2. Leemos todo hasta encontrar otra " o EOF
    // 3. Si llegamos a EOF sin cerrar, es un error (ILLEGAL token)
    fn readString(self: *Lexer) Token {
        const start_column = self.column;
        self.readChar(); // consumimos la " inicial

        const start = self.position;
        // Leemos hasta encontrar la " de cierre o EOF
        while (self.ch != '"' and self.ch != 0) {
            // Si el string tiene saltos de linea, los contamos
            if (self.ch == '\n') {
                self.line += 1;
                self.column = 0;
            }
            self.readChar();
        }

        // Si llegamos a EOF sin encontrar ", es un error
        if (self.ch == 0) {
            return Token.init(.ILLEGAL, "unterminated string", self.line, start_column);
        }

        const lexeme = self.source[start..self.position];
        self.readChar(); // consumimos la " final
        return Token.init(.STRING, lexeme, self.line, start_column);
    }

    // OBTENER SIGUIENTE TOKEN
    // Esta es la funcion PRINCIPAL del lexer
    // Es llamada repetidamente por el parser para obtener tokens uno por uno
    //
    // Flujo de trabajo:
    // 1. Saltamos espacios y comentarios (no son significativos)
    // 2. Miramos el caracter actual
    // 3. Decidimos que tipo de token es
    // 4. Lo construimos y retornamos
    //
    // Por que usamos switch?
    // - Es mas eficiente que muchos if/else
    // - Es mas claro: vemos todos los casos de un vistazo
    // - El compilador puede optimizarlo mejor
    pub fn nextToken(self: *Lexer) Token {
        // Primero limpiamos espacios y comentarios
        // Usamos un bucle para manejar múltiples comentarios consecutivos
        while (true) {
            self.skipWhitespace();
            if (self.ch == '/' and self.peekChar() == '/') {
                self.skipComment();
            } else {
                break;
            }
        }

        // Guardamos la posicion ANTES de consumir el token
        // Esto es importante para reportar errores correctamente
        const tok_column = self.column;
        const tok_line = self.line;

        // SWITCH GIGANTE: cada caracter determina que token es
        // Los bloques 'blk:' son necesarios en Zig para retornar valores desde switch
        const tok = switch (self.ch) {
            // OPERADORES ARITMETICOS SIMPLES
            // Son de un solo caracter, faciles de reconocer
            '+' => blk: {
                self.readChar(); // Consumimos el '+'
                break :blk Token.init(.PLUS, "+", tok_line, tok_column);
            },
            '-' => blk: {
                self.readChar();
                break :blk Token.init(.MINUS, "-", tok_line, tok_column);
            },
            '*' => blk: {
                self.readChar();
                break :blk Token.init(.STAR, "*", tok_line, tok_column);
            },
            '/' => blk: {
                self.readChar();
                break :blk Token.init(.SLASH, "/", tok_line, tok_column);
            },

            // OPERADOR DE ASIGNACION E IGUALDAD
            // Aqui viene la parte interesante: '=' puede ser ASSIGN o EQ
            // - Si solo es '=', es asignacion: x = 5
            // - Si es '==', es comparacion: if x == 5
            // Usamos peekChar() para decidir sin consumir el caracter
            '=' => blk: {
                if (self.peekChar() == '=') {
                    // Es '==' (igualdad)
                    self.readChar(); // consume primer '='
                    self.readChar(); // consume segundo '='
                    break :blk Token.init(.EQ, "==", tok_line, tok_column);
                }
                // Es solo '=' (asignacion)
                self.readChar();
                break :blk Token.init(.ASSIGN, "=", tok_line, tok_column);
            },

            // OPERADOR DE DESIGUALDAD
            // '!' solo existe como '!=' en nuestro lenguaje
            // Si encontramos '!' solo, es un error (ILLEGAL)
            '!' => blk: {
                if (self.peekChar() == '=') {
                    self.readChar();
                    self.readChar();
                    break :blk Token.init(.NEQ, "!=", tok_line, tok_column);
                }
                // '!' solo no es valido en Boemia Script
                self.readChar();
                break :blk Token.init(.ILLEGAL, "!", tok_line, tok_column);
            },

            // OPERADORES DE COMPARACION (MENOR QUE)
            // '<' puede ser LT o LTE
            '<' => blk: {
                if (self.peekChar() == '=') {
                    self.readChar();
                    self.readChar();
                    break :blk Token.init(.LTE, "<=", tok_line, tok_column);
                }
                self.readChar();
                break :blk Token.init(.LT, "<", tok_line, tok_column);
            },

            // OPERADORES DE COMPARACION (MAYOR QUE)
            // '>' puede ser GT o GTE
            '>' => blk: {
                if (self.peekChar() == '=') {
                    self.readChar();
                    self.readChar();
                    break :blk Token.init(.GTE, ">=", tok_line, tok_column);
                }
                self.readChar();
                break :blk Token.init(.GT, ">", tok_line, tok_column);
            },
            // DELIMITADORES
            // Parentesis, llaves, punto y coma, etc.
            // Son todos de un solo caracter, muy directos
            '(' => blk: {
                self.readChar();
                break :blk Token.init(.LPAREN, "(", tok_line, tok_column);
            },
            ')' => blk: {
                self.readChar();
                break :blk Token.init(.RPAREN, ")", tok_line, tok_column);
            },
            '{' => blk: {
                self.readChar();
                break :blk Token.init(.LBRACE, "{", tok_line, tok_column);
            },
            '}' => blk: {
                self.readChar();
                break :blk Token.init(.RBRACE, "}", tok_line, tok_column);
            },
            ';' => blk: {
                self.readChar();
                break :blk Token.init(.SEMICOLON, ";", tok_line, tok_column);
            },
            ':' => blk: {
                self.readChar();
                break :blk Token.init(.COLON, ":", tok_line, tok_column);
            },
            ',' => blk: {
                self.readChar();
                break :blk Token.init(.COMMA, ",", tok_line, tok_column);
            },

            // STRINGS
            // Si encontramos ", delegamos a readString()
            '"' => self.readString(),

            // FIN DE ARCHIVO
            // 0 es nuestra marca especial de EOF
            0 => Token.init(.EOF, "", tok_line, tok_column),

            // CASO ELSE - TODO LO DEMAS
            // Este es el caso catch-all para todo lo que no matcheamos arriba
            // Aqui manejamos identificadores, numeros, y caracteres ilegales
            else => blk: {
                // Si empieza con letra, es un identificador o keyword
                if (isLetter(self.ch)) {
                    const ident = self.readIdentifier();
                    // lookupIdentifier decide si es keyword o variable
                    const tok_type = token.lookupIdentifier(ident);
                    break :blk Token.init(tok_type, ident, tok_line, tok_column);
                }
                // Si empieza con digito, es un numero
                else if (isDigit(self.ch)) {
                    break :blk self.readNumber();
                }
                // Si no es ninguno de los anteriores, es un caracter ilegal
                else {
                    const lexeme = self.source[self.position .. self.position + 1];
                    self.readChar();
                    break :blk Token.init(.ILLEGAL, lexeme, tok_line, tok_column);
                }
            },
        };

        return tok;
    }
};

// FUNCIONES AUXILIARES
// Estas funciones helper verifican tipos de caracteres
// Las definimos fuera del struct porque son funciones puras
// no necesitan acceso a self

// VERIFICAR SI ES LETRA
// En Boemia Script, las letras son a-z, A-Z, y underscore
// El underscore cuenta como letra para permitir nombres como _variable
fn isLetter(ch: u8) bool {
    return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or ch == '_';
}

// VERIFICAR SI ES DIGITO
// Simple: caracteres del '0' al '9'
fn isDigit(ch: u8) bool {
    return ch >= '0' and ch <= '9';
}
