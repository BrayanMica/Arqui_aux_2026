.global _start

// utils.s — itoa, write_file, print_error, integer_sqrt
.include "utils.s"

//prueba datos (referencia, ya no se usan — los datos vienen del CSV)
test_data:
	//.quad 50, 48, 46, 45, 43, 42
	//quad 50, 48, 46, 45, 43, 42          // Trend descendete: SLOPE_X100=-160
	//.quad 10, 20, 30, 40, 50, 60          // ascendente: SLOPE_X100=1000
	//.quad 30, 30, 30, 30, 30, 30          // estable: SLOPE_X100=0
	//.quad 0, 0, 0, 0, 0, 0, 0, 0          // ESTABLE CON CEROS: SLOPE_X100=0

//pruebas erroes
	//.quad 42                               					  	// ERROR Division por cero: N=1 -> DEN=0
	//.quad 0                             					      // ERROR Division por cero: N=1 -> DEN=0 (cero)
	//.quad 100, 50                          					  // N=2 minimo funcional: SLOPE_X100=-5000
	//.quad 100, 50, 0                       					  // N=3 descendente: SLOPE_X100=-5000
	//.quad -500000, -490000, -480000, -470000, -460000           // negativos grandes
	//.quad -100, 50, -30, 80, -60, 20                           	 // Signos alternados
	//.quad 0, 50, 0, 50, 0, 50                                   // Intercalado con ceros
	//.quad -999999, -500000, 0, 500000, 999999                   // Rango maximo pos/neg

	N_test = (. - test_data) / 8      // N=6

.data
//archivo salida--------------------------------------------------
outfile:
	.asciz "resultado_regresion.txt"
//estructura del archivo-
str_calc:
	.ascii "CALC=LINEAR_REGRESSION\n"
	len_calc = . - str_calc
str_col:
	.ascii "COLUMN="
	len_col = . - str_col 		//Temp,Hum suelo, etcetera
str_ws:
	.ascii "WINDOW_START="
	len_ws = . - str_ws  		//fila inicial del analisis
str_we:
	.ascii "WINDOW_END="
	len_we = . -str_we 		//fila final del analisis
str_count:
	.ascii "COUNT="  		//numero de datos
	len_count = . - str_count
str_slope:
	.ascii "SLOPE_X100="		// pendiente * 100
	len_slope = . - str_slope
str_trend:
	.ascii "TREND="			//direccion tendencia
	len_trend = . - str_trend
str_status:
	.ascii "STATUS=" 		//estado de la operacion, funciono? ok
	len_status = . - str_status
str_asc:
	.ascii "ASCENDING\n" 		//opcion ascendente de trend
	len_asc = . - str_asc
str_desc:
	.ascii "DESCENDING\n" 		//opcion descendente de trend
	len_desc = . - str_desc
str_stable:
	.ascii "STABLE\n" 		//opcion neutral de trend
	len_stable = . - str_stable
str_ok:
	.ascii "OK\n"  			//opcion de status
	len_ok = . - str_ok
str_err:
	.ascii "ERROR\n" 		//Opcion para status en caso de error
	len_err = . - str_err

// Mensajes de error (agrupados)
str_err_zero_div: 			//division por cero
	.ascii "ERROR: Division by zero\n"
	len_err_zero_div = . - str_err_zero_div

str_err_insufficient:
	.ascii "ERROR: datos insuficientes\n"		//count<2
	len_err_insufficient = . - str_err_insufficient

str_err_file:
	.ascii "ERROR: No se encontro el archivo\n"		//no se encontro archivo csv
	len_err_file = . - str_err_file

str_err_parse:
	.ascii "ERROR: Error en la conversion\n"		//no es numero
	len_err_parse = . - str_err_parse

nl:
	.ascii "\n" 			//salto de linea

// num_buffer declarado en utils.s

.bss
// Parametros guardados para la salida
saved_col_ptr:  .skip 8	// puntero al nombre de la columna (argv)
saved_ws:       .skip 8	// linea_inicial (entero)
saved_we:       .skip 8	// linea_final (entero)
saved_count:    .skip 8	// cantidad de datos procesados

//funcionalidad--------------------------------------
.text

//manejo de errores:-----------------

//division entre 0
fail_zero_div:
	mov x0, #1
	ldr x1, =str_err_zero_div
	mov x2, len_err_zero_div
	b print_error

//no hay suficientes datos para analizar: count<2
fail_insufficient_data:
	mov x0, #1
	ldr x1, =str_err_insufficient
	mov x2, len_err_insufficient
	b print_error

//archivo no se encontro
fail_file_not_found:
	mov x0, #1
	ldr x1, =str_err_file
	mov x2, len_err_file
	b print_error

// Valor no numerico
fail_parse_error:
	mov x0, #1
	ldr x1, =str_err_parse
	mov x2, len_err_parse
	b print_error

// Funcionalidad principal (calculos)
_start:

	// Leer argumentos: ./regresion lecturas.csv 10 80 TEMP
	ldr x0, [sp]               // argc
	cmp x0, #5                 // programa + 4 argumentos
	blt fail_insufficient_data

	ldr x0, [sp, #16]         // argv[1] = archivo
	ldr x1, [sp, #24]         // argv[2] = linea_inicial
	ldr x2, [sp, #32]         // argv[3] = linea_final
	ldr x3, [sp, #40]         // argv[4] = columna

	// Guardar puntero de columna para la salida
	ldr x4, =saved_col_ptr
	str x3, [x4]

	// Validar archivo, lineas, columna (historical_analyzer_validate de utils.s)
	bl historical_analyzer_validate
	mov x11, x0               // x11 = indice de columna
	add x11, x11, #1          // ajustar: CSV tiene columna ID antes de los sensores

	// Convertir linea_inicial a entero (cadena_a_entero de utils.s)
	ldr x0, [sp, #24]         // re-leer argv[2], sp no cambio
	bl cadena_a_entero
	mov x13, x0               // x13 = linea_inicial (entero) para read_column_to_stack
	ldr x4, =saved_ws
	str x0, [x4]              // guardar para salida

	// Convertir linea_final a entero
	ldr x0, [sp, #32]         // re-leer argv[3]
	bl cadena_a_entero
	mov x14, x0               // x14 = linea_final (entero) para read_column_to_stack
	ldr x4, =saved_we
	str x0, [x4]              // guardar para salida

	// Leer columna del CSV al stack (read_column_to_stack de utils.s)
	// entrada: x11=columna, x13=linea_ini, x14=linea_fin
	// retorna: x0=inicio datos, x1=limite superior, x2=COUNT, x3=restaurar
	bl read_column_to_stack

	// Validar COUNT >= 2
	cmp x2, #2
	blt fail_insufficient_data

	// Guardar COUNT para salida
	mov x26, x2               // N = COUNT
	ldr x4, =saved_count
	str x2, [x4]

	// El stack tiene los datos en orden inverso (LIFO)
	// x1 = limite superior, primer valor cronologico esta en x1-16
	sub x24, x1, #16          // puntero al primer valor (orden cronologico)

	// Inicializar sumatorias
	mov x9, #0                 // sumatoria X
	mov x10, #0                // sumatoria Y
	mov x12, #0                // sumatoria XY
	mov x13, #0                // (sumatoria xy)²
	mov x14, #0                // contador xi

sum_loop:
	cmp x14, x26
	beq sums_done

	ldr x15, [x24]             // Yi

	add x9, x9, x14            // sumatoria X += Xi
	add x10, x10, x15          // sumatoria Y += Y_i

	mul x22, x14, x15
	add x12, x12, x22          // sumatoria XY += X_i * Y_i

	mul x22, x14, x14
	add x13, x13, x22          // sumatoria X² += X_i * X_i

	add x14, x14, #1           // X_i++
	sub x24, x24, #16          // siguiente dato en stack (orden cronologico)
	b sum_loop

sums_done:
	// NUM = N*sumatoria XY - sumatoria X*sumatoria Y
	mul x15, x26, x12
	mul x22, x9, x10
	sub x23, x15, x22          // x23 = NUM

	// DEN = N*sumatoria X² - sumatoria X * sumatoria X
	mul x15, x26, x13
	mul x22, x9, x9
	sub x25, x15, x22          // x25 = DEN

	// Validar DEN != 0
	cmp x25, #0
	beq fail_zero_div

	// MX100 = (NUM * 100) / DEN
	cmp x23, #0
	bge num_positive

	// NUM negativo
	mov x0, #0
	sub x15, x0, x23
	mov x0, #100
	mul x15, x15, x0
	udiv x15, x15, x25
	mov x0, #0
	sub x19, x0, x15
	b classify

num_positive:
	mov x0, #100
	mul x23, x23, x0
	udiv x19, x23, x25

classify:
	cmp x19, #0
	bgt trend_up
	blt trend_down

	// estable
	ldr x20, =str_stable
	mov x21, len_stable
	b print_result

trend_up:
	ldr x20, =str_asc
	mov x21, len_asc
	b print_result

trend_down:
	ldr x20, =str_desc
	mov x21, len_desc

print_result:
	// Abrir archivo de salida (resultado_regresion.txt)
	mov x0, #-100              // AT_FDCWD
	ldr x1, =outfile
	mov x2, #(1 | 64 | 512)   // O_WRONLY| O_CREAT|O_TRUNC  //repo aux
	mov x3, #420              //permiso
	mov x8, #56               // syscall openat
	svc #0
	mov x27, x0               // x27 = fd del archivo para toda la salida

	// "CALC=LINEAR_REGRESSION\n"
	mov x0, x27
	ldr x1, =str_calc
	mov x2, len_calc
	bl write_file

	// "COLUMN=" + nombre columna + newline
	mov x0, x27
	ldr x1, =str_col
	mov x2, len_col
	bl write_file

	ldr x4, =saved_col_ptr
	ldr x1, [x4]              // puntero al string de columna
	mov x2, #0
col_len_loop:
	ldrb w3, [x1, x2]         // calcular longitud del nombre
	cbz w3, col_len_done
	add x2, x2, #1
	b col_len_loop
col_len_done:
	mov x0, x27
	bl write_file

	mov x0, x27
	ldr x1, =nl
	mov x2, #1
	bl write_file

	// "WINDOW_START=" + valor
	mov x0, x27
	ldr x1, =str_ws
	mov x2, len_ws
	bl write_file

	ldr x4, =saved_ws
	ldr x0, [x4]
	ldr x1, =num_buffer
	bl itoa
	mov x0, x27
	ldr x1, =num_buffer
	bl write_file

	mov x0, x27
	ldr x1, =nl
	mov x2, #1
	bl write_file

	// "WINDOW_END=" + valor
	mov x0, x27
	ldr x1, =str_we
	mov x2, len_we
	bl write_file

	ldr x4, =saved_we
	ldr x0, [x4]
	ldr x1, =num_buffer
	bl itoa
	mov x0, x27
	ldr x1, =num_buffer
	bl write_file

	mov x0, x27
	ldr x1, =nl
	mov x2, #1
	bl write_file

	// "COUNT=" + valor
	mov x0, x27
	ldr x1, =str_count
	mov x2, len_count
	bl write_file

	ldr x4, =saved_count
	ldr x0, [x4]
	ldr x1, =num_buffer
	bl itoa
	mov x0, x27
	ldr x1, =num_buffer
	bl write_file

	mov x0, x27
	ldr x1, =nl
	mov x2, #1
	bl write_file

	// "SLOPE_X100=" + valor
	mov x0, x27
	ldr x1, =str_slope
	mov x2, len_slope
	bl write_file

	// M_X100
	mov x0, x19               // valor a convertir
	ldr x1, =num_buffer       // destino
	bl itoa                    // x2 = longitud resultante
	mov x0, x27
	ldr x1, =num_buffer
	bl write_file

	mov x0, x27
	ldr x1, =nl
	mov x2, #1
	bl write_file

	// "TREND=" + tendencia
	mov x0, x27
	ldr x1, =str_trend
	mov x2, len_trend
	bl write_file

	// tendencia (ya incluye \n)
	mov x0, x27
	mov x1, x20
	mov x2, x21
	bl write_file

	// "STATUS=OK\n"
	mov x0, x27
	ldr x1, =str_status
	mov x2, len_status
	bl write_file

	mov x0, x27
	ldr x1, =str_ok
	mov x2, len_ok
	bl write_file

	// Cerrar archivo de salida
	mov x0, x27
	mov x8, #57                // syscall close
	svc #0

	// exit(0)
	mov x0, #0
	mov x8, #93
	svc #0
