import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../domain/models.dart';

bool get windowsAcquisitionAvailable => Platform.isWindows;
String get _powershell =>
    (Platform.environment['SystemRoot'] ?? r'C:\Windows') +
    r'\System32\WindowsPowerShell\v1.0\powershell.exe';
List<String> _command(String script) => [
  '-NoLogo',
  '-NoProfile',
  '-NonInteractive',
  '-STA',
  '-Command',
  script,
];

Future<List<Uint8List>?> acquireWindowsPage(int limit) async {
  if (!windowsAcquisitionAvailable || limit < 1) return null;
  final directory = await Directory.systemTemp.createTemp('flex-scan-');
  try {
    final file = File('${directory.path}${Platform.pathSeparator}seite.jpg');
    final result = await Process.run(
      _powershell,
      _command(r'''
$ErrorActionPreference = 'Stop'
try {
  $dialog = New-Object -ComObject WIA.CommonDialog
  $image = $dialog.ShowAcquireImage(0,0,0,'{B96B3CAE-0728-11D3-9D7B-0000F81EF32E}',$true,$true,$false)
  if ($null -ne $image) {
    $converter = New-Object -ComObject WIA.ImageProcess
    $converter.Filters.Add($converter.FilterInfos.Item('Convert').FilterID)
    $converter.Filters.Item(1).Properties.Item('FormatID').Value = '{B96B3CAE-0728-11D3-9D7B-0000F81EF32E}'
    $converter.Apply($image).SaveFile($env:FLEX_SCAN_OUTPUT)
  }
} catch { exit 1 }
'''),
      environment: {'FLEX_SCAN_OUTPUT': file.path},
    );
    if (result.exitCode != 0) {
      throw const DomainError(
        'Windows konnte den Scanner nicht öffnen. Prüfe den WIA-Treiber oder importiere eine Bilddatei.',
      );
    }
    if (!await file.exists()) return null;
    if (await file.length() > 25 * 1024 * 1024) {
      throw const DomainError(
        'Der Scan ist zu groß. Bitte eine niedrigere Auflösung wählen.',
      );
    }
    return [await file.readAsBytes()];
  } finally {
    await directory.delete(recursive: true);
  }
}

Future<({Future<String> result, void Function() stop, void Function() cancel})>
startWindowsSpeech(String language) async {
  final dir = await Directory.systemTemp.createTemp('flex-voice-');
  final stopFile = File.fromUri(dir.uri.resolve('stop'));
  late final Process process;
  try {
    process = await Process.start(
      _powershell,
      _command(r'''
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
try {
  Add-Type -AssemblyName System.Speech
  $all = [System.Speech.Recognition.SpeechRecognitionEngine]::InstalledRecognizers()
  $voice = $all | Where-Object {$_.Culture.Name -eq $env:FLEX_SPEECH_LANGUAGE} | Select-Object -First 1
  if (-not $voice) {$voice = $all | Where-Object {$_.Culture.TwoLetterISOLanguageName -eq $env:FLEX_SPEECH_LANGUAGE.Substring(0,2)} | Select-Object -First 1}
  if (-not $voice) {exit 2}
  $engine = [System.Speech.Recognition.SpeechRecognitionEngine]::new($voice)
  $engine.LoadGrammar((New-Object System.Speech.Recognition.DictationGrammar))
  $engine.SetInputToDefaultAudioDevice()
  Register-ObjectEvent $engine SpeechRecognized -SourceIdentifier flexPhrase | Out-Null
  Register-ObjectEvent $engine RecognizeCompleted -SourceIdentifier flexDone | Out-Null
  $engine.RecognizeAsync([System.Speech.Recognition.RecognizeMode]::Single)
  $limit = [DateTime]::UtcNow.AddSeconds(60)
  $stopping = $false
  while ([DateTime]::UtcNow -lt $limit) {
    if ((Test-Path -LiteralPath $env:FLEX_SPEECH_STOP) -and -not $stopping) {$stopping = $true; $engine.RecognizeAsyncStop()}
    $event = Get-Event | Select-Object -First 1
    if (-not $event) {Start-Sleep -Milliseconds 80; continue}
    Remove-Event -EventIdentifier $event.EventIdentifier
    if ($event.SourceIdentifier -eq 'flexPhrase') {[Console]::WriteLine($event.SourceEventArgs.Result.Text)}
    if ($event.SourceIdentifier -eq 'flexDone') {break}
  }
  $engine.Dispose()
} catch {exit 1}
'''),
      environment: {
        'FLEX_SPEECH_LANGUAGE': language,
        'FLEX_SPEECH_STOP': stopFile.path,
      },
    );
  } catch (_) {
    await dir.delete(recursive: true);
    rethrow;
  }
  final output = process.stdout.transform(utf8.decoder).join();
  final errors = process.stderr.drain<void>();
  Future<String> result() async {
    final code = await process.exitCode;
    await dir.delete(recursive: true);
    await errors;
    final text = (await output).trim();
    if (code != 0) {
      throw DomainError(
        code == 2
            ? 'Für diese Sprache ist auf Windows keine lokale Spracherkennung installiert.'
            : 'Windows konnte die Spracherkennung nicht starten. Bitte Mikrofon und Spracheinstellungen prüfen.',
      );
    }
    return text;
  }

  return (
    result: result(),
    stop: () {
      if (dir.existsSync()) stopFile.writeAsBytesSync([]);
    },
    cancel: () {
      process.kill();
    },
  );
}
