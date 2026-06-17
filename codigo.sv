module safecrack_fsm (
    input  logic       clk,
    input  logic [3:0] KEY,   // KEY[0]=reset; KEY[1]=confirm; KEY[2]=d++; KEY[3]=d--
    
    // 7:0 para incluir led do DecimalPoint   
    output logic [7:0]  HEX0,      // ultimo dígito mais à direita
    output logic [7:0]  HEX1,      // terceiro dígito
    output logic [7:0]  HEX2,      // segundo dígito
    output logic [7:0]  HEX3,      // primeiro dígito mais à esquerda
    output logic [7:0]  HEX4,      // indicador do dígito ativo     

    // saidas para os leds de feedback
    output logic [8:0] LEDG      // G de green 
    output logic [17:0] LEDR     // R de red 
);

// definicao da senha  
    localparam logic [3:0] SENHA_0 = 4'd4;   //array de 4 bits em todas 
    localparam logic [3:0] SENHA_1 = 4'd3;
    localparam logic [3:0] SENHA_2 = 4'd2;
    localparam logic [3:0] SENHA_3 = 4'd1;

// definicao 7 estados possiveis da FSM
    typedef enum logic [6:0] { 
        S0 = 7'b0000001, //edit primeiro digito HEX3
        S1 = 7'b0000010, //edit segundo digito HEX2
        S2 = 7'b0000100, //edit terceiro digito HEX1
        S3 = 7'b0001000, //edit quarto digito HEX0
        VERIFICACAO = 7'0010000, // comparando senha inserida com senha correta
        SUCESSO = 7'0100000 // senha certa: LEDG
        FAIL =  7'1000000 // senha errada: LEDR 
    } state_t;

    state_t state, next_state  //memoria que sera guardada por esses dois registradores

// definicao variaveis da senha posta pelo usuario 
    logic [3:0] d0, d1, d2, d3
    logic [3:0] next_d0, next_d1, next_d2, next_d3 //armazena os proximos para mudar de estado na borda do cloock 
    
