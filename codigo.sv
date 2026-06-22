module safecrack_fsm (
    input  logic       clk,
    input  logic [3:0] KEY,   // KEY[0]=reset; KEY[1]=confirm; KEY[2]=d++; KEY[3]=d--
    
    // contador do digito em edicao
    output logic [3:0] contador,  
  
    output logic [6:0] HEX0,       // ultimo dígito mais à direita
    output logic [6:0] HEX1,       // terceiro dígito
    output logic [6:0] HEX2,       // segundo dígito
    output logic [6:0] HEX3,       // primeiro dígito mais à esquerda
    output logic [6:0] HEX4,       // exibe o número do dígito ativo na tela     

    // saidas para os leds de feedback
    output logic [8:0] LEDG,       // G de green 
    output logic [17:0] LEDR       // R de red 
);

    // definicao da senha  
    localparam logic [3:0] SENHA_0 = 4'd6;   //array de 4 bits em todas 
    localparam logic [3:0] SENHA_1 = 4'd7;
    localparam logic [3:0] SENHA_2 = 4'd6;
    localparam logic [3:0] SENHA_3 = 4'd7;

    // definicao 7 estados possiveis da FSM
    typedef enum logic [6:0] { 
        EDIT_D0     = 7'b0000001, //edit primeiro digito HEX3
        EDIT_D1     = 7'b0000010, //edit segundo digito HEX2
        EDIT_D2     = 7'b0000100, //edit terceiro digito HEX1
        EDIT_D3     = 7'b0001000, //edit quarto digito HEX0
        VERIFICACAO = 7'b0010000, // comparando senha inserida com senha correta
        SUCESSO     = 7'b0100000, // senha certa: LEDG
        FAIL        = 7'b1000000  // senha errada: LEDR 
    } state_t; 

    state_t state, next_state;  //memoria que sera guardada por esses dois registradores

    // definicao variaveis da senha posta pelo usuario 
    logic [3:0] d0, d1, d2, d3;
    logic [3:0] next_d0, next_d1, next_d2, next_d3; //armazena os proximos para mudar de estado na borda do cloock 
    
    // def da constante do clk da placa e contadores de tempo 
    localparam int CLK_FREQ = 50_000_000; 
    logic [28:0] timer_cnt, next_timer_cnt; 

    logic [3:1] btn_prev; // estado anterior dos botões
    logic [3:1] btn_edge; // fica em 1 no instante do clique

    // FF pra atualizar estado anterior a cada pulso de clock
    always_ff @(posedge clk or negedge KEY[0]) begin
        if (~KEY[0]) begin
            btn_prev <= 3'b000;
        end 
        else begin
            btn_prev <= ~KEY[3:1]; // inverte pq é ativo em baixo
        end
    end
    
    assign btn_edge = (~KEY[3:1]) & (~btn_prev);

    // sequential logic 
    always_ff @(posedge clk or negedge KEY[0]) begin
        if (~KEY[0]) begin
            state     <= EDIT_D0;
            d0        <= 4'd0;
            d1        <= 4'd0;
            d2        <= 4'd0;
            d3        <= 4'd0;
            timer_cnt <= 29'd0;
        end 
        else begin
            state     <= next_state;
            d0        <= next_d0;
            d1        <= next_d1;
            d2        <= next_d2;
            d3        <= next_d3;
            timer_cnt <= next_timer_cnt;
        end
    end

    // logica de transição para prox estado 
    always_comb begin
        next_state     = state;
        next_d0        = d0;
        next_d1        = d1;
        next_d2        = d2;
        next_d3        = d3;
        next_timer_cnt = timer_cnt;

        case (state)
            EDIT_D0: begin                                                      // em tods os states de EDIT
                if (btn_edge[2]) next_d0 = (d0 == 4'd9) ? 4'd0 : d0 + 1'b1; // incrementa nesse digito
                if (btn_edge[3]) next_d0 = (d0 == 4'd0) ? 4'd9 : d0 - 1'b1; // decrementa nesse digito
                if (btn_edge[1]) next_state = EDIT_D1;                      // confirma e move para o proximo estado 
            end

            EDIT_D1: begin
                if (btn_edge[2]) next_d1 = (d1 == 4'd9) ? 4'd0 : d1 + 1'b1;
                if (btn_edge[3]) next_d1 = (d1 == 4'd0) ? 4'd9 : d1 - 1'b1;
                if (btn_edge[1]) next_state = EDIT_D2;
            end

            EDIT_D2: begin 
                if (btn_edge[2]) next_d2 = (d2 == 4'd9) ? 4'd0 : d2 + 1'b1;
                if (btn_edge[3]) next_d2 = (d2 == 4'd0) ? 4'd9 : d2 - 1'b1;
                if (btn_edge[1]) next_state = EDIT_D3;
            end

            EDIT_D3: begin 
                if (btn_edge[2]) next_d3 = (d3 == 4'd9) ? 4'd0 : d3 + 1'b1;
                if (btn_edge[3]) next_d3 = (d3 == 4'd0) ? 4'd9 : d3 - 1'b1;
                if (btn_edge[1]) begin
                    next_state = VERIFICACAO; 
                    next_timer_cnt = 29'd0; // zera o contador pra próximo estado
                end
            end

            VERIFICACAO: begin
                if ({d0, d1, d2, d3} == {SENHA_0, SENHA_1, SENHA_2, SENHA_3})
                    next_state = SUCESSO;
                else
                    next_state = FAIL;
            end 

            SUCESSO: begin 
                //segura no estado das LEDG por 5 seg
                if (timer_cnt < (CLK_FREQ * 5)) begin
                    next_timer_cnt = timer_cnt + 1'b1;
                end 
                else begin
                    next_state = EDIT_D0; // reseta a FSM
                    next_d0 = 4'd0; next_d1 = 4'd0; next_d2 = 4'd0; next_d3 = 4'd0;
                end
            end

            FAIL: begin 
                //segura no estado das LEDR por 3 seg
                if (timer_cnt < (CLK_FREQ * 3)) begin
                    next_timer_cnt = timer_cnt + 1'b1;
                end 
                else begin
                    next_state = EDIT_D0; // reseta a FSM
                    next_d0 = 4'd0; next_d1 = 4'd0; next_d2 = 4'd0; next_d3 = 4'd0;
                end
            end
            
            default: next_state = EDIT_D0; 
        endcase 
    end
    // lógica saída
    //  de Binário para 7 Segmentos do display da placa 
    function automatic logic [6:0] s7seg(input logic [3:0] bin);
        case (bin)
            4'd0: return 7'b1000000;
            4'd1: return 7'b1111001;
            4'd2: return 7'b0100100;
            4'd3: return 7'b0110000;
            4'd4: return 7'b0111001;
            4'd5: return 7'b0100010;
            4'd6: return 7'b0000010;
            4'd7: return 7'b1111000;
            4'd8: return 7'b0000000;
            4'd9: return 7'b0010000;
            default: return 7'b1111111; //apagado
        endcase
    endfunction

    always_comb begin
        // valores das leds
        LEDG = 9'b0;
        LEDR = 18'b0;
        if (state == SUCESSO) LEDG = 9'h1FF;    // acende leds verdes
        if (state == FAIL)    LEDR = 18'h3FFFF; // Acende leds vermelhas

        // atualização automática dos Displays com as variáveis de senha
        HEX3 = s7seg(d0);
        HEX2 = s7seg(d1);
        HEX1 = s7seg(d2);
        HEX0 = s7seg(d3);

        // atualização da variável 'contador' dependendo do estado
        case (state)
            EDIT_D0: contador = 4'd1;
            EDIT_D1: contador = 4'd2;
            EDIT_D2: contador = 4'd3;
            EDIT_D3: contador = 4'd4;
            default: contador = 4'd0; //zera o contador se estiver verificando, falhando ou sucesso
        endcase

        //mostrar o valor do contador na placa
        if (contador > 4'd0)
            HEX4 = s7seg(contador);
        else
            HEX4 = 7'b1111111; // deixa apagado quando não estiver editando
    end
endmodule
