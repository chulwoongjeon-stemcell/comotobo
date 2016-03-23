unit MainWin;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, EasyDelphiQ, EasyDelphiQ.Interfaces, Some.namespace,
  Neas.PowermanApi.Notifications.DTOs.V1, System.Generics.Collections;

type
  TMainForm = class(TForm)
    Button1: TButton;
    Memo1: TMemo;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Subscribe: TButton;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure SubscribeClick(Sender: TObject);
  private
    FBus: TBus;
    FBusPM: TBus;
    FSubscription: ISubscriptionResult;
    FSubscriptionPM: ISubscriptionResult;
    FList: TThreadList<ProductionGroupDataSerieCollectionV1>;
    Procedure BusConnected(Sender: TObject);
    Procedure BusDisconnected(Sender: TObject);
    Procedure Handler( var Msg: TestDTO );
    Procedure HandlerPM( var Msg: ProductionGroupDataSerieCollectionV1 );
    Procedure WMUSER(var Msg: TMessage); Message WM_USER;
  public
  end;

var
  MainForm: TMainForm;

implementation

Uses
  EasyDelphiQ.DTO, JSON;

{$R *.dfm}

procedure TMainForm.BusConnected(Sender: TObject);
begin
  Memo1.Lines.Add( 'Connected' );
end;

procedure TMainForm.BusDisconnected(Sender: TObject);
begin
  Memo1.Lines.Add( 'Disconnected' );
end;

procedure TMainForm.Button1Click(Sender: TObject);
var
  DTO: TestDTO;
begin
  DTO := TestDTO.Create;
  Try
    DTO.ID := 42;
    DTO.Name := 'Zaphod';
    FBus.Publish( DTO );
    Memo1.Lines.Add( 'Message published' );
  Finally
    DTO.Free;
  End;
end;

procedure TMainForm.Button2Click(Sender: TObject);
var
  DTO: TestDTO;
begin
  DTO := FBus.Get<TestDTO>( 'Testbench' );
  if DTO = nil then
    Memo1.Lines.Add( 'No message' )
  else
  Try
    Memo1.Lines.Add( 'Received:' );
    Memo1.Lines.Add( '  DTO.ID:   ' + DTO.ID.ToString );
    Memo1.Lines.Add( '  DTO.Name: ' + DTO.Name );
  Finally
    DTO.Free;
  End;
end;

procedure TMainForm.Button3Click(Sender: TObject);
begin
  FSubscription := FBus.Subscribe<TestDTO>( 'Testbench', '', Handler );
end;

procedure TMainForm.Button4Click(Sender: TObject);
begin
  FSubscription.Cancel;
  FSubscription := nil;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  ReportMemoryLeaksOnShutdown := True;
  FBus := RabbitHutch.CreateBus( 'localhost', 'TestUser', 'password' );
  FBus.OnConnected := BusConnected;
  FBus.OnDisconnected := BusDisconnected;
  FSubscription := nil;

  FBusPM := RabbitHutch.CreateBus( 'host=rabbitmq_test;username=rabbit;password=rabbit' );
  FBusPM.OnConnected := BusConnected;
  FBusPM.OnDisconnected := BusDisconnected;
  FSubscriptionPM := nil;

  FList := TThreadList<ProductionGroupDataSerieCollectionV1>.Create;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FBus.Free;
  FBusPM.Free;
  FList.Free;
end;

procedure TMainForm.Handler(var Msg: TestDTO);
var
  ID: Integer;
  Name: String;
begin
  ID   := Msg.ID;
  Name := Msg.Name;
  TThread.Queue( nil,
    Procedure
    begin
      Memo1.Lines.Add( 'Received:' );
      Memo1.Lines.Add( '  DTO.ID:   ' + ID.ToString );
      Memo1.Lines.Add( '  DTO.Name: ' + Name );
    end );
end;

procedure TMainForm.HandlerPM(var Msg: ProductionGroupDataSerieCollectionV1);
begin
  FList.Add( Msg );
  Msg := nil;
  PostMessage( Handle, WM_USER, 0, 0 )
end;

procedure TMainForm.SubscribeClick(Sender: TObject);
begin
  FSubscriptionPM := FBusPM.Subscribe<ProductionGroupDataSerieCollectionV1>( 'NexusDevTest', 'PowermanTest', '', HandlerPM );
end;

procedure TMainForm.WMUSER(var Msg: TMessage);
var
  DSList: ProductionGroupDataSerieCollectionV1;
  Dataseries: ProductionGroupDataSerieV1;
  List: TList<ProductionGroupDataSerieCollectionV1>;
begin
  List := FList.LockList;
  Try
    for DSList in List do
    Begin
      Memo1.Lines.Add( 'Powerman Notification (' + DSList.Count.ToString + ' dataseries)' );
      for Dataseries in DSList do
        Memo1.Lines.Add( TJSONSerializer.Serialize(Dataseries) );
      DSList.Free;
    End;
    List.Clear;
  Finally
    FList.UnlockList;
  End;
end;

end.
