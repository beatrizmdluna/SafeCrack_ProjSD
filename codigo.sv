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
    localparam logic [3:0] SENHA_0 = 4'd6;   
    localparam logic [3:0] SENHA_1 = 4'd7;
    localparam logic [3:0] SENHA_2 = 4'd6;
    localparam logic [3:0] SENHA_3 = 4'd7;

    // definicao 7 estados possiveis da FSM
    typedef enum logic [6:0] { 
        EDIT_D0     = 7'b0000001, 
        EDIT_D1     = 7'b0000010, 
        EDIT_D2     = 7'b0000100, 
        EDIT_D3     = 7'b0001000, 
        VERIFICACAO = 7'b0010000, 
        SUCESSO     = 7'b0100000, 
        FAIL        = 7'b1000000  
    } state_t; 

    state_t state, next_state;  

    // definicao variaveis da senha posta pelo usuario 
    logic [3:0] d0, d1, d2, d3;
    logic [3:0] next_d0, next_d1, next_d2, next_d3; 
    
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
            // index bit a bit 
            btn_prev[1] <= ~KEY[1];
            btn_prev[2] <= ~KEY[2];
            btn_prev[3] <= ~KEY[3];
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
            EDIT_D0: begin                                                                     
                next_timer_cnt = 29'd0; // zera o timer quando volta pro estado inicial 
                if (btn_edge[2]) next_d0 = (d0 == 4'd9) ? 4'd0 : d0 + 1'b1; 
                if (btn_edge[3]) next_d0 = (d0 == 4'd0) ? 4'd9 : d0 - 1'b1; 
                if (btn_edge[1]) next_state = EDIT_D1;                      
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
                    next_timer_cnt = 29'd0; 
                end
            end

            VERIFICACAO: begin
                if ({d0, d1, d2, d3} == {SENHA_0, SENHA_1, SENHA_2, SENHA_3})
                    next_state = SUCESSO;
                else
                    next_state = FAIL;
            end 

            SUCESSO: begin 
                if (timer_cnt < (CLK_FREQ * 5)) begin
                    next_timer_cnt = timer_cnt + 1'b1;
                end 
                else begin
                    next_state = EDIT_D0; 
                    next_d0 = 4'd0; next_d1 = 4'd0; next_d2 = 4'd0; next_d3 = 4'd0;
                end
            end

            FAIL: begin 
                if (timer_cnt < (CLK_FREQ * 3)) begin
                    next_timer_cnt = timer_cnt + 1'b1;
                end 
                else begin
                    next_state = EDIT_D0; 
                    next_d0 = 4'd0; next_d1 = 4'd0; next_d2 = 4'd0; next_d3 = 4'd0;
                end
            end
            
            default: next_state = EDIT_D0; 
        endcase 
    end

    // lógica saída (função s7seg e bloco de displays mantidos idênticos)
    function automatic logic [6:0] s7seg(input logic [3:0] bin);
    case (bin)
        4'd0:    s7seg = 7'b0000001;
        4'd1:    s7seg = 7'b1001111;
        4'd2:    s7seg = 7'b0010010;
        4'd3:    s7seg = 7'b0000110;
        4'd4:    s7seg = 7'b1001100;
        4'd5:    s7seg = 7'b0100100;
        4'd6:    s7seg = 7'b0100000;
        4'd7:    s7seg = 7'b0001111;
        4'd8:    s7seg = 7'b0000000;
        4'd9:    s7seg = 7'b0000100;
        default: s7seg = 7'b1111110; // hifen
    endcase
endfunction

    always_comb begin
        LEDG = 9'b0;
        LEDR = 18'b0;
        if (state == SUCESSO) LEDG = 9'h1FF;    
        if (state == FAIL)    LEDR = 18'h3FFFF; 

        HEX3 = s7seg(d0);
        HEX2 = s7seg(d1);
        HEX1 = s7seg(d2);
        HEX0 = s7seg(d3);

        case (state)
            EDIT_D0: contador = 4'd1;
            EDIT_D1: contador = 4'd2;
            EDIT_D2: contador = 4'd3;
            EDIT_D3: contador = 4'd4;
            default: contador = 4'd0; 
        endcase

        if (contador > 4'd0)
            HEX4 = s7seg(contador);
        else
            HEX4 = 7'b1111111; 
    end
endmodule
