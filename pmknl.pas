Program PMkNL;
{$Define MKNL}
{$I-}
{$IfDef SPEED}
{$Else}
 {$IfDef VIRTUALPASCAL}
  {$Define VP}
  {$M 65520}
 {$Else}
  {$M 65520, 0, 655360}
 {$EndIf}
{$EndIf}

Uses
{$IfDef VP}
 OS2Base, OS2Def,
{$EndIf}
{$IfDef UNIX}
 Linux,
{$EndIf}
 dos,
 mkglobt, mkmisc, mkmsgabs, mkmsgfid, mkmsgezy, mkmsgjam, mkmsghud, mkmsgsqu,
 crc, types, generalp, log, inifile2;
{$IfDef VP}
 {$IfDef VPDEMO}
  {$Dynamic VP11DEMO.LIB}
 {$EndIf}
{$EndIf}

Const
 Name : String[7]              = 'ProMkNL';
 ShortName : String[5]         = 'PMKNL';
{Current Version}
 Version : String[20]           =
{$IfDef OS2}
 '/2 '
{$Else}
 {$IfDef UNIX}
 '/Lx '
 {$Else}
  {$IfDef DPMI}
  '/16 '
  {$Else}
  '/8 '
  {$EndIf}
 {$EndIf}
{$EndIf}
 +'0.9beta9';

 cSunday = 0;
 cMonday = 1;
 cTuesday = 2;
 cWednesday = 3;
 cThursday = 4;
 cFriday = 5;
 cSaturday = 6;
 cAll = 7;

 cYes = 1;

 cNIntl = 2; {Notify: force INTL}
 cNCrash = 4; {Notify: set crash flag}
 cNKillSent = 8; {Notify: set kill/sent flag}
 cSIntl = 2; {Submit: force INTL}
 cSCrash = 4; {Submit: set crash flag}
 cSKillSent = 8; {Submit: set kill/sent flag}

 cTComposite = 0;
 cTZone = 1;
 cTRegion = 2;
 cTNet = 3;
 cTHub = 4;
 cTNode = 5;

 cEInvalidType = 1;
 cEEmptyAddr = 2;
 cEInvalidAddr = 3;
 cEEmptyPhone = 4;
 cEInvalidPhone = 5;
 cEEmptyBaud = 6;
 cEInvalidBaud = 7;
 cEEmptyFlag = 8;
 cEInvalidFlag = 9;
 cWEmptySysName = 128+1;
 cWEmptyLocation = 128+2;
 cWEmptySysOpName = 128+3;
 cWInvalidComment = 128+4;
 cWEmptyLine = 128+5;
 cWEOF = 128+6;

 cPhoneChars : Set of Char = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '-', '.', '*', '#'];

 cNumFlags = 49;
 cFlags : Array[1..cNumFlags] of String[10] = (
  'CM', 'MO', 'LO',
  'MN', 'XA', 'XB', 'XC', 'XP', 'XR', 'XW', 'XX',
  'V21', 'V22', 'V29', 'V32', 'V32B', 'V33', 'V34', 'V34+', 'H96', 'HST',
  'H14', 'H16', 'MAX', 'PEP', 'CSP', 'ZYX', 'Z19', 'VFC', 'V32T',
  'V90C', 'V90S', 'X2C', 'X2S',
  'X75', 'V110H', 'V110L', 'ISDN', 'V120H', 'V120L',
  'MNP', 'V42', 'V42B',
  '#01', '#02', '#03', '#09', '#18', '#20');


Type
 PCfg = ^TCfg;
 PData = ^TData;
 PFiles = ^TFiles;
 PBaud = ^TBaud;

 TNetAddr = {21 Byte}
  Record
  Zone, Net, Node, Point: Word;
  Domain: String[12];
  end;

 TFile =
  Record
  Typ: Byte;
  PartAddr: Word;
  UPD: String[100];
  NotifyAddr: TNetAddr;
  SkipComments: Boolean;
  End;

 TData = Array[1..100] of String[255]; {25kb}
 TFiles = Array[1..100] of TFile;
 TBaud = Array[1..30] of Word;

 TCfg =
  Record
  {Section GENERAL}
  LogFile: String128;
  LogLevel: Byte;
  MasterDir: String128;
  UpdateDir: String128;
  BadDir: String128;
  OutPath: String128;
  MailDir: String128;
  NetMail: String128;

  {Section <SectionName>}
  OutFile: String40;
  OutDiff: String40;
  Prolog: String128;
  Epilog: String128;
  CopyRight: String128;
  ProcessDay: Byte;
  NotifyErr: Byte;
  NotifyOK: Byte;
  OwnAddr: TNetAddr;
  SubmitAddr: TNetAddr;
  Submit: Byte;
  NetName: String40;
  NLType: Byte;
  CreateBatch: String;
  CallBatch: String;
  Data: PData;
  NumData: Byte;
  Files: PFiles;
  NumFiles: Byte;
  Baud: PBaud;
  NumBaud: Byte;
  End;

Var
 Ini: IniObj;
 lh: Word; {LogHandle}
 Cfg: PCfg;
 SecName: String40;
 NM: AbsMsgPtr;
 NMOpen: Boolean;
 DoProcess: Boolean;

Function Addr2Str(Addr: TNetAddr): String;
Var
  s: String;

  Begin
  With Addr do
    Begin
    s := IntToStr(Zone) + ':' + IntToStr(Net) + '/' + IntToStr(Node);
    If (Point <> 0) then s := s + '.' + IntToStr(Point);
    If (Domain <> '') then s := s + '@' + Domain;
    Addr2Str := s;
    End;
  End;

Function Addr2StrND(Addr: TNetAddr): String; {no domain}
Var
  s: String;

  Begin
  With Addr do
    Begin
    s := IntToStr(Zone) + ':' + IntToStr(Net) + '/' + IntToStr(Node);
    If (Point <> 0) then s := s + '.' + IntToStr(Point);
    Addr2StrND := s;
    End;
  End;

Procedure PartStr2Addr(s: String; var Addr: TNetAddr);
Var
{$IfDef VIRTUALPASCAL}
  i: LongInt;
{$Else}
  i: Integer;
{$EndIf}

  Begin
  If (Pos(':', s) = 0) then Val(s, Addr.Zone, i)
  Else
   Begin
   Val(Copy(s, 1, Pos(':', s)-1), Addr.Zone, i);
   Delete(s, 1, Pos(':', s));
   If (Pos('/', s) = 0) then Val(s, Addr.Net, i)
   Else
    Begin
    Val(Copy(s, 1, Pos('/', s)-1), Addr.Net, i);
    Delete(s, 1, Pos('/', s));
    If (Pos('.', s) = 0) then Val(s, Addr.Node, i)
    Else
     Begin
     Val(Copy(s, 1, Pos('.', s)-1), Addr.Node, i);
     Delete(s, 1, Pos('.', s));
     Val(s, Addr.Point, i);
     End;
    End;
   End;
  End;

Procedure Str2Addr(s: String; var Addr: TNetAddr);
Var
{$IfDef VIRTUALPASCAL}
  i: LongInt;
{$Else}
  i: Integer;
{$EndIf}

  Begin
  If (Pos(':', s) = 0) then Addr.Zone := 0
  Else
    Begin
    Val(Copy(s, 1, Pos(':', s) - 1), Addr.Zone, i);
    Delete(s, 1, Pos(':', s));
    End;
  If (Pos('/', s) = 0) then
    Begin
    End
  Else
    Begin
    Val(Copy(s, 1, Pos('/', s) - 1), Addr.Net, i);
    Delete(s, 1, Pos('/', s));
    End;
  If (Pos('.', s) = 0) or
   ((Pos('.', s) > Pos('@', s)) and (Pos('@', s) > 0)) then
    Begin
    Addr.Point := 0;
    If (Pos('@', s) = 0) then
      Begin
      Val(s, Addr.Node, i);
      Addr.Domain := '';
      End
    Else
      Begin
      Val(Copy(s, 1, Pos('@', s) - 1), Addr.Node, i);
      Delete(s, 1, Pos('@', s));
      Addr.Domain := UpStr(s);
      End;
    End
  Else
    Begin
    Val(Copy(s, 1, Pos('.', s) - 1), Addr.Node, i);
    Delete(s, 1, Pos('.', s));
    If (Pos('@', s) = 0) then
      Begin
      Val(s, Addr.Point, i);
      Addr.Domain := '';
      End
    Else
      Begin
      Val(Copy(s, 1, Pos('@', s) - 1), Addr.Point, i);
      Delete(s, 1, Pos('@', s));
      Addr.Domain := UpStr(s);
      End;
    End;
  End;

Function CompAddr(A1, A2: TNetAddr): Boolean;
Var
  C: Boolean;

  Begin
  c := ((A1.Zone = 0) or (A2.Zone = 0) or (A1.Zone = A2.Zone));
  c := c and ((A1.Net = 0) or (A2.Net = 0) or (A1.Net = A2.Net));
  c := c and (A1.Node = A2.Node);
  c := c and (A1.Point = A2.Point);
  c := c and ((A1.Domain = '') or (A2.Domain = '') or (UpStr(A1.Domain) = UpStr(A2.Domain)));
  CompAddr := c;
  End;

Procedure TNetAddr2MKAddr(A1: TNetAddr; Var MKAddr: AddrType);
  Begin
  MKAddr.Zone := A1.Zone;
  MKAddr.Net := A1.Net;
  MKAddr.Node := A1.Node;
  MKAddr.Point := A1.Point;
  MKAddr.Domain := A1.Domain;
  End;


Procedure Syntax;
 Begin
 WriteLn('Syntax: '+ShortName+' <SectionName> [/P|/T]');
 End;

Function ParseCfg: Boolean;
Var
{$IfDef VP}
 Error: LongInt;
{$Else}
 Error: Integer;
{$EndIf}
 s, s1: String;
 i: Byte;
 p: Byte;
 b: Boolean;

 Begin
 ParseCfg := True;
 Cfg^.LogFile := Ini.ReadEntry('GENERAL', 'LOG');
 If (Cfg^.LogFile = '') then
  Begin
  WriteLn('no Logfile defined!');
  ParseCfg := False;
  Exit;
  End;
 Val(Ini.ReadEntry('GENERAL', 'LOGLEVEL'), Cfg^.LogLevel, Error);
 Cfg^.MasterDir := AddDirSep(Ini.ReadEntry('GENERAL', 'MASTER'));
 Cfg^.UpdateDir := AddDirSep(Ini.ReadEntry('GENERAL', 'UPDATE'));
 Cfg^.BadDir := AddDirSep(Ini.ReadEntry('GENERAL', 'BAD'));
 Cfg^.OutPath := AddDirSep(Ini.ReadEntry('GENERAL', 'OUTPATH'));
 Cfg^.MailDir := AddDirSep(Ini.ReadEntry('GENERAL', 'MAILDIR'));
 Cfg^.Netmail := Ini.ReadEntry('GENERAL', 'NETMAIL');

 If Ini.GetSecNum(SecName) = 0 then
  Begin
  WriteLn('Section "'+SecName+'" not found or empty!');
  ParseCfg := False;
  Exit;
  End;
 Cfg^.OutFile := Ini.ReadEntry(SecName, 'OUTFILE');
 Cfg^.OutDiff := Ini.ReadEntry(SecName, 'OUTDIFF');
 Cfg^.Prolog := Ini.ReadEntry(SecName, 'PROLOG');
 Cfg^.Epilog := Ini.ReadEntry(SecName, 'EPILOG');
 Cfg^.Copyright := Ini.ReadEntry(SecName, 'COPYRIGHT');
 Cfg^.CreateBatch := Ini.ReadEntry(SecName, 'CREATEBATCH');
 Cfg^.CallBatch := Ini.ReadEntry(SecName, 'CALLBATCH');
 s := UpStr(Ini.ReadEntry(SecName, 'PROCESS'));
 If (s = 'MONDAY') then Cfg^.ProcessDay := cMonday
 Else If (s = 'TUESDAY') then Cfg^.ProcessDay := cTuesday
 Else If (s = 'WEDNESDAY') then Cfg^.ProcessDay := cWednesday
 Else If (s = 'THURSDAY') then Cfg^.ProcessDay := cThursday
 Else If (s = 'FRIDAY') then Cfg^.ProcessDay := cFriday
 Else If (s = 'SATURDAY') then Cfg^.ProcessDay := cSaturday
 Else If (s = 'SUNDAY') then Cfg^.ProcessDay := cSunday
 Else If (s = 'ALL') then Cfg^.ProcessDay := cAll
 Else
  Begin
  WriteLn('Invalid ProcessDay: '+s);
  Cfg^.ProcessDay := 0;
  End;
 s := UpStr(Ini.ReadEntry(SecName, 'NOTIFYERR'));
 Cfg^.NotifyErr := 0;
 If (Pos('YES', s) > 0) then Inc(Cfg^.NotifyErr, cYes);
 If (Pos('CRASH', s) > 0) then Inc(Cfg^.NotifyErr, cNCrash);
 If (Pos('INTL', s) > 0) then Inc(Cfg^.NotifyErr, cNIntl);
 If (Pos('KILLSENT', s) > 0) then Inc(Cfg^.NotifyErr, cNKillSent);
 s := UpStr(Ini.ReadEntry(SecName, 'NOTIFYOK'));
 Cfg^.NotifyOK := 0;
 If (Pos('YES', s) > 0) then Inc(Cfg^.NotifyOK, cYes);
 If (Pos('CRASH', s) > 0) then Inc(Cfg^.NotifyOK, cNCrash);
 If (Pos('INTL', s) > 0) then Inc(Cfg^.NotifyOK, cNIntl);
 If (Pos('KILLSENT', s) > 0) then Inc(Cfg^.NotifyOK, cNKillSent);
 Str2Addr(Ini.ReadEntry(SecName, 'OWNADDR'), Cfg^.OwnAddr);
 s := UpStr(Ini.ReadEntry(SecName, 'SUBMIT'));
 If (s <> '') then
  Begin
  Cfg^.Submit := cYes;
  If (Pos(',', s) > 0) then
   Begin
   Str2Addr(Copy(s, 1, Pos(',', s)-1), Cfg^.SubmitAddr);
   If (Pos('CRASH', s) > 0) then Inc(Cfg^.Submit, cSCrash);
   If (Pos('INTL', s) > 0) then Inc(Cfg^.Submit, cSIntl);
   If (Pos('KILLSENT', s) > 0) then Inc(Cfg^.Submit, cSKillSent);
   End
  Else Str2Addr(s, Cfg^.SubmitAddr);
  End
 Else Cfg^.Submit := 0;
 Cfg^.NetName := Ini.ReadEntry(SecName, 'NETNAME');
 s1 := UpStr(Ini.ReadEntry(SecName, 'TYPE'));
 If (s1 = 'COMPOSITE') then Cfg^.NLType := cTComposite
 Else If (s1 = 'ZONE') then Cfg^.NLType := cTZone
 Else If (s1 = 'REGION') then Cfg^.NLType := cTRegion
 Else If (s1 = 'NETWORK') then Cfg^.NLType := cTNet
 Else If (s1 = 'NET') then Cfg^.NLType := cTNet
 Else If (s1 = 'HUB') then Cfg^.NLType := cTHub
 Else If (s1 = 'NODE') then Cfg^.NLType := cTNode
 Else Cfg^.NLType := cTNode;
 s := Ini.ReadEntry(SecName, 'ALLOWBAUD');
 If (s = '') then Cfg^.NumBaud := 0
 Else
  Begin
  i := 0;
  p := Pos(',', s);
  While (p > 0) do
   Begin
   Inc(i);
   Val(Copy(s, 1, p-1), Cfg^.Baud^[i], Error);
   Delete(s, 1, p);
   p := Pos(',', s);
   End;
  Inc(i);
  Val(Copy(s, 1, p-1), Cfg^.Baud^[i], Error);
  Cfg^.NumBaud := i;
  End;
 i := 0;
 Ini.SetSection(SecName);
 With Ini do b := (UpStr(ReSecEnName) <> 'DATA') and (UpStr(ReSecEnName) <> 'FILE');
 While b do
  Begin
  If not Ini.SetNextOpt then
   Begin
   Cfg^.NumData := 0;
   Cfg^.NumFiles := 0;
   Exit;
   End;
  b := (UpStr(Ini.ReSecEnName) <> 'DATA') ;
  b := b and (UpStr(Ini.ReSecEnName) <> 'FILE')
  End;
 While UpStr(Ini.ReSecEnName) = 'DATA' do
  Begin
  Inc(i);
  Cfg^.Data^[i] := Ini.ReSecEnValue;
  s := Cfg^.Data^[i];
  If not Ini.SetNextOpt then Break;
  End;
 Cfg^.NumData:= i;
 While (UpStr(Ini.ReSecEnName) <> 'FILE') do
  Begin
  If not Ini.SetNextOpt then
   Begin
   Cfg^.NumFiles := 0;
   Exit;
   End;
  End;
 i := 0;
 While UpStr(Ini.ReSecEnName) = 'FILE' do
  Begin
  Inc(i);
  s := KillLeadingSpcs(Ini.ReSecEnValue);
  With Cfg^.Files^[i] do
   Begin
   s1 := UpStr(Copy(s, 1, Pos(',', s)-1));
   Delete(s, 1, Pos(',', s));
   s := KillLeadingSpcs(s);
   If (s1 = 'ZONE') then Typ := cTZone
   Else If (s1 = 'REGION') then Typ := cTRegion
   Else If (s1 = 'NETWORK') then Typ := cTNet
   Else If (s1 = 'NET') then Typ := cTNet
   Else If (s1 = 'HUB') then Typ := cTHub
   Else If (s1 = 'NODE') then Typ := cTNode
   Else Typ := cTNode;
   Val(Copy(s, 1, Pos(',', s)-1), PartAddr, Error);
   Delete(s, 1, Pos(',', s));
   UPD := KillLeadingSpcs(Copy(s, 1, Pos(',', s)-1));
   Delete(s, 1, Pos(',', s));
   If (Pos(',', s) > 0) then
    Begin
    Str2Addr(Copy(s, 1, Pos(',', s)-1), NotifyAddr);
    Delete(s, 1, Pos(',', s));
    If (UpStr(s) = 'SKIPCOMMENTS') then SkipComments := True;
    End
   Else
    Begin
    Str2Addr(s, NotifyAddr);
    SkipComments := False;
    End;
   End;
  If not Ini.SetNextOpt then Break;
  End;
 Cfg^.NumFiles:= i;
 End;

Procedure Init;
Var
 DT: TimeTyp;
 CfgName: String;
 s: String;

 Begin
 WriteLn(Name+Version);
 WriteLn;
 If (ParamCount < 1) then
  Begin
  Syntax;
  Halt(1);
  End;
 SecName := ParamStr(1);
 If FileExist(GetEnv(ShortName)+DirSep+LowStr(ShortName)+'.cfg') then
  CfgName := GetEnv(ShortName)+DirSep+LowStr(ShortName)+'.cfg'
 Else CfgName := LowStr(ShortName)+'.cfg';
 Ini.Init(CfgName);
 New(Cfg);
 New(Cfg^.Data);
 New(Cfg^.Files);
 New(Cfg^.Baud);
 If not ParseCfg then
  Begin
  Dispose(Cfg^.Baud);
  Dispose(Cfg^.Files);
  Dispose(Cfg^.Data);
  Dispose(Cfg);
  Ini.Done;
  Halt(2);
  End;
 Today(DT);
 s := ParamStr(2);
 DoProcess := (Upcase(s[2]) = 'P') or ((DT.DayOfWeek = Cfg^.Processday) or
   (Cfg^.ProcessDay = cAll));
 DoProcess := DoProcess and not (Upcase(s[2]) = 'T');
 lh := OpenLog(Binkley, Cfg^.LogFile, ShortName, Name+Version);
 LogSetScrLevel(lh, 5);
 LogSetLogLevel(lh, Cfg^.LogLevel);
 LogSetCurLevel(lh, 4);
 LogWriteLn(lh, 'Section '+SecName);
 LogSetCurLevel(lh, 1);
 End;

Procedure Done;
 Begin
 CloseLog(lh);
 Ini.Done;
 Dispose(Cfg^.Files);
 Dispose(Cfg^.Data);
 Dispose(Cfg);
 End;

Function OpenNM: Boolean;
 Begin
 OpenNM := True;
 Case UpCase(Cfg^.NetMail[1]) of
  'H': NM := New(HudsonMsgPtr, Init);
  'S': NM := New(SqMsgPtr, Init);
  'F': NM := New(FidoMsgPtr, Init);
  'E': NM := New(EzyMsgPtr, Init);
 Else
  Begin
  LogSetCurLevel(LH, 1);
  LogWriteLn(LH, 'Invalid type for netmail area!');
  OpenNM := False;
  Exit;
  End;
 End;
 NM^.SetMsgPath(Copy(Cfg^.NetMail, 2, Length(Cfg^.NetMail) - 1));
 If (NM^.OpenMsgBase <> 0) then
  Begin
  LogSetCurLevel(LH, 1);
  LogWriteLn(LH, 'Couldn''t open netmail area!');
  Dispose(NM, Done);
  OpenNM := False;
  Exit;
  End;
 If (UpCase(Cfg^.NetMail[1]) = 'F') then FidoMsgPtr(NM)^.SetDefaultZone(0);
 NM^.SetMailType(mmtNetMail);
 End;

Procedure CloseNM;
 Begin
 If (NM^.CloseMsgBase <> 0) then
  Begin
  LogSetCurLevel(LH, 1);
  LogWriteLn(LH, 'Couldn''t close netmail area!');
  End;
 Dispose(NM, Done);
 End;

Function GetMsgID : String;
Var
 MsgIDFile: Text;
 CurMsgID: ULong;
 Dir: String;
 s: String;
 Error: Integer;

 begin
 Dir := GetEnv('MSGID');
 If (Dir = '') then Dir := AddDirSep(Cfg^.MasterDir)
 Else Dir := AddDirSep(Dir);
 Assign(MsgIDFile, Dir + 'msgid.dat');
 {$I-} ReSet(MsgIDFile); {$I+}
 If (IOResult = 0) then
  begin
  ReadLn(MsgIDFile, s);
  While (s[Byte(s[0])] = #10) or (s[Byte(s[0])] = #13) do Dec(s[0]);
  Val(s, CurMsgID, Error);
  If (Error <> 0) or (CurMsgID = 0) then CurMsgID := 1;
  Close(MsgIDFile);
  end
 Else CurMsgID := 1; {Reset MsgID if no MSGID.DAT is found}
 GetMsgID := WordToHex(word(CurMsgID SHR 16)) + WordToHex(word(CurMsgID));
 Inc(CurMsgID);
 {$I-} ReWrite(MsgIDFile); {$I+}
 If (IOResult = 0) then
  Begin
  Write(MsgIDFile, CurMsgID, #13#10);
  Close(MsgIDFile);
  End;
 end;

Procedure SetDT(MB: AbsMsgPtr);
Var
 DT: TimeTyp;
 s: String;

 Begin
 With MB^ do
  Begin
  Today(DT);
  If (DT.Year > 100) then DT.Year := DT.Year mod 100;
  Now(DT);
  If (DT.Month > 9) then s := IntToStr(DT.Month) + '-'
  Else s := '0' + IntToStr(DT.Month) + '-';
  If (DT.Day > 9) then s := s + IntToStr(DT.Day) + '-'
  Else s := s + '0' + IntToStr(DT.Day) + '-';
  If (DT.Year > 9) then s := s + IntToStr(DT.Year)
  Else s := s + '0' + IntToStr(DT.Year);
  SetDate(s);
  If (DT.Hour > 9) then s := IntToStr(DT.Hour) + ':'
  Else s := '0' + IntToStr(DT.Hour) + ':';
  If (DT.Min > 9) then s := s + IntToStr(DT.Min)
  Else s := s + '0' + IntToStr(DT.Min);
  SetTime(s);
  End;
 End;

Procedure SendOK(e: TFile);
Var
 MKAddr: AddrType;
 s: String;

 Begin
 LogSetCurLevel(lh, 3);
 LogWriteLn(lh, 'sending OK-receipt to '+Addr2Str(e.NotifyAddr));
 If not OpenNM then Exit;
 With NM^ do
  Begin
  StartNewMsg;
  s := Name + Version;
  SetFrom(s);
  TNetAddr2MKAddr(Cfg^.OwnAddr, MKAddr);
  SetOrig(MKAddr);
  SetTo('Coordinator');
  TNetAddr2MKAddr(e.NotifyAddr, MKAddr);
  SetDest(MKAddr);
  SetSubj(e.UPD+' received: No errors');
  SetLocal(True);
  SetCrash((Cfg^.NotifyOK and cNCrash) > 0);
  SetKillSent((Cfg^.NotifyOK and cNKillSent) > 0);
  SetDT(NM);
  If (Cfg^.OwnAddr.Point <> 0) then DoStringLn(#1'FMPT '+IntToStr(Cfg^.OwnAddr.Point));
  If (e.NotifyAddr.Point <> 0) then DoStringLn(#1'TOPT '+IntToStr(e.NotifyAddr.Point));
  If (e.NotifyAddr.Zone <> Cfg^.OwnAddr.Zone) or ((Cfg^.NotifyOK and cNIntl) > 0) then
   DoStringLn(#1'INTL '+Addr2StrND(e.NotifyAddr)+' '+Addr2StrND(Cfg^.OwnAddr));
  DoStringLn(#1'MSGID: '+Addr2Str(Cfg^.OwnAddr)+' '+GetMsgID);
  DoStringLn(#1'PID: '+Name+Version);
  DoStringLn('Your nodelist update, '+e.UPD+', has been received and processsed without errors.');
  DoStringLn('--- '+Name+Version);
  If (WriteMsg <> 0) then
   Begin
   LogSetCurLevel(LH, 1);
   LogWriteLn(LH, 'Couldn''t write to netmail area!');
   End;
  End;
 CloseNM;
 End;

Procedure Mark(e: TFile; lNum: Word; Line: String; Error: Byte; ErrStr: String);
Var
 MKAddr: AddrType;
 s: String;

 Begin
 If (Cfg^.NotifyErr and cYes) = 0 then Exit;
 If not NMOpen then
  Begin
  LogSetCurLevel(lh, 3);
  LogWriteLn(lh, 'sending ERROR-receipt to '+Addr2Str(e.NotifyAddr));
  If not OpenNM then Exit;
  With NM^ do
   Begin
   StartNewMsg;
   s := Name + Version;
   SetFrom(s);
   TNetAddr2MKAddr(Cfg^.OwnAddr, MKAddr);
   SetOrig(MKAddr);
   SetTo('Coordinator');
   TNetAddr2MKAddr(e.NotifyAddr, MKAddr);
   SetDest(MKAddr);
   SetSubj(e.UPD+' received: contained ERRORS!');
   SetLocal(True);
   SetCrash((Cfg^.NotifyErr and cNCrash) > 0);
   SetKillSent((Cfg^.NotifyErr and cNKillSent) > 0);
   SetDT(NM);
   If (Cfg^.OwnAddr.Point <> 0) then DoStringLn(#1'FMPT '+IntToStr(Cfg^.OwnAddr.Point));
   If (e.NotifyAddr.Point <> 0) then DoStringLn(#1'TOPT '+IntToStr(e.NotifyAddr.Point));
   If (e.NotifyAddr.Zone <> Cfg^.OwnAddr.Zone) or ((Cfg^.NotifyOK and cNIntl) > 0) then
    DoStringLn(#1'INTL '+Addr2StrND(e.NotifyAddr)+' '+Addr2StrND(Cfg^.OwnAddr));
   DoStringLn(#1'MSGID: '+Addr2Str(Cfg^.OwnAddr)+' '+GetMsgID);
   DoStringLn(#1'PID: '+Name+Version);
   DoStringLn('Your nodelist update, '+e.UPD+', contained the following mistakes: ');
   DoStringLn('');
   End;
  NMOpen := True;
  End;
 With NM^ do
  Begin
  DoStringLn('Line '+IntToStr(lNum)+' > '+Line);
  Case Error of
   cEInvalidType : DoStringLn('Error: Invalid type: "'+ErrStr+'"');
   cEEmptyAddr : DoStringLn('Error: Empty address');
   cEInvalidAddr : DoStringLn('Error: Invalid address: "'+ErrStr+'"');
   cEEmptyPhone : DoStringLn('Error: Empty phonenumber');
   cEInvalidPhone : DoStringLn('Error: Invalid phonenumber: "'+ErrStr+'"');
   cEEmptyBaud : DoStringLn('Error: Empty baudrate');
   cEInvalidBaud : DoStringLn('Error: Invalid baudrate: "'+ErrStr+'"');
   cEEmptyFlag : DoStringLn('Error: Empty flag');
   cEInvalidFlag : DoStringLn('Error: Invalid flag: "'+ErrStr+'"');
   cWEmptySysName : DoStringLn('Warning: Empty systemname');
   cWEmptyLocation : DoStringLn('Warning: Empty location');
   cWEmptySysOpName : DoStringLn('Warning: Empty SysOp-name');
   cWInvalidComment : DoStringLn('Warning: Invalid comment-type: "'+ErrStr+'"');
   cWEmptyLine: DoStringLn('Warning: empty line');
   cWEOF: DoStringLn('Warning: EOF-character (#26/#$19) found');
   Else
    Begin
    DoStringLn('Error: unknown error #'+IntToStr(Error)+': "'+ErrStr+'". Please contact author!');
    End;
   End;
  DoStringLn('');
  End;
 End;

Function CheckUPD(fn: FileStr; e: TFile): Boolean;
Var
 line: String;
 f: Text;
 lNum: Word;
 Bad: Boolean;
 Warnings: Boolean;

 Procedure ParseLine(Line: String);
 Var
  p: Byte;
  s, l: String;
  IsPvt: Boolean;
  x, y: Word;
{$IfDef VP}
  Error: LongInt;
{$Else}
  Error: Integer;
{$EndIf}
  UFlags: Boolean;

  Begin
  If (Line = '') then
   Begin
   Mark(e, lNum, Line, cWEmptyLine, '');
   Warnings := True;
   Exit;
   End;
  If (Line[1] = #26) then
   Begin
   Mark(e, lNum, Line, cWEOF, '');
   Warnings := True;
   Exit;
   End;
  If (Line[1] = ';') then
   Begin
   If (Length(Line) = 1) then Exit;
   If not (UpCase(Line[2]) in ['S', 'U', 'F', 'A', 'E', ' ', #26]) then
    Begin
    Mark(e, lNum, Line, cWInvalidComment, Line[2]);
    Warnings := True;
    End;
   Exit;
   End;
  IsPvt := False;
  UFlags := False;
  l := Line;
  {type}
  p := Pos(',', l);
  If (p > 1) then
   Begin
   s := UpStr(Copy(l, 1, p-1));
   If not ((s = 'ZONE') or (s = 'REGION') or (s = 'HOST') or (s = 'HUB') or
    (s = 'PVT') or (s = 'HOLD') or (s = 'DOWN')) then
     Begin
     Bad := True;
     Mark(e, lNum, Line, cEInvalidType, s);
     End
   Else if (s = 'PVT') then IsPvt := True;
   End;
  Delete(l, 1, p);
  {address}
  p := Pos(',', l);
  s := Copy(l, 1, p-1);
  If (s = '') then
   Begin
   Bad := True;
   Mark(e, lNum, Line, cEEmptyAddr, '');
   End
  Else
   Begin
   Val(s, x, Error);
   If (Error <> 0) then
    Begin
    Bad := True;
    Mark(e, lNum, Line, cEInvalidAddr, s);
    End;
   End;
  Delete(l, 1, p);
  {SystemName}
  p := Pos(',', l);
  s := Copy(l, 1, p-1);
  If (s = '') then
   Begin
   Mark(e, lNum, Line, cWEmptySysName, '');
   Warnings := True;
   End;
  Delete(l, 1, p);
  {Location}
  p := Pos(',', l);
  s := Copy(l, 1, p-1);
  If (s = '') then
   Begin
   Mark(e, lNum, Line, cWEmptyLocation, '');
   Warnings := True;
   End;
  Delete(l, 1, p);
  {SysOpName}
  p := Pos(',', l);
  s := Copy(l, 1, p-1);
  If (s = '') then
   Begin
   Mark(e, lNum, Line, cWEmptySysOpName, '');
   Warnings := True;
   End;
  Delete(l, 1, p);
  {Phone}
  p := Pos(',', l);
  s := UpStr(Copy(l, 1, p-1));
  If not IsPvt then
   Begin
   If (s = '') then
    Begin
    Bad := True;
    Mark(e, lNum, Line, cEEmptyPhone, '');
    End
   Else
    Begin
    Error := 0;
    For x := 1 to Length(s) do If not (s[x] in cPhoneChars) then Error := 1;
    If (Error > 0) then
     Begin
     Bad := True;
     Mark(e, lNum, Line, cEInvalidPhone, s);
     End;
    Delete(l, 1, p);
    End;
   End;
  {baud}
  p := Pos(',', l);
  s := Copy(l, 1, p-1);
  If (s = '') then
   Begin
   Bad := True;
   Mark(e, lNum, Line, cEEmptyBaud, '');
   End
  Else
   Begin
   Val(s, x, Error);
   If (Error <> 0) then
    Begin
    Bad := True;
    Mark(e, lNum, Line, cEInvalidBaud, s);
    End;
   If (Cfg^.NumBaud = 0) then
    Begin
    If not ((x = 300) or (x = 1200) or (x = 2400) or (x = 9600)) then
     Begin
     Bad := True;
     Mark(e, lNum, Line, cEInvalidBaud, s);
     End;
    End
   Else
    Begin
    Error := 1;
    For y := 1 to Cfg^.NumBaud do If (x = Cfg^.Baud^[y]) then Error := 0;
    If (Error = 1) then
     Begin
     Bad := True;
     Mark(e, lNum, Line, cEInvalidBaud, s);
     End;
    End;
   End;
  Delete(l, 1, p);
  {flags}
  p := Pos(',', l);
  While (p > 0) and not UFlags do
   Begin
   s := UpStr(Copy(l, 1, p-1));
   Error := 1;
   If (s = '') then
    Begin
    Bad := True;
    Mark(e, lNum, Line, cEEmptyFlag, '');
    Error := 0;
    End
   Else If (s = 'U') then
    Begin
    Error := 0;
    UFlags := True
    End
   Else If (s[1] = 'G') then Error := 0
   Else If (s[1] = 'U') then Error := 0
   Else
    Begin
    For x := 1 to cNumFlags do If (s = cFlags[x]) then Error := 0;
    End;
   If (Error = 1) then
    Begin
    Bad := True;
    Mark(e, lNum, Line, cEInvalidFlag, s);
    End;
   Delete(l, 1, p);
   p := Pos(',', l);
   End;
  End;

 Begin
 CheckUPD := True;
 Bad := False;
 Warnings := False;
 lNum := 0;
 NMOpen := False;
 Assign(f, fn);
 {$I-} ReSet(f); {$I+}
 If (IOResult <> 0) then
  Begin
  LogSetCurLevel(lh, 1);
  LogWriteLn(lh, 'Could not open "'+fn+'"!');
  CheckUPD := False;
  Exit;
  End;

 While not EOF(f) do
  Begin
  Inc(lNum);
  ReadLn(f, Line);
  While ((Line[Byte(Line[0])] = #13) or (Line[Byte(Line[0])] = #10)) do
   Line[0] := Char(Byte(Line[0])-1);
  ParseLine(Line);
  End;

 {$I-} Close(f); {$I+}
 If (IOResult <> 0) then
  Begin
  LogSetCurLevel(lh, 1);
  LogWriteLn(lh, 'Could not close "'+fn+'"!');
  End;

 CheckUPD := not Bad;
 If NMOpen then
  Begin
  NM^.DoStringLn('');
  NM^.DoStringLn('--- '+Name+Version);
  If (NM^.WriteMsg <> 0) then
   Begin
   LogSetCurLevel(LH, 1);
   LogWriteLn(LH, 'Couldn''t write to netmail area!');
   End;
  CloseNM;
  End;
 NMOpen := False;
 lNum := IOResult;
 If (((not Warnings) and (not Bad)) and ((Cfg^.NotifyOK and cYes) > 0)) then SendOK(e);
 lNum := IOResult;
 End;

Procedure SubmitUPD(fn: FileStr);
Var
 MKAddr: AddrType;
 s: String;

 Begin
 LogSetCurLevel(lh, 3);
 LogWriteLn(lh, 'submitting '+fn+' to '+Addr2Str(Cfg^.SubmitAddr));
 If not OpenNM then Exit;
 With NM^ do
  Begin
  StartNewMsg;
  s := Name + Version;
  SetFrom(s);
  TNetAddr2MKAddr(Cfg^.OwnAddr, MKAddr);
  SetOrig(MKAddr);
  SetTo('Coordinator');
  TNetAddr2MKAddr(Cfg^.SubmitAddr, MKAddr);
  SetDest(MKAddr);
  SetSubj(fn);
  SetLocal(True);
  SetFAttach(True);
  SetCrash((Cfg^.Submit and cSCrash) > 0);
  SetKillSent((Cfg^.Submit and cSKillSent) > 0);
  SetDT(NM);
  If (Cfg^.OwnAddr.Point <> 0) then DoStringLn(#1'FMPT '+IntToStr(Cfg^.OwnAddr.Point));
  If (Cfg^.SubmitAddr.Point <> 0) then DoStringLn(#1'TOPT '+IntToStr(Cfg^.SubmitAddr.Point));
  If (Cfg^.SubmitAddr.Zone <> Cfg^.OwnAddr.Zone) or ((Cfg^.Submit and cSIntl) > 0) then
   DoStringLn(#1'INTL '+Addr2StrND(Cfg^.SubmitAddr)+' '+Addr2StrND(Cfg^.OwnAddr));
  DoStringLn(#1'MSGID: '+Addr2Str(Cfg^.OwnAddr)+' '+GetMsgID);
  DoStringLn(#1'PID: '+Name+Version);
  If (WriteMsg <> 0) then
   Begin
   LogSetCurLevel(LH, 1);
   LogWriteLn(LH, 'Couldn''t write to netmail area!');
   End;
  End;
 CloseNM;
 End;

Procedure LookForUPDs;
Var
 i: LongInt;

 Begin
 If (Cfg^.NumFiles = 0) then Exit;
 For i := 1 to Cfg^.NumFiles do
  Begin
  If FileExist(Cfg^.MailDir + Cfg^.Files^[i].UPD) then
   Begin
   LogSetCurLevel(lh, 3);
   LogWriteLn(lh, 'Found "'+Cfg^.MailDir + Cfg^.Files^[i].UPD+'" ('+Addr2Str(Cfg^.Files^[i].NotifyAddr)+')');
   If CheckUPD(Cfg^.MailDir + Cfg^.Files^[i].UPD, Cfg^.Files^[i]) then
    Begin
    If FileExist(Cfg^.UpdateDir + Cfg^.Files^[i].UPD) then DelFile(Cfg^.UpdateDir + Cfg^.Files^[i].UPD);
    If not MoveFile(Cfg^.MailDir + Cfg^.Files^[i].UPD, Cfg^.UpdateDir + Cfg^.Files^[i].UPD) then
     Begin
     LogSetCurLevel(lh, 1);
     LogWriteLn(lh, 'Could not move "'+Cfg^.MailDir + Cfg^.Files^[i].UPD+'"');
     LogWriteLn(lh, 'to "'+Cfg^.UpdateDir + Cfg^.Files^[i].UPD+'"!');
     End;
    End
   Else
    Begin
    If FileExist(Cfg^.BadDir + Cfg^.Files^[i].UPD) then DelFile(Cfg^.BadDir + Cfg^.Files^[i].UPD);
    If not MoveFile(Cfg^.MailDir + Cfg^.Files^[i].UPD, Cfg^.BadDir + Cfg^.Files^[i].UPD) then
     Begin
     LogSetCurLevel(lh, 1);
     LogWriteLn(lh, 'Could not move "'+Cfg^.MailDir + Cfg^.Files^[i].UPD+'"');
     LogWriteLn(lh, 'to "'+Cfg^.BadDir + Cfg^.Files^[i].UPD+'"!');
     End
    End;
   End;
  End;
 End;

Procedure DoBatch(UPDName: String; DayNum: Word);
Var
 f: Text;
 d: DirStr;
 n: NameStr;
 s, s1: String;
 PrevDayNum: Word;
 DT: TimeTyp;
 DTUnx: ULong;

 Begin
 Assign(f, Cfg^.CreateBatch);
 {$I-} ReWrite(f); {$I+}
 If (IOResult <> 0) then
  Begin
  LogSetCurLevel(lh, 1);
  LogWriteLn(lh, 'Could not open "'+Cfg^.CreateBatch+'"!');
  Exit;
  End;

 FSplit(UPDName, d, n, s);
 Today(DT); Now(DT);
 DTUnx := DTToUnixDate(DT);
 DTUnx := DTUnx - 7*24*60*60;
 UnixToDT(DTUnx, DT);
 PrevDayNum := DayOfYear(DT);
 s1 := d+n + ' no-diff ' + IntToStr(DayNum div 100) + ' ' + IntToStr((DayNum div 10) mod 10) +
  ' ' + IntToStr(DayNum mod 10) + ' ' + IntToStr(PrevDayNum div 100) + ' ' +
  IntToStr((PrevDayNum div 10) mod 10) + ' ' + IntToStr(PrevDayNum mod 10);
 WriteLn(f, Cfg^.CallBatch + ' ' + s1);

 {$I-} Close(f); {$I+}
 If (IOResult <> 0) then
  Begin
  LogSetCurLevel(lh, 1);
  LogWriteLn(lh, 'Could not close "'+Cfg^.CreateBatch+'"!');
  End;
{$IfDef UNIX}
 ChMod(Cfg^.CreateBatch, 493); {Octal 755}
{$EndIf}
 LogSetCurLevel(lh, 3);
 LogWriteLn(lh, 'created batch '+Cfg^.CreateBatch);
 End;

Procedure CreateUPD;
Var
 f, f1: Text;
 i: Byte;
 DT: TimeTyp;
 s: String;
 fn: FileStr;
 fn2: PathStr;
 CRC: Word;

 Procedure CopyFile(fname: String; IsCpy: Boolean; SkipComments: Boolean);
 Var
  ftc: Text;
  p: Byte;

  Begin
  Assign(ftc, fname);
  {$I-} ReSet(ftc); {$I+}
  If (IOResult <> 0) then
   Begin
   LogSetCurLevel(lh, 1);
   LogWriteLn(lh, 'Could not open "'+fname+'"!');
   End
  Else
   Begin
   While not EOF(ftc) do
    Begin
    ReadLn(ftc, s);
    While ((s[Byte(s[0])] = #13) or (s[Byte(s[0])] = #10)) do
     s[0] := Char(Byte(s[0])-1);
    If (s = '') then Continue;
    If (s[1] = #26) then Continue; {skip EOF}
    If ((s[1] = ';') and SkipComments) then Continue;
    If IsCpy then If (Pos('####', s) > 0) then
     Begin
     p := Pos('####', s);
     Delete(s, p, 4);
     Insert(IntToStr(DT.Year), s, p);
     End;
    Write(f, s, #13#10);
    End;
   {$I-} Close(ftc); {$I+}
   If (IOResult <> 0) then
    Begin
    LogSetCurLevel(lh, 1);
    LogWriteLn(lh, 'Could not close "'+fname+'"!');
    End
   End;
  End;

 Begin
 Today(DT); Now(DT);
 If (DT.Year < 38) then DT.Year := DT.Year + 2000
 Else If (DT.Year < 1900) then DT.Year := DT.Year + 1900;
 Write('Day #'+IntToStr(DayOfYear(DT)), #13#10);
 FSplit(Cfg^.OutFile, s, fn, s);
 Assign(f, Cfg^.OutPath+fn+'.tmp');
 {$I-} ReWrite(f); {$I+}
 If (IOResult <> 0) then
  Begin
  LogSetCurLevel(lh, 1);
  LogWriteLn(lh, 'Could not open "'+Cfg^.OutPath+fn+'.tmp"!');
  Exit;
  End;

 If (Cfg^.NLType = cTcomposite) then
  Begin
  {copy copyright}
  If (Cfg^.CopyRight <> '') then CopyFile(Cfg^.CopyRight, True, False);
  {copy prolog}
  If (Cfg^.ProLog <> '') then CopyFile(Cfg^.ProLog, False, False);
  End;

 {copy DATA-lines from config}
 If (Cfg^.NumData > 0) then For i := 1 to Cfg^.NumData do
  Begin
  Write(f, Cfg^.Data^[i], #13#10);
  End;
 Write(f, ';A', #13#10);

 {copy FILES}
 If (Cfg^.NumFiles > 0) then For i := 1 to Cfg^.NumFiles do
  Begin
  if (pos(dirSep, cfg^.files^[i].upd) > 0) then
   Begin
   If FileExist(Cfg^.Files^[i].UPD) then
    Begin
    CopyFile(Cfg^.Files^[i].UPD, False, Cfg^.Files^[i].SkipComments);
    Write(f, ';A', #13#10);
    End;
   End
  Else
   Begin
   If FileExist(Cfg^.UpdateDir+Cfg^.Files^[i].UPD) then
    Begin
    CopyFile(Cfg^.UpdateDir+Cfg^.Files^[i].UPD, False, Cfg^.Files^[i].SkipComments);
    Write(f, ';A', #13#10);
    End;
   End;
  End;

 If (Cfg^.NLType = cTcomposite) then
  Begin
  {copy epilog}
  If (Cfg^.EpiLog <> '') then CopyFile(Cfg^.Epilog, False, False);
  End;

 {$I-} Close(f); {$I+}
 If (IOResult <> 0) then
  Begin
  LogSetCurLevel(lh, 1);
  LogWriteLn(lh, 'Could not close "'+Cfg^.OutPath+fn+'.tmp"!');
  End;

 {calc CRC}
 CRC := GetCRC16(Cfg^.OutPath+fn+'.tmp');

 {copy temp file to final file}
 If (Pos('.', Cfg^.OutFile) > 0) then fn2 := Cfg^.OutPath + Cfg^.OutFile
 Else fn2 := Cfg^.OutPath + Cfg^.OutFile + '.' + IntToStr03(DayOfYear(DT));
 Assign(f1, fn2);
 {$I-} ReWrite(f1); {$I+}
 If (IOResult <> 0) then
  Begin
  LogSetCurLevel(lh, 1);
  LogWriteLn(lh, 'Could not open "'+fn2+'"!');
  Exit;
  End;
 {$I-} ReSet(f); {$I+}
 If (IOResult <> 0) then
  Begin
  LogSetCurLevel(lh, 1);
  LogWriteLn(lh, 'Could not open "'+Cfg^.OutPath+fn+'.tmp"!');
  Exit;
  End;

 {add copyright}
 If (Cfg^.NLType = cTcomposite) then
  Begin
  Write(f1, ';A '+Cfg^.NetName + ' Nodelist for '+WkDaysEng[DT.DayOfWeek]+', '+
             MonthsEng[DT.Month]+' '+IntToStr(DT.Day)+', '+IntToStr(DT.Year)+
             ' -- Day number '+IntToStr(DayOfYear(DT))+' : ' + IntToStr(CRC),
             #13#10);
  End;

  While not EOF(f) do
   Begin
   ReadLn(f, s);
   While ((s[Byte(s[0])] = #13) or (s[Byte(s[0])] = #10)) do
    s[0] := Char(Byte(s[0])-1);
   If (s = '') then Continue;
   If (s[1] = #26) then Continue;
   Write(f1, s, #13#10);
   End;

 {$I-} Close(f1); {$I+}
 If (IOResult <> 0) then
  Begin
  LogSetCurLevel(lh, 1);
  LogWriteLn(lh, 'Could not close "'+fn2+'"!');
  End;
 {$I-} Close(f); {$I+}
 If (IOResult <> 0) then
  Begin
  LogSetCurLevel(lh, 1);
  LogWriteLn(lh, 'Could not close "'+Cfg^.OutPath+fn+'.tmp"!');
  End;
 {$I-} Erase(f); {$I+}
 If (IOResult <> 0) then
  Begin
  LogSetCurLevel(lh, 1);
  LogWriteLn(lh, 'Could not delete "'+Cfg^.OutPath+fn+'.tmp"!');
  End;
 LogSetCurLevel(lh, 4);
 LogWriteLn(lh, 'created UPD '+fn2);
 If (Cfg^.Submit and cYes) > 0 then SubmitUPD(fn2);
 If (Cfg^.CreateBatch <> '') and (Cfg^.CallBatch <> '') then DoBatch(fn2, DayOfYear(DT));
 End;

Procedure Run;
 Begin
 LookForUPDs;
 If DoProcess then CreateUPD;
 End;


Begin
Init;
Run;
Done;
End.

