var infPath = "E:\\Win8\\AMD64\\*.inf"

var ws = new ActiveXObject("WScript.Shell");
ws.Run("pnputil -i -a " + infPath);

var interval = 3000;

for (var i = 0; i < 3; i++) {
    WScript.Sleep(interval);
    ws.AppActivate("Windows Security");
    ws.SendKeys("i");
}
