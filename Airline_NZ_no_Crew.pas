Program Airline_NZ_no_Crew;

uses SysUtils, Unit_Constants; // Unit_Random_Values;

const Screen_Output = true;

      Milliarde     = 1000 * Million;
      Output_Step   = 10   * Million;
      MaxFlight     = 100 * Million; //Milliarde;
      Dur_Long      = 1000.0;

      {---Natural history}
      Stages         = 16;
      Total_Stages   = 4 * Stages;
      D_E            = 5.0;
      D_P            = 1.0; 
      D_I            = 5.0;
      D_L            = 5.0;
      c_P            = 1.0;
      c_I            = 1.0;
      c_L            = 0.5;
      epsilon        = Stages / D_E;
      phi            = Stages / D_P;
      gamma          = Stages / D_I;
      delta          = Stages / D_L;
      D_Sum          = D_E +    D_P +     D_I +     D_L;
      D_Inf_Sum      =      c_P*D_P + c_I*D_I + c_L*D_L;

      {---Disease}
      Report_Stage   = 2 * Stages + round (Stages / D_I); {---1 day after onset}

      {---Passengers}
      N_Pass         = 300;

type Strategy_Type = (Exit_PCR, 
                      Quarantine, 
                      Entry_PCR, 
                      PCR_2, 
                      PCR_3, 
                      Masks_NZ, 
                      Self_Report,
                      Tracing_PCR,
                      Tracing_Self);
     
     Stages_Array_W = array [1..Total_Stages] of Word;
     Stages_Array_D = array [1..Total_Stages] of Double;
     P_Beta = ^Stages_Array_D;

var Sus_Pass, Inf_Pass: Word;
    InitProb: array [1 .. N_Pass] of Double;
    Inf_NZ_by_Pass: Word;
    Foreign_Cum_Fract, Trans_Rate:  Stages_Array_D; 
    Pass_Rate:                      Stages_Array_D;          
    Beta_Flight:                    Stages_Array_D; 
    Beta_NZ_NoMasks, Beta_NZ_Masks: Stages_Array_D;
    Pass:                           Stages_Array_W;
    Cum_Rates_Pass: array [0..Total_Stages]     of Double;
    Sens:           array [1..Total_Stages + 1] of Double;
    Inf_Time:       array [1..1000]             of Double;
    Beta: P_Beta;
    Sum_Beta_Pass: Double;
    Time_until_PCR_2, Time_until_PCR_3, Extended_End_Time, Dur_Quarantine: Double;
    X: array [Exit_PCR .. Tracing_Self] of Boolean; 
    f: text;

    {---Parameters which may be randomly sampled}
    Value_Re_NZ, Value_Sick_Prob, Value_Report_Sympt, Value_Dur_Flight: Double;
    Value_Pre_Flight_PCR, Value_Mask_Effect: Double; 
    Value_Contact_Traced, Value_Dur_Trace, Value_Re_Flight: Double;
    Value_AU_Prevalence: Double;

    AU_Prevalence_Factor, Dur_Flight_Factor: Double;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Create_Output_File (File_Name: String);

  begin
  {---Open output files}
  assign  (f, File_Name + '.txt');
  rewrite (f);
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Close_Output_file; 

  begin
  close (f);
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Set_Rates;

  var k: Word;

  begin
  for k := 1 to Stages do 
    begin
    Trans_Rate [k + 0 * Stages] := epsilon;
    Trans_Rate [k + 1 * Stages] := phi;
    Trans_Rate [k + 2 * Stages] := gamma;
    Trans_Rate [k + 3 * Stages] := delta;
    
    Beta_Flight [k + 0 * Stages] := 0.0;
    Beta_Flight [k + 1 * Stages] := c_P * Value_Re_Flight / D_Inf_Sum;
    Beta_Flight [k + 2 * Stages] := c_I * Value_Re_Flight / D_Inf_Sum;
    Beta_Flight [k + 3 * Stages] := c_L * Value_Re_Flight / D_Inf_Sum;

    Beta_NZ_NoMasks [k + 0 * Stages] := 0.0;
    Beta_NZ_NoMasks [k + 1 * Stages] := c_P * Value_Re_NZ / D_Inf_Sum;
    Beta_NZ_NoMasks [k + 2 * Stages] := c_I * Value_Re_NZ / D_Inf_Sum;
    Beta_NZ_NoMasks [k + 3 * Stages] := c_L * Value_Re_NZ / D_Inf_Sum;
    
    Beta_NZ_Masks [k + 0 * Stages] := (1.0 - Value_Mask_Effect) * Beta_NZ_NoMasks [k + 0 * Stages];
    Beta_NZ_Masks [k + 1 * Stages] := (1.0 - Value_Mask_Effect) * Beta_NZ_NoMasks [k + 1 * Stages];
    Beta_NZ_Masks [k + 2 * Stages] := (1.0 - Value_Mask_Effect) * Beta_NZ_NoMasks [k + 2 * Stages];
    Beta_NZ_Masks [k + 3 * Stages] := (1.0 - Value_Mask_Effect) * Beta_NZ_NoMasks [k + 3 * Stages];
    end;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Set_Parameter_Values_AU;

  begin
  Value_AU_Prevalence  := Get_AU_Prevalence * AU_Prevalence_Factor;
  Value_Pre_Flight_PCR := Get_Pre_Flight_PCR;
  Value_Re_Flight      := Get_Flight_Risk_per_Hour * 24.0 * D_Inf_Sum;
  Set_Rates;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Set_Parameter_Values_NZ;

  begin
  Value_Dur_Flight     := Get_Dur_Flight * Dur_Flight_Factor;
  Value_Mask_Effect    := Get_Mask_Effect;
  Value_Re_NZ          := Get_Re_NZ;
  Value_Sick_Prob      := Get_Sick_Prob;
  Value_Report_Sympt   := Get_Report_Sympt;
  Value_Dur_Trace      := Get_Dur_Trace;
  Value_Contact_Traced := Get_Contact_Traced;
  Set_Rates;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Set_InitProb;

  var i: Word;
      ln_Bin: array [0 .. N_Pass] of Double;

  begin
  ln_Bin [0] := 0.0;
  for i := 1 to N_Pass do ln_Bin [i] := ln_Bin [i-1] + ln (N_Pass - i + 1) - ln (i);

  for i := 0 to N_Pass do
    InitProb [i] := exp (ln_Bin [i] + i * ln (Value_AU_Prevalence) + (N_Pass - i) * ln (1.0 - Value_Au_Prevalence)); 

  for i := 1 to N_Pass do
    InitProb [i] := InitProb [i-1] + InitProb [i];
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Set_Default_Parameter_Values;

  begin
  Time_until_PCR_2  :=   3.0 - 1.0;
  Time_until_PCR_3  :=  12.0 - 1.0;
  Extended_End_Time := Time_until_PCR_3;
  Dur_Quarantine    := 14.0;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Set_Strategy_No_Interventions;

  begin
  Set_Default_Parameter_Values;

  X [Exit_PCR]        := false;
  X [Entry_PCR]       := false;

  X [Quarantine]      := false;

  X [PCR_2]           := false;
  X [PCR_3]           := false;

  X [Self_Report]     := false;
  X [Masks_NZ]        := false;

  X [Tracing_Self]    := false;
  X [Tracing_PCR]     := false;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Set_Strategy_Ex;

  begin
  Set_Strategy_No_Interventions;
  X [Exit_PCR] := true;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Set_Strategy_ExQu;

  begin
  Set_Strategy_Ex;
  X [Quarantine] := true;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Set_Strategy_ExEn;

  begin
  Set_Strategy_Ex;
  X [Entry_PCR] := true;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Set_Strategy_ExEnP2;

  begin
  Set_Strategy_ExEn;
  X [PCR_2] := true;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Set_Strategy_ExEnP2Tr;

  begin
  Set_Strategy_ExEnP2;
  X [Tracing_PCR] := true;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Set_Strategy_ExEnP2TrMa;

  begin
  Set_Strategy_ExEnP2Tr;
  X [Masks_NZ] := true;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Set_Strategy_ExEnP2TrSe;

  begin
  Set_Strategy_ExEnP2Tr;
  X [Self_Report]  := true;
  X [Tracing_Self] := true;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Set_Strategy_ExEnP2TrMaSe;

  begin
  Set_Strategy_ExEnP2TrSe;
  X [Masks_NZ] := true;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Set_Strategy_ExEnP2P3;

  begin
  Set_Strategy_ExEnP2;
  X [PCR_3] := true;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Set_Strategy_ExEnP2P3Tr;

  begin
  Set_Strategy_ExEnP2P3;
  X [Tracing_PCR] := true;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Set_Strategy_ExEnP2P3TrMa;

  begin
  Set_Strategy_ExEnP2P3;
  X [Masks_NZ] := true;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Set_Strategy_ExEnP2P3TrSe;

  begin
  Set_Strategy_ExEnP2P3Tr;
  X [Self_Report]  := true;
  X [Tracing_Self] := true;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Set_Strategy_ExEnP2P3TrMaSe;

  begin
  Set_Strategy_ExEnP2P3TrSe;
  X [Masks_NZ] := true;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Set_Sensitivity;

  begin
  Sens [ 1] :=  0.0000068637466;
  Sens [ 2] :=  0.00007312;
  Sens [ 3] :=  0.0004200059;
  Sens [ 4] :=  0.0016557915;
  Sens [ 5] :=  0.0050192794;
  Sens [ 6] :=  0.0124462231;
  Sens [ 7] :=  0.0263307968;
  Sens [ 8] :=  0.0489590775;
  Sens [ 9] :=  0.0819713153;
  Sens [10] :=  0.1258988012;
  Sens [11] :=  0.1798377025;
  Sens [12] :=  0.2415711471;
  Sens [13] :=  0.3082520076;
  Sens [14] :=  0.376863391;
  Sens [15] :=  0.4441640323;
  Sens [16] :=  0.5075053114;
  Sens [17] :=  0.5439643638;
  Sens [18] :=  0.555818357;
  Sens [19] :=  0.5673633149;
  Sens [20] :=  0.5786439393;
  Sens [21] :=  0.5896691639;
  Sens [22] :=  0.600459407;
  Sens [23] :=  0.6109097312;
  Sens [24] :=  0.6210083422;
  Sens [25] :=  0.6309541102;
  Sens [26] :=  0.6405614632;
  Sens [27] :=  0.6497182203;
  Sens [28] :=  0.6586096037;
  Sens [29] :=  0.667131147;
  Sens [30] :=  0.6753596289;
  Sens [31] :=  0.6833754344;
  Sens [32] :=  0.6909798547;
  Sens [33] :=  0.7095025694;
  Sens [34] :=  0.7357930048;
  Sens [35] :=  0.7559324972;
  Sens [36] :=  0.7707415529;
  Sens [37] :=  0.7811086487;
  Sens [38] :=  0.7879870519;
  Sens [39] :=  0.7918273534;
  Sens [40] :=  0.7931503511;
  Sens [41] :=  0.7923944153;
  Sens [42] :=  0.7898845209;
  Sens [43] :=  0.7857850542;
  Sens [44] :=  0.7803531048;
  Sens [45] :=  0.7738429303;
  Sens [46] :=  0.7663261414;
  Sens [47] :=  0.7579158466;
  Sens [48] :=  0.7486873689;
  Sens [49] :=  0.7386871293;
  Sens [50] :=  0.7280852478;
  Sens [51] :=  0.7169522565;
  Sens [52] :=  0.7053361651;
  Sens [53] :=  0.6932518325;
  Sens [54] :=  0.6808214297;
  Sens [55] :=  0.6681722411;
  Sens [56] :=  0.6553317897;
  Sens [57] :=  0.6422308946;
  Sens [58] :=  0.6288664292;
  Sens [59] :=  0.6154427316;
  Sens [60] :=  0.6018618814;
  Sens [61] :=  0.5880635859;
  Sens [62] :=  0.5741050319;
  Sens [63] :=  0.5599451595;
  Sens [64] :=  0.5455316266;

  {---After infection}
  Sens [65] :=  0.34;
  end;

{----------------------------------------------------------------------------}
{---ACHTUNG: Hier war ein Fehler im Programm; korrigiert im März 2021}
{----------------------------------------------------------------------------}
Procedure Set_Cumulative_Infection_Fractions_in_Australia;

  var k: Word;
      Sum: Double;

  begin
  Sum := 0.0;
  for k := 1 to Stages do 
    begin
    Sum                                := Sum + D_E / (D_Sum * Stages);
    Foreign_Cum_Fract [k + 0 * Stages] := Sum;
    end;
  for k := 1 to Stages do 
    begin
    Sum                                := Sum + D_P / (D_Sum * Stages);
    Foreign_Cum_Fract [k + 1 * Stages] := Sum;
    end;
  for k := 1 to Stages do 
    begin
    Sum                                := Sum + D_I / (D_Sum * Stages);
    Foreign_Cum_Fract [k + 2 * Stages] := Sum;
    end;
  for k := 1 to Stages do 
    begin
    Sum                                := Sum + D_L / (D_Sum * Stages);
    Foreign_Cum_Fract [k + 3 * Stages] := Sum;
    end;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Recalculate_Beta;

  var k: Word;

  begin
  if (Inf_Pass > 0) then
    begin
    Sum_Beta_Pass := 0.0;
    for k := 1 to Total_Stages do 
      if (Pass [k] > 0) then 
        Sum_Beta_Pass := Sum_Beta_Pass + Pass [k] * Beta^ [k];
    end;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Cumulate_Rates_Pass (InfProb: Double);

  var k: Word;

  begin
  Cum_Rates_Pass [0] := InfProb;
  for k := 1 to Total_Stages do Cum_Rates_Pass [k] := Cum_Rates_Pass [k-1] + Pass_Rate [k];
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Event_Transition_Pass (k: Word);

  begin
  if (k = 0)  
    then begin
         {---New infection}
         inc (Inf_Pass);
         dec (Sus_Pass);
         end
    else begin
         {---Decrease former stage}
         Pass      [k] := Pass      [k] - 1;
         Pass_Rate [k] := Pass_Rate [k] - Trans_Rate [k];
         Sum_Beta_Pass := Sum_Beta_Pass - Beta^      [k];
         end;

  if (k = Total_Stages) 
    then begin
         {---Loss of infection}
         dec (Inf_Pass);
         end
    else begin
         {---Increase new stage}
         Pass      [k+1] := Pass      [k+1] + 1;
         Pass_Rate [k+1] := Pass_Rate [k+1] + Trans_Rate [k+1];
         Sum_Beta_Pass   := Sum_Beta_Pass   + Beta^      [k+1];
         end;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Event_Replace_Sick_Pass (k: Word);

  begin
  dec (Inf_Pass);
  inc (Sus_Pass);
  Pass      [k] := Pass      [k] - 1;
  Pass_Rate [k] := Pass_Rate [k] - Trans_Rate [k];
  Sum_Beta_Pass := Sum_Beta_Pass - Beta^      [k];
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Initialize_Uninfected_Passengers;

  var k: Word;

  begin
  Sus_Pass := N_Pass;
  Inf_Pass := 0;
  for k := 1 to Total_Stages do
    begin
    Pass      [k] := 0;
    Pass_Rate [k] := 0.0;
    end;
  Sum_Beta_Pass := 0.0;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Simulate_Infection_Of_Passengers_in_Australia;

  var i: Integer;
      j, k: Word;
      rand: Double;

  begin
  i := -1;
  repeat rand := random until (rand < 1.0);
  repeat inc (i) until (InitProb [i] > rand);
  for j := 1 to i do
    begin
    k := 0;
    repeat rand := random until (rand < 1.0);
    repeat inc (k) until (Foreign_Cum_Fract [k] > rand);
    inc (Pass [k]); 
    Pass_Rate [k] := Pass_Rate [k] + Trans_Rate [k];
    Sum_Beta_Pass := Sum_Beta_Pass + Beta^ [k];
    inc (Inf_Pass);
    dec (Sus_Pass);
    end;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Perform_Exit_PCR;

  var i, k: Word;

  begin
  if (Inf_Pass > 0) then
    for k := Stages + 1 to Total_Stages do
      for i := 1 to Pass [k] do
        if (random < Value_Pre_Flight_PCR) then
          Event_Replace_Sick_Pass (k);
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Perform_Entry_PCR;

  var i, k: Word;

  begin
  if (Inf_Pass > 0) then
    for k := Stages + 1 to Total_Stages do
      for i := 1 to Pass [k] do
        if (random < Sens [k]) then 
          Event_Replace_Sick_Pass (k);
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Simulate_Flight_Infections;

   var time, rand, InfProb, rate: double;
       k: Integer;

   begin
   time := 0.0;
   while ((time < Value_Dur_Flight) and (Inf_Pass > 0)) do
     begin
     InfProb := Sum_Beta_Pass / N_Pass;
     Cumulate_Rates_Pass (InfProb * Sus_Pass);
     rate := Cum_Rates_Pass [Total_Stages];
     repeat rand := random until (rand > 0.0);

     time := time - ln (rand) / rate;
     if (time < Value_Dur_Flight) then
       begin
       repeat rand := random * rate until (rand < rate);
       k := -1; 
       repeat inc (k) until (rand < Cum_Rates_Pass [k]);
       Event_Transition_Pass (k);
       end;
     end;
   end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Simulate_Quarantine_Pass;

   var time, rand, rate: double;
       k: Word;

   begin
   time := 0.0;
   while ((Inf_Pass > 0) and (time < Dur_Quarantine)) do
     begin
     Cumulate_Rates_Pass (0.0);
     rate := Cum_Rates_Pass [Total_Stages];
     repeat rand := random until (rand > 0.0);
     time := time - ln (rand) / rate;
     if (time < Dur_Quarantine) then
       begin
       k := 0; 
       repeat rand := random * rate until (rand < rate);
       repeat inc (k) until (rand < Cum_Rates_Pass [k]);
       Event_Transition_Pass (k);
       end;
     end;
   end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Simulate_NZ_Infections_by_NZ (Dur: Double);

  var rand, rate, time: double;
      k: Word;
      Infected: Boolean;

  begin
  k        := 1;
  Time     := 0.0;
  Infected := true;
  while ((Infected) and (time < Dur)) do
    begin
    rate := Trans_Rate [k] + Beta_NZ_NoMasks [k];
    repeat rand := random until (rand > 0.0);
    time := time - ln (rand) / rate;
    if (time < Dur) then
      begin
      rand := random * rate;
      if (rand < Beta_NZ_NoMasks [k]) 
        then Inc (Inf_NZ_by_Pass)
        else begin
             Inc (k);
             if (k > Total_Stages) then Infected := false;
             end;
      end;
    end;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Simulate_Surveilled_NZ_Infections_by_One_Passenger (Start_k: Word; Dur: Double; Followed_by_PCR: Boolean);

  var rand, rate, time, Stop_Time: double;
      k, Victims: Word;
      Roaming, Detected_by_Self, Detected_by_PCR: Boolean;

  begin
  {---Initializations}
  k                := Start_k;
  Victims          := 0;
  Time             := 0.0;
  Roaming          := true;
  Detected_by_Self := false;
  Detected_by_PCR  := false;

  {---Simulate NZ infections and stage transitions}
  while ((Roaming) and (time < Dur)) do
    begin
    rate := Trans_Rate [k] + Beta^ [k];

    {---When will the next event occur?}
    repeat rand := random until (rand > 0.0);
    time := time - ln (rand) / rate;
    if (time < Dur) then
      begin
      {---Which kind of event will occur?}
      rand := random * rate;
      if (rand < Trans_Rate [k])
        then begin
             {---Stage transition} 
             if ((X [Self_Report]) and (k = Report_Stage) and (random < Value_Sick_Prob * Value_Report_Sympt))
               then begin
                    {---Traveller reports to have symptoms}
                    if (random < Sens [k])
                      then begin
                           {---Index case detection (1): Self-reported symptoms are confirmed by PCR}
                           Event_Replace_Sick_Pass (k);
                           Detected_by_Self := true;
                           Roaming          := false;
                           Stop_Time        := time + Value_Dur_Trace;
                           end
                      else begin
                           {---Stage transition despite self-reporting, because of negative PCR result}
                           Event_Transition_Pass (k);
                           inc (k);
                           end;
                    end
               else begin
                    {---Stage transition without self-reporting}
                    Event_Transition_Pass (k);

                    {---Loss of infection of roaming crew member before end of maximum roaming time}
                    if (k = Total_Stages)
                      then begin
                           Roaming := false;

                           {---The passenger has already been removed by "Event_Transition_Pass"}
                           {---from the group of infected individuals;}
                           {---the infection may or may not be deteced at the following PCR}
                           if ((Followed_by_PCR) and (random < Sens [Total_Stages + 1])) then
                             begin
                             Detected_by_PCR := true;
                             Stop_Time       := Dur + Value_Dur_Trace;
                             end;
                           end
                      else inc (k);
                    end;
             end
        else begin
             {---NZ infection (queued)}
             inc (Victims);
             Inf_Time [Victims] := time;
             end;
      end;
    end;

  {---Perform PCR of still active cases}
  {---Caveat: for self-detected cases and for cases who cleared their infection, PCR has already been performed}
  if ((Followed_by_PCR) and (Roaming) and (random < Sens [k])) then 
    begin    
    Event_Replace_Sick_Pass (k);
    Stop_Time := Dur + Value_Dur_Trace;
    end; 

  {---Let the victims (= secondary cases) create tertiary cases}
  if (Victims > 0) then
    begin 
    if (Detected_by_Self) then
      for k := 1 to Victims do
        if ((X [Tracing_Self]) and (random < Value_Contact_Traced)) 
          then Simulate_NZ_Infections_by_NZ (Stop_Time - Inf_Time [k])
          else inc (Inf_NZ_by_Pass);
    if (Detected_by_PCR) then
      for k := 1 to Victims do
        if ((X [Tracing_PCR]) and (random < Value_Contact_Traced)) 
          then Simulate_NZ_Infections_by_NZ (Stop_Time - Inf_Time [k])
          else inc (Inf_NZ_by_Pass);
    if ((not (Detected_by_Self)) and (not (Detected_by_PCR))) then
      Inf_NZ_by_Pass := Inf_NZ_by_Pass + Victims; 
    end;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Simulate_Unsurveilled_NZ_Infections_by_One_Passenger (Start_k: Word; Dur: Double);

  var rand, rate, time: double;
      k: Word;
      Roaming: Boolean;

  begin
  k       := Start_k;
  Time    := 0.0;
  Roaming := true;
  while ((Roaming) and (time < Dur)) do
    begin
    rate := Trans_Rate [k] + Beta^ [k];
    repeat rand := random until (rand > 0.0);
    time := time - ln (rand) / rate;
    if (time < Dur) then
      begin
      rand := random * rate;
      if (rand < Trans_Rate [k])
        then begin 
             Event_Transition_Pass (k);
             if (k = Total_Stages)
               then Roaming := false
               else inc (k);
             end
        else inc (Inf_NZ_by_Pass);
      end;
    end;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Simulate_NZ_Infections_by_Passengers (Phase: String);

  var i, k: Word;
      Last_End_Time: Double;
      Copy_Pass: Stages_Array_W;
 
  begin
  if (Phase = 'Early')
    then begin
         {---(A) Infection of individuals within the surveillance period}
         {---Initialize current time}
         Last_End_Time := 0.0;

         {---(1) First PCR, possibly with preceeding transmissions}
         if ((X [PCR_2]) and (Inf_Pass > 0)) then 
           begin
           {---Make a copy of the number of passengers by state}
           for k := 1 to Total_Stages do
             Copy_Pass [k] := Pass [k];

           {---Allow each passenger to infect somebody and finally peform PCR}
           for k := 1 to Total_Stages do
             for i := 1 to Copy_Pass [k] do 
               Simulate_Surveilled_NZ_Infections_by_One_Passenger (k, Time_Until_PCR_2, X [PCR_2]);

           {---Memorize current time}
           Last_End_Time := Time_until_PCR_2;
           end;

         {---(2) Second PCR with preceeding transmissions}
         if ((X [PCR_3]) and (Inf_Pass > 0)) then 
           begin
           {---Make a copy of the number of passengers by state}
           for k := 1 to Total_Stages do
             Copy_Pass [k] := Pass [k];

           {---Allow each passenger to infect somebody and finally peform PCR}
           for k := 1 to Total_Stages do
             for i := 1 to Copy_Pass [k] do 
               Simulate_Surveilled_NZ_Infections_by_One_Passenger (k, Time_Until_PCR_3 - Last_End_Time, X [PCR_3]);

           {---Memorize current time}
           Last_End_Time := Time_until_PCR_3;
           end;

         {---(3) Are surveillance measures extended beyond the second PCR time?}
         if ((Extended_End_Time > Last_End_Time) and (Inf_Pass > 0)) then 
           begin
           {---Make a copy of the number of passengers by state}
           for k := 1 to Total_Stages do
             Copy_Pass [k] := Pass [k];

           {---Allow each passenger to infect somebody}
           for k := 1 to Total_Stages do
             for i := 1 to Copy_Pass [k] do 
               Simulate_Surveilled_NZ_Infections_by_One_Passenger (k, Extended_End_Time - Last_End_Time, false);
           end;
         end
    else begin
         {---(B) Infection of individuals after the end of the quarantine or surveillance period}
         if (Inf_Pass > 0) then
           begin
           {---Make a copy of the number of passengers by state}
           for k := 1 to Total_Stages do
             Copy_Pass [k] := Pass [k];

           {---Allow each passenger to infect somebody}
           for k := 1 to Total_Stages do
             for i := 1 to Copy_Pass [k] do 
               Simulate_Unsurveilled_NZ_Infections_by_One_Passenger (k, Dur_Long);
           end;
         end;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Run_Simulation_Series (File_Name, Output_Text: String);

  var Flight: LongInt;
    
  begin
  {---Perform simulations}
  for Flight := 1 to MaxFlight do
    begin
    {---Output of flight number}
    if ((Screen_Output) and (Flight mod Output_Step = 0)) then 
      writeln (File_Name, ' ', Output_Text, ' ', Flight);

    {---Initialize output counter}
    Inf_NZ_by_Pass := 0;

    {---Set beta to flight mode before picking up the infection in Australia}
    Beta := @Beta_Flight;
    Recalculate_Beta;

    {---Set back infection status of passengers}
    Initialize_Uninfected_Passengers;

    {---Infect passengers in Australia}
    Set_Parameter_Values_AU;
    Simulate_Infection_of_Passengers_in_Australia;

    {---Check for symptoms upon exit of Austrailia}
    if (X [Exit_PCR]) then
      Perform_Exit_PCR;

    if (Inf_Pass > 0) then
      begin
      Set_Parameter_Values_NZ;

      {---Transmit infection on board}
      Simulate_Flight_Infections;

      {---Set beta to NZ mode}
      if (X [Masks_NZ]) 
        then Beta := @Beta_NZ_Masks
        else Beta := @Beta_NZ_NoMasks;
      Recalculate_Beta;

      {---Check for symptoms upon entry in NZ}
      if (X [Entry_PCR]) then Perform_Entry_PCR;

      {---Quarantine or surveilled stay of passengers}
      if (X [Quarantine]) 
        then Simulate_Quarantine_Pass
        else Simulate_NZ_Infections_by_Passengers ('Early');

      {---Set beta to NZ mode without interventions}
      Beta := @Beta_NZ_NoMasks;
      Recalculate_Beta;

      {---Passengers infect people in NZ}
      Simulate_NZ_Infections_by_Passengers ('Late');

      if (Inf_NZ_by_Pass > 0) then
        writeln (f, Output_Text, ' ', Inf_NZ_by_Pass, ' ', Value_Re_NZ:3:1);
      end;
    end;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Baseline_Simulations;

  const File_Name = 'Baseline';  

  var Strategy_Name: String;

  begin
  {---Create output files}
  Create_Output_File (File_Name);

  {---No interventions}
  Strategy_Name := '00_None';
  Set_Strategy_No_Interventions;
  Run_Simulation_Series (File_Name, Strategy_Name);

  {---Exit screening}
  Strategy_Name := '01_Ex';
  Set_Strategy_Ex;
  Run_Simulation_Series (File_Name, Strategy_Name);

  {---Exit screening + entry PCR}
  Strategy_Name := '02_ExEn';
  Set_Strategy_ExEn;
  Run_Simulation_Series (File_Name, Strategy_Name);

  {---Exit screening + entry PCR + PCR1}
  Strategy_Name := '03_ExEnP2';
  Set_Strategy_ExEnP2;
  Run_Simulation_Series (File_Name, Strategy_Name);

  {---Exit screening + entry PCR + PCR1 + Tracing}
  Strategy_Name := '04_ExEnP2Tr';
  Set_Strategy_ExEnP2Tr;
  Run_Simulation_Series (File_Name, Strategy_Name);

  {---Exit screening + entry PCR + PCR1 + Tracing + Self-reporting}
  Strategy_Name := '05_ExEnP2TrSe';
  Set_Strategy_ExEnP2TrSe;
  Run_Simulation_Series (File_Name, Strategy_Name);

  {---Exit screening + entry PCR + PCR1 + Tracing + Masks in NZ}
  Strategy_Name := '06_ExEnP2TrMa';
  Set_Strategy_ExEnP2TrMa;
  Run_Simulation_Series (File_Name, Strategy_Name);

  {---Exit screening + entry PCR + PCR1 + Tracing + Masks + Self reporting}
  Strategy_Name := '07_ExEnP2TrMaSe';
  Set_Strategy_ExEnP2TrMaSe;
  Run_Simulation_Series (File_Name, Strategy_Name);

  {---Exit screening + entry PCR + PCR1 + PCR2}
  Strategy_Name := '08_ExEnP2P3';
  Set_Strategy_ExEnP2P3;
  Run_Simulation_Series (File_Name, Strategy_Name);

  {---Exit screening + entry PCR + PCR1 + PCR2 + Tracing}
  Strategy_Name := '09_ExEnP2P3Tr';
  Set_Strategy_ExEnP2P3Tr;
  Run_Simulation_Series (File_Name, Strategy_Name);

  {---Exit screening + entry PCR + PCR1 + PCR2 + Tracing + Self-reporting}
  Strategy_Name := '10_ExEnP2P3TrSe';
  Set_Strategy_ExEnP2P3TrSe;
  Run_Simulation_Series (File_Name, Strategy_Name);

  {---Exit screening + entry PCR + PCR1 + PCR2 + Tracing + Masks in NZ}
  Strategy_Name := '11_ExEnP2P3TrMa';
  Set_Strategy_ExEnP2P3TrMa;
  Run_Simulation_Series (File_Name, Strategy_Name);

  {---Exit screening + entry PCR + PCR1 + PCR2 + Tracing + Masks in NZ + Self reporting}
  Strategy_Name := '12_ExEnP2P3TrMaSe';
  Set_Strategy_ExEnP2P3TrMaSe;
  Run_Simulation_Series (File_Name, Strategy_Name);

  {---Exit screening + Quarantine of 7 days}
  Strategy_Name := '13_ExQu_7';
  Set_Strategy_ExQu;
  Dur_Quarantine := 7.0;
  Run_Simulation_Series (File_Name, Strategy_Name);

  {---Exit screening + Quarantine of 14 days}
  Strategy_Name := '14_ExQu_14';
  Set_Strategy_ExQu;
  Dur_Quarantine := 14.0;
  Run_Simulation_Series (File_Name, Strategy_Name);

  {---Exit screening + Quarantine of 21 days}
  Strategy_Name := '15_ExQu_21';
  Set_Strategy_ExQu;
  Dur_Quarantine := 21.0;
  Run_Simulation_Series (File_Name, Strategy_Name);

  {---Close output files}
  Close_Output_File;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Extra_Simulations (File_Name: String);

  var Strategy_Name: String;

  begin
  {---Create output files}
  Create_Output_File (File_Name);

  {---No interventions}
  Strategy_Name := '00_None';
  Set_Strategy_No_Interventions;
  Run_Simulation_Series (File_Name, Strategy_Name);

  {---Exit screening + entry PCR + PCR1}
  Strategy_Name := '07_ExEnP2TrMaSe';
  Set_Strategy_ExEnP2TrMaSe;
  Run_Simulation_Series (File_Name, Strategy_Name);

  {---Exit screening + entry PCR + PCR1 + PCR2}
  Strategy_Name := '12_ExEnP2P3TrMaSe';
  Set_Strategy_ExEnP2P3TrMaSe;
  Run_Simulation_Series (File_Name, Strategy_Name);

  {---Exit screening + Quarantine of 14 days}
  Strategy_Name := '14_ExQu_14';
  Set_Strategy_ExQu;
  Dur_Quarantine := 14.0;
  Run_Simulation_Series (File_Name, Strategy_Name);

  {---Close output files}
  Close_Output_File;
  end;

{----------------------------------------------------------------------------}
{----------------------------------------------------------------------------}
Procedure Country_Simulations;

  begin
  AU_Prevalence_Factor := 1.0;
  Set_Parameter_Values_AU;
  Set_InitProb;
  Extra_Simulations ('Baseline');

{  AU_Prevalence_Factor := 0.1;
  Set_Parameter_Values_AU;
  Set_InitProb;
  Extra_Simulations ('AU_div_10');
}
  AU_Prevalence_Factor := 10.0;
  Set_Parameter_Values_AU;
  Set_InitProb;
  Extra_Simulations ('AU_times_10');

{  AU_Prevalence_Factor := 163.0 / 48.0;
  Dur_Flight_Factor    := 10.6 / 3.0;
  Set_Parameter_Values_AU;
  Set_InitProb;
  Extra_Simulations ('Japan');

  AU_Prevalence_Factor := 5115.0 / 48.0;
  Dur_Flight_Factor    := 13.0 / 3.0;
  Set_Parameter_Values_AU;
  Set_InitProb;
  Extra_Simulations ('US'); 

  {---Setting back original values}
  {---to avoid side-effects if simulations are run later}
  AU_Prevalence_Factor := 1.0;
  Dur_Flight_Factor    := 1.0;
  Set_Parameter_Values_AU;
  Set_InitProb;
}  end;

{----------------------------------------------------------------------------}
{---                      MAIN PROGRAM:                                   ---}
{----------------------------------------------------------------------------}

begin
AU_Prevalence_Factor := 1.0;
Dur_Flight_Factor    := 1.0;

Set_Parameter_Values_AU;
Set_Parameter_Values_NZ;

{---Initializations}
Set_InitProb;
Set_Cumulative_Infection_Fractions_in_Australia;
Set_Sensitivity;
Set_Rates;

{---Perform simulations}
//Baseline_Simulations;
// Extra_Simulations ('PSA');
Country_Simulations;
end.
