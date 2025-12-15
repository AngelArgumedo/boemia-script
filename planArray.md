 Plan de Implementación: Arrays Dinámicos en Boemia Script

     Resumen

     Implementar arrays dinámicos con sintaxis let arr: [int] = [1, 2, 3]; que soporten:
     - Acceso por índice: arr[0]
     - Obtener tamaño: arr.length
     - Agregar elementos: arr.push(x)
     - Iteración: for item in arr { ... }

     Backend: Estructuras C personalizadas con malloc/free.

     Decisiones de Diseño

     Sistema de Tipos

     - Transformar DataType de enum simple a union recursivo
     - Soportar tipos genéricos: [T], [[T]], etc.
     - Sintaxis de declaración: let arr: [int] = [1, 2, 3];

     Backend C

     typedef struct {
         long long* data;
         size_t length;
         size_t capacity;
     } Array_int;

     Con funciones helper: Array_int_create(), Array_int_push(), Array_int_free()

     Archivos Críticos a Modificar

     1. src/ast.zig

     Cambios principales:
     - Transformar DataType enum → union con variante ARRAY
     - Agregar nuevas expresiones: ArrayLiteral, IndexAccess, MemberAccess, MethodCall
     - Agregar nuevo statement: ForInStmt
     - Actualizar métodos deinit() para todas las nuevas estructuras

     2. src/token.zig

     Nuevos tokens:
     - LBRACKET - [
     - RBRACKET - ]
     - DOT - .
     - IN - palabra clave para for-in

     3. src/lexer.zig

     Reconocimiento de tokens:
     - Agregar casos en nextToken() para [, ], .
     - Agregar "in" al mapa de keywords

     4. src/parser.zig

     Nuevas funciones:
     - parseDataType() - parsear tipos con soporte para [T]
     - Modificar parsePrimary() - agregar case para LBRACKET (array literals)
     - Modificar case IDENTIFIER - agregar soporte para [index], .member, .method()
     - parseForInStatement() - parsear for item in arr

     5. src/analyzer.zig

     Type checking:
     - Extender checkExpr() con casos para array operations
     - Implementar typesEqual() para comparación recursiva de tipos
     - Validar operaciones de arrays (índices, tipos de elementos, etc.)
     - Type checking para for-in loops

     6. src/codegen.zig

     Generación de código:
     - writeArrayStructDefinitions() - generar structs y helpers
     - collectArrayTypes() - recolectar todos los tipos de array usados
     - generateArrayStruct() - generar definición de struct
     - generateArrayHelpers() - generar create/push/free
     - Modificar generateExpr() - casos para array operations
     - Modificar generateStmt() - caso especial para arrays en variable_decl
     - Generar código para for-in loops

     Orden de Implementación (8 Fases)

     FASE 1: Fundamentos del Sistema de Tipos (2-3 días)

     1.1 Modificar DataType (ast.zig líneas 4-28)

     Transformar enum a union:
     pub const DataType = union(enum) {
         INT,
         FLOAT,
         STRING,
         BOOL,
         VOID,
         ARRAY: *ArrayType,

         pub const ArrayType = struct {
             element_type: *DataType,
             allocator: std.mem.Allocator,
         };

         // Actualizar fromString() para parsear [T]
         pub fn fromString(allocator: std.mem.Allocator, s: []const u8) !?DataType

         // Actualizar toString() para formatear [T]
         pub fn toString(self: DataType, allocator: std.mem.Allocator) ![]const u8

         // Nuevo: nombre para C (Array_int, Array_Array_int)
         pub fn toCName(self: DataType, allocator: std.mem.Allocator) ![]const u8

         // Nuevo: liberar memoria recursivamente
         pub fn deinit(self: *DataType) void
     };

     Test: Crear tipos manualmente y verificar toString/toCName

     1.2 Agregar Tokens (token.zig líneas 13-72, lexer.zig línea 277)

     En token.zig:
     pub const TokenType = enum {
         // ... existentes
         LBRACKET,    // [
         RBRACKET,    // ]
         DOT,         // .
         IN,          // for-in
     };

     // Actualizar keywords (línea 133):
     .{ "in", .IN },

     En lexer.zig (dentro de nextToken switch):
     '[' => Token.init(.LBRACKET, "[", tok_line, tok_column),
     ']' => Token.init(.RBRACKET, "]", tok_line, tok_column),
     '.' => Token.init(.DOT, ".", tok_line, tok_column),

     Test: Lexer reconoce [, ], ., palabra in

     FASE 2: Parsing Básico (3-4 días)

     2.1 Parsear Tipos de Array (parser.zig)

     Nueva función después de línea 555:
     fn parseDataType(self: *Parser) ParseError!DataType {
         // Verificar sintaxis [T]
         if (self.peek_token.type == .LBRACKET) {
             self.nextToken(); // consume token actual
             self.nextToken(); // consume '['

             const element_type = try self.parseDataType(); // recursivo

             if (self.current_token.type != .RBRACKET) {
                 return ParseError.UnexpectedToken;
             }
             self.nextToken(); // consume ']'

             // Crear DataType.ARRAY
             const elem_type_ptr = try self.allocator.create(DataType);
             elem_type_ptr.* = element_type;

             const array_type = try self.allocator.create(DataType.ArrayType);
             array_type.* = .{
                 .element_type = elem_type_ptr,
                 .allocator = self.allocator,
             };

             return DataType{ .ARRAY = array_type };
         }

         // Tipo simple
         return try DataType.fromString(self.allocator, self.peek_token.lexeme)
             orelse return ParseError.InvalidType;
     }

     Modificar parseVariableDecl (línea 114):
     // ANTES:
     const data_type = DataType.fromString(self.peek_token.lexeme) orelse ...;

     // DESPUÉS:
     const data_type = try self.parseDataType();

     Test: let arr: [int] = ...; parsea correctamente

     2.2 Nuevas Expresiones en AST (ast.zig línea 31)

     Agregar al union Expr:
     pub const Expr = union(enum) {
         // ... existentes
         array_literal: *ArrayLiteral,
         index_access: *IndexAccess,
         member_access: *MemberAccess,
         method_call: *MethodCall,

         pub const ArrayLiteral = struct {
             elements: []Expr,
             element_type: ?DataType,
         };

         pub const IndexAccess = struct {
             array: Expr,
             index: Expr,
         };

         pub const MemberAccess = struct {
             object: Expr,
             member: []const u8,
         };

         pub const MethodCall = struct {
             object: Expr,
             method: []const u8,
             args: []Expr,
         };
     };

     Actualizar deinit (línea 57):
     Agregar casos para liberar memoria de las nuevas expresiones

     2.3 Parsear Array Literals (parser.zig línea 453)

     En parsePrimary(), agregar case:
     .LBRACKET => blk: {
         self.nextToken(); // consume '['

         var elements: std.ArrayList(Expr) = .empty;
         defer elements.deinit(self.allocator);

         if (self.current_token.type == .RBRACKET) {
             // Array vacío
             self.nextToken();
             const arr_lit = try self.allocator.create(Expr.ArrayLiteral);
             arr_lit.* = .{
                 .elements = try elements.toOwnedSlice(self.allocator),
                 .element_type = null,
             };
             break :blk Expr{ .array_literal = arr_lit };
         }

         // Parsear elementos separados por coma
         while (true) {
             const elem = try self.parseExpression(0);
             try elements.append(self.allocator, elem);

             if (self.current_token.type == .COMMA) {
                 self.nextToken();
                 continue;
             }

             if (self.current_token.type == .RBRACKET) {
                 self.nextToken();
                 break;
             }

             return ParseError.UnexpectedToken;
         }

         const arr_lit = try self.allocator.create(Expr.ArrayLiteral);
         arr_lit.* = .{
             .elements = try elements.toOwnedSlice(self.allocator),
             .element_type = null,
         };
         break :blk Expr{ .array_literal = arr_lit };
     },

     Test: [1, 2, 3], [], [[1,2],[3,4]] se parsean

     FASE 3: Operaciones de Array (2-3 días)

     3.1 Parsear Index/Member/Method Access (parser.zig línea 478)

     Modificar case IDENTIFIER en parsePrimary:
     .IDENTIFIER => blk: {
         const name = self.current_token.lexeme;
         self.nextToken();

         var expr = Expr{ .identifier = name };

         // Loop para encadenamiento: arr[0][1], arr.length, etc.
         while (true) {
             if (self.current_token.type == .LBRACKET) {
                 // Index access: arr[index]
                 self.nextToken();
                 const index = try self.parseExpression(0);

                 if (self.current_token.type != .RBRACKET) {
                     return ParseError.UnexpectedToken;
                 }
                 self.nextToken();

                 const idx_access = try self.allocator.create(Expr.IndexAccess);
                 idx_access.* = .{ .array = expr, .index = index };
                 expr = Expr{ .index_access = idx_access };

             } else if (self.current_token.type == .DOT) {
                 // Member/method access
                 self.nextToken();

                 if (self.current_token.type != .IDENTIFIER) {
                     return ParseError.UnexpectedToken;
                 }
                 const member_name = self.current_token.lexeme;
                 self.nextToken();

                 if (self.current_token.type == .LPAREN) {
                     // Method call: arr.push(5)
                     self.nextToken();

                     var args: std.ArrayList(Expr) = .empty;
                     defer args.deinit(self.allocator);

                     while (self.current_token.type != .RPAREN) {
                         const arg = try self.parseExpression(0);
                         try args.append(self.allocator, arg);

                         if (self.current_token.type == .COMMA) {
                             self.nextToken();
                         }
                     }
                     self.nextToken(); // consume ')'

                     const meth_call = try self.allocator.create(Expr.MethodCall);
                     meth_call.* = .{
                         .object = expr,
                         .method = member_name,
                         .args = try args.toOwnedSlice(self.allocator),
                     };
                     expr = Expr{ .method_call = meth_call };
                 } else {
                     // Property access: arr.length
                     const mem_access = try self.allocator.create(Expr.MemberAccess);
                     mem_access.* = .{ .object = expr, .member = member_name };
                     expr = Expr{ .member_access = mem_access };
                 }

             } else if (self.current_token.type == .LPAREN) {
                 // Function call (código existente)
                 // ... mantener código actual
                 break;
             } else {
                 break;
             }
         }

         break :blk expr;
     },

     Test: arr[0], arr.length, arr.push(5), matrix[i][j]

     FASE 4: Type Checking (3-4 días)

     4.1 Type Checking para Arrays (analyzer.zig línea 269)

     Agregar casos en checkExpr:
     .array_literal => |arr| blk: {
         if (arr.elements.len == 0) {
             return AnalyzerError.TypeMismatch; // Error: array vacío
         }

         // Inferir tipo del primer elemento
         const first_type = try self.checkExpr(&arr.elements[0]);

         // Verificar que todos sean del mismo tipo
         for (arr.elements[1..]) |*elem| {
             const elem_type = try self.checkExpr(elem);
             if (!self.typesEqual(elem_type, first_type)) {
                 return AnalyzerError.TypeMismatch;
             }
         }

         // Crear tipo [T]
         const elem_type_ptr = try self.allocator.create(DataType);
         elem_type_ptr.* = first_type;

         const array_type = try self.allocator.create(DataType.ArrayType);
         array_type.* = .{
             .element_type = elem_type_ptr,
             .allocator = self.allocator,
         };

         break :blk DataType{ .ARRAY = array_type };
     },

     .index_access => |idx| blk: {
         const array_type = try self.checkExpr(&idx.array);
         const index_type = try self.checkExpr(&idx.index);

         // Índice debe ser int
         if (index_type != .INT) {
             return AnalyzerError.TypeMismatch;
         }

         // array_type debe ser ARRAY
         switch (array_type) {
             .ARRAY => |arr_type| break :blk arr_type.element_type.*,
             else => return AnalyzerError.TypeMismatch,
         }
     },

     .member_access => |mem| blk: {
         const object_type = try self.checkExpr(&mem.object);

         switch (object_type) {
             .ARRAY => {
                 if (std.mem.eql(u8, mem.member, "length")) {
                     break :blk DataType.INT;
                 } else {
                     return AnalyzerError.InvalidOperation;
                 }
             },
             else => return AnalyzerError.InvalidOperation,
         }
     },

     .method_call => |meth| blk: {
         const object_type = try self.checkExpr(&meth.object);

         switch (object_type) {
             .ARRAY => |arr_type| {
                 if (std.mem.eql(u8, meth.method, "push")) {
                     // Verificar 1 argumento
                     if (meth.args.len != 1) {
                         return AnalyzerError.TypeMismatch;
                     }

                     // Verificar tipo del argumento
                     const arg_type = try self.checkExpr(&meth.args[0]);
                     if (!self.typesEqual(arg_type, arr_type.element_type.*)) {
                         return AnalyzerError.TypeMismatch;
                     }

                     break :blk DataType.VOID;
                 } else {
                     return AnalyzerError.InvalidOperation;
                 }
             },
             else => return AnalyzerError.InvalidOperation,
         }
     },

     Nueva función auxiliar:
     fn typesEqual(self: *Analyzer, a: DataType, b: DataType) bool {
         const tag_a = @as(std.meta.Tag(DataType), a);
         const tag_b = @as(std.meta.Tag(DataType), b);

         if (tag_a != tag_b) return false;

         switch (a) {
             .ARRAY => |arr_a| {
                 switch (b) {
                     .ARRAY => |arr_b| {
                         return self.typesEqual(arr_a.element_type.*, arr_b.element_type.*);
                     },
                     else => return false,
                 }
             },
             else => return true,
         }
     }

     Test: Detectar errores de tipo en operaciones de arrays

     FASE 5: Code Generation - Estructuras (4-5 días)

     5.1 Generar Estructuras C (codegen.zig)

     Agregar campos al CodeGenerator (línea 17):
     pub const CodeGenerator = struct {
         // ... campos existentes
         array_types_seen: std.StringHashMap(DataType),
     };

     Nueva función después de writeHeaders (línea 72):
     fn writeArrayStructDefinitions(self: *CodeGenerator, program: *Program) !void {
         // Recolectar tipos únicos
         var array_types = std.StringHashMap(DataType).init(self.allocator);
         defer array_types.deinit();

         try self.collectArrayTypes(program, &array_types);

         // Generar struct para cada tipo
         var it = array_types.iterator();
         while (it.next()) |entry| {
             try self.generateArrayStruct(entry.value_ptr.*);
         }

         try self.write("\n");
     }

     fn generateArrayStruct(self: *CodeGenerator, array_type: DataType) !void {
         switch (array_type) {
             .ARRAY => |arr_type| {
                 const elem_type_c = try self.mapTypeToC(arr_type.element_type.*);
                 const struct_name = try array_type.toCName(self.allocator);
                 defer self.allocator.free(struct_name);

                 // typedef struct { ... } Array_int;
                 try self.write("typedef struct {\n");
                 try self.write("    ");
                 try self.write(elem_type_c);
                 try self.write("* data;\n");
                 try self.write("    size_t length;\n");
                 try self.write("    size_t capacity;\n");
                 try self.write("} ");
                 try self.write(struct_name);
                 try self.write(";\n\n");

                 // Generar helpers
                 try self.generateArrayHelpers(struct_name, elem_type_c);
             },
             else => {},
         }
     }

     fn generateArrayHelpers(self: *CodeGenerator, struct_name: []const u8, elem_type: []const u8) !void {
         // Array_int_create()
         try self.write(struct_name);
         try self.write(" ");
         try self.write(struct_name);
         try self.write("_create(size_t initial_capacity) {\n");
         try self.write("    ");
         try self.write(struct_name);
         try self.write(" arr = {0};\n");
         try self.write("    arr.capacity = initial_capacity > 0 ? initial_capacity : 4;\n");
         try self.write("    arr.data = (");
         try self.write(elem_type);
         try self.write("*)malloc(arr.capacity * sizeof(");
         try self.write(elem_type);
         try self.write("));\n");
         try self.write("    arr.length = 0;\n");
         try self.write("    return arr;\n");
         try self.write("}\n\n");

         // Array_int_push()
         try self.write("void ");
         try self.write(struct_name);
         try self.write("_push(");
         try self.write(struct_name);
         try self.write("* arr, ");
         try self.write(elem_type);
         try self.write(" value) {\n");
         try self.write("    if (arr->length >= arr->capacity) {\n");
         try self.write("        arr->capacity *= 2;\n");
         try self.write("        arr->data = (");
         try self.write(elem_type);
         try self.write("*)realloc(arr->data, arr->capacity * sizeof(");
         try self.write(elem_type);
         try self.write("));\n");
         try self.write("    }\n");
         try self.write("    arr->data[arr->length++] = value;\n");
         try self.write("}\n\n");

         // Array_int_free()
         try self.write("void ");
         try self.write(struct_name);
         try self.write("_free(");
         try self.write(struct_name);
         try self.write("* arr) {\n");
         try self.write("    free(arr->data);\n");
         try self.write("}\n\n");
     }

     Modificar generate (línea 40):
     pub fn generate(self: *CodeGenerator, program: *Program) ![]const u8 {
         try self.writeHeaders();

         // NUEVO: generar structs de arrays
         try self.writeArrayStructDefinitions(program);

         // ... resto del código existente
     }

     Test: Código C compilable con structs y helpers

     5.2 Generar Código para Expresiones (codegen.zig línea 269)

     Agregar casos en generateExpr:
     .array_literal => |arr| {
         // Este caso se maneja mejor en variable_decl
         // Para expresiones, asumimos que ya se generó
     },

     .index_access => |idx| {
         try self.generateExpr(&idx.array);
         try self.write(".data[");
         try self.generateExpr(&idx.index);
         try self.write("]");
     },

     .member_access => |mem| {
         if (std.mem.eql(u8, mem.member, "length")) {
             try self.generateExpr(&mem.object);
             try self.write(".length");
         }
     },

     .method_call => |meth| {
         if (std.mem.eql(u8, meth.method, "push")) {
             const obj_type = try self.inferExprType(&meth.object);
             const struct_name = try obj_type.toCName(self.allocator);
             defer self.allocator.free(struct_name);

             try self.write(struct_name);
             try self.write("_push(&");
             try self.generateExpr(&meth.object);
             try self.write(", ");
             try self.generateExpr(&meth.args[0]);
             try self.write(")");
         }
     },

     Modificar variable_decl en generateStmt (línea 83):
     .variable_decl => |decl| {
         self.variable_types.put(decl.name, decl.data_type) catch ...;

         try self.writeIndent();

         if (decl.data_type == .ARRAY) {
             // Caso especial para arrays
             const type_c = try self.mapTypeToC(decl.data_type);
             defer self.allocator.free(type_c);

             try self.write(type_c);
             try self.write(" ");
             try self.write(decl.name);
             try self.write(" = ");

             switch (decl.value) {
                 .array_literal => |arr| {
                     const struct_name = try decl.data_type.toCName(self.allocator);
                     defer self.allocator.free(struct_name);

                     // Array_int_create(3);
                     try self.write(struct_name);
                     try self.write("_create(");
                     const cap = std.fmt.allocPrint(self.allocator, "{d}", .{arr.elements.len})
                         catch return CodeGenError.OutOfMemory;
                     defer self.allocator.free(cap);
                     try self.write(cap);
                     try self.write(");\n");

                     // Array_int_push(&arr, 1);
                     for (arr.elements) |*elem| {
                         try self.writeIndent();
                         try self.write(struct_name);
                         try self.write("_push(&");
                         try self.write(decl.name);
                         try self.write(", ");
                         try self.generateExpr(elem);
                         try self.write(");\n");
                     }
                     return;
                 },
                 else => {
                     try self.generateExpr(&decl.value);
                     try self.write(";\n");
                 },
             }
         } else {
             // Código existente para tipos simples
             // ...
         }
     },

     Test: let arr: [int] = [1,2,3]; genera C correcto

     FASE 6: For-In Loops (2-3 días)

     6.1 AST y Parser

     En ast.zig después de línea 106:
     pub const Stmt = union(enum) {
         // ... existentes
         for_in_stmt: *ForInStmt,

         pub const ForInStmt = struct {
             iterator: []const u8,
             iterator_type: ?DataType,
             iterable: Expr,
             body: []Stmt,
         };
     };

     En parser.zig, modificar case FOR (línea 88):
     .FOR => blk: {
         self.nextToken();

         // Distinguir: for-in vs for tradicional
         if (self.current_token.type == .IDENTIFIER and self.peek_token.type == .IN) {
             break :blk self.parseForInStatement();
         } else {
             break :blk self.parseForStatement();
         }
     },

     Nueva función:
     fn parseForInStatement(self: *Parser) ParseError!Stmt {
         if (self.current_token.type != .IDENTIFIER) {
             return ParseError.UnexpectedToken;
         }
         const iterator = self.current_token.lexeme;
         self.nextToken();

         if (self.current_token.type != .IN) {
             return ParseError.UnexpectedToken;
         }
         self.nextToken();

         const iterable = try self.parseExpression(0);

         if (self.current_token.type != .LBRACE) {
             return ParseError.UnexpectedToken;
         }
         self.nextToken();

         const body = try self.parseBlock();
         self.nextToken();

         const for_in = try self.allocator.create(Stmt.ForInStmt);
         for_in.* = .{
             .iterator = iterator,
             .iterator_type = null,
             .iterable = iterable,
             .body = body,
         };

         return Stmt{ .for_in_stmt = for_in };
     }

     6.2 Type Checking (analyzer.zig línea 64)

     Agregar caso:
     .for_in_stmt => |for_in| {
         const iterable_type = try self.checkExpr(&for_in.iterable);

         switch (iterable_type) {
             .ARRAY => |arr_type| {
                 // Registrar iterator
                 try self.symbol_table.put(for_in.iterator, Symbol{
                     .data_type = arr_type.element_type.*,
                     .is_const = true,
                 });

                 // Analizar cuerpo
                 for (for_in.body) |*stmt| {
                     try self.analyzeStmt(stmt);
                 }

                 // Limpiar iterator
                 _ = self.symbol_table.remove(for_in.iterator);
             },
             else => return AnalyzerError.TypeMismatch,
         }
     },

     6.3 Code Generation (codegen.zig línea 81)

     Agregar caso en generateStmt:
     .for_in_stmt => |for_in| {
         try self.writeIndent();
         try self.write("for (size_t __i_");
         try self.write(for_in.iterator);
         try self.write(" = 0; __i_");
         try self.write(for_in.iterator);
         try self.write(" < ");
         try self.generateExpr(&for_in.iterable);
         try self.write(".length; __i_");
         try self.write(for_in.iterator);
         try self.write("++) {\n");

         self.indent_level += 1;

         // Declarar variable del iterator
         try self.writeIndent();
         const iter_type = for_in.iterator_type.?;
         const type_c = try self.mapTypeToC(iter_type);
         defer self.allocator.free(type_c);
         try self.write(type_c);
         try self.write(" ");
         try self.write(for_in.iterator);
         try self.write(" = ");
         try self.generateExpr(&for_in.iterable);
         try self.write(".data[__i_");
         try self.write(for_in.iterator);
         try self.write("];\n");

         // Generar cuerpo
         for (for_in.body) |*stmt| {
             try self.generateStmt(stmt);
         }

         self.indent_level -= 1;
         try self.writeIndent();
         try self.write("}\n");
     },

     Test: for item in arr { print(item); } funciona

     FASE 7: Testing (2-3 días)

     7.1 Tests Básicos

     Crear archivos de prueba:

     examples/test_arrays_basic.bs:
     let arr: [int] = [1, 2, 3];
     print(arr.length);
     print(arr[0]);
     print(arr[1]);

     examples/test_arrays_push.bs:
     let arr: [int] = [10];
     arr.push(20);
     arr.push(30);
     print(arr.length);
     print(arr[2]);

     examples/test_arrays_forin.bs:
     let nums: [int] = [5, 10, 15];
     for n in nums {
         print(n);
     }

     examples/test_arrays_nested.bs:
     let matrix: [[int]] = [[1, 2], [3, 4]];
     print(matrix[0][1]);
     print(matrix[1][0]);

     7.2 Verificar Compilación y Ejecución

     Para cada test:
     1. Compilar con Boemia Script
     2. Verificar que C se genera correctamente
     3. Compilar con GCC
     4. Ejecutar y verificar output

     FASE 8: Gestión de Memoria y Refinamiento (1-2 días)

     8.1 Agregar Cleanup de Arrays

     Problema: Arrays con malloc deben liberarse con free

     Solución: Agregar llamadas a _free() antes de salir de scopes

     En codegen, antes de cada return 0 en main y antes de cada return en funciones:
     Array_int_free(&arr);

     8.2 Documentación

     Actualizar:
     - README.md con ejemplos de arrays
     - Crear examples/arrays_demo.bs
     - Documentar limitaciones conocidas

     Consideraciones Importantes

     Limitaciones

     1. Arrays vacíos requieren anotación de tipo:
     let arr: [int] = [];  // OK
     let arr = [];          // ERROR
     2. No hay bounds checking: arr[100] puede causar crash
     3. No hay slicing: arr[1..3] no soportado
     4. Métodos limitados: Solo push y length

     Gestión de Memoria

     - Arrays usan malloc/realloc/free
     - Cada array necesita _free() antes de salir de scope
     - Arrays de arrays liberan recursivamente

     Testing Strategy

     Probar incrementalmente:
     - Después de cada fase, compilar y ejecutar tests
     - Usar valgrind para detectar memory leaks
     - Verificar que código C generado es válido

     Resumen de Cambios por Archivo

     | Archivo      | Líneas Aprox | Complejidad             |
     |--------------|--------------|-------------------------|
     | ast.zig      | +150         | Alta (tipos recursivos) |
     | token.zig    | +10          | Baja                    |
     | lexer.zig    | +15          | Baja                    |
     | parser.zig   | +200         | Alta                    |
     | analyzer.zig | +150         | Media-Alta              |
     | codegen.zig  | +300         | Muy Alta                |

     Total estimado: ~825 líneas de código nuevo/modificado

     Tiempo estimado: 18-26 días de trabajo
