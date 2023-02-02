uses System.IO, System.Net;

{$reference 'System.Windows.Forms.dll'}
{$reference 'System.Drawing.dll'} 
uses System, System.Windows.Forms;

{$reference System.Web.Extensions.dll}
uses System.Collections.Generic, System.Web.Script.Serialization;

var API_URL := 'https://zincycorn.zation.ru';
var jss := new JavaScriptSerializer();

type
  Json = Dictionary<string, object>;
  JsonArr = array of object;

function request(requestMethod: string; method: string; p: string): Json;
begin
  var myRequest : HttpWebRequest := HttpWebRequest(WebRequest.Create(API_URL+'/'+method+'?'+p));
  myRequest.Method := requestMethod;
  
  var myResponse : WebResponse := myRequest.GetResponse();
  var sr : StreamReader := new StreamReader(myResponse.GetResponseStream(), System.Text.Encoding.UTF8);
  var data := sr.ReadToEnd();
  sr.Close();
  myResponse.Close();
  
  Result := jss.DeserializeObject(data) as Json;
end;

function loadImage(url: string): System.Drawing.Image;
begin
  var myRequest : HttpWebRequest := HttpWebRequest(WebRequest.Create(url));
  myRequest.Method := 'GET';
  
  var myResponse : WebResponse := myRequest.GetResponse();
  var sr : System.IO.Stream := myResponse.GetResponseStream();
  var data := System.Drawing.Image.FromStream(sr);
  sr.Close();
  myResponse.Close();
  
  Result := data;
end;

var form := new Form;
var index := 0;
var request_started := false;
var list := new List<object>();
var text := new System.Windows.Forms.Label();
var picture := new PictureBox();

procedure draw();
begin  
  var item := list[index] as Json;
  var attachments := item['attachments'] as JsonArr;
  
  text.Text := item['text'] as string;
  
  if attachments.Length > 0 then
  begin
    var photos := new List<Json>();
    
    foreach attachment_obj: object in attachments do
    begin
      var attachment := attachment_obj as Json;

      if attachment['type'].Equals('photo') then photos.Add(attachment);
    end;
    
    foreach photo: Json in photos do
      text.Text += NewLine+photo['url'] as string;
  end;
end;

function loadNext(): JsonArr;
begin
  var response := request('GET', 'feed/new', '')['response'] as Json;
  try
    Result := response['items'] as JsonArr;
  except
    writeln(response['items']);
    Result := nil;
  end;
end;

procedure next(sender: object; e: EventArgs);
begin
  if (not request_started) then
  if (index >= list.Count-1) then
    begin
      request_started := true;
      
      {$opt: pharallel sections}
      begin
        begin
          var lst := loadNext();
          list.AddRange(lst);
          
          request_started := false;
          next(nil, nil);
        end;
      end;
    end else begin
      index += 1;
      draw();
    end;
end;

procedure previous(sender: object; e: EventArgs);
begin
  if index > 0 then
  begin
    index -= 1;
    draw();
  end;
end;

procedure openInBrowserHandler(sender: object; e: EventArgs);
begin
  var item := list[index] as Json;
  Exec('explorer', 'https://zation.ru/post'+(item['owner_id'].ToString()) +'_'+(item['id'].ToString()));
end;

begin
  form.Size := new System.Drawing.Size(400, 600);
  form.Text := 'Zation';
  
  var nextBtn := new Button();
  nextBtn.Dock := DockStyle.Bottom;
  nextBtn.Text := 'Дальше';
  nextBtn.Click += next;
  
  var openInBrowserBtn := new Button();
  openInBrowserBtn.Dock := DockStyle.Bottom;
  openInBrowserBtn.Text := 'Открыть в Браузере';
  openInBrowserBtn.Click += openInBrowserHandler;
  
  text.Size := form.Size;
  
  form.Controls.Add(nextBtn);
  form.Controls.Add(openInBrowserBtn);
  form.Controls.Add(text);
  form.Controls.Add(picture);
  

  next(nil, nil);
  
  Application.Run(form);
  writeln();
end.