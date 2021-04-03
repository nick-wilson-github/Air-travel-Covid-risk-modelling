Unit Unit_Constants;

interface

const Million = 1000000;

      {---Disease}
      Sick_Prob      = 0.6;
      Report_Sympt   = 0.5;

      {---Flight schedule}
      Dur_Flight           = 3.0 / 24.0;  // AU: 3.0; JP: 10.6; US: 13.0 hours
      Flight_Risk_per_hour = 0.00214337;

      {---Australia}
      AU_Prevalence  = 48.0 / Double (Million); // AU: 48; JP: 163; US: 5115
      Pre_Flight_PCR = 0.623;

      {---Passengers}
      Mask_Effect    = 0.66;

      {---New Zealand}
      Re_NZ          = 2.5;
      Contact_Traced = 0.80;
      Dur_Trace      = 2.0;

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

implementation

function Get_AU_Prevalence: Double;
  begin
  Get_AU_Prevalence := AU_Prevalence;
  end;

function Get_Sick_Prob: Double;
  begin
  Get_Sick_Prob := Sick_Prob;
  end;

function Get_Report_Sympt: Double;
  begin
  Get_Report_Sympt := Report_Sympt;
  end;

function Get_Dur_Flight: Double;
  begin
  Get_Dur_Flight := Dur_Flight;
  end;

function Get_Flight_Risk_per_Hour: Double;
  begin
  Get_Flight_Risk_per_Hour := Flight_Risk_per_Hour;
  end;

function Get_Pre_Flight_PCR: Double;
  begin
  Get_Pre_Flight_PCR := Pre_Flight_PCR;
  end;

function Get_Mask_Effect: Double;
  begin
  Get_Mask_Effect := Mask_Effect;
  end;

function get_Re_NZ: Double;
  begin
  Get_Re_NZ := Re_NZ;
  end;

function Get_Dur_Trace: Double;
  begin
  Get_Dur_Trace := Dur_Trace;
  end;

function Get_Contact_Traced: Double;
  begin
  Get_Contact_Traced := Contact_Traced;
  end;

end.
