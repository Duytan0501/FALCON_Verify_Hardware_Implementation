`timescale 1ns / 1ps
module ntt_engine (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output reg  [8:0]  ram_addr_a,
    output reg  [8:0]  ram_addr_b,
    input  wire [15:0] ram_rdata_a,
    input  wire [15:0] ram_rdata_b,
    output wire [15:0] ram_wdata_a,
    output wire [15:0] ram_wdata_b,
    output reg         ram_we_a,
    output reg         ram_we_b,
    output reg  [8:0]  ram_h_addr,
    input  wire [15:0] ram_h_rdata,
    output reg         done
);
    localparam IDLE        = 5'd0;
    localparam NTT_OUTER   = 5'd1;
    localparam NTT_MID     = 5'd2;
    localparam NTT_READ    = 5'd3;
    localparam NTT_WAIT    = 5'd4;
    localparam NTT_WRITE   = 5'd5;
    localparam PWM_READ    = 5'd6;
    localparam PWM_WAIT    = 5'd7;
    localparam PWM_WRITE   = 5'd8;
    localparam INTT_OUTER  = 5'd9;
    localparam INTT_MID    = 5'd10;
    localparam INTT_READ   = 5'd11;
    localparam INTT_WAIT   = 5'd12;
    localparam INTT_WRITE  = 5'd13;
    localparam FIN_READ    = 5'd14;
    localparam FIN_WAIT    = 5'd15;
    localparam FIN_WRITE   = 5'd16;
    localparam DONE_STATE  = 5'd17;
    reg [4:0]  state;
    reg [9:0]  m;
    reg [9:0]  t;
    reg [9:0]  ht;
    reg [9:0]  hm;
    reg [9:0]  dt;
    reg [9:0]  i;
    reg [9:0]  j1;
    reg [9:0]  j2;
    reg [9:0]  j;
    reg [9:0]  u_cnt;
    reg [15:0] s_const;
    reg [15:0] mul_x;
    reg [15:0] mul_y;
    wire [15:0] mul_z;
    reg [15:0] add_x;
    reg [15:0] add_y;
    wire [15:0] add_z;
    reg [15:0] sub_x;
    reg [15:0] sub_y;
    wire [15:0] sub_z;
    reg [15:0] ram_wdata_a_reg;
    reg [15:0] ram_wdata_b_reg;
    assign ram_wdata_a = ram_wdata_a_reg;
    assign ram_wdata_b = ram_wdata_b_reg;
    reg [15:0] GMb [0:511];
    reg [15:0] iGMb [0:511];
 initial begin
        GMb[  0]=16'd4091;  GMb[  1]=16'd7888;  GMb[  2]=16'd11060; GMb[  3]=16'd11208; GMb[  4]=16'd6960;  GMb[  5]=16'd4342;  GMb[  6]=16'd6275;  GMb[  7]=16'd9759; 
        GMb[  8]=16'd1591;  GMb[  9]=16'd6399;  GMb[ 10]=16'd9477;  GMb[ 11]=16'd5266;  GMb[ 12]=16'd586;   GMb[ 13]=16'd5825;  GMb[ 14]=16'd7538;  GMb[ 15]=16'd9710; 
        GMb[ 16]=16'd1134;  GMb[ 17]=16'd6407;  GMb[ 18]=16'd1711;  GMb[ 19]=16'd965;   GMb[ 20]=16'd7099;  GMb[ 21]=16'd7674;  GMb[ 22]=16'd3743;  GMb[ 23]=16'd6442; 
        GMb[ 24]=16'd10414; GMb[ 25]=16'd8100;  GMb[ 26]=16'd1885;  GMb[ 27]=16'd1688;  GMb[ 28]=16'd1364;  GMb[ 29]=16'd10329; GMb[ 30]=16'd10164; GMb[ 31]=16'd9180; 
        GMb[ 32]=16'd12210; GMb[ 33]=16'd6240;  GMb[ 34]=16'd997;   GMb[ 35]=16'd117;   GMb[ 36]=16'd4783;  GMb[ 37]=16'd4407;  GMb[ 38]=16'd1549;  GMb[ 39]=16'd7072; 
        GMb[ 40]=16'd2829;  GMb[ 41]=16'd6458;  GMb[ 42]=16'd4431;  GMb[ 43]=16'd8877;  GMb[ 44]=16'd7144;  GMb[ 45]=16'd2564;  GMb[ 46]=16'd5664;  GMb[ 47]=16'd4042; 
        GMb[ 48]=16'd12189; GMb[ 49]=16'd432;   GMb[ 50]=16'd10751; GMb[ 51]=16'd1237;  GMb[ 52]=16'd7610;  GMb[ 53]=16'd1534;  GMb[ 54]=16'd3983;  GMb[ 55]=16'd7863; 
        GMb[ 56]=16'd2181;  GMb[ 57]=16'd6308;  GMb[ 58]=16'd8720;  GMb[ 59]=16'd6570;  GMb[ 60]=16'd4843;  GMb[ 61]=16'd1690;  GMb[ 62]=16'd14;    GMb[ 63]=16'd3872; 
        GMb[ 64]=16'd5569;  GMb[ 65]=16'd9368;  GMb[ 66]=16'd12163; GMb[ 67]=16'd2019;  GMb[ 68]=16'd7543;  GMb[ 69]=16'd2315;  GMb[ 70]=16'd4673;  GMb[ 71]=16'd7340; 
        GMb[ 72]=16'd1553;  GMb[ 73]=16'd1156;  GMb[ 74]=16'd8401;  GMb[ 75]=16'd11389; GMb[ 76]=16'd1020;  GMb[ 77]=16'd2967;  GMb[ 78]=16'd10772; GMb[ 79]=16'd7045; 
        GMb[ 80]=16'd3316;  GMb[ 81]=16'd11236; GMb[ 82]=16'd5285;  GMb[ 83]=16'd11578; GMb[ 84]=16'd10637; GMb[ 85]=16'd10086; GMb[ 86]=16'd9493;  GMb[ 87]=16'd6180; 
        GMb[ 88]=16'd9277;  GMb[ 89]=16'd6130;  GMb[ 90]=16'd3323;  GMb[ 91]=16'd883;   GMb[ 92]=16'd10469; GMb[ 93]=16'd489;   GMb[ 94]=16'd1502;  GMb[ 95]=16'd2851; 
        GMb[ 96]=16'd11061; GMb[ 97]=16'd9729;  GMb[ 98]=16'd2742;  GMb[ 99]=16'd12241; GMb[100]=16'd4970;  GMb[101]=16'd10481; GMb[102]=16'd10078; GMb[103]=16'd1195; 
        GMb[104]=16'd730;   GMb[105]=16'd1762;  GMb[106]=16'd3854;  GMb[107]=16'd2030;  GMb[108]=16'd5892;  GMb[109]=16'd10922; GMb[110]=16'd9020;  GMb[111]=16'd5274; 
        GMb[112]=16'd9179;  GMb[113]=16'd3604;  GMb[114]=16'd3782;  GMb[115]=16'd10206; GMb[116]=16'd3180;  GMb[117]=16'd3467;  GMb[118]=16'd4668;  GMb[119]=16'd2446; 
        GMb[120]=16'd7613;  GMb[121]=16'd9386;  GMb[122]=16'd834;   GMb[123]=16'd7703;  GMb[124]=16'd6836;  GMb[125]=16'd3403;  GMb[126]=16'd5351;  GMb[127]=16'd12276; 
        GMb[128]=16'd3580;  GMb[129]=16'd1739;  GMb[130]=16'd10820; GMb[131]=16'd9787;  GMb[132]=16'd10209; GMb[133]=16'd4070;  GMb[134]=16'd12250; GMb[135]=16'd8525; 
        GMb[136]=16'd10401; GMb[137]=16'd2749;  GMb[138]=16'd7338;  GMb[139]=16'd10574; GMb[140]=16'd6040;  GMb[141]=16'd943;   GMb[142]=16'd9330;  GMb[143]=16'd1477; 
        GMb[144]=16'd6865;  GMb[145]=16'd9668;  GMb[146]=16'd3585;  GMb[147]=16'd6633;  GMb[148]=16'd12145; GMb[149]=16'd4063;  GMb[150]=16'd3684;  GMb[151]=16'd7680; 
        GMb[152]=16'd8188;  GMb[153]=16'd6902;  GMb[154]=16'd3533;  GMb[155]=16'd9807;  GMb[156]=16'd6090;  GMb[157]=16'd727;   GMb[158]=16'd10099; GMb[159]=16'd7003; 
        GMb[160]=16'd6945;  GMb[161]=16'd1949;  GMb[162]=16'd9731;  GMb[163]=16'd10559; GMb[164]=16'd6057;  GMb[165]=16'd378;   GMb[166]=16'd7871;  GMb[167]=16'd8763; 
        GMb[168]=16'd8901;  GMb[169]=16'd9229;  GMb[170]=16'd8846;  GMb[171]=16'd4551;  GMb[172]=16'd9589;  GMb[173]=16'd11664; GMb[174]=16'd7630;  GMb[175]=16'd8821; 
        GMb[176]=16'd5680;  GMb[177]=16'd4956;  GMb[178]=16'd6251;  GMb[179]=16'd8388;  GMb[180]=16'd10156; GMb[181]=16'd8723;  GMb[182]=16'd2341;  GMb[183]=16'd3159; 
        GMb[184]=16'd1467;  GMb[185]=16'd5460;  GMb[186]=16'd8553;  GMb[187]=16'd7783;  GMb[188]=16'd2649;  GMb[189]=16'd2320;  GMb[190]=16'd9036;  GMb[191]=16'd6188; 
        GMb[192]=16'd737;   GMb[193]=16'd3698;  GMb[194]=16'd4699;  GMb[195]=16'd5753;  GMb[196]=16'd9046;  GMb[197]=16'd3687;  GMb[198]=16'd16;    GMb[199]=16'd914;  
        GMb[200]=16'd5186;  GMb[201]=16'd10531; GMb[202]=16'd4552;  GMb[203]=16'd1964;  GMb[204]=16'd3509;  GMb[205]=16'd8436;  GMb[206]=16'd7516;  GMb[207]=16'd5381; 
        GMb[208]=16'd10733; GMb[209]=16'd3281;  GMb[210]=16'd7037;  GMb[211]=16'd1060;  GMb[212]=16'd2895;  GMb[213]=16'd7156;  GMb[214]=16'd8887;  GMb[215]=16'd5357; 
        GMb[216]=16'd6409;  GMb[217]=16'd8197;  GMb[218]=16'd2962;  GMb[219]=16'd6375;  GMb[220]=16'd5064;  GMb[221]=16'd6634;  GMb[222]=16'd5625;  GMb[223]=16'd278;  
        GMb[224]=16'd932;   GMb[225]=16'd10229; GMb[226]=16'd8927;  GMb[227]=16'd7642;  GMb[228]=16'd351;   GMb[229]=16'd9298;  GMb[230]=16'd237;   GMb[231]=16'd5858; 
        GMb[232]=16'd7692;  GMb[233]=16'd3146;  GMb[234]=16'd12126; GMb[235]=16'd7586;  GMb[236]=16'd2053;  GMb[237]=16'd11285; GMb[238]=16'd3802;  GMb[239]=16'd5204; 
        GMb[240]=16'd4602;  GMb[241]=16'd1748;  GMb[242]=16'd11300; GMb[243]=16'd340;   GMb[244]=16'd3711;  GMb[245]=16'd4614;  GMb[246]=16'd300;   GMb[247]=16'd10993; 
        GMb[248]=16'd5070;  GMb[249]=16'd10049; GMb[250]=16'd11616; GMb[251]=16'd12247; GMb[252]=16'd7421;  GMb[253]=16'd10707; GMb[254]=16'd5746;  GMb[255]=16'd5654; 
        GMb[256]=16'd3835;  GMb[257]=16'd5553;  GMb[258]=16'd1224;  GMb[259]=16'd8476;  GMb[260]=16'd9237;  GMb[261]=16'd3845;  GMb[262]=16'd250;   GMb[263]=16'd11209; 
        GMb[264]=16'd4225;  GMb[265]=16'd6326;  GMb[266]=16'd9680;  GMb[267]=16'd12254; GMb[268]=16'd4136;  GMb[269]=16'd2778;  GMb[270]=16'd692;   GMb[271]=16'd8808; 
        GMb[272]=16'd6410;  GMb[273]=16'd6718;  GMb[274]=16'd10105; GMb[275]=16'd10418; GMb[276]=16'd3759;  GMb[277]=16'd7356;  GMb[278]=16'd11361; GMb[279]=16'd8433; 
        GMb[280]=16'd6437;  GMb[281]=16'd3652;  GMb[282]=16'd6342;  GMb[283]=16'd8978;  GMb[284]=16'd5391;  GMb[285]=16'd2272;  GMb[286]=16'd6476;  GMb[287]=16'd7416; 
        GMb[288]=16'd8418;  GMb[289]=16'd10824; GMb[290]=16'd11986; GMb[291]=16'd5733;  GMb[292]=16'd876;   GMb[293]=16'd7030;  GMb[294]=16'd2167;  GMb[295]=16'd2436; 
        GMb[296]=16'd3442;  GMb[297]=16'd9217;  GMb[298]=16'd8206;  GMb[299]=16'd4858;  GMb[300]=16'd5964;  GMb[301]=16'd2746;  GMb[302]=16'd7178;  GMb[303]=16'd1434; 
        GMb[304]=16'd7389;  GMb[305]=16'd8879;  GMb[306]=16'd10661; GMb[307]=16'd11457; GMb[308]=16'd4220;  GMb[309]=16'd1432;  GMb[310]=16'd10832; GMb[311]=16'd4328; 
        GMb[312]=16'd8557;  GMb[313]=16'd1867;  GMb[314]=16'd9454;  GMb[315]=16'd2416;  GMb[316]=16'd3816;  GMb[317]=16'd9076;  GMb[318]=16'd686;   GMb[319]=16'd5393; 
        GMb[320]=16'd2523;  GMb[321]=16'd4339;  GMb[322]=16'd6115;  GMb[323]=16'd619;   GMb[324]=16'd937;   GMb[325]=16'd2834;  GMb[326]=16'd7775;  GMb[327]=16'd3279; 
        GMb[328]=16'd2363;  GMb[329]=16'd7488;  GMb[330]=16'd6112;  GMb[331]=16'd5056;  GMb[332]=16'd824;   GMb[333]=16'd10204; GMb[334]=16'd11690; GMb[335]=16'd1113; 
        GMb[336]=16'd2727;  GMb[337]=16'd9848;  GMb[338]=16'd896;   GMb[339]=16'd2028;  GMb[340]=16'd5075;  GMb[341]=16'd2654;  GMb[342]=16'd10464; GMb[343]=16'd7884; 
        GMb[344]=16'd12169; GMb[345]=16'd5434;  GMb[346]=16'd3070;  GMb[347]=16'd6400;  GMb[348]=16'd9132;  GMb[349]=16'd11672; GMb[350]=16'd12153; GMb[351]=16'd4520; 
        GMb[352]=16'd1273;  GMb[353]=16'd9739;  GMb[354]=16'd11468; GMb[355]=16'd9937;  GMb[356]=16'd10039; GMb[357]=16'd9720;  GMb[358]=16'd2262;  GMb[359]=16'd9399; 
        GMb[360]=16'd11192; GMb[361]=16'd315;   GMb[362]=16'd4511;  GMb[363]=16'd1158;  GMb[364]=16'd6061;  GMb[365]=16'd6751;  GMb[366]=16'd11865; GMb[367]=16'd357;  
        GMb[368]=16'd7367;  GMb[369]=16'd4550;  GMb[370]=16'd983;   GMb[371]=16'd8534;  GMb[372]=16'd8352;  GMb[373]=16'd10126; GMb[374]=16'd7530;  GMb[375]=16'd9253; 
        GMb[376]=16'd4367;  GMb[377]=16'd5221;  GMb[378]=16'd3999;  GMb[379]=16'd8777;  GMb[380]=16'd3161;  GMb[381]=16'd6990;  GMb[382]=16'd4130;  GMb[383]=16'd11652; 
        GMb[384]=16'd3374;  GMb[385]=16'd11477; GMb[386]=16'd1753;  GMb[387]=16'd292;   GMb[388]=16'd8681;  GMb[389]=16'd2806;  GMb[390]=16'd10378; GMb[391]=16'd12188; 
        GMb[392]=16'd5800;  GMb[393]=16'd11811; GMb[394]=16'd3181;  GMb[395]=16'd1988;  GMb[396]=16'd1024;  GMb[397]=16'd9340;  GMb[398]=16'd2477;  GMb[399]=16'd10928; 
        GMb[400]=16'd4582;  GMb[401]=16'd6750;  GMb[402]=16'd3619;  GMb[403]=16'd5503;  GMb[404]=16'd5233;  GMb[405]=16'd2463;  GMb[406]=16'd8470;  GMb[407]=16'd7650; 
        GMb[408]=16'd7964;  GMb[409]=16'd6395;  GMb[410]=16'd1071;  GMb[411]=16'd1272;  GMb[412]=16'd3474;  GMb[413]=16'd11045; GMb[414]=16'd3291;  GMb[415]=16'd11344; 
        GMb[416]=16'd8502;  GMb[417]=16'd9478;  GMb[418]=16'd9837;  GMb[419]=16'd1253;  GMb[420]=16'd1857;  GMb[421]=16'd6233;  GMb[422]=16'd4720;  GMb[423]=16'd11561; 
        GMb[424]=16'd6034;  GMb[425]=16'd9817;  GMb[426]=16'd3339;  GMb[427]=16'd1797;  GMb[428]=16'd2879;  GMb[429]=16'd6242;  GMb[430]=16'd5200;  GMb[431]=16'd2114; 
        GMb[432]=16'd7962;  GMb[433]=16'd9353;  GMb[434]=16'd11363; GMb[435]=16'd5475;  GMb[436]=16'd6084;  GMb[437]=16'd9601;  GMb[438]=16'd4108;  GMb[439]=16'd7323; 
        GMb[440]=16'd10438; GMb[441]=16'd9471;  GMb[442]=16'd1271;  GMb[443]=16'd408;   GMb[444]=16'd6911;  GMb[445]=16'd3079;  GMb[446]=16'd360;   GMb[447]=16'd8276; 
        GMb[448]=16'd11535; GMb[449]=16'd9156;  GMb[450]=16'd9049;  GMb[451]=16'd11539; GMb[452]=16'd850;   GMb[453]=16'd8617;  GMb[454]=16'd784;   GMb[455]=16'd7919; 
        GMb[456]=16'd8334;  GMb[457]=16'd12170; GMb[458]=16'd1846;  GMb[459]=16'd10213; GMb[460]=16'd12184; GMb[461]=16'd7827;  GMb[462]=16'd11903; GMb[463]=16'd5600; 
        GMb[464]=16'd9779;  GMb[465]=16'd1012;  GMb[466]=16'd721;   GMb[467]=16'd2784;  GMb[468]=16'd6676;  GMb[469]=16'd6552;  GMb[470]=16'd5348;  GMb[471]=16'd4424; 
        GMb[472]=16'd6816;  GMb[473]=16'd8405;  GMb[474]=16'd9959;  GMb[475]=16'd5150;  GMb[476]=16'd2356;  GMb[477]=16'd5552;  GMb[478]=16'd5267;  GMb[479]=16'd1333; 
        GMb[480]=16'd8801;  GMb[481]=16'd9661;  GMb[482]=16'd7308;  GMb[483]=16'd5788;  GMb[484]=16'd4910;  GMb[485]=16'd909;   GMb[486]=16'd11613; GMb[487]=16'd4395; 
        GMb[488]=16'd8238;  GMb[489]=16'd6686;  GMb[490]=16'd4302;  GMb[491]=16'd3044;  GMb[492]=16'd2285;  GMb[493]=16'd12249; GMb[494]=16'd1963;  GMb[495]=16'd9216; 
        GMb[496]=16'd4296;  GMb[497]=16'd11918; GMb[498]=16'd695;   GMb[499]=16'd4371;  GMb[500]=16'd9793;  GMb[501]=16'd4884;  GMb[502]=16'd2411;  GMb[503]=16'd10230; 
        GMb[504]=16'd2650;  GMb[505]=16'd841;   GMb[506]=16'd3890;  GMb[507]=16'd10231; GMb[508]=16'd7248;  GMb[509]=16'd8505;  GMb[510]=16'd11196; GMb[511]=16'd6688;
        iGMb[  0]=16'd4091;  iGMb[  1]=16'd4401;  iGMb[  2]=16'd1081;  iGMb[  3]=16'd1229;  iGMb[  4]=16'd2530;  iGMb[  5]=16'd6014;  iGMb[  6]=16'd7947;  iGMb[  7]=16'd5329; 
        iGMb[  8]=16'd2579;  iGMb[  9]=16'd4751;  iGMb[ 10]=16'd6464;  iGMb[ 11]=16'd11703; iGMb[ 12]=16'd7023;  iGMb[ 13]=16'd2812;  iGMb[ 14]=16'd5890;  iGMb[ 15]=16'd10698; 
        iGMb[ 16]=16'd3109;  iGMb[ 17]=16'd2125;  iGMb[ 18]=16'd1960;  iGMb[ 19]=16'd10925; iGMb[ 20]=16'd10601; iGMb[ 21]=16'd10404; iGMb[ 22]=16'd4189;  iGMb[ 23]=16'd1875; 
        iGMb[ 24]=16'd5847;  iGMb[ 25]=16'd8546;  iGMb[ 26]=16'd4615;  iGMb[ 27]=16'd5190;  iGMb[ 28]=16'd11324; iGMb[ 29]=16'd10578; iGMb[ 30]=16'd5882;  iGMb[ 31]=16'd11155; 
        iGMb[ 32]=16'd8417;  iGMb[ 33]=16'd12275; iGMb[ 34]=16'd10599; iGMb[ 35]=16'd7446;  iGMb[ 36]=16'd5719;  iGMb[ 37]=16'd3569;  iGMb[ 38]=16'd5981;  iGMb[ 39]=16'd10108; 
        iGMb[ 40]=16'd4426;  iGMb[ 41]=16'd8306;  iGMb[ 42]=16'd10755; iGMb[ 43]=16'd4679;  iGMb[ 44]=16'd11052; iGMb[ 45]=16'd1538;  iGMb[ 46]=16'd11857; iGMb[ 47]=16'd100;  
        iGMb[ 48]=16'd8247;  iGMb[ 49]=16'd6625;  iGMb[ 50]=16'd9725;  iGMb[ 51]=16'd5145;  iGMb[ 52]=16'd3412;  iGMb[ 53]=16'd7858;  iGMb[ 54]=16'd5831;  iGMb[ 55]=16'd9460; 
        iGMb[ 56]=16'd5217;  iGMb[ 57]=16'd10740; iGMb[ 58]=16'd7882;  iGMb[ 59]=16'd7506;  iGMb[ 60]=16'd12172; iGMb[ 61]=16'd11292; iGMb[ 62]=16'd6049;  iGMb[ 63]=16'd79;   
        iGMb[ 64]=16'd13;    iGMb[ 65]=16'd6938;  iGMb[ 66]=16'd8886;  iGMb[ 67]=16'd5453;  iGMb[ 68]=16'd4586;  iGMb[ 69]=16'd11455; iGMb[ 70]=16'd2903;  iGMb[ 71]=16'd4676; 
        iGMb[ 72]=16'd9843;  iGMb[ 73]=16'd7621;  iGMb[ 74]=16'd8822;  iGMb[ 75]=16'd9109;  iGMb[ 76]=16'd2083;  iGMb[ 77]=16'd8507;  iGMb[ 78]=16'd8685;  iGMb[ 79]=16'd3110; 
        iGMb[ 80]=16'd7015;  iGMb[ 81]=16'd3269;  iGMb[ 82]=16'd1367;  iGMb[ 83]=16'd6397;  iGMb[ 84]=16'd10259; iGMb[ 85]=16'd8435;  iGMb[ 86]=16'd10527; iGMb[ 87]=16'd11559; 
        iGMb[ 88]=16'd11094; iGMb[ 89]=16'd2211;  iGMb[ 90]=16'd1808;  iGMb[ 91]=16'd7319;  iGMb[ 92]=16'd48;   iGMb[ 93]=16'd9547;  iGMb[ 94]=16'd2560;  iGMb[ 95]=16'd1228; 
        iGMb[ 96]=16'd9438;  iGMb[ 97]=16'd10787; iGMb[ 98]=16'd11800; iGMb[ 99]=16'd1820;  iGMb[100]=16'd11406; iGMb[101]=16'd8966;  iGMb[102]=16'd6159;  iGMb[103]=16'd3012; 
        iGMb[104]=16'd6109;  iGMb[105]=16'd2796;  iGMb[106]=16'd2203;  iGMb[107]=16'd1652;  iGMb[108]=16'd711;   iGMb[109]=16'd7004;  iGMb[110]=16'd1053;  iGMb[111]=16'd8973; 
        iGMb[112]=16'd5244;  iGMb[113]=16'd1517;  iGMb[114]=16'd9322;  iGMb[115]=16'd11269; iGMb[116]=16'd900;   iGMb[117]=16'd3888;  iGMb[118]=16'd11133; iGMb[119]=16'd10736; 
        iGMb[120]=16'd4949;  iGMb[121]=16'd7616;  iGMb[122]=16'd9974;  iGMb[123]=16'd4746;  iGMb[124]=16'd10270; iGMb[125]=16'd126;   iGMb[126]=16'd2921;  iGMb[127]=16'd6720; 
        iGMb[128]=16'd6635;  iGMb[129]=16'd6543;  iGMb[130]=16'd1582;  iGMb[131]=16'd4868;  iGMb[132]=16'd42;    iGMb[133]=16'd673;   iGMb[134]=16'd2240;  iGMb[135]=16'd7219; 
        iGMb[136]=16'd1296;  iGMb[137]=16'd11989; iGMb[138]=16'd7675;  iGMb[139]=16'd8578;  iGMb[140]=16'd11949; iGMb[141]=16'd989;   iGMb[142]=16'd10541; iGMb[143]=16'd7687; 
        iGMb[144]=16'd7085;  iGMb[145]=16'd8487;  iGMb[146]=16'd1004;  iGMb[147]=16'd10236; iGMb[148]=16'd4703;  iGMb[149]=16'd163;   iGMb[150]=16'd9143;  iGMb[151]=16'd4597; 
        iGMb[152]=16'd6431;  iGMb[153]=16'd12052; iGMb[154]=16'd2991;  iGMb[155]=16'd11938; iGMb[156]=16'd4647;  iGMb[157]=16'd3362;  iGMb[158]=16'd2060;  iGMb[159]=16'd11357; 
        iGMb[160]=16'd12011; iGMb[161]=16'd6664;  iGMb[162]=16'd5655;  iGMb[163]=16'd7225;  iGMb[164]=16'd5914;  iGMb[165]=16'd9327;  iGMb[166]=16'd4092;  iGMb[167]=16'd5880; 
        iGMb[168]=16'd6932;  iGMb[169]=16'd3402;  iGMb[170]=16'd5133;  iGMb[171]=16'd9394;  iGMb[172]=16'd11229; iGMb[173]=16'd5252;  iGMb[174]=16'd9008;  iGMb[175]=16'd1556; 
        iGMb[176]=16'd6908;  iGMb[177]=16'd4773;  iGMb[178]=16'd3853;  iGMb[179]=16'd8780;  iGMb[180]=16'd10325; iGMb[181]=16'd7737;  iGMb[182]=16'd1758;  iGMb[183]=16'd7103; 
        iGMb[184]=16'd11375; iGMb[185]=16'd12273; iGMb[186]=16'd8602;  iGMb[187]=16'd3243;  iGMb[188]=16'd6536;  iGMb[189]=16'd7590;  iGMb[190]=16'd8591;  iGMb[191]=16'd11552; 
        iGMb[192]=16'd6101;  iGMb[193]=16'd3253;  iGMb[194]=16'd9969;  iGMb[195]=16'd9640;  iGMb[196]=16'd4506;  iGMb[197]=16'd3736;  iGMb[198]=16'd6829;  iGMb[199]=16'd10822; 
        iGMb[200]=16'd9130;  iGMb[201]=16'd9948;  iGMb[202]=16'd3566;  iGMb[203]=16'd2133;  iGMb[204]=16'd3901;  iGMb[205]=16'd6038;  iGMb[206]=16'd7333;  iGMb[207]=16'd6609; 
        iGMb[208]=16'd3468;  iGMb[209]=16'd4659;  iGMb[210]=16'd625;   iGMb[211]=16'd2700;  iGMb[212]=16'd7738;  iGMb[213]=16'd3443;  iGMb[214]=16'd3060;  iGMb[215]=16'd3388; 
        iGMb[216]=16'd3526;  iGMb[217]=16'd4418;  iGMb[218]=16'd11911; iGMb[219]=16'd6232;  iGMb[220]=16'd1730;  iGMb[221]=16'd2558;  iGMb[222]=16'd10340; iGMb[223]=16'd5344; 
        iGMb[224]=16'd5286;  iGMb[225]=16'd2190;  iGMb[226]=16'd11562; iGMb[227]=16'd6199;  iGMb[228]=16'd2482;  iGMb[229]=16'd8756;  iGMb[230]=16'd5387;  iGMb[231]=16'd4101; 
        iGMb[232]=16'd4609;  iGMb[233]=16'd8605;  iGMb[234]=16'd8226;  iGMb[235]=16'd144;   iGMb[236]=16'd5656;  iGMb[237]=16'd8704;  iGMb[238]=16'd2621;  iGMb[239]=16'd5424; 
        iGMb[240]=16'd10812; iGMb[241]=16'd2959;  iGMb[242]=16'd11346; iGMb[243]=16'd6249;  iGMb[244]=16'd1715;  iGMb[245]=16'd4951;  iGMb[246]=16'd9540;  iGMb[247]=16'd1888; 
        iGMb[248]=16'd3764;  iGMb[249]=16'd39;    iGMb[250]=16'd8219;  iGMb[251]=16'd2080;  iGMb[252]=16'd2502;  iGMb[253]=16'd1469;  iGMb[254]=16'd10550; iGMb[255]=16'd8709; 
        iGMb[256]=16'd5601;  iGMb[257]=16'd1093;  iGMb[258]=16'd3784;  iGMb[259]=16'd5041;  iGMb[260]=16'd2058;  iGMb[261]=16'd8399;  iGMb[262]=16'd11448; iGMb[263]=16'd9639; 
        iGMb[264]=16'd2059;  iGMb[265]=16'd9878;  iGMb[266]=16'd7405;  iGMb[267]=16'd2496;  iGMb[268]=16'd7918;  iGMb[269]=16'd11594; iGMb[270]=16'd371;   iGMb[271]=16'd7993; 
        iGMb[272]=16'd3073;  iGMb[273]=16'd10326; iGMb[274]=16'd40;    iGMb[275]=16'd10004; iGMb[276]=16'd9245;  iGMb[277]=16'd7987;  iGMb[278]=16'd5603;  iGMb[279]=16'd4051; 
        iGMb[280]=16'd7894;  iGMb[281]=16'd676;   iGMb[282]=16'd11380; iGMb[283]=16'd7379;  iGMb[284]=16'd6501;  iGMb[285]=16'd4981;  iGMb[286]=16'd2628;  iGMb[287]=16'd3488; 
        iGMb[288]=16'd10956; iGMb[289]=16'd7022;  iGMb[290]=16'd6737;  iGMb[291]=16'd9933;  iGMb[292]=16'd7139;  iGMb[293]=16'd2330;  iGMb[294]=16'd3884;  iGMb[295]=16'd5473; 
        iGMb[296]=16'd7865;  iGMb[297]=16'd6941;  iGMb[298]=16'd5737;  iGMb[299]=16'd5613;  iGMb[300]=16'd9505;  iGMb[301]=16'd11568; iGMb[302]=16'd11277; iGMb[303]=16'd2510; 
        iGMb[304]=16'd6689;  iGMb[305]=16'd386;   iGMb[306]=16'd4462;  iGMb[307]=16'd105;   iGMb[308]=16'd2076;  iGMb[309]=16'd10443; iGMb[310]=16'd119;   iGMb[311]=16'd3955; 
        iGMb[312]=16'd4370;  iGMb[313]=16'd11505; iGMb[314]=16'd3672;  iGMb[315]=16'd11439; iGMb[316]=16'd750;   iGMb[317]=16'd3240;  iGMb[318]=16'd3133;  iGMb[319]=16'd754;  
        iGMb[320]=16'd4013;  iGMb[321]=16'd11929; iGMb[322]=16'd9210;  iGMb[323]=16'd5378;  iGMb[324]=16'd11881; iGMb[325]=16'd11018; iGMb[326]=16'd2818;  iGMb[327]=16'd1851; 
        iGMb[328]=16'd4966;  iGMb[329]=16'd8181;  iGMb[330]=16'd2688;  iGMb[331]=16'd6205;  iGMb[332]=16'd6814;  iGMb[333]=16'd926;   iGMb[334]=16'd2936;  iGMb[335]=16'd4327; 
        iGMb[336]=16'd10175; iGMb[337]=16'd7089;  iGMb[338]=16'd6047;  iGMb[339]=16'd9410;  iGMb[340]=16'd10492; iGMb[341]=16'd8950;  iGMb[342]=16'd2472;  iGMb[343]=16'd6255; 
        iGMb[344]=16'd728;   iGMb[345]=16'd7569;  iGMb[346]=16'd6056;  iGMb[347]=16'd10432; iGMb[348]=16'd11036; iGMb[349]=16'd2452;  iGMb[350]=16'd2811;  iGMb[351]=16'd3787; 
        iGMb[352]=16'd945;   iGMb[353]=16'd8998;  iGMb[354]=16'd1244;  iGMb[355]=16'd8815;  iGMb[356]=16'd11017; iGMb[357]=16'd11218; iGMb[358]=16'd5894;  iGMb[359]=16'd4325; 
        iGMb[360]=16'd4639;  iGMb[361]=16'd3819;  iGMb[362]=16'd9826;  iGMb[363]=16'd7056;  iGMb[364]=16'd6786;  iGMb[365]=16'd8670;  iGMb[366]=16'd5539;  iGMb[367]=16'd7707; 
        iGMb[368]=16'd1361;  iGMb[369]=16'd9812;  iGMb[370]=16'd2949;  iGMb[371]=16'd11265; iGMb[372]=16'd10301; iGMb[373]=16'd9108;  iGMb[374]=16'd478;   iGMb[375]=16'd6489; 
        iGMb[376]=16'd101;   iGMb[377]=16'd1911;  iGMb[378]=16'd9483;  iGMb[379]=16'd3608;  iGMb[380]=16'd11997; iGMb[381]=16'd10536; iGMb[382]=16'd812;   iGMb[383]=16'd8915; 
        iGMb[384]=16'd637;   iGMb[385]=16'd8159;  iGMb[386]=16'd5299;  iGMb[387]=16'd9128;  iGMb[388]=16'd3512;  iGMb[389]=16'd8290;  iGMb[390]=16'd7068;  iGMb[391]=16'd7922; 
        iGMb[392]=16'd3036;  iGMb[393]=16'd4759;  iGMb[394]=16'd2163;  iGMb[395]=16'd3937;  iGMb[396]=16'd3755;  iGMb[397]=16'd11306; iGMb[398]=16'd7739;  iGMb[399]=16'd4922; 
        iGMb[400]=16'd11932; iGMb[401]=16'd424;   iGMb[402]=16'd5538;  iGMb[403]=16'd6228;  iGMb[404]=16'd11131; iGMb[405]=16'd7778;  iGMb[406]=16'd11974; iGMb[407]=16'd1097; 
        iGMb[408]=16'd2890;  iGMb[409]=16'd10027; iGMb[410]=16'd2569;  iGMb[411]=16'd2250;  iGMb[412]=16'd2352;  iGMb[413]=16'd821;   iGMb[414]=16'd2550;  iGMb[415]=16'd11016; 
        iGMb[416]=16'd7769;  iGMb[417]=16'd136;   iGMb[418]=16'd617;   iGMb[419]=16'd3157;  iGMb[420]=16'd5889;  iGMb[421]=16'd9219;  iGMb[422]=16'd6855;  iGMb[423]=16'd120;  
        iGMb[424]=16'd4405;  iGMb[425]=16'd1825;  iGMb[426]=16'd9635;  iGMb[427]=16'd7214;  iGMb[428]=16'd10261; iGMb[429]=16'd11393; iGMb[430]=16'd2441;  iGMb[431]=16'd9562; 
        iGMb[432]=16'd11176; iGMb[433]=16'd599;   iGMb[434]=16'd2085;  iGMb[435]=16'd11465; iGMb[436]=16'd7233;  iGMb[437]=16'd6177;  iGMb[438]=16'd4801;  iGMb[439]=16'd9926; 
        iGMb[440]=16'd9010;  iGMb[441]=16'd4514;  iGMb[442]=16'd9455;  iGMb[443]=16'd11352; iGMb[444]=16'd11670; iGMb[445]=16'd6174;  iGMb[446]=16'd7950;  iGMb[447]=16'd9766; 
        iGMb[448]=16'd6896;  iGMb[449]=16'd11603; iGMb[450]=16'd3213;  iGMb[451]=16'd8473;  iGMb[452]=16'd9873;  iGMb[453]=16'd2835;  iGMb[454]=16'd10422; iGMb[455]=16'd3732; 
        iGMb[456]=16'd7961;  iGMb[457]=16'd1457;  iGMb[458]=16'd10857; iGMb[459]=16'd8069;  iGMb[460]=16'd832;   iGMb[461]=16'd1628;  iGMb[462]=16'd3410;  iGMb[463]=16'd4900; 
        iGMb[464]=16'd10855; iGMb[465]=16'd5111;  iGMb[466]=16'd9543;  iGMb[467]=16'd6325;  iGMb[468]=16'd7431;  iGMb[469]=16'd4083;  iGMb[470]=16'd3072;  iGMb[471]=16'd8847; 
        iGMb[472]=16'd9853;  iGMb[473]=16'd10122; iGMb[474]=16'd5259;  iGMb[475]=16'd11413; iGMb[476]=16'd6556;  iGMb[477]=16'd303;   iGMb[478]=16'd1465;  iGMb[479]=16'd3871; 
        iGMb[480]=16'd4873;  iGMb[481]=16'd5813;  iGMb[482]=16'd10017; iGMb[483]=16'd6898;  iGMb[484]=16'd3311;  iGMb[485]=16'd5947;  iGMb[486]=16'd8637;  iGMb[487]=16'd5852; 
        iGMb[488]=16'd3856;  iGMb[489]=16'd928;   iGMb[490]=16'd4933;  iGMb[491]=16'd8530;  iGMb[492]=16'd1871;  iGMb[493]=16'd2184;  iGMb[494]=16'd5571;  iGMb[495]=16'd5879; 
        iGMb[496]=16'd3481;  iGMb[497]=16'd11597; iGMb[498]=16'd9511;  iGMb[499]=16'd8153;  iGMb[500]=16'd35;    iGMb[501]=16'd2609;  iGMb[502]=16'd5963;  iGMb[503]=16'd8064; 
        iGMb[504]=16'd1080;  iGMb[505]=16'd12039; iGMb[506]=16'd8444;  iGMb[507]=16'd3052;  iGMb[508]=16'd3813;  iGMb[509]=16'd11065; iGMb[510]=16'd6736;  iGMb[511]=16'd8454;
    end
    mq_add add (
        .x(add_x),
        .y(add_y),
        .z(add_z)
    );
    mq_sub sub (
        .x(sub_x),
        .y(sub_y),
        .z(sub_z)
    );
    mq_montymul mul (
        .x(mul_x),
        .y(mul_y),
        .z(mul_z)
    );
    always @(*) begin
        mul_x = 16'd0; mul_y = 16'd0;
        add_x = 16'd0; add_y = 16'd0;
        sub_x = 16'd0; sub_y = 16'd0;
        case (state)
            NTT_WAIT, NTT_WRITE: begin
                mul_x = ram_rdata_b;
                mul_y = s_const;
                add_x = ram_rdata_a;
                add_y = mul_z;
                sub_x = ram_rdata_a;
                sub_y = mul_z;
            end
            PWM_WAIT, PWM_WRITE: begin
                mul_x = ram_rdata_a;
                mul_y = ram_h_rdata;
            end
            INTT_WAIT, INTT_WRITE: begin
                add_x = ram_rdata_a;
                add_y = ram_rdata_b;
                sub_x = ram_rdata_a;
                sub_y = ram_rdata_b;
                mul_x = sub_z;
                mul_y = s_const;
            end
            FIN_WAIT, FIN_WRITE: begin
                mul_x = ram_rdata_a;
                mul_y = 16'd128; 
            end
        endcase
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= IDLE;
            done            <= 1'b0;
            ram_we_a        <= 1'b0;
            ram_we_b        <= 1'b0;
            ram_wdata_a_reg <= 16'd0;
            ram_wdata_b_reg <= 16'd0;
        end else begin
            ram_we_a <= 1'b0;
            ram_we_b <= 1'b0;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        t     <= 10'd512;
                        m     <= 10'd1;
                        state <= NTT_OUTER;
                    end
                end
                NTT_OUTER: begin
                    if (m < 10'd512) begin
                        ht    <= t >> 1;
                        i     <= 10'd0;
                        j1    <= 10'd0;
                        state <= NTT_MID;
                    end else begin
                        u_cnt <= 10'd0;
                        state <= PWM_READ;
                    end
                end
                NTT_MID: begin
                    if (i < m) begin
                        s_const <= GMb[m + i];
                        j       <= j1;
                        j2      <= j1 + (t >> 1);
                        state   <= NTT_READ;
                    end else begin
                        t     <= t >> 1;
                        m     <= m << 1;
                        state <= NTT_OUTER;
                    end
                end
                NTT_READ: begin
                    if (j < j2) begin
                        ram_addr_a <= j[8:0];
                        ram_addr_b <= j + ht;
                        state      <= NTT_WAIT;
                    end else begin
                        i     <= i + 1'b1;
                        j1    <= j1 + t;
                        state <= NTT_MID;
                    end
                end
                NTT_WAIT: begin
                    state <= NTT_WRITE;
                end
                NTT_WRITE: begin
                    ram_addr_a      <= j[8:0];
                    ram_addr_b      <= j + ht;
                    ram_wdata_a_reg <= add_z;  
                    ram_wdata_b_reg <= sub_z;  
                    ram_we_a        <= 1'b1;
                    ram_we_b        <= 1'b1;
                    j               <= j + 1'b1;
                    state           <= NTT_READ;
                end
                PWM_READ: begin
                    if (u_cnt < 10'd512) begin
                        ram_addr_a <= u_cnt[8:0];
                        ram_h_addr <= u_cnt[8:0];
                        state      <= PWM_WAIT;
                    end else begin
                        t     <= 10'd1;
                        m     <= 10'd512;
                        state <= INTT_OUTER;
                    end
                end
                PWM_WAIT: begin
                    state <= PWM_WRITE;
                end
                PWM_WRITE: begin
                    ram_addr_a      <= u_cnt[8:0];
                    ram_wdata_a_reg <= mul_z;  
                    ram_we_a        <= 1'b1;
                    u_cnt           <= u_cnt + 1'b1;
                    state           <= PWM_READ;
                end
                INTT_OUTER: begin
                    if (m > 10'd1) begin
                        hm    <= m >> 1;
                        dt    <= t << 1;
                        i     <= 10'd0;
                        j1    <= 10'd0;
                        state <= INTT_MID;
                    end else begin
                        u_cnt <= 10'd0;
                        state <= FIN_READ;
                    end
                end
                INTT_MID: begin
                    if (i < hm) begin
                        s_const <= iGMb[hm + i];
                        j       <= j1;
                        j2      <= j1 + t;
                        state   <= INTT_READ;
                    end else begin
                        t     <= t << 1;
                        m     <= m >> 1;
                        state <= INTT_OUTER;
                    end
                end
                INTT_READ: begin
                    if (j < j2) begin
                        ram_addr_a <= j[8:0];
                        ram_addr_b <= j + t;
                        state      <= INTT_WAIT;
                    end else begin
                        i     <= i + 1'b1;
                        j1    <= j1 + dt;
                        state <= INTT_MID;
                    end
                end
                INTT_WAIT: begin
                    state <= INTT_WRITE;
                end
                INTT_WRITE: begin
                    ram_addr_a      <= j[8:0];
                    ram_addr_b      <= j + t;
                    ram_wdata_a_reg <= add_z;  
                    ram_wdata_b_reg <= mul_z;  
                    ram_we_a        <= 1'b1;
                    ram_we_b        <= 1'b1;
                    j               <= j + 1'b1;
                    state           <= INTT_READ;
                end
                FIN_READ: begin
                    if (u_cnt < 10'd512) begin
                        ram_addr_a <= u_cnt[8:0];
                        state      <= FIN_WAIT;
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                FIN_WAIT: begin
                    state <= FIN_WRITE;
                end
                FIN_WRITE: begin
                    ram_addr_a      <= u_cnt[8:0];
                    ram_wdata_a_reg <= mul_z; 
                    ram_we_a        <= 1'b1;
                    u_cnt           <= u_cnt + 1'b1;
                    state           <= FIN_READ;
                end
                DONE_STATE: begin
                    done  <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule