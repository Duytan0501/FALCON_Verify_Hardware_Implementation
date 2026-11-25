`timescale 1ns / 1ps

module fpr_gm_rom (
    input  wire        clk,
    input  wire [8:0]  addr,    // 0..511 (FALCON-512 dung toi da 0..383)
    input  wire        conj,    // 0: FFT / poly_merge_fft | 1: iFFT / poly_split_fft
    output reg  [63:0] s_re,
    output reg  [63:0] s_im,
    input  wire [3:0]  logn,    // 0..10 cho fpr_p2_tab
    output reg  [63:0] p2_val
);

    // =========================================================================
    // 1. GIẢI MÃ ĐỐI XỨNG PHẦN TƯ: 512 ĐỊA CHỈ -> 128 Ô ROM GỐC
    // =========================================================================
    reg [6:0] rom_idx;
    reg       do_swap;

    always @(*) begin
        rom_idx = 7'd0;
        do_swap = 1'b0;
        if (addr[8]) begin
            do_swap = addr[7];
            rom_idx = {1'b1,      addr[7] ? ~addr[6:1] : addr[6:1]}; // 256..511 -> 64..127
        end else if (addr[7]) begin
            do_swap = addr[6];
            rom_idx = {2'b01,     addr[6] ? ~addr[5:1] : addr[5:1]}; // 128..255 -> 32..63
        end else if (addr[6]) begin
            do_swap = addr[5];
            rom_idx = {3'b001,    addr[5] ? ~addr[4:1] : addr[4:1]}; // 64..127  -> 16..31
        end else if (addr[5]) begin
            do_swap = addr[4];
            rom_idx = {4'b0001,   addr[4] ? ~addr[3:1] : addr[3:1]}; // 32..63   -> 8..15
        end else if (addr[4]) begin
            do_swap = addr[3];
            rom_idx = {5'b00001,  addr[3] ? ~addr[2:1] : addr[2:1]}; // 16..31   -> 4..7
        end else if (addr[3]) begin
            do_swap = addr[2];
            rom_idx = {6'b000001, addr[2] ? ~addr[1]   : addr[1]};   // 8..15    -> 2..3
        end else if (addr[2]) begin
            do_swap = addr[1];
            rom_idx = 7'd1;                                          // 4..7     -> 1
        end else begin
            do_swap = 1'b0;
            rom_idx = 7'd0;                                          // 2..3     -> 0
        end
    end

    // =========================================================================
    // 2. BẢNG ROM 128 CẶP GỐC (CHÉP TRỰC TIẾP TỪ fpr.c)
    // =========================================================================
    reg [63:0] base_re;
    reg [63:0] base_im;

    always @(*) begin
        case (rom_idx)
            // k = 2
            7'd0:   begin base_re = 64'd4604544271217802189; base_im = 64'd4604544271217802189; end
            // k = 4
            7'd1:   begin base_re = 64'd4606496786581982534; base_im = 64'd4600565431771507043; end
            // k = 8, 10
            7'd2:   begin base_re = 64'd4607009347991985328; base_im = 64'd4596196889902818827; end
            7'd3:   begin base_re = 64'd4603179351334086856; base_im = 64'd4605664432017547683; end
            // k = 16, 18, 20, 22
            7'd4:   begin base_re = 64'd4607139046673687846; base_im = 64'd4591727299969791020; end
            7'd5:   begin base_re = 64'd4603889326261607894; base_im = 64'd4605137878724712257; end
            7'd6:   begin base_re = 64'd4606118860100255153; base_im = 64'd4602163548591158843; end
            7'd7:   begin base_re = 64'd4598900923775164166; base_im = 64'd4606794571824115162; end
            // k = 32, 34, ..., 46
            7'd8:   begin base_re = 64'd4607171569234046334; base_im = 64'd4587232218149935124; end
            7'd9:   begin base_re = 64'd4604224084862889120; base_im = 64'd4604849113969373103; end
            7'd10:  begin base_re = 64'd4606317631232591731; base_im = 64'd4601373767755717824; end
            7'd11:  begin base_re = 64'd4599740487990714333; base_im = 64'd4606655894547498725; end
            7'd12:  begin base_re = 64'd4606912484326125783; base_im = 64'd4597922303871901467; end
            7'd13:  begin base_re = 64'd4602805845399633902; base_im = 64'd4605900952042040894; end
            7'd14:  begin base_re = 64'd4605409869824231233; base_im = 64'd4603540801876750389; end
            7'd15:  begin base_re = 64'd4594454542771183930; base_im = 64'd4607084929468638487; end
            // k = 64, 66, ..., 94
            7'd16:  begin base_re = 64'd4607179706000002317; base_im = 64'd4582730748936808062; end
            7'd17:  begin base_re = 64'd4604386048625945823; base_im = 64'd4604698657331085206; end
            7'd18:  begin base_re = 64'd4606409688975526202; base_im = 64'd4600971798440897930; end
            7'd19:  begin base_re = 64'd4600154912527631775; base_im = 64'd4606578871587619388; end
            7'd20:  begin base_re = 64'd4606963563043808649; base_im = 64'd4597061974398750563; end
            7'd21:  begin base_re = 64'd4602994049708411683; base_im = 64'd4605784983948558848; end
            7'd22:  begin base_re = 64'd4605539368864982914; base_im = 64'd4603361638657888991; end
            7'd23:  begin base_re = 64'd4595327571478659014; base_im = 64'd4607049811591515049; end
            7'd24:  begin base_re = 64'd4607114680469659603; base_im = 64'd4593485039402578702; end
            7'd25:  begin base_re = 64'd4603716733069447353; base_im = 64'd4605276012900672507; end
            7'd26:  begin base_re = 64'd4606012266443150634; base_im = 64'd4602550884377336506; end
            7'd27:  begin base_re = 64'd4598476289818621559; base_im = 64'd4606856142606846307; end
            7'd28:  begin base_re = 64'd4606727809065869586; base_im = 64'd4599322407794599425; end
            7'd29:  begin base_re = 64'd4601771097584682078; base_im = 64'd4606220668805321205; end
            7'd30:  begin base_re = 64'd4604995550503212910; base_im = 64'd4604058477489546729; end
            7'd31:  begin base_re = 64'd4589965306122607094; base_im = 64'd4607158013403433018; end
            // k = 128, 130, ..., 190
            7'd32:  begin base_re = 64'd4607181740574479067; base_im = 64'd4578227681973159812; end
            7'd33:  begin base_re = 64'd4604465633578481725; base_im = 64'd4604621949701367983; end
            7'd34:  begin base_re = 64'd4606453861145241227; base_im = 64'd4600769149537129431; end
            7'd35:  begin base_re = 64'd4600360675823176935; base_im = 64'd4606538458821337243; end
            7'd36:  begin base_re = 64'd4606987119037722413; base_im = 64'd4596629994023683153; end
            7'd37:  begin base_re = 64'd4603087070374583113; base_im = 64'd4605725276488455441; end
            7'd38:  begin base_re = 64'd4605602459698789090; base_im = 64'd4603270878689749849; end
            7'd39:  begin base_re = 64'd4595762727260045105; base_im = 64'd4607030246558998647; end
            7'd40:  begin base_re = 64'd4607127537664763515; base_im = 64'd4592606767730311893; end
            7'd41:  begin base_re = 64'd4603803453461190356; base_im = 64'd4605207475328619533; end
            7'd42:  begin base_re = 64'd4606066157444814153; base_im = 64'd4602357870542944470; end
            7'd43:  begin base_re = 64'd4598688984595225406; base_im = 64'd4606826008603986804; end
            7'd44:  begin base_re = 64'd4606761837001494797; base_im = 64'd4599112075441176914; end
            7'd45:  begin base_re = 64'd4601967947786150793; base_im = 64'd4606170366472647579; end
            7'd46:  begin base_re = 64'd4605067233569943231; base_im = 64'd4603974338538572089; end
            7'd47:  begin base_re = 64'd4590846768565625881; base_im = 64'd4607149205763218185; end
            7'd48:  begin base_re = 64'd4607165468267934125; base_im = 64'd4588998070480937184; end
            7'd49:  begin base_re = 64'd4604141730443515286; base_im = 64'd4604922840319727473; end
            7'd50:  begin base_re = 64'd4606269759522929756; base_im = 64'd4601573027631668967; end
            7'd51:  begin base_re = 64'd4599531889160152938; base_im = 64'd4606692493141721470; end
            7'd52:  begin base_re = 64'd4606884969294623682; base_im = 64'd4598262871476403630; end
            7'd53:  begin base_re = 64'd4602710690099904183; base_im = 64'd4605957195211051218; end
            7'd54:  begin base_re = 64'd4605343481119364930; base_im = 64'd4603629178146150899; end
            7'd55:  begin base_re = 64'd4594016801320007031; base_im = 64'd4607100477024622401; end
            7'd56:  begin base_re = 64'd4607068040143112603; base_im = 64'd4594891488091520602; end
            7'd57:  begin base_re = 64'd4603451617570386922; base_im = 64'd4605475169017376660; end
            7'd58:  begin base_re = 64'd4605843545406134034; base_im = 64'd4602900303344142735; end
            7'd59:  begin base_re = 64'd4597492765973365521; base_im = 64'd4606938683557690074; end
            7'd60:  begin base_re = 64'd4606618018794815019; base_im = 64'd4599948172872067014; end
            7'd61:  begin base_re = 64'd4601173347964633034; base_im = 64'd4606364276725003740; end
            7'd62:  begin base_re = 64'd4604774382555066977; base_im = 64'd4604305528345395596; end
            7'd63:  begin base_re = 64'd4585465300892538317; base_im = 64'd4607176315382986589; end
            // k = 256, 258, ..., 382
            7'd64:  begin base_re = 64'd4607182249242036882; base_im = 64'd4573724215515480177; end
            7'd65:  begin base_re = 64'd4604505071555817232; base_im = 64'd4604583231088591477; end
            7'd66:  begin base_re = 64'd4606475480113671417; base_im = 64'd4600667422348321968; end
            7'd67:  begin base_re = 64'd4600463181646572228; base_im = 64'd4606517779747998088; end
            7'd68:  begin base_re = 64'd4606998399608725124; base_im = 64'd4596413578358834022; end
            7'd69:  begin base_re = 64'd4603133304188877240; base_im = 64'd4605694995810664660; end
            7'd70:  begin base_re = 64'd4605633586259814045; base_im = 64'd4603225210076562971; end
            7'd71:  begin base_re = 64'd4595979936813835462; base_im = 64'd4607019963775302583; end
            7'd72:  begin base_re = 64'd4607133460805585796; base_im = 64'd4592167175087283203; end
            7'd73:  begin base_re = 64'd4603846496621587377; base_im = 64'd4605172808754305228; end
            7'd74:  begin base_re = 64'd4606092657816072624; base_im = 64'd4602260871257280788; end
            7'd75:  begin base_re = 64'd4598795050632330097; base_im = 64'd4606810452769876110; end
            7'd76:  begin base_re = 64'd4606778366364612594; base_im = 64'd4599006600037663623; end
            7'd77:  begin base_re = 64'd4602065906208722008; base_im = 64'd4606144763310860551; end
            7'd78:  begin base_re = 64'd4605102686554936490; base_im = 64'd4603931940768740167; end
            7'd79:  begin base_re = 64'd4591287158938884897; base_im = 64'd4607144295058764886; end
            7'd80:  begin base_re = 64'd4607168688050493276; base_im = 64'd4588115294056142819; end
            7'd81:  begin base_re = 64'd4604183020748362039; base_im = 64'd4604886103475043762; end
            7'd82:  begin base_re = 64'd4606293848208650998; base_im = 64'd4601473544562720001; end
            7'd83:  begin base_re = 64'd4599636300858866724; base_im = 64'd4606674353838411301; end
            7'd84:  begin base_re = 64'd4606898891031025132; base_im = 64'd4598136582470364665; end
            7'd85:  begin base_re = 64'd4602758354025980442; base_im = 64'd4605929219593405673; end
            7'd86:  begin base_re = 64'd4605376811039722786; base_im = 64'd4603585091850767959; end
            7'd87:  begin base_re = 64'd4594235767444503503; base_im = 64'd4607092871118901179; end
            7'd88:  begin base_re = 64'd4607076652372832968; base_im = 64'd4594673119063280916; end
            7'd89:  begin base_re = 64'd4603496309891590679; base_im = 64'd4605442656228245717; end
            7'd90:  begin base_re = 64'd4605872393621214213; base_im = 64'd4602853162432841185; end
            7'd91:  begin base_re = 64'd4597707695679609371; base_im = 64'd4606925748668145757; end
            7'd92:  begin base_re = 64'd4606637115963965612; base_im = 64'd4599844446633109139; end
            7'd93:  begin base_re = 64'd4601273700967202825; base_im = 64'd4606341107699334546; end
            7'd94:  begin base_re = 64'd4604811873195349477; base_im = 64'd4604264921241055824; end
            7'd95:  begin base_re = 64'd4586348876009622851; base_im = 64'd4607174111710118367; end
            7'd96:  begin base_re = 64'd4607178180169683960; base_im = 64'd4584498631466405633; end
            7'd97:  begin base_re = 64'd4604345904647073908; base_im = 64'd4604736643460027021; end
            7'd98:  begin base_re = 64'd4606387137437298591; base_im = 64'd4601072712526242277; end
            7'd99:  begin base_re = 64'd4600051662802353687; base_im = 64'd4606598603759044570; end
            7'd100: begin base_re = 64'd4606951288507767453; base_im = 64'd4597277522845151878; end
            7'd101: begin base_re = 64'd4602947266358709886; base_im = 64'd4605814408482919348; end
            7'd102: begin base_re = 64'd4605507406967535927; base_im = 64'd4603406726595779752; end
            7'd103: begin base_re = 64'd4595109641634432498; base_im = 64'd4607059093103722971; end
            7'd104: begin base_re = 64'd4607107746899444102; base_im = 64'd4593797652641645341; end
            7'd105: begin base_re = 64'd4603673059103075106; base_im = 64'd4605309881318010327; end
            7'd106: begin base_re = 64'd4605984877841711338; base_im = 64'd4602646891659203088; end
            7'd107: begin base_re = 64'd4598369669086960528; base_im = 64'd4606870719641066940; end
            7'd108: begin base_re = 64'd4606710311774494716; base_im = 64'd4599427256825614420; end
            7'd109: begin base_re = 64'd4601672213217083403; base_im = 64'd4606245366082353408; end
            7'd110: begin base_re = 64'd4604959323120302796; base_im = 64'd4604100215502905499; end
            7'd111: begin base_re = 64'd4589524267239410099; base_im = 64'd4607161910007591876; end
            7'd112: begin base_re = 64'd4607153778602162496; base_im = 64'd4590406145430462614; end
            7'd113: begin base_re = 64'd4604016517974851588; base_im = 64'd4605031521104517324; end
            7'd114: begin base_re = 64'd4606195668621671667; base_im = 64'd4601869677011524443; end
            7'd115: begin base_re = 64'd4599217346014614711; base_im = 64'd4606744984357082948; end
            7'd116: begin base_re = 64'd4606841238740778884; base_im = 64'd4598582729657176439; end
            7'd117: begin base_re = 64'd4602454542796181607; base_im = 64'd4606039359984203741; end
            7'd118: begin base_re = 64'd4605241877142478242; base_im = 64'd4603760198400967492; end
            7'd119: begin base_re = 64'd4593046061348462537; base_im = 64'd4607121277474223905; end
            7'd120: begin base_re = 64'd4607040195955932526; base_im = 64'd4595545269419264690; end
            7'd121: begin base_re = 64'd4603316355454250015; base_im = 64'd4605571053506370248; end
            7'd122: begin base_re = 64'd4605755272910869620; base_im = 64'd4603040651631881451; end
            7'd123: begin base_re = 64'd4596846128749438754; base_im = 64'd4606975506703684317; end
            7'd124: begin base_re = 64'd4606558823023444576; base_im = 64'd4600257918160607478; end
            7'd125: begin base_re = 64'd4600870609507958271; base_im = 64'd4606431930490633905; end
            7'd126: begin base_re = 64'd4604660425598397818; base_im = 64'd4604425958770613225; end
            7'd127: begin base_re = 64'd4580962600092897021; base_im = 64'd4607180892816495009; end
            default: begin base_re = 64'd0; base_im = 64'd0; end
        endcase
    end

    // =========================================================================
    // 3. TÁI TẠO ĐẦY ĐỦ 512 CẶP & CHỐT ĐỒNG BỘ 1 CHU KỲ
    // =========================================================================
    wire [63:0] ev_re  = do_swap ? base_im : base_re;
    wire [63:0] ev_im  = do_swap ? base_re : base_im;

    wire [63:0] odd_re = {~ev_im[63], ev_im[62:0]};
    wire [63:0] odd_im = ev_re;

    wire [63:0] raw_re = (addr == 9'd0) ? 64'd0 :
                         (addr == 9'd1) ? 64'd9223372036854775808 :
                         (addr[0] ? odd_re : ev_re);

    wire [63:0] raw_im = (addr == 9'd0) ? 64'd0 :
                         (addr == 9'd1) ? 64'd4607182418800017408 :
                         (addr[0] ? odd_im : ev_im);

    always @(posedge clk) begin
        s_re <= raw_re;
        s_im <= {raw_im[63] ^ conj, raw_im[62:0]};
    end

    // =========================================================================
    // 4. BẢNG fpr_p2_tab[0..10] (CHIA 2^(logn-1) CUỐI iFFT)
    // =========================================================================
    always @(*) begin
        case (logn)
            4'd0:    p2_val = 64'd4611686018427387904; // 2.0
            4'd1:    p2_val = 64'd4607182418800017408; // 1.0
            4'd2:    p2_val = 64'd4602678819172646912; // 1/2
            4'd3:    p2_val = 64'd4598175219545276416; // 1/4
            4'd4:    p2_val = 64'd4593671619917905920; // 1/8
            4'd5:    p2_val = 64'd4589168020290535424; // 1/16
            4'd6:    p2_val = 64'd4584664420663164928; // 1/32
            4'd7:    p2_val = 64'd4580160821035794432; // 1/64
            4'd8:    p2_val = 64'd4575657221408423936; // 1/128
            4'd9:    p2_val = 64'd4571153621781053440; // 1/256
            4'd10:   p2_val = 64'd4566650022153682944; // 1/512
            default: p2_val = 64'd0;
        endcase
    end

endmodule