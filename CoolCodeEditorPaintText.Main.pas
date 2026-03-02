unit CoolCodeEditorPaintText.Main;

interface

procedure Register;

implementation

uses
  System.Types, System.SysUtils, Winapi.Windows, System.IOUtils, System.Generics.Collections,
  ToolsAPI, ToolsAPI.Editor, Vcl.Graphics, Vcl.Controls, Vcl.GraphUtil, System.StrUtils;

type
  TIDEWizard = class(TNotifierObject, IOTAWizard)
  private
    FEditorEventsNotifier: Integer;

    procedure PaintText(const Rect: TRect; const ColNum: SmallInt; const Text: string;
      const SyntaxCode: TOTASyntaxCode; const Hilight, BeforeEvent: Boolean;
      var AllowDefaultPainting: Boolean; const Context: INTACodeEditorPaintContext);
    procedure DrawGlowingText(ACanvas: TCanvas; X, Y: Integer; const Text: string; TextColor, GlowColor: TColor;
      GlowRadius: Single);


  protected
  function BlendColor(Color1, Color2: TColor; Alpha: Integer): TColor;
    procedure DrawGlowText(Canvas: TCanvas; const Text: string; X, Y: Integer;
      TextColor, GlowColor, BgColor: TColor; Radius: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    function GetIDString: string;
    procedure Execute;
    function GetName: string;
    function GetState: TWizardState;
  end;

  TCodeEditorNotifier = class(TNTACodeEditorNotifier)
  protected
    function AllowedEvents: TCodeEditorEvents; override;
  end;

var
  rectline: TRect;

procedure Register;
begin
  RegisterPackageWizard(TIDEWizard.Create);
end;

{ TIDEWizard }

function TIDEWizard.BlendColor(Color1, Color2: TColor; Alpha: Integer): TColor;
var
  C1, C2: LongInt;
  R, G, B: Byte;
begin
  // Convert TColor to standard RGB (handles system colors like clBtnFace)
  C1 := ColorToRGB(Color1);
  C2 := ColorToRGB(Color2);

  // Interpolate Red, Green, and Blue channels based on the Alpha (0..255)
  R := (GetRValue(C1) * Alpha + GetRValue(C2) * (255 - Alpha)) div 255;
  G := (GetGValue(C1) * Alpha + GetGValue(C2) * (255 - Alpha)) div 255;
  B := (GetBValue(C1) * Alpha + GetBValue(C2) * (255 - Alpha)) div 255;

  Result := RGB(R, G, B);
end;

constructor TIDEWizard.Create;
begin
  inherited;
  var LNotifier := TCodeEditorNotifier.Create;

  var LEditorServices: INTACodeEditorServices;
  if Supports(BorlandIDEServices, INTACodeEditorServices, LEditorServices) then
    FEditorEventsNotifier := LEditorServices.AddEditorEventsNotifier(LNotifier)
  else
    FEditorEventsNotifier := -1;
  LNotifier.OnEditorPaintText := PaintText;
//  LNotifier.OnEditorPaintLine := PaintLine;

  rectline.Height := 1;
  rectline.Width := 200;
end;

destructor TIDEWizard.Destroy;
begin
  var LEditorServices: INTACodeEditorServices;
  if Supports(BorlandIDEServices, INTACodeEditorServices, LEditorServices) and
    (FEditorEventsNotifier <> -1) and Assigned(LEditorServices) then
    LEditorServices.RemoveEditorEventsNotifier(FEditorEventsNotifier);
  inherited;
end;

procedure TIDEWizard.DrawGlowingText(ACanvas: TCanvas; X, Y: Integer; const Text: string; TextColor, GlowColor: TColor;
  GlowRadius: Single);
begin

end;

procedure TIDEWizard.DrawGlowText(Canvas: TCanvas; const Text: string; X, Y: Integer; TextColor, GlowColor,
  BgColor: TColor; Radius: Integer);
var
  RStep, dx, dy: Integer;
  CurrentColor: TColor;
  BlendRatio: Double;
begin
  Canvas.Brush.Style := bsClear;

  // Draw from the outside in so the inner layers cleanly overwrite the outer ones
  for RStep := Radius downto 1 do
  begin
    // Calculate how close we are to the center (1.0 = center, 0.0 = outer edge)
    BlendRatio := 1.0 - (RStep / (Radius + 1));

    // Square the ratio. This creates an exponential light falloff,
    // which looks much more natural than a linear fade.
    BlendRatio := BlendRatio * BlendRatio;

    // Blend the glow color with the solid background color
    CurrentColor := BlendColor(GlowColor, BgColor, Round(BlendRatio * 255));
    Canvas.Font.Color := CurrentColor;

    // Draw the text in a ring at the current radius
    for dx := -RStep to RStep do
    begin
      for dy := -RStep to RStep do
      begin
        // Only draw if the offset falls on the perimeter of the current radius
        if Round(Sqrt(dx * dx + dy * dy)) = RStep then
          Canvas.TextOut(X + dx, Y + dy, Text);
      end;
    end;
  end;

  // Finally, draw the main crisp text directly in the center
  Canvas.Font.Color := TextColor;
  Canvas.TextOut(X, Y, Text);

end;

procedure TIDEWizard.Execute;
begin
end;

function TIDEWizard.GetIDString: string;
begin
  Result := '[D9BBDF1A-F6CE-4483-8E5A-DBCB34E34030]';
end;

function TIDEWizard.GetName: string;
begin
  Result := 'CodeEditor.PaintText.Demo';
end;

function TIDEWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TIDEWizard.PaintText(const Rect: TRect; const ColNum: SmallInt;
  const Text: string; const SyntaxCode: TOTASyntaxCode; const Hilight,
  BeforeEvent: Boolean; var AllowDefaultPainting: Boolean;
  const Context: INTACodeEditorPaintContext);
var
  newText: String;
begin
    // Replace IDE drawing, reverse reserved words.
    if BeforeEvent and (SyntaxCode = atReservedWord) then
    begin
      newText := text;
      if MatchText(Text, ['Begin']) then
        newText := '{';
      if MatchText(Text, ['end']) then
        newText := '}';
  //    Context.Canvas.Brush.Color := clBlack;// TColor($64b5e8);
      Context.Canvas.FillRect(Rect);

      //Context.Canvas.Font.Color := clWhite;
//      Context.Canvas.TextOut(Rect.Left, Rect.Top, NewText);
    //  DrawGlowingText(Context.Canvas, Rect.Left, Rect.Top,  NewText,  Context.Canvas.Font.Color, clblack, 3);
      DrawGlowText(Context.Canvas, newtext, rect.Left, rect.Top, clblack{Context.Canvas.Font.Color}, clSilver, Context.Canvas.Brush.Color, 5);

      AllowDefaultPainting := False;
    end;

end;

{ TCodeEditorNotifier }

function TCodeEditorNotifier.AllowedEvents: TCodeEditorEvents;
begin
  Result := [cevPaintTextEvents, cevPaintLineEvents];
end;

end.
