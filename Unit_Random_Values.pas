Unit Unit_Random_Values;

interface

const Million        = 1000000;
      max            = 999;
      AU_Prevalence  = 48.0 / Double (Million); // AU: 48; JP: 163; US: 5115


type X = array [0 .. max] of Double;

var {---Disease}
    Sick_Prob:    X;
    Report_Sympt: X;

    {---Flight schedule}
    Flight_Risk_per_Hour: X;
    Dur_Flight: X;

    {---Australia}
    Pre_Flight_PCR: X;

    {---Passengers}
    Mask_Effect: X;

    {---New Zealand}
    Re_NZ:          X;
    Contact_Traced: X;
    Dur_Trace:      X;

    r: Word;

function Get_AU_Prevalence:        Double;
function Get_Pre_Flight_PCR:       Double;
function Get_Flight_Risk_per_Hour: Double;
function Get_Dur_Flight:           Double;
function Get_Re_NZ:                Double;
function Get_Mask_Effect:          Double;
function Get_Sick_Prob:            Double;
function Get_Report_Sympt:         Double;
function Get_Contact_Traced:       Double;
function Get_Dur_Trace:            Double;

{------------------------------------------------------------------------------------------------}
implementation
{------------------------------------------------------------------------------------------------}

function Get_AU_Prevalence: Double;
  begin
  Get_AU_Prevalence := AU_Prevalence;
  end;

function Get_Sick_Prob: Double;
  begin
  r := round (random * max); 
  Get_Sick_Prob := Sick_Prob [r];
  end;

function Get_Report_Sympt: Double;
  begin
  r := round (random * max); 
  Get_Report_Sympt := Report_Sympt [r];
  end;

function Get_Dur_Flight: Double;
  begin
  r := round (random * max); 
  Get_Dur_Flight := Dur_Flight [r];
  end;

function Get_Flight_Risk_per_Hour: Double;
  begin
  r := round (random * max); 
  Get_Flight_Risk_per_Hour := Flight_Risk_per_Hour [r];
  end;

function Get_Pre_Flight_PCR: Double;
  begin
  r := round (random * max); 
  Get_Pre_Flight_PCR := Pre_Flight_PCR [r];
  end;

function Get_Mask_Effect: Double;
  begin
  r := round (random * max); 
  Get_Mask_Effect := Mask_Effect [r];
  end;

function get_Re_NZ: Double;
  begin
  r := round (random * max); 
  Get_Re_NZ := Re_NZ [r];
  end;

function Get_Dur_Trace: Double;
  begin
  r := round (random * max); 
  Get_Dur_Trace := Dur_Trace [r];
  end;

function Get_Contact_Traced: Double;
  begin
  r := round (random * max); 
  Get_Contact_Traced := Contact_Traced [r];
  end;

Procedure Read_Values;
  var i: Word;
      z: Double;
      f: text;
  begin
  assign (f, 'Random_Values.txt');
  reset  (f);
  for i := 0 to max do
    begin
    read   (f, z);
    Pre_Flight_PCR       [i] := z / 100.0;
    read   (f, z);
    Dur_Flight           [i] := z / 24.0;
    read   (f, z);
    Flight_Risk_per_Hour [i] := z;
    read   (f, z);
    Re_NZ                [i] := z;
    read   (f, z);
    Mask_Effect          [i] := z / 100.0;
    read   (f, z);
    Sick_Prob            [i] := z / 100.0;
    read   (f, z);
    Report_Sympt         [i] := z / 100.0;
    read   (f, z);
    Contact_Traced       [i] := z / 100.0;
    readln (f, z);
    Dur_Trace            [i] := z;
    end;
  close (f);
  end;

Procedure Check_Values;
   begin
   write (Pre_Flight_PCR      [3]:6:3);
   write (Dur_Flight          [3]:6:3);
   write (Flight_Risk_per_Hour[3]:6:3); 
   write (Re_NZ               [3]:6:3);
   write (Mask_Effect         [3]:6:3);
   write (Sick_Prob           [3]:6:3);
   write (Report_Sympt        [3]:6:3);
   write (Contact_Traced      [3]:6:3);
   write (Dur_Trace           [3]:6:3);
   writeln;
   halt;
   end;
 

{------------------------------------------------------------------------------------------------}
begin
Read_Values;
// Check_Values;
end.
